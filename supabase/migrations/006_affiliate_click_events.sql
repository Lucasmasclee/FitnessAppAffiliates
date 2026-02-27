-- Event-tabel voor individuele affiliate-clicks (voor tijdsreeksen & analytics)

create table if not exists public.affiliate_click_events (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  platform text,
  occurred_at timestamptz not null default now()
);

comment on table public.affiliate_click_events is
  'Elke click op een affiliate-link (via Branch of redirect), met timestamp en optioneel platform, voor tijdsgrafieken.';

create index if not exists idx_affiliate_click_events_affiliate_id_occurred_at
  on public.affiliate_click_events(affiliate_id, occurred_at desc);

alter table public.affiliate_click_events enable row level security;

drop policy if exists "Users can read own click events" on public.affiliate_click_events;
create policy "Users can read own click events"
  on public.affiliate_click_events for select
  using (
    affiliate_id in (
      select id from public.affiliates where user_id = auth.uid()
    )
  );

