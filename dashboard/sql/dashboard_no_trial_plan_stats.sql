-- No-trial follow-up metrics after plan_generation_completed (separate RPC for performance).
-- Cohort: plan_generation_completed in [p_from, p_to), earliest timestamp per user.

drop function if exists public.dashboard_no_trial_plan_stats(timestamptz, timestamptz);

create or replace function public.dashboard_no_trial_plan_stats(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  plan_generations_completed bigint,
  no_trial_came_back_after_12h bigint,
  no_trial_trial_after_12h bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with plan_completed_cohort as (
    select
      public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) as user_key,
      min(e.created_at) as plan_completed_at
    from public.analytics_events e
    where e.event_name = 'plan_generation_completed'
      and e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  ),
  plan_follow_up_events as (
    select
      pc.user_key,
      pc.plan_completed_at,
      e.created_at,
      e.event_name
    from plan_completed_cohort pc
    join public.analytics_events e
      on public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) = pc.user_key
      and e.created_at >= pc.plan_completed_at
  ),
  plan_completed_flags as (
    select
      pc.user_key,
      coalesce(
        bool_or(
          pfe.event_name = 'purchase_success'
          and pfe.created_at < pc.plan_completed_at + interval '12 hours'
        ),
        false
      ) as purchased_within_12h,
      coalesce(
        bool_or(pfe.created_at >= pc.plan_completed_at + interval '12 hours'),
        false
      ) as any_event_after_12h,
      coalesce(
        bool_or(
          pfe.event_name = 'purchase_success'
          and pfe.created_at >= pc.plan_completed_at + interval '12 hours'
        ),
        false
      ) as purchased_after_12h
    from plan_completed_cohort pc
    left join plan_follow_up_events pfe
      on pfe.user_key = pc.user_key
    group by pc.user_key, pc.plan_completed_at
  )
  select
    (select count(*)::bigint from plan_completed_cohort) as plan_generations_completed,
    count(*) filter (
      where not purchased_within_12h and any_event_after_12h
    )::bigint as no_trial_came_back_after_12h,
    count(*) filter (
      where not purchased_within_12h and purchased_after_12h
    )::bigint as no_trial_trial_after_12h
  from plan_completed_flags;
$$;

comment on function public.dashboard_no_trial_plan_stats(timestamptz, timestamptz) is
  'Users with plan_generation_completed in range: no purchase_success within 12h, then came back (any event) or purchased after 12h.';

grant execute on function public.dashboard_no_trial_plan_stats(timestamptz, timestamptz)
  to anon, authenticated, service_role;
