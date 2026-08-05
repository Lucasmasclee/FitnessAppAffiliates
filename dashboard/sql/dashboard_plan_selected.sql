-- Plan selected counts (paywall_plan_selected) for the developer dashboard.
-- "selected" = total events; "unique" = distinct users per plan (each user counts once per plan).

drop function if exists public.dashboard_plan_selected(timestamptz, timestamptz);

create or replace function public.dashboard_plan_selected(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  monthly bigint,
  quarterly bigint,
  yearly bigint,
  lifetime bigint,
  unique_monthly bigint,
  unique_quarterly bigint,
  unique_yearly bigint,
  unique_lifetime bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'monthly'
    )::bigint as monthly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'quarterly'
    )::bigint as quarterly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'yearly'
    )::bigint as yearly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'lifetime'
    )::bigint as lifetime,
    count(distinct public.dashboard_analytics_user_key(
      e.analytics_user_id,
      e.anonymous_id
    )) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'monthly'
    )::bigint as unique_monthly,
    count(distinct public.dashboard_analytics_user_key(
      e.analytics_user_id,
      e.anonymous_id
    )) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'quarterly'
    )::bigint as unique_quarterly,
    count(distinct public.dashboard_analytics_user_key(
      e.analytics_user_id,
      e.anonymous_id
    )) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'yearly'
    )::bigint as unique_yearly,
    count(distinct public.dashboard_analytics_user_key(
      e.analytics_user_id,
      e.anonymous_id
    )) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'lifetime'
    )::bigint as unique_lifetime
  from public.analytics_events e
  where e.event_name = 'paywall_plan_selected'
    and e.created_at >= p_from
    and e.created_at < p_to;
$$;

comment on function public.dashboard_plan_selected(timestamptz, timestamptz) is
  'paywall_plan_selected totals and unique-user counts by plan for [p_from, p_to).';

grant execute on function public.dashboard_plan_selected(timestamptz, timestamptz)
  to anon, authenticated, service_role;
