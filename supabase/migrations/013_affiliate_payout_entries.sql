-- Handmatige payout-entries per affiliate (beheer via Supabase Table Editor)

create table if not exists public.affiliate_payout_entries (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,

  -- Tekst die de affiliate in het dashboard ziet (bijv. "June 2026 · €45.00 · Bank transfer")
  entry_text text not null,

  -- Optioneel bedrag voor "Paid out (all time)" in het dashboard
  amount numeric(10, 2),

  -- Datum voor sortering (nieuwste bovenaan); standaard vandaag
  payout_date timestamptz not null default now(),

  created_at timestamptz not null default now()
);

comment on table public.affiliate_payout_entries is
  'Handmatige payout-regels per affiliate. Voeg rijen toe via Supabase Table Editor.';

comment on column public.affiliate_payout_entries.affiliate_id is
  'Kies de affiliate (foreign key naar affiliates.id).';

comment on column public.affiliate_payout_entries.entry_text is
  'Vrije tekst die in het dashboard onder Payout history verschijnt.';

comment on column public.affiliate_payout_entries.amount is
  'Optioneel. Wordt opgeteld in Paid out (all time). Laat leeg als alleen tekst nodig is.';

comment on column public.affiliate_payout_entries.payout_date is
  'Sorteervolgorde in het dashboard (nieuwste eerst).';

create index if not exists idx_affiliate_payout_entries_affiliate_date
  on public.affiliate_payout_entries(affiliate_id, payout_date desc);

alter table public.affiliate_payout_entries enable row level security;

drop policy if exists "Users can read own payout entries" on public.affiliate_payout_entries;
create policy "Users can read own payout entries"
  on public.affiliate_payout_entries for select
  using (
    affiliate_id in (
      select id from public.affiliates where user_id = auth.uid()
    )
  );

-- Schrijven alleen via Supabase dashboard / service role (geen client policy)
