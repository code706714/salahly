-- Milestone 5: deleting an account.
--
-- delete_my_account() runs in one transaction for the person calling it
-- and nobody else (it takes no user id). It ends the person's open
-- requests and jobs so nobody on the other side is left waiting, erases
-- what identifies them, and deletes the auth user.
--
-- What stays, with no name, phone or screenshot and no link to a person:
-- the transfers (credit_topups) and the ledger, which are financial
-- records, and the sha256 of the phone in private.free_credit_grants so
-- deleting and signing up again can't claim the free uses a second time.
--
-- Files: deleting rows from storage.objects does not delete the files
-- (and a protect trigger blocks it), so the paths are queued in
-- private.storage_purge and a service-role Edge Function (purge-storage)
-- removes them through the Storage API, then reports them done. The
-- cron job below wakes that function every five minutes once its URL
-- and secret are in the vault.

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
  unique (bucket_id, name)
);
alter table private.storage_purge enable row level security;

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

  -- The technician keeps their job history but not who it was for.
  update public.customers c
     set name = 'عميل محذوف', phone = null, area_id = null, address = null, notes = null
   where c.source = 'platform'
     and exists (
       select 1
         from public.service_requests r
         join public.jobs j on j.id = r.job_id
        where r.consumer_id = v_user_id
          and j.customer_id = c.id and j.technician_id = c.technician_id
     );
  update public.jobs
     set description = null, address = null
   where source = 'platform'
     and id in (
       select job_id from public.service_requests
        where consumer_id = v_user_id and job_id is not null
     );

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
  select encode(sha256(convert_to(v_phone, 'UTF8')), 'hex'), r.role
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
     set claimed_at = now()
   where q.id in (
     select s.id
       from private.storage_purge s
      where s.claimed_at is null or s.claimed_at < now() - interval '10 minutes'
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
  if not exists (select 1 from private.storage_purge) then
    return;
  end if;
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'purge_storage_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'purge_storage_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-purge-secret', v_secret),
    body := '{}'::jsonb
  );
end;
$$;

revoke execute on function private.run_storage_purge() from public, anon, authenticated;

select cron.schedule('storage-purge', '*/5 * * * *', 'select private.run_storage_purge()');
