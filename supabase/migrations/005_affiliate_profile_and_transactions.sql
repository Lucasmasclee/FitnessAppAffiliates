-- Extra profielinfo per affiliate + transactie-tabel voor installs/subscriptions/payout-status

-- Extra velden op affiliates voor dashboard-secties (account, commissietier, payout-methode, etc.)
alter table public.affiliates
  add column if not exists commission_tier text,
  add column if not exists join_date timestamptz,
  add column if not exists payout_method text,
  add column if not exists payout_details text,
  add column if not exists tax_info_status text;

comment on column public.affiliates.commission_tier is 'Huidige commissietier voor affiliate (bijv. base, tier2, custom).';
comment on column public.affiliates.join_date is 'Datum waarop affiliate officieel is gestart.';
comment on column public.affiliates.payout_method is 'Voorkeursuitbetalingsmethode (bijv. bank, paypal).';
comment on column public.affiliates.payout_details is 'Verificatie-/betaalgegevens (bijv. gemaskeerde IBAN of PayPal e-mail).';
comment on column public.affiliates.tax_info_status is 'Status van belastinggegevens (bijv. pending, verified).';

-- Per-event transacties: installs, subscriptions, refunds, handmatige correcties
create table if not exists public.affiliate_transactions (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,

  -- Soort event: install, subscription, refund, adjustment
  event_type text not null check (event_type in ('install', 'subscription', 'refund', 'adjustment')),

  -- Alleen gevuld voor subscription-events (monthly / yearly / anders)
  subscription_type text,

  event_date timestamptz not null default now(),

  -- Bedragen (optioneel, maar handig voor analytics)
  gross_amount numeric(10, 2),
  commission_amount numeric(10, 2) not null default 0,
  currency text not null default 'EUR',

  -- Status van het event zelf (bijv. of een subscription is goedgekeurd / terugbetaald)
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'refunded', 'cancelled')),

  -- Payout-status van de commissie die bij dit event hoort
  payout_status text not null default 'pending'
    check (payout_status in ('pending', 'eligible', 'paid')),

  payout_date timestamptz,

  -- Datum tot wanneer de commissie in hold staat (bijv. 60 dagen)
  hold_until timestamptz,

  notes text
);

comment on table public.affiliate_transactions is
  'Per-affiliate events (install, subscription, refund, adjustment) met commissie & payout-status voor dashboard, funnel en transactielijst.';

create index if not exists idx_affiliate_transactions_affiliate_id_event_date
  on public.affiliate_transactions(affiliate_id, event_date desc);

alter table public.affiliate_transactions enable row level security;

drop policy if exists "Users can read own transactions" on public.affiliate_transactions;
create policy "Users can read own transactions"
  on public.affiliate_transactions for select
  using (
    affiliate_id in (
      select id from public.affiliates where user_id = auth.uid()
    )
  );

