-- Per-platform click breakdown for affiliates (iOS vs Android).
-- Existing "clicks" remains the total; these two columns allow
-- you to see how many clicks came from each platform.

alter table public.affiliate_stats
  add column if not exists clicks_ios bigint not null default 0;

alter table public.affiliate_stats
  add column if not exists clicks_android bigint not null default 0;

