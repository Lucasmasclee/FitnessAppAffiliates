-- Allow affiliate codes up to 16 characters (was 4–10).

alter table public.affiliates
  drop constraint if exists affiliates_affiliate_code_length,
  add constraint affiliates_affiliate_code_length
    check (char_length(affiliate_code) between 4 and 16);
