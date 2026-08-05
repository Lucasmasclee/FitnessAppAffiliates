-- Rolling 7-day free-trial -> sub conversion per chart day.
-- For anchor day D: trial cohort = purchase_success on UTC dates [D-7, D].
-- Conversion = users with weekplanning_viewed >= trial_start + 3d 5m / trial starters.

drop function if exists public.dashboard_daily_trial_to_sub(timestamptz, timestamptz);

create or replace function public.dashboard_daily_trial_to_sub(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  day date,
  trial_starters bigint,
  app_open_total_after_d3 bigint,
  trial_to_sub_pct numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select
      (p_from at time zone 'utc')::date as range_from,
      ((p_to - interval '1 microsecond') at time zone 'utc')::date as range_to
  ),
  days as (
    select generate_series(b.range_from, b.range_to, interval '1 day')::date as day
    from bounds b
  ),
  purchase_rows as (
    select
      public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) as user_key,
      e.created_at,
      e.properties
    from public.analytics_events e
    cross join bounds b
    where e.event_name = 'purchase_success'
      and e.created_at >= ((b.range_from - 7) at time zone 'utc')
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
  ),
  window_purchases as (
    select
      d.day as anchor_day,
      pr.user_key,
      pr.created_at,
      pr.properties
    from days d
    join purchase_rows pr
      on (pr.created_at at time zone 'utc')::date between d.day - 7 and d.day
  ),
  cohort_mode as (
    select
      d.day as anchor_day,
      exists (
        select 1
        from window_purchases wp
        where wp.anchor_day = d.day
          and wp.properties ? 'has_free_trial_offer'
      ) as used_free_trial_flag
    from days d
  ),
  trial_starts as (
    select
      wp.anchor_day,
      wp.user_key,
      min(wp.created_at) as trial_start_at
    from window_purchases wp
    join cohort_mode cm on cm.anchor_day = wp.anchor_day
    where not cm.used_free_trial_flag
      or lower(coalesce(wp.properties ->> 'has_free_trial_offer', 'false')) = 'true'
    group by wp.anchor_day, wp.user_key
  ),
  app_open_after_d3_users as (
    select distinct
      ts.anchor_day,
      ts.user_key
    from trial_starts ts
    join public.analytics_events e
      on public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) = ts.user_key
    where e.event_name = 'weekplanning_viewed'
      and e.created_at >= ts.trial_start_at + interval '3 days 5 minutes'
  ),
  daily_counts as (
    select
      ts.anchor_day as day,
      count(*)::bigint as trial_starters,
      count(distinct ao.user_key)::bigint as app_open_total_after_d3
    from trial_starts ts
    left join app_open_after_d3_users ao
      on ao.anchor_day = ts.anchor_day
     and ao.user_key = ts.user_key
    group by ts.anchor_day
  )
  select
    d.day,
    coalesce(dc.trial_starters, 0)::bigint as trial_starters,
    coalesce(dc.app_open_total_after_d3, 0)::bigint as app_open_total_after_d3,
    round(
      coalesce(dc.app_open_total_after_d3, 0)::numeric
        / nullif(coalesce(dc.trial_starters, 0), 0)
        * 100,
      2
    ) as trial_to_sub_pct
  from days d
  left join daily_counts dc on dc.day = d.day
  order by d.day;
$$;

comment on function public.dashboard_daily_trial_to_sub(timestamptz, timestamptz) is
  'Rolling 7-day trial->sub % per UTC day: opens after D+3 / trial starters from purchase_success in [day-7, day].';

grant execute on function public.dashboard_daily_trial_to_sub(timestamptz, timestamptz)
  to anon, authenticated, service_role;
