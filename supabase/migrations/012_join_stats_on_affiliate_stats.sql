-- Join landing page aggregates on affiliate_stats (queryable in Supabase)

alter table public.affiliate_stats
  add column if not exists join_page_views bigint not null default 0;

alter table public.affiliate_stats
  add column if not exists join_cta_clicks bigint not null default 0;

comment on column public.affiliate_stats.join_page_views is
  'Page visits on /join/{affiliate_code} (one per browser session).';

comment on column public.affiliate_stats.join_cta_clicks is
  'CTA button clicks on /join/{affiliate_code}.';

-- Site-wide totals (no affiliate code or all traffic)
create table if not exists public.join_landing_totals (
  id smallint primary key default 1 check (id = 1),
  page_views bigint not null default 0,
  cta_clicks bigint not null default 0,
  updated_at timestamptz not null default now()
);

comment on table public.join_landing_totals is
  'Global /join landing page totals. View in Supabase Table Editor (single row, id=1).';

insert into public.join_landing_totals (id, page_views, cta_clicks)
values (1, 0, 0)
on conflict (id) do nothing;

alter table public.join_landing_totals enable row level security;
