-- Denormaliseer alle profielkolommen van public.affiliates naar public.affiliate_stats.
-- Geen tabellen of bestaande kolommen verwijderd; affiliates blijft de bron van waarheid.
-- affiliate_id blijft PK/FK en is gelijk aan affiliates.id (we kopiëren geen aparte id-kolom).
-- affiliates.updated_at wordt gemapt naar affiliate_profile_updated_at omdat affiliate_stats.updated_at
-- al de laatste wijziging van de statistieken bijhoudt.

-- 1) Nieuwe kolommen (eerst nullable voor veilige backfill)
alter table public.affiliate_stats
  add column if not exists user_id uuid references auth.users (id) on delete cascade;

alter table public.affiliate_stats
  add column if not exists email text;

alter table public.affiliate_stats
  add column if not exists phone text;

alter table public.affiliate_stats
  add column if not exists social_media text;

alter table public.affiliate_stats
  add column if not exists affiliate_code text;

alter table public.affiliate_stats
  add column if not exists created_at timestamptz;

alter table public.affiliate_stats
  add column if not exists affiliate_profile_updated_at timestamptz;

alter table public.affiliate_stats
  add column if not exists branch_link_alias text;

alter table public.affiliate_stats
  add column if not exists commission_tier text;

alter table public.affiliate_stats
  add column if not exists join_date timestamptz;

alter table public.affiliate_stats
  add column if not exists payout_method text;

alter table public.affiliate_stats
  add column if not exists payout_details text;

alter table public.affiliate_stats
  add column if not exists tax_info_status text;

comment on column public.affiliate_stats.created_at is
  'Kopie van affiliates.created_at (aanmaakmoment affiliate-profiel).';

comment on column public.affiliate_stats.affiliate_profile_updated_at is
  'Kopie van affiliates.updated_at; niet te verwarren met affiliate_stats.updated_at (statistieken).';

-- 2) Backfill: bestaande stats-rijen vullen vanuit affiliates (geen rijen worden verwijderd)
update public.affiliate_stats s
set
  user_id = a.user_id,
  email = a.email,
  phone = a.phone,
  social_media = a.social_media,
  affiliate_code = a.affiliate_code,
  created_at = a.created_at,
  affiliate_profile_updated_at = a.updated_at,
  branch_link_alias = a.branch_link_alias,
  commission_tier = a.commission_tier,
  join_date = a.join_date,
  payout_method = a.payout_method,
  payout_details = a.payout_details,
  tax_info_status = a.tax_info_status
from public.affiliates a
where s.affiliate_id = a.id;

-- 3) NOT NULL waar affiliates dat ook heeft (elke stats-rij heeft een geldige affiliate door FK)
alter table public.affiliate_stats alter column user_id set not null;

alter table public.affiliate_stats alter column email set not null;

alter table public.affiliate_stats alter column phone set not null;

alter table public.affiliate_stats alter column affiliate_code set not null;

alter table public.affiliate_stats alter column created_at set not null;

alter table public.affiliate_stats alter column affiliate_profile_updated_at set not null;

create index if not exists idx_affiliate_stats_user_id on public.affiliate_stats (user_id);

create index if not exists idx_affiliate_stats_affiliate_code on public.affiliate_stats (affiliate_code);

-- 4) Bij elke wijziging aan affiliates: profiel in affiliate_stats bijwerken of rij aanmaken (counters blijven behouden bij conflict)
create or replace function public.sync_affiliates_row_to_affiliate_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.affiliate_stats (
    affiliate_id,
    user_id,
    email,
    phone,
    social_media,
    affiliate_code,
    created_at,
    affiliate_profile_updated_at,
    branch_link_alias,
    commission_tier,
    join_date,
    payout_method,
    payout_details,
    tax_info_status
  )
  values (
    new.id,
    new.user_id,
    new.email,
    new.phone,
    new.social_media,
    new.affiliate_code,
    new.created_at,
    new.updated_at,
    new.branch_link_alias,
    new.commission_tier,
    new.join_date,
    new.payout_method,
    new.payout_details,
    new.tax_info_status
  )
  on conflict (affiliate_id) do update
  set
    user_id = excluded.user_id,
    email = excluded.email,
    phone = excluded.phone,
    social_media = excluded.social_media,
    affiliate_code = excluded.affiliate_code,
    created_at = excluded.created_at,
    affiliate_profile_updated_at = excluded.affiliate_profile_updated_at,
    branch_link_alias = excluded.branch_link_alias,
    commission_tier = excluded.commission_tier,
    join_date = excluded.join_date,
    payout_method = excluded.payout_method,
    payout_details = excluded.payout_details,
    tax_info_status = excluded.tax_info_status;
  return new;
end;
$$;

comment on function public.sync_affiliates_row_to_affiliate_stats() is
  'Houdt gespiegelde affiliate-profielkolommen in affiliate_stats gelijk met affiliates; overschrijft geen tellers.';

drop trigger if exists trg_sync_affiliates_to_affiliate_stats on public.affiliates;

create trigger trg_sync_affiliates_to_affiliate_stats
after insert or update on public.affiliates
for each row
execute function public.sync_affiliates_row_to_affiliate_stats();

-- 5) Bij insert/update op affiliate_stats: profiel altijd opnieuw uit affiliates (dekt upserts met alleen affiliate_id)
create or replace function public.affiliate_stats_apply_affiliate_profile_mirror()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a public.affiliates%rowtype;
begin
  select * into strict a from public.affiliates where id = new.affiliate_id;

  new.user_id := a.user_id;
  new.email := a.email;
  new.phone := a.phone;
  new.social_media := a.social_media;
  new.affiliate_code := a.affiliate_code;
  new.created_at := a.created_at;
  new.affiliate_profile_updated_at := a.updated_at;
  new.branch_link_alias := a.branch_link_alias;
  new.commission_tier := a.commission_tier;
  new.join_date := a.join_date;
  new.payout_method := a.payout_method;
  new.payout_details := a.payout_details;
  new.tax_info_status := a.tax_info_status;

  return new;
end;
$$;

comment on function public.affiliate_stats_apply_affiliate_profile_mirror() is
  'Vult/ververst gespiegelde profielkolommen op affiliate_stats vanuit de bijbehorende affiliates-rij.';

drop trigger if exists trg_affiliate_stats_profile_mirror on public.affiliate_stats;

create trigger trg_affiliate_stats_profile_mirror
before insert or update on public.affiliate_stats
for each row
execute function public.affiliate_stats_apply_affiliate_profile_mirror();
