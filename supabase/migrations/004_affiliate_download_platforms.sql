-- Per-platform download breakdown for affiliates (iOS vs Android).
-- Existing "downloads" remains the total; these two columns allow
-- you to see how many downloads came from each platform.

alter table public.affiliate_stats
  add column if not exists downloads_ios bigint not null default 0;

alter table public.affiliate_stats
  add column if not exists downloads_android bigint not null default 0;

