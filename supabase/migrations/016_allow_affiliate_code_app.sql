-- Allow affiliate code "app" (remove from reserved list) and min length 3.

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_length,
  add constraint affiliates_affiliate_code_length
    check (char_length(affiliate_code) between 3 and 16);

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_reserved,
  add constraint affiliates_affiliate_code_reserved
    check (
      affiliate_code not in (
        'admin', 'support', 'help', 'api', 'www', 'dashboard', 'login', 'signup',
        'subscribe', 'pricing', 'terms', 'privacy', 'liftbetter', 'null', 'undefined'
      )
    );
