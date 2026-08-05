-- Acquisition funnel for the developer dashboard (one row per source).
-- analytics metrics = unique users (dashboard_analytics_user_key).
-- Affiliate clicks = affiliate_stats.clicks (lifetime totals; not date-ranged).

drop function if exists public.dashboard_acquisition_funnel();
drop function if exists public.dashboard_acquisition_funnel(timestamptz, timestamptz);

create or replace function public.dashboard_acquisition_funnel(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  source_id text,
  source_label text,
  impressions bigint,
  product_page_views bigint,
  clicks bigint,
  downloads bigint,
  app_opens bigint,
  paywall_views bigint,
  subscriptions bigint,
  impressions_status text,
  product_page_views_status text,
  clicks_status text,
  downloads_status text,
  app_opens_status text,
  paywall_views_status text,
  subscriptions_status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_reddit_downloads bigint := 0;
  v_reddit_opens bigint := 0;
  v_reddit_paywall bigint := 0;
  v_reddit_subs bigint := 0;
begin
  with reddit_users as (
    select distinct public.dashboard_analytics_user_key(
      r.analytics_user_id,
      r.anonymous_id
    ) as uk
    from public.analytics_events r
    where r.event_name = 'reddit_install_attributed'
      and r.created_at < p_to
      and public.dashboard_analytics_user_key(r.analytics_user_id, r.anonymous_id) is not null
  ),
  reddit_events as (
    select
      e.event_name,
      public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) as uk
    from public.analytics_events e
    where e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
      and (
        e.event_name = 'reddit_install_attributed'
        or (
          e.event_name in ('onboarding_started', 'paywall_viewed', 'purchase_success')
          and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id)
            in (select uk from reddit_users)
        )
      )
  )
  select
    count(distinct uk) filter (where event_name = 'reddit_install_attributed'),
    count(distinct uk) filter (where event_name = 'onboarding_started'),
    count(distinct uk) filter (where event_name = 'paywall_viewed'),
    count(distinct uk) filter (where event_name = 'purchase_success')
  into
    v_reddit_downloads,
    v_reddit_opens,
    v_reddit_paywall,
    v_reddit_subs
  from reddit_events;

  return query
  with codes as (
    select *
    from (values
      ('app'::text, 'AppAccount'::text, 'app'::text),
      ('download', 'Lennard TikTok & Insta', 'download'),
      ('lennard', 'Lennard YT', 'lennard'),
      ('lm10', 'Lucas TikTok & YT', 'lm10')
    ) as t(id, label, affiliate_code)
  ),
  affiliate_event_metrics as (
    select
      c.id as sid,
      c.label as slabel,
      c.affiliate_code,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'attribution_received') as dl,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'onboarding_started') as opens,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'paywall_viewed') as paywalls,
      count(distinct public.dashboard_analytics_user_key(
        e.analytics_user_id,
        e.anonymous_id
      )) filter (where e.event_name = 'purchase_success') as subs
    from codes c
    left join public.analytics_events e
      on (
        lower(coalesce(e.campaign, '')) = c.affiliate_code
        or lower(coalesce(e.properties ->> 'affiliate_code', '')) = c.affiliate_code
      )
      and e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
    group by c.id, c.label, c.affiliate_code
  ),
  affiliate_click_stats as (
    select
      lower(s.affiliate_code) as affiliate_code,
      coalesce(s.clicks, 0)::bigint as clicks
    from public.affiliate_stats s
    where lower(s.affiliate_code) in ('app', 'download', 'lennard', 'lm10')
  )
  select
    m.sid,
    m.slabel,
    null::bigint,
    null::bigint,
    coalesce(cs.clicks, 0)::bigint,
    coalesce(m.dl, 0)::bigint,
    coalesce(m.opens, 0)::bigint,
    coalesce(m.paywalls, 0)::bigint,
    coalesce(m.subs, 0)::bigint,
    'unavailable'::text,
    'unavailable'::text,
    'ok'::text,
    'ok'::text,
    'ok'::text,
    'ok'::text,
    'ok'::text
  from affiliate_event_metrics m
  left join affiliate_click_stats cs on cs.affiliate_code = m.affiliate_code

  union all

  select
    'reddit_ads'::text,
    'Reddit Ads'::text,
    null::bigint,
    null::bigint,
    null::bigint,
    coalesce(v_reddit_downloads, 0)::bigint,
    coalesce(v_reddit_opens, 0)::bigint,
    coalesce(v_reddit_paywall, 0)::bigint,
    coalesce(v_reddit_subs, 0)::bigint,
    'unavailable'::text,
    'unavailable'::text,
    'unavailable'::text,
    'ok'::text,
    'ok'::text,
    'ok'::text,
    'ok'::text

  union all

  select
    'asc_search'::text,
    'App Store Search'::text,
    null::bigint,
    null::bigint,
    null::bigint,
    null::bigint,
    null::bigint,
    null::bigint,
    null::bigint,
    'pending_asc_api'::text,
    'pending_asc_api'::text,
    'pending_asc_api'::text,
    'pending_asc_api'::text,
    'unavailable'::text,
    'unavailable'::text,
    'unavailable'::text;
end;
$$;

comment on function public.dashboard_acquisition_funnel(timestamptz, timestamptz) is
  'Developer dashboard acquisition funnel by source for [p_from, p_to). Analytics = unique users.';

grant execute on function public.dashboard_acquisition_funnel(timestamptz, timestamptz)
  to anon, authenticated, service_role;
