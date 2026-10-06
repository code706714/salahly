-- Milestone 5: deleting an account.
--
-- delete_my_account() runs in one transaction for the person calling it
-- and nobody else (it takes no user id). It ends the person's open
-- requests and jobs so nobody on the other side is left waiting, erases
-- what identifies them, and deletes the auth user.
--
-- What stays, with no name, phone or screenshot and no link to a person:
-- the transfers (credit_topups) and the ledger, which are financial
-- records, and a one-way hash of the phone in private.free_credit_grants
-- so deleting and signing up again can't claim the free uses a second
-- time. The hash is an HMAC-SHA256 with a secret pepper from the vault
-- (free_credit_pepper), so it can't be reversed by trying every Egyptian
-- number; without the pepper (local development) it is a plain sha256.
-- A phone number is low-entropy personal data: this record is kept for
-- abuse prevention under legitimate interest.
--
-- Someone on site is not left without the address: a job already started
-- keeps its address and the customer's phone for the technician until the
-- job ends or is cancelled (then a trigger, or the daily housekeeping,
-- erases them).
--
-- Files: deleting rows from storage.objects does not delete the files
-- (and a protect trigger blocks it), so the paths are queued in
-- private.storage_purge and a service-role Edge Function (purge-storage)
-- removes them through the Storage API, then reports them done. The
-- cron job below wakes that function every five minutes once its URL
-- and secret are in the vault; a file is tried at most 10 times and then
-- stays flagged failed for a person to look at. A deleted person's
-- still-valid session can no longer upload (the storage policies require
-- the account), and files whose owner has no profile any more are queued
-- too, so nothing uploaded in that gap stays.

-- Financial records outlive the person, so they must not go with them.
alter table public.credit_topups alter column user_id drop not null;
alter table public.credit_topups drop constraint credit_topups_user_id_fkey;
alter table public.credit_topups
  add constraint credit_topups_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

alter table public.credit_ledger alter column user_id drop not null;
alter table public.credit_ledger drop constraint credit_ledger_user_id_fkey;
alter table public.credit_ledger
  add constraint credit_ledger_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete set null;

create table private.storage_purge (
  id bigint generated always as identity primary key,
  bucket_id text not null,
  name text not null,
  queued_at timestamptz not null default now(),
  claimed_at timestamptz,
  attempts integer not null default 0,
  failed boolean generated always as (attempts >= 10) stored,
  unique (bucket_id, name)
);
alter table private.storage_purge enable row level security;

-- What the last run of the wake-up job found, for dashboards.
create table private.purge_status (
  id boolean primary key default true check (id),
  checked_at timestamptz not null default now(),
  problem text
);
alter table private.purge_status enable row level security;

-- Uploads need a live account ------------------------------------------
-- The session of a deleted person stays valid until its token expires, so
-- the policies check the account too. Photos for onboarding are uploaded
-- before the profile exists, so those two buckets check the sign-in itself.
create function guard.account_exists()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from auth.users where id = (select auth.uid()));
$$;

create function guard.has_profile()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles where id = (select auth.uid()));
$$;

revoke execute on function guard.account_exists(), guard.has_profile() from public, anon;
grant execute on function guard.account_exists(), guard.has_profile() to authenticated;

