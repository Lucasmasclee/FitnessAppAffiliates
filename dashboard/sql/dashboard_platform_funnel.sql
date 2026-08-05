-- Platform funnel (iOS / Android) for the developer dashboard.
-- Unique users per step (dashboard_analytics_user_key).

drop function if exists public.dashboard_platform_funnel(timestamptz, timestamptz);

create or replace function public.dashboard_platform_funnel(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  platform text,
  onboarding_started bigint,
  paywall_views bigint,
  subscriptions bigint,
  plan_selected bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with platforms as (
    select unnest(array['ios', 'android']::text[]) as platform
  ),
  counts as (
    select
      lower(coalesce(e.platform, '')) as platform,
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
      )) filter (where e.event_name = 'purchase_success')::bigint as subscriptions,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'paywall_plan_selected')::bigint as plan_selected
    from public.analytics_events e
    where e.created_at >= p_from
      and e.created_at < p_to
      and lower(coalesce(e.platform, '')) in ('ios', 'android')
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  )
  select
    p.platform,
    coalesce(c.onboarding_started, 0)::bigint as onboarding_started,
    coalesce(c.paywall_views, 0)::bigint as paywall_views,
    coalesce(c.subscriptions, 0)::bigint as subscriptions,
    coalesce(c.plan_selected, 0)::bigint as plan_selected
  from platforms p
  left join counts c on c.platform = p.platform
  order by p.platform;
$$;

comment on function public.dashboard_platform_funnel(timestamptz, timestamptz) is
  'Unique-user onboarding / paywall / subscription counts by platform for [p_from, p_to).';

grant execute on function public.dashboard_platform_funnel(timestamptz, timestamptz)
  to anon, authenticated, service_role;
