-- Two escrow gaps found while walking the app as a user.
--
-- 1. Deleting an account while money was held for a job set the escrow's
--    people to null: the held money was never released, the technician was
--    never paid and the proof was purged. Deleting now waits until the
--    escrow is settled.
-- 2. A complaint did not stop the automatic release after 72 hours, though
--    the person who complains believes the money is protected. An open
--    complaint now holds it until the team resolves it.

create or replace function private.release_due_escrows()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_escrow record;
  v_count integer := 0;
begin
  for v_escrow in
    select e.id
      from public.job_escrows e
      join public.service_requests r on r.id = e.request_id
      join public.jobs j on j.id = r.job_id
     where e.status = 'held'
       and j.status in ('finished', 'paid')
       and j.finished_at <= now() - private.escrow_hours_to_release()
       and not exists (
         select 1 from public.complaints c
          where c.request_id = e.request_id and c.resolved_at is null
       )
  loop
    perform private.release_escrow(v_escrow.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.delete_my_account(p_confirmation text)
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

  -- Money held for a job (or owed to the technician) is paid or given back
  -- by the team, who need the person's name, proof and payout account.
  if exists (
    select 1 from public.job_escrows e
     where (e.consumer_id = v_user_id
            and e.status in ('pending', 'held', 'disputed', 'refund_due'))
        or (e.technician_id = v_user_id
            and e.status in ('pending', 'held', 'released', 'disputed', 'refund_due'))
  ) then
    raise exception 'escrow_active' using errcode = 'P0001';
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

-- A job that is finished, undone and finished again charged its use twice.
-- Each job is charged once; jobs finished before this change count as
-- charged.
create table private.charged_jobs (
  job_id uuid primary key references public.jobs (id) on delete cascade
);
alter table private.charged_jobs enable row level security;

insert into private.charged_jobs (job_id)
select j.id from public.jobs j
 where j.source = 'platform' and j.status in ('finished', 'paid')
on conflict do nothing;

create or replace function private.charge_finished_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if exists (
    select 1 from public.service_requests r
     where r.job_id = new.id and r.repeat_booking
  ) then
    return null;
  end if;
  insert into private.charged_jobs (job_id) values (new.id)
  on conflict do nothing;
  get diagnostics v_count = row_count;
  if v_count = 0 then
    return null;
  end if;
  -- A job that finishes with nothing left to charge (a balance an admin
  -- emptied meanwhile) is still finished.
  update public.technician_profiles
     set job_credits = job_credits - 1
   where id = new.technician_id and job_credits > 0;
  if found then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (new.technician_id, 'technician', -1, 'job_finished');
  end if;
  return null;
end;
$$;
