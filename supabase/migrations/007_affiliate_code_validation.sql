-- Enforce safe, user-facing affiliate codes (backwards-compatible):
-- - keep existing affiliate IDs as attribution source-of-truth
-- - affiliate_code remains the public code, but is validated + stored lowercase

-- Normalize affiliate_code to lowercase on write (does not modify existing rows unless they are updated).
create or replace function public.normalize_affiliate_code()
returns trigger
language plpgsql
as $$
begin
  if new.affiliate_code is not null then
    new.affiliate_code := lower(trim(new.affiliate_code));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalize_affiliate_code on public.affiliates;
create trigger trg_normalize_affiliate_code
before insert or update of affiliate_code on public.affiliates
for each row
execute function public.normalize_affiliate_code();

-- Format + safety constraints.
alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_length,
  add constraint affiliates_affiliate_code_length
    check (char_length(affiliate_code) between 4 and 10);

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_charset,
  add constraint affiliates_affiliate_code_charset
    check (affiliate_code ~ '^[a-z0-9]+$');

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_lowercase,
  add constraint affiliates_affiliate_code_lowercase
    check (affiliate_code = lower(affiliate_code));

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_reserved,
  add constraint affiliates_affiliate_code_reserved
    check (
      affiliate_code not in (
        'admin', 'support', 'help', 'api', 'www', 'app', 'dashboard', 'login', 'signup',
        'subscribe', 'pricing', 'terms', 'privacy', 'liftbetter', 'null', 'undefined'
      )
    );

