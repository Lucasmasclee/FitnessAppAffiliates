-- Join landing page analytics (page views & CTA clicks)

create table if not exists public.join_page_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('page_view', 'cta_click')),
  affiliate_code text,
  page_path text,
  occurred_at timestamptz not null default now()
);

comment on table public.join_page_events is
  'Events from the /join landing page: page_view and cta_click, optionally tagged with affiliate_code from the URL.';

create index if not exists idx_join_page_events_occurred_at
  on public.join_page_events (occurred_at desc);

create index if not exists idx_join_page_events_type_occurred_at
  on public.join_page_events (event_type, occurred_at desc);

create index if not exists idx_join_page_events_affiliate_code
  on public.join_page_events (affiliate_code)
  where affiliate_code is not null;

alter table public.join_page_events enable row level security;

-- No public read/write via anon key; Edge Functions use service role.
