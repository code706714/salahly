-- avatars: technician photos customers see, served publicly.
-- verification-docs: ID card photos only the verification team sees.
-- Users write only inside a folder named after their own user id, using a
-- random uuid file name, and can't overwrite or delete what they sent.
-- Each user can upload a limited number of files per bucket per day, so a
-- signed-in account can't fill the buckets.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('verification-docs', 'verification-docs', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

-- Functions that row level security policies call. The API roles may run
-- them, but the schema isn't exposed over the REST API.
create schema guard;
revoke all on schema guard from public;
grant usage on schema guard to authenticated;

create function guard.upload_quota_left(p_bucket text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) < 10
  from storage.objects
  where bucket_id = p_bucket
    and owner_id = (select auth.uid()::text)
    and created_at > now() - interval '1 day';
$$;

revoke execute on function guard.upload_quota_left(text) from public, anon;
grant execute on function guard.upload_quota_left(text) to authenticated;

create policy "Users upload avatars to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and guard.upload_quota_left(bucket_id)
  );

create policy "Users upload ID documents to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'verification-docs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and guard.upload_quota_left(bucket_id)
  );
