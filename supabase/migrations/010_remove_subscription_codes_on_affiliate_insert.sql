-- Stop auto-creating subscription_codes entries when a new affiliate registers.
-- The table itself may still be used elsewhere; we only remove the trigger + function.

drop trigger if exists trg_subscription_code_on_affiliate_insert on public.affiliates;
drop function if exists public.subscription_code_for_new_affiliate();

