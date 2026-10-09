-- Realtime: the app learns about a new notification (a request, an offer,
-- a counter-price, a verification answer) the moment it is recorded.
-- Row level security on `notifications` already limits each person to
-- their own rows, and Realtime applies it to what it delivers.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
