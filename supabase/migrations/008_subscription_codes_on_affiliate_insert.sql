-- Bij elke nieuwe affiliate-rij: subscription code [affiliate_code]_join in subscription_codes.
create table if not exists public.subscription_codes (
  code text primary key,
  is_valid boolean not null default true
);

create or replace function public.subscription_code_for_new_affiliate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.subscription_codes (code, is_valid)
  values (new.affiliate_code || '_join', true)
  on conflict (code) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_subscription_code_on_affiliate_insert on public.affiliates;
create trigger trg_subscription_code_on_affiliate_insert
  after insert on public.affiliates
  for each row
  execute function public.subscription_code_for_new_affiliate();

comment on function public.subscription_code_for_new_affiliate() is
  'Inserts subscription_codes row code = affiliate_code || ''_join'', is_valid = true for each new affiliate.';
