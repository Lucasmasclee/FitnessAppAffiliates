-- Daily conversion funnel counts for the developer dashboard.
-- Unique users per day per step.

drop function if exists public.dashboard_daily_conversions(timestamptz, timestamptz);

create or replace function public.dashboard_daily_conversions(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  day date,
  onboarding_started bigint,
  paywall_views bigint,
  subscriptions bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with days as (
    select generate_series(
      (p_from at time zone 'utc')::date,
      ((p_to - interval '1 microsecond') at time zone 'utc')::date,
      interval '1 day'
    )::date as day
  ),
  counts as (
    select
      (e.created_at at time zone 'utc')::date as day,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'onboarding_started')::bigint as onboarding_started,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'paywall_viewed')::bigint as paywall_views,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'purchase_success')::bigint as subscriptions
    from public.analytics_events e
    where e.event_name in (
        'onboarding_started',
        'paywall_viewed',
        'purchase_success'
      )
      and e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  )
  select
    d.day,
    coalesce(c.onboarding_started, 0)::bigint as onboarding_started,
    coalesce(c.paywall_views, 0)::bigint as paywall_views,
    coalesce(c.subscriptions, 0)::bigint as subscriptions
  from days d
  left join counts c on c.day = d.day
  order by d.day;
$$;

comment on function public.dashboard_daily_conversions(timestamptz, timestamptz) is
  'Daily unique-user onboarding / paywall / purchase counts for [p_from, p_to).';

grant execute on function public.dashboard_daily_conversions(timestamptz, timestamptz)
  to anon, authenticated, service_role;
