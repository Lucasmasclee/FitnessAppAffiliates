-- Link each affiliate to one Branch link (alias, e.g. join1, join2).
-- Set manually in Supabase (or later via admin) when you assign a Branch link to an affiliate.
alter table public.affiliates
  add column if not exists branch_link_alias text;

create index if not exists idx_affiliates_branch_link_alias
  on public.affiliates(branch_link_alias)
  where branch_link_alias is not null;

comment on column public.affiliates.branch_link_alias is 'Branch short link alias (e.g. join1). Link URL: https://liftbetter.app.link/<alias>. Set manually when assigning a link to an affiliate.';

-- Atomic increment of clicks for the affiliate that owns the given Branch link alias.
-- Used by the branch-webhook Edge Function.
create or replace function public.increment_clicks_by_branch_alias(p_alias text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.affiliate_stats
  set clicks = clicks + 1, updated_at = now()
  where affiliate_id = (select id from public.affiliates where branch_link_alias = p_alias limit 1);
$$;
