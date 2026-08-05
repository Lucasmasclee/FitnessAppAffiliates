-- Free-trial dashboard metrics using existing analytics events only.
-- Trial starters are approximated from purchase_success in [p_from, p_to).
-- If has_free_trial_offer exists on any purchase_success row in range, only true rows count.

drop function if exists public.dashboard_trial_stats(timestamptz, timestamptz);

create or replace function public.dashboard_trial_stats(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  trial_starters bigint,
  app_open_d1 bigint,
  app_open_d2 bigint,
  app_open_d3 bigint,
  app_open_total_after_d3 bigint,
  app_open_d4 bigint,
  app_open_d5 bigint,
  app_open_d6 bigint,
  app_open_d7 bigint,
  app_open_d10 bigint,
  app_open_d14 bigint,
  workout_started_trial bigint,
  workout_2nd_started_trial bigint,
  workout_3rd_started_trial bigint,
  workout_5_started_trial bigint,
  workout_7_started_trial bigint,
  workout_10_started_trial bigint,
  workout_15_started_trial bigint,
  workout_20_started_trial bigint,
  used_free_trial_flag boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with purchase_rows as (
    select
      public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) as user_key,
      e.created_at,
      e.properties
    from public.analytics_events e
    where e.event_name = 'purchase_success'
      and e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
  ),
  cohort_mode as (
    select exists (
      select 1
      from purchase_rows pr
      where pr.properties ? 'has_free_trial_offer'
    ) as used_free_trial_flag
  ),
  trial_starts as (
    select
      pr.user_key,
      min(pr.created_at) as trial_start_at
    from purchase_rows pr
    cross join cohort_mode cm
    where not cm.used_free_trial_flag
      or lower(coalesce(pr.properties ->> 'has_free_trial_offer', 'false')) = 'true'
    group by pr.user_key
  ),
  app_open_hits as (
    select distinct
      ts.user_key,
      ((e.created_at at time zone 'utc')::date - (ts.trial_start_at at time zone 'utc')::date) as day_offset
    from trial_starts ts
    join public.analytics_events e
      on public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) = ts.user_key
    where e.event_name = 'weekplanning_viewed'
      and ((e.created_at at time zone 'utc')::date - (ts.trial_start_at at time zone 'utc')::date)
        in (1, 2, 3, 4, 5, 6, 7, 10, 14)
  ),
  app_open_counts as (
    select
      count(*) filter (where day_offset = 1) as app_open_d1,
      count(*) filter (where day_offset = 2) as app_open_d2,
      count(*) filter (where day_offset = 3) as app_open_d3,
      count(*) filter (where day_offset = 4) as app_open_d4,
      count(*) filter (where day_offset = 5) as app_open_d5,
      count(*) filter (where day_offset = 6) as app_open_d6,
      count(*) filter (where day_offset = 7) as app_open_d7,
      count(*) filter (where day_offset = 10) as app_open_d10,
      count(*) filter (where day_offset = 14) as app_open_d14
    from app_open_hits
  ),
  app_open_after_d3_users as (
    select distinct ts.user_key
    from trial_starts ts
    join public.analytics_events e
      on public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) = ts.user_key
    where e.event_name = 'weekplanning_viewed'
      and e.created_at >= ts.trial_start_at + interval '3 days 5 minutes'
  ),
  exercise_entry_day_counts as (
    select
      ts.user_key,
      count(
        distinct (e.created_at at time zone 'utc')::date
      ) as active_day_count
    from trial_starts ts
    join public.analytics_events e
      on public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) = ts.user_key
    where e.event_name = 'exercise_entry_saved'
      and e.created_at >= ts.trial_start_at
    group by ts.user_key
  )
  select
    (select count(*)::bigint from trial_starts) as trial_starters,
    coalesce((select app_open_d1 from app_open_counts), 0)::bigint as app_open_d1,
    coalesce((select app_open_d2 from app_open_counts), 0)::bigint as app_open_d2,
    coalesce((select app_open_d3 from app_open_counts), 0)::bigint as app_open_d3,
    (select count(*)::bigint from app_open_after_d3_users) as app_open_total_after_d3,
    coalesce((select app_open_d4 from app_open_counts), 0)::bigint as app_open_d4,
    coalesce((select app_open_d5 from app_open_counts), 0)::bigint as app_open_d5,
    coalesce((select app_open_d6 from app_open_counts), 0)::bigint as app_open_d6,
    coalesce((select app_open_d7 from app_open_counts), 0)::bigint as app_open_d7,
    coalesce((select app_open_d10 from app_open_counts), 0)::bigint as app_open_d10,
    coalesce((select app_open_d14 from app_open_counts), 0)::bigint as app_open_d14,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 1) as workout_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 2) as workout_2nd_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 3) as workout_3rd_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 5) as workout_5_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 7) as workout_7_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 10) as workout_10_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 15) as workout_15_started_trial,
    (select count(*)::bigint from exercise_entry_day_counts where active_day_count >= 20) as workout_20_started_trial,
    (select used_free_trial_flag from cohort_mode) as used_free_trial_flag;
$$;

comment on function public.dashboard_trial_stats(timestamptz, timestamptz) is
  'Free-trial dashboard stats for [p_from, p_to): trial starters, weekplanning_viewed retention, exercise_entry_saved on distinct days after trial start.';

grant execute on function public.dashboard_trial_stats(timestamptz, timestamptz)
  to anon, authenticated, service_role;
