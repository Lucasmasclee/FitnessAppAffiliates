-- Completed subscription split (purchase_success) by plan for the developer dashboard.
-- Used for display-only "Current split" row (monthly vs yearly); not for ARPPC math.

drop function if exists public.dashboard_subscription_plan_split(timestamptz, timestamptz);

create or replace function public.dashboard_subscription_plan_split(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  monthly bigint,
  yearly bigint,
  ios_monthly bigint,
  ios_yearly bigint,
  android_monthly bigint,
  android_yearly bigint
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
      where lower(btrim(e.properties ->> 'selected_plan')) = 'yearly'
    )::bigint as yearly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'monthly'
        and lower(coalesce(e.platform, '')) = 'ios'
    )::bigint as ios_monthly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'yearly'
        and lower(coalesce(e.platform, '')) = 'ios'
    )::bigint as ios_yearly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'monthly'
        and lower(coalesce(e.platform, '')) = 'android'
    )::bigint as android_monthly,
    count(*) filter (
      where lower(btrim(e.properties ->> 'selected_plan')) = 'yearly'
        and lower(coalesce(e.platform, '')) = 'android'
    )::bigint as android_yearly
  from public.analytics_events e
  where e.event_name = 'purchase_success'
    and e.created_at >= p_from
    and e.created_at < p_to
    and lower(btrim(coalesce(e.properties ->> 'selected_plan', ''))) in ('monthly', 'yearly');
$$;

comment on function public.dashboard_subscription_plan_split(timestamptz, timestamptz) is
  'purchase_success counts for monthly/yearly plans (total + ios/android) for [p_from, p_to).';

grant execute on function public.dashboard_subscription_plan_split(timestamptz, timestamptz)
  to anon, authenticated, service_role;
