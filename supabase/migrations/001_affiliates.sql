-- Affiliates: one row per user (Supabase Auth user_id), with contact details and unique link code
create table if not exists public.affiliates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  phone text not null,
  social_media text,
  affiliate_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id)
);

-- Stats per affiliate (clicks, downloads, subscriptions)
create table if not exists public.affiliate_stats (
  affiliate_id uuid primary key references public.affiliates(id) on delete cascade,
  clicks bigint not null default 0,
  downloads bigint not null default 0,
  monthly_subs bigint not null default 0,
  yearly_subs bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- RLS: users can only read/update their own affiliate row
alter table public.affiliates enable row level security;
alter table public.affiliate_stats enable row level security;

create policy "Users can read own affiliate"
  on public.affiliates for select
  using (auth.uid() = user_id);

create policy "Users can insert own affiliate"
  on public.affiliates for insert
  with check (auth.uid() = user_id);

create policy "Users can update own affiliate"
  on public.affiliates for update
  using (auth.uid() = user_id);

create policy "Users can read own stats"
  on public.affiliate_stats for select
  using (
    affiliate_id in (select id from public.affiliates where user_id = auth.uid())
  );

-- Service role / Edge Function will insert affiliates and update stats; no policy for that from client
-- Edge Function uses service role key and bypasses RLS

create index if not exists idx_affiliates_user_id on public.affiliates(user_id);
create index if not exists idx_affiliates_affiliate_code on public.affiliates(affiliate_code);
