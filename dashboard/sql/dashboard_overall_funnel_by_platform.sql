-- Overall funnel steps split by platform (iOS / Android) for the developer dashboard.
-- analytics steps = unique users; clicks = raw affiliate click events.

drop function if exists public.dashboard_overall_funnel_by_platform(timestamptz, timestamptz);

create or replace function public.dashboard_overall_funnel_by_platform(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  platform text,
  clicks bigint,
  downloads bigint,
  survey_started bigint,
  survey_ended bigint,
  paywall_views bigint,
  plan_selected bigint,
  subscriptions bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with platforms as (
    select unnest(array['ios', 'android']::text[]) as platform
  ),
  click_counts as (
    select
      lower(coalesce(c.platform, '')) as platform,
      count(*)::bigint as clicks
    from public.affiliate_click_events c
    where c.occurred_at >= p_from
      and c.occurred_at < p_to
      and lower(coalesce(c.platform, '')) in ('ios', 'android')
    group by 1
  ),
  event_counts as (
    select
      lower(coalesce(e.platform, '')) as platform,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'attribution_received')::bigint as downloads,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'onboarding_started')::bigint as survey_started,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'onboarding_completed')::bigint as survey_ended,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'paywall_viewed')::bigint as paywall_views,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'purchase_success')::bigint as subscriptions
    from public.analytics_events e
    where e.created_at >= p_from
      and e.created_at < p_to
      and lower(coalesce(e.platform, '')) in ('ios', 'android')
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  ),
  plan_selected_counts as (
    select
      lower(coalesce(e.platform, '')) as platform,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint as plan_selected
    from public.analytics_events e
    where e.event_name = 'paywall_plan_selected'
      and e.created_at >= p_from
      and e.created_at < p_to
      and lower(coalesce(e.platform, '')) in ('ios', 'android')
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by 1
  )
  select
    p.platform,
    coalesce(cc.clicks, 0)::bigint as clicks,
    coalesce(ec.downloads, 0)::bigint as downloads,
    coalesce(ec.survey_started, 0)::bigint as survey_started,
    coalesce(ec.survey_ended, 0)::bigint as survey_ended,
    coalesce(ec.paywall_views, 0)::bigint as paywall_views,
    coalesce(ps.plan_selected, 0)::bigint as plan_selected,
    coalesce(ec.subscriptions, 0)::bigint as subscriptions
  from platforms p
  left join click_counts cc on cc.platform = p.platform
  left join event_counts ec on ec.platform = p.platform
  left join plan_selected_counts ps on ps.platform = p.platform
  order by p.platform;
$$;

comment on function public.dashboard_overall_funnel_by_platform(timestamptz, timestamptz) is
  'Overall funnel unique-user totals by platform (ios/android) for [p_from, p_to).';

grant execute on function public.dashboard_overall_funnel_by_platform(timestamptz, timestamptz)
  to anon, authenticated, service_role;