alter policy "Users upload avatars to their own folder" on storage.objects
  with check (
    bucket_id = 'avatars'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.account_exists())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Users upload ID documents to their own folder" on storage.objects
  with check (
    bucket_id = 'verification-docs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.account_exists())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "People upload transfer proofs to their own folder" on storage.objects
  with check (
    bucket_id = 'transfer-proofs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Consumers upload request photos to their own folder" on storage.objects
  with check (
    bucket_id = 'request-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.is_consumer())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Technicians upload job photos to their own folder" on storage.objects
  with check (
    bucket_id = 'job-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.is_technician())
    and guard.upload_quota_left(bucket_id)
  );

-- The phone hash ----------------------------------------------------------
-- ONE place that hashes a phone for the free-use records. With the pepper
-- (vault secret free_credit_pepper) it is an HMAC-SHA256; without it, a
-- plain sha256 (local development, and every record made before the pepper).
create function private.legacy_phone_hash(p_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(sha256(convert_to(p_phone, 'UTF8')), 'hex');
$$;

create function private.phone_hash(p_phone text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pepper text;
begin
  select decrypted_secret into v_pepper
    from vault.decrypted_secrets where name = 'free_credit_pepper';
  if coalesce(v_pepper, '') = '' then
    return private.legacy_phone_hash(p_phone);
  end if;
  return encode(
    extensions.hmac(convert_to(p_phone, 'UTF8'), convert_to(v_pepper, 'UTF8'), 'sha256'),
    'hex'
  );
end;
$$;

-- Same rules as before. A phone already recorded with the old plain hash
-- still counts, so the first release with a pepper can't hand out the free
-- uses again.
create or replace function private.claim_free_credits(p_user_id uuid, p_role public.user_role)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_phone text;
  v_hash text;
  v_legacy text;
begin
  select phone into v_phone from auth.users where id = p_user_id;
  v_hash := private.phone_hash(v_phone);
  v_legacy := private.legacy_phone_hash(v_phone);

  if v_legacy <> v_hash and exists (
    select 1 from private.free_credit_grants
     where phone_hash = v_legacy and role = p_role
  ) then
    return 0;
  end if;

  insert into private.free_credit_grants (phone_hash, role)
  values (v_hash, p_role)
  on conflict do nothing;

  if not found then
    return 0;
  end if;

  return (
    select case p_role
      when 'consumer' then s.consumer_free_requests
      else s.technician_free_jobs
    end
    from public.app_settings s
  );
end;
$$;

-- Customer and job details of a deleted consumer ------------------------
-- Writes to rows already erased can't put the details back: the technician's
-- phone syncs its own copy, and a stale one must not restore a person who
-- deleted their account. The erasing code itself sets private.anonymizing.
create function private.scrub_platform_jobs(p_job_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('private.anonymizing', 'on', true);
  update public.customers c
     set name = 'عميل محذوف', phone = null, area_id = null, address = null, notes = null
   where c.source = 'platform'
     and exists (
       select 1 from public.jobs j
        where j.id = any (p_job_ids)
          and j.customer_id = c.id and j.technician_id = c.technician_id
     )
     and not exists (
       select 1 from public.jobs j
        where j.customer_id = c.id and j.technician_id = c.technician_id
          and j.source = 'platform' and j.status = 'started'
          and j.id <> all (p_job_ids)
     );
  update public.jobs
     set description = null, address = null
   where source = 'platform' and id = any (p_job_ids);
  perform set_config('private.anonymizing', 'off', true);
end;
$$;

-- A platform job whose request is gone belongs to a deleted consumer.
create function private.platform_job_orphaned(p_job_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select not exists (select 1 from public.service_requests where job_id = p_job_id);
$$;

create function private.guard_platform_customer()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.source = 'platform'
     and current_setting('private.anonymizing', true) is distinct from 'on'
     and not exists (
       select 1
         from public.jobs j
         join public.service_requests r on r.job_id = j.id
        where j.customer_id = old.id
     ) then
    new.name := old.name;
    new.phone := old.phone;
    new.area_id := old.area_id;
    new.address := old.address;
    new.notes := old.notes;
  end if;
  return new;
end;
$$;

create trigger customers_guard_platform before update on public.customers
  for each row execute function private.guard_platform_customer();

-- The rules of guard_platform_job, plus: nothing is written back onto a
-- job of a deleted consumer, and the time of a quote is a plausible one.
create or replace function private.guard_platform_job()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.source <> 'platform' then
    return new;
  end if;
  if new.deleted_at is not null and old.deleted_at is null
     or new.customer_id <> old.customer_id then
    raise exception 'platform_job_locked' using errcode = '42501';
  end if;
  if old.status = 'cancelled' and new.status <> 'cancelled' and exists (
    select 1 from public.service_requests r
     where r.job_id = old.id and r.status = 'cancelled'
  ) then
    raise exception 'request_cancelled' using errcode = '42501';
  end if;
  if current_setting('private.anonymizing', true) is distinct from 'on'
     and private.platform_job_orphaned(old.id) then
    new.description := old.description;
    new.address := old.address;
  end if;
  if new.quote_sent_at is distinct from old.quote_sent_at and new.quote_sent_at is not null then
    new.quote_sent_at := private.client_time(new.quote_sent_at);
  end if;
  if new.quote_status = 'sent'
     and old.quote_status in ('accepted', 'declined')
     and new.quote_sent_at is not distinct from old.quote_sent_at then
    new.quote_status := old.quote_status;
  elsif new.quote_status in ('accepted', 'declined')
     and (new.quote_status, new.quote_sent_at) is distinct from (old.quote_status, old.quote_sent_at)
     and not exists (select 1 from private.customer_answers a where a.job_id = old.id) then
    raise exception 'quote_needs_customer' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- A job kept for the technician while he was on site is erased when it ends.
create function private.scrub_ended_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.platform_job_orphaned(new.id) then
    perform private.scrub_platform_jobs(array[new.id]);
  end if;
  return null;
end;
$$;

create trigger jobs_scrub_when_ended after update of status on public.jobs
  for each row
  when (
    old.source = 'platform'
    and new.status in ('finished', 'paid', 'cancelled')
    and old.status is distinct from new.status
  )
  execute function private.scrub_ended_job();

-- A job that never ends (the technician forgot) is erased after 3 days.
create function private.scrub_orphan_platform_jobs()
returns void
language sql
set search_path = ''
as $$
  select private.scrub_platform_jobs(coalesce(array_agg(j.id), '{}'))
    from public.jobs j
   where j.source = 'platform'
     and not exists (select 1 from public.service_requests r where r.job_id = j.id)
     and (j.description is not null or j.address is not null)
     and (j.status in ('finished', 'paid', 'cancelled')
          or coalesce(j.started_at, j.created_at) < now() - interval '3 days');
$$;

select cron.schedule('scrub-orphan-jobs', '17 * * * *', 'select private.scrub_orphan_platform_jobs()');

create function public.delete_my_account(p_confirmation text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_phone text;
  v_request public.service_requests;
  v_job public.jobs;
  v_issued_at bigint;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  if p_confirmation is distinct from 'DELETE' then
    raise exception 'confirmation_required' using errcode = '22023';
  end if;

  -- Already gone (a second tap, a retry after a lost answer): nothing to do.
  select phone into v_phone from auth.users where id = v_user_id for update;
  if not found then
    return;
  end if;

  -- Deleting everything needs a recent login (a stolen phone or token
  -- must not be enough). When the token says when the person last signed in
  -- (amr), that time counts; a refreshed token keeps it. Otherwise its age.
  select coalesce(
           max((a ->> 'timestamp')::bigint),
           (auth.jwt() ->> 'iat')::bigint
         )
    into v_issued_at
    from jsonb_array_elements(
      case when jsonb_typeof(auth.jwt() -> 'amr') = 'array'
           then auth.jwt() -> 'amr' else '[]'::jsonb end
    ) a;
  if v_issued_at is null or v_issued_at < extract(epoch from now()) - 900 then
    raise exception 'recent_login_required' using errcode = 'P0001';
  end if;
  perform 1 from public.profiles where id = v_user_id for update;

  -- Money they sent that nobody has checked yet would be lost.
  if exists (
    select 1 from public.credit_topups where user_id = v_user_id and status = 'pending'
  ) then
    raise exception 'topup_pending' using errcode = 'P0001';
  end if;

  -- As a consumer ------------------------------------------------------
  -- Requests still looking for a technician end, and the use held for
  -- each comes back (the technicians with offers are told by the trigger).
  for v_request in
    select * from public.service_requests
     where consumer_id = v_user_id and status = 'open'
     for update
  loop
    update public.service_requests
       set status = 'cancelled', cancelled_at = now(), cancelled_by = 'consumer',
           credit_held = false
     where id = v_request.id;
    if v_request.credit_held then
      perform private.return_use(v_user_id, 'consumer');
    end if;
  end loop;

  -- Picked technicians: a job not yet started is cancelled and their use
  -- comes back, exactly as when the consumer cancels. One already under
  -- way stays in the technician's records and they are told.
  for v_request in
    select * from public.service_requests
     where consumer_id = v_user_id and status = 'assigned'
     for update
  loop
    select * into v_job from public.jobs where id = v_request.job_id for update;
    if v_job.status in ('unconfirmed', 'confirmed') then
      update public.service_requests
         set status = 'cancelled', cancelled_at = now(), cancelled_by = 'consumer'
       where id = v_request.id;
      update public.jobs set status = 'cancelled', cancelled_at = now() where id = v_job.id;
      perform private.return_use(v_job.technician_id, 'technician');
    elsif v_job.status = 'started' then
      perform private.notify(
        v_job.technician_id, 'technician', 'request_cancelled_by_consumer'
      );
    end if;
  end loop;

  -- The technician keeps their job history but not who it was for. A job
  -- already started keeps the address and phone until it ends.
  perform private.scrub_platform_jobs(array(
    select j.id
      from public.service_requests r
      join public.jobs j on j.id = r.job_id
     where r.consumer_id = v_user_id and j.status <> 'started'
  ));

  -- As a technician ----------------------------------------------------
  -- Jobs picked from the platform that are still open are cancelled: the
  -- consumer gets their use back and is told.
  for v_request in
    select r.*
      from public.service_requests r
      join public.request_offers o on o.id = r.chosen_offer_id
     where o.technician_id = v_user_id and r.status = 'assigned'
     for update of r
  loop
    select * into v_job from public.jobs where id = v_request.job_id for update;
    if v_job.status in ('unconfirmed', 'confirmed', 'started') then
      update public.jobs set status = 'cancelled', cancelled_at = now() where id = v_job.id;
    end if;
  end loop;
  -- Cancelled ones lose the link to the offer that is going away; ones
  -- already done have no technician to show any more and go.
  update public.service_requests
     set chosen_offer_id = null
   where status = 'cancelled'
     and chosen_offer_id in (select id from public.request_offers where technician_id = v_user_id);
  delete from public.service_requests
   where status = 'assigned'
     and chosen_offer_id in (select id from public.request_offers where technician_id = v_user_id);

  -- What is kept, without the person ----------------------------------
  update public.credit_topups
     set user_id = null,
         sender_account = 'deleted',
         screenshot_path = 'deleted/' || id::text,
         reject_reason = null
   where user_id = v_user_id;
  update public.credit_ledger set user_id = null where user_id = v_user_id;

  insert into private.free_credit_grants (phone_hash, role)
  select private.phone_hash(v_phone), r.role
    from (
      select 'consumer'::public.user_role as role
       where exists (select 1 from public.consumer_profiles where id = v_user_id)
      union all
      select 'technician'
       where exists (select 1 from public.technician_profiles where id = v_user_id)
    ) r
  on conflict do nothing;

  -- The files, to be removed through the Storage API.
  insert into private.storage_purge (bucket_id, name)
  select o.bucket_id, o.name
    from storage.objects o
   where o.bucket_id in (
           'avatars', 'verification-docs', 'request-photos', 'job-photos', 'transfer-proofs'
         )
     and (o.owner_id = v_user_id::text or split_part(o.name, '/', 1) = v_user_id::text)
  on conflict do nothing;

  -- Everything else that points at the person goes with them.
  delete from auth.users where id = v_user_id;
end;
$$;

-- The purge worker: the Edge Function claims a batch, removes the files,
-- and reports them done. Only the service role may call these.
create function public.storage_purge_claim(p_limit integer default 100)
returns table (id bigint, bucket_id text, name text)
language sql
security definer
set search_path = ''
as $$
  update private.storage_purge q
     set claimed_at = now(), attempts = q.attempts + 1
   where q.id in (
     select s.id
       from private.storage_purge s
      where s.attempts < 10
        and (s.claimed_at is null or s.claimed_at < now() - interval '10 minutes')
      order by s.id
      limit least(greatest(coalesce(p_limit, 100), 1), 500)
        for update skip locked
   )
  returning q.id, q.bucket_id, q.name;
$$;

create function public.storage_purge_done(p_ids bigint[])
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.storage_purge where id = any (p_ids);
$$;

revoke execute on function
  public.delete_my_account(text),
  public.storage_purge_claim(integer),
  public.storage_purge_done(bigint[])
from public, anon, authenticated;
grant execute on function public.delete_my_account(text) to authenticated;
grant execute on function
  public.storage_purge_claim(integer),
  public.storage_purge_done(bigint[])
to service_role;

-- Wakes the worker while files wait. The URL of the function and its
-- secret are in the vault (purge_storage_url, purge_storage_secret);
-- without them nothing is sent.
create extension if not exists pg_net;

create function private.run_storage_purge()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  -- Files of people whose profile is gone (an upload that slipped in while
  -- their account was being deleted, or an onboarding left unfinished for a
  -- day) are queued like the others.
  insert into private.storage_purge (bucket_id, name)
  select o.bucket_id, o.name
    from storage.objects o
    left join public.profiles p on p.id::text = split_part(o.name, '/', 1)
   where o.bucket_id in (
           'avatars', 'verification-docs', 'request-photos', 'job-photos', 'transfer-proofs'
         )
     and p.id is null
     and o.name ~ '^[0-9a-f-]{36}/'
     and o.created_at < now() - interval '1 day'
  on conflict do nothing;

  if not exists (select 1 from private.storage_purge where attempts < 10) then
    insert into private.purge_status (id, checked_at, problem) values (true, now(), null)
    on conflict (id) do update set checked_at = excluded.checked_at, problem = null;
    return;
  end if;
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'purge_storage_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'purge_storage_secret';
  if v_url is null or v_secret is null then
    raise warning 'storage purge is not configured: vault secrets purge_storage_url and purge_storage_secret are missing';
    insert into private.purge_status (id, checked_at, problem)
    values (true, now(), 'vault_secrets_missing')
    on conflict (id) do update set checked_at = excluded.checked_at, problem = excluded.problem;
    return;
  end if;
  insert into private.purge_status (id, checked_at, problem) values (true, now(), null)
  on conflict (id) do update set checked_at = excluded.checked_at, problem = null;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-purge-secret', v_secret),
    body := '{}'::jsonb
  );
end;
$$;

-- How long the oldest file still waiting for removal has waited (null when
-- none). For dashboards and alerts: anything over an hour means the
-- worker is not running.
create function private.purge_backlog()
returns interval
language sql
stable
set search_path = ''
as $$
  select now() - min(queued_at) from private.storage_purge;
$$;

revoke execute on all functions in schema private from public, anon, authenticated;

select cron.schedule('storage-purge', '*/5 * * * *', 'select private.run_storage_purge()');
