-- Overall (all-sources) funnel steps for the developer dashboard.
-- clicks = affiliate_click_events in range (occurred_at) — raw click events.
-- analytics steps = unique users (dashboard_analytics_user_key) in range.
-- plan_selected = unique users with >=1 plan selection (unchanged).

drop function if exists public.dashboard_overall_funnel(timestamptz, timestamptz);

create or replace function public.dashboard_overall_funnel(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
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
  select
    (
      select count(*)::bigint
      from public.affiliate_click_events c
      where c.occurred_at >= p_from
        and c.occurred_at < p_to
    ) as clicks,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'attribution_received'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as downloads,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'onboarding_started'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as survey_started,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'onboarding_completed'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as survey_ended,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'paywall_viewed'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as paywall_views,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'paywall_plan_selected'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as plan_selected,
    (
      select count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      ))::bigint
      from public.analytics_events e
      where e.event_name = 'purchase_success'
        and e.created_at >= p_from
        and e.created_at < p_to
        and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    ) as subscriptions;
$$;

comment on function public.dashboard_overall_funnel(timestamptz, timestamptz) is
  'Overall funnel unique-user totals for [p_from, p_to). clicks = raw affiliate clicks.';

grant execute on function public.dashboard_overall_funnel(timestamptz, timestamptz)
  to anon, authenticated, service_role;
