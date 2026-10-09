-- A technician's use is charged when the job is finished and paid for, not
-- when the customer picks him. Until then it is only held: he can't take
-- more open platform jobs than he has uses, and nothing leaves the balance.

alter type public.ledger_reason add value if not exists 'job_finished';

-- Taking a use: a consumer's is taken when the request is sent. A
-- technician's is held while the job is open, so this only checks that one
-- is free; the balance changes when the job finishes. The balance row is
-- locked so two jobs picked at once can't hold the same use.
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
  ) then
    raise exception 'no_credits' using errcode = 'P0001';
  end if;
end;
$$;

-- Giving a use back: a consumer's returns to the balance. A technician's
-- was never taken, so a cancelled job just stops holding it.
create or replace function private.return_use(p_user_id uuid, p_role public.user_role)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits + 1
     where id = p_user_id;
    if found then
      insert into public.credit_ledger (user_id, role, delta, reason)
      values (p_user_id, p_role, 1, 'request_refunded');
    end if;
  end if;
end;
$$;

-- The uses already taken for jobs that are still open go back to the
-- balance; they are charged again when those jobs finish.
with held as (
  select technician_id, count(*)::integer as uses
    from public.jobs
   where source = 'platform' and status in ('unconfirmed', 'confirmed', 'started')
   group by technician_id
),
given_back as (
  update public.technician_profiles t
     set job_credits = t.job_credits + h.uses
    from held h
   where t.id = h.technician_id
  returning t.id, h.uses
)
insert into public.credit_ledger (user_id, role, delta, reason)
select id, 'technician', uses, 'request_refunded' from given_back;

create function private.charge_finished_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

create trigger jobs_charge_finished after update of status on public.jobs
  for each row
  when (
    new.source = 'platform'
    and new.status in ('finished', 'paid')
    and old.status not in ('finished', 'paid')
  )
  execute function private.charge_finished_job();
revoke execute on function private.charge_finished_job() from public, anon, authenticated;
