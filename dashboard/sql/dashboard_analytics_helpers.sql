-- Shared helpers for dashboard analytics (run before other dashboard_*.sql updates).
-- Unique-user metrics use analytics_user_id, falling back to anonymous_id.

drop function if exists public.dashboard_analytics_user_key(text, text);

create or replace function public.dashboard_analytics_user_key(
  p_analytics_user_id text,
  p_anonymous_id text
)
returns text
language sql
immutable
parallel safe
as $$
  select nullif(
    btrim(coalesce(p_analytics_user_id, p_anonymous_id, '')),
    ''
  );
$$;

comment on function public.dashboard_analytics_user_key(text, text) is
  'Stable per-user key for dashboard unique counts (analytics_user_id, else anonymous_id).';

grant execute on function public.dashboard_analytics_user_key(text, text)
  to anon, authenticated, service_role;
