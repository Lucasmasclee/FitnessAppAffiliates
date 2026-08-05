-- Survey onboarding step views for the developer dashboard.
-- Unique users per screen (viewed or completed at least once).

drop function if exists public.dashboard_survey_step_views(timestamptz, timestamptz);

create or replace function public.dashboard_survey_step_views(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  step_index int,
  screen text,
  views bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with screens as (
    select *
    from (values
      (0, 'intro'),
      (1, 'goal'),
      (3, 'biggest_challenge'),
      (4, 'transformation_proof'),
      (8, 'training_experience'),
      (9, 'gym_confidence'),
      (10, 'training_frequency'),
      (11, 'available_days'),
      (12, 'split_selection'),
      (13, 'week_schedule_preview'),
      (14, 'muscle_focus_depth_choice'),
      (15, 'muscle_focus_simple'),
      (16, 'muscle_priority'),
      (17, 'plan_generation'),
      (18, 'extra_help_features'),
      (19, 'paywall_planned_workouts'),
      (20, 'workout_notification_opt_in'),
      (21, 'paywall_guidance'),
      (27, 'paywall_purchase')
    ) as t(step_index, screen)
  ),
  counts as (
    select
      coalesce(nullif(btrim(e.properties ->> 'step_name'), ''), 'unknown') as screen,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint as views
    from public.analytics_events e
    where e.event_name in ('onboarding_step_viewed', 'onboarding_step_completed')
      and e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  )
  select
    s.step_index,
    s.screen,
    coalesce(c.views, 0)::bigint as views
  from screens s
  left join counts c on c.screen = s.screen
  order by s.step_index;
$$;

comment on function public.dashboard_survey_step_views(timestamptz, timestamptz) is
  'Unique users per survey screen (viewed or completed) for [p_from, p_to).';

grant execute on function public.dashboard_survey_step_views(timestamptz, timestamptz)
  to anon, authenticated, service_role;
