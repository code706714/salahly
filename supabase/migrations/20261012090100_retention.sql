-- Reasons to keep booking through the app: a free request after every third
-- finished job, repeat bookings that cost the technician nothing, and a
-- yearly nudge to book the same service again.

alter table public.service_requests
  add column repeat_booking boolean not null default false,
  add column reminded_at timestamptz;

-- A request for a technician the consumer already finished a job with
-- through the app is a repeat booking. Decided here, never by the client.
create function private.mark_repeat_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.repeat_booking := new.preferred_technician_id is not null and exists (
    select 1
      from public.service_requests r
      join public.jobs j on j.id = r.job_id
     where r.consumer_id = new.consumer_id
       and j.technician_id = new.preferred_technician_id
       and j.source = 'platform'
       and j.status in ('finished', 'paid')
  );
  return new;
end;
$$;
revoke execute on function private.mark_repeat_booking() from public, anon, authenticated;

create trigger service_requests_mark_repeat before insert on public.service_requests
  for each row execute function private.mark_repeat_booking();

-- A repeat booking neither holds nor takes one of the technician's uses.
create or replace function private.take_use(p_user_id uuid, p_role public.user_role)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_credits integer;
begin
  if p_role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits - 1
     where id = p_user_id and request_credits > 0;
    if not found then
      raise exception 'no_credits' using errcode = 'P0001';
    end if;
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (p_user_id, p_role, -1, 'request_sent');
    return;
  end if;

  select job_credits into v_credits
    from public.technician_profiles
   where id = p_user_id
   for update;
  if v_credits is null or v_credits <= (
    select count(*)
      from public.jobs j
     where j.technician_id = p_user_id
       and j.source = 'platform'
       and j.status in ('unconfirmed', 'confirmed', 'started')
       and not exists (
         select 1 from public.service_requests r
          where r.job_id = j.id and r.repeat_booking
       )
  ) then
    raise exception 'no_credits' using errcode = 'P0001';
  end if;
end;
$$;

create or replace function private.charge_finished_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.service_requests r
     where r.job_id = new.id and r.repeat_booking
  ) then
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

-- Every third job a consumer finishes through the app gives a free request.
create function private.reward_loyal_consumer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
begin
  select * into v_request from public.service_requests where job_id = new.id;
  if not found then
    return null;
  end if;
  if (
    select count(*)
      from public.service_requests r
      join public.jobs j on j.id = r.job_id
     where r.consumer_id = v_request.consumer_id
       and j.status in ('finished', 'paid')
  ) % 3 <> 0 then
    return null;
  end if;
  update public.consumer_profiles
     set request_credits = request_credits + 1
   where id = v_request.consumer_id;
  if found then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (v_request.consumer_id, 'consumer', 1, 'loyalty_reward');
    perform private.notify(
      v_request.consumer_id, 'consumer', 'loyalty_reward', v_request.id
    );
  end if;
  return null;
end;
$$;
revoke execute on function private.reward_loyal_consumer() from public, anon, authenticated;

create trigger jobs_reward_loyal after update of status on public.jobs
  for each row
  when (
    new.source = 'platform'
    and new.status in ('finished', 'paid')
    and old.status not in ('finished', 'paid')
  )
  execute function private.reward_loyal_consumer();

-- Once per finished job, when the service usually needs doing again.
create function private.send_maintenance_reminders()
returns void
language sql
security definer
set search_path = ''
as $$
  with due as (
    update public.service_requests r
       set reminded_at = now()
      from public.jobs j
     where j.id = r.job_id
       and r.reminded_at is null
       and j.source = 'platform'
       and j.status in ('finished', 'paid')
       and j.finished_at < now() - case r.category_id
             when 'ac' then interval '6 months'
             when 'washing_machines' then interval '12 months'
             when 'refrigerators' then interval '12 months'
           end
    returning r.id, r.consumer_id
  )
  select private.notify(consumer_id, 'consumer', 'maintenance_reminder', id)
    from due;
$$;
revoke execute on function private.send_maintenance_reminders() from public, anon, authenticated;

select cron.schedule(
  'maintenance-reminders',
  '0 7 * * *',
  'select private.send_maintenance_reminders()'
);

create or replace function private.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_kind::text = any (array[
    'offer_received', 'technician_arriving', 'job_confirmed', 'job_started',
    'job_finished', 'price_change', 'request_cancelled_by_technician',
    'request_expired', 'new_request', 'offer_picked',
    'request_cancelled_by_consumer', 'verification_approved',
    'verification_rejected', 'topup_approved', 'topup_rejected',
    'offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted',
    'loyalty_reward', 'maintenance_reminder'
  ]);
$$;
