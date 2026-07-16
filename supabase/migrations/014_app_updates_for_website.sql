-- App updates shown on the public website (managed via Supabase Table Editor)

create table if not exists public.app_updates_for_website (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  date date not null,
  explanation text not null,
  created_at timestamptz not null default now()
);

comment on table public.app_updates_for_website is
  'Release notes / app updates for the public Updates page on liftbetter.cloud.';

create index if not exists idx_app_updates_for_website_date
  on public.app_updates_for_website(date desc);

alter table public.app_updates_for_website enable row level security;

drop policy if exists "Anyone can read app updates" on public.app_updates_for_website;
create policy "Anyone can read app updates"
  on public.app_updates_for_website for select
  using (true);

-- Writes only via Supabase dashboard / service role (no client policy)
