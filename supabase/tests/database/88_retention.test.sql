begin;
create extension if not exists pgtap with schema extensions;

select plan(19);

-- Consumers c1 (books again and again) and c2 (reminders); technicians a1, a2.
create function pg_temp.u(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

create function pg_temp.ph(p_n text)
returns text
language sql
as $$
  select '20100' || lpad((ascii(left(p_n, 1)) * 10 + right(p_n, 1)::int)::text, 7, '0');
$$;

insert into auth.users (id, phone, aud, role)
select pg_temp.u(n), pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('c1'), ('c2'), ('a1'), ('a2')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n), 'اسم ' || n,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('a1'), ('a2')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 0 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2')) v (n);

insert into public.customers (id, technician_id, name, phone, source)
select pg_temp.u('d' || right(n, 1)), pg_temp.u(n), 'عميل ' || n, '+201000000099', 'platform'
  from (values ('a1'), ('a2')) v (n);

-- A platform job and the request that led to it.
create function pg_temp.booked(
  p_consumer text, p_technician text, p_category text, p_direct boolean,
  p_status public.job_status default 'unconfirmed',
  p_finished_at timestamptz default null
)
returns uuid
language plpgsql
as $$
declare
  v_job uuid := gen_random_uuid();
  v_request uuid := gen_random_uuid();
begin
  insert into public.jobs (id, technician_id, customer_id, status, finished_at, quote_status, source)
  values (v_job, pg_temp.u(p_technician), pg_temp.u('d' || right(p_technician, 1)),
          p_status, p_finished_at, 'accepted', 'platform');
  insert into public.service_requests (
    id, consumer_id, category_id, issue, area_id, address_label, address_details,
    preferred_on, time_window, expires_at, preferred_technician_id, status, job_id
  )
  values (
    v_request, pg_temp.u(p_consumer), p_category,
    case p_category when 'ac' then 'not_cooling' else 'washer_leaking' end::public.request_issue,
    'nasr_city', 'البيت', 'عنوان', current_date, 'any_time', now() + interval '1 day',
    case when p_direct then pg_temp.u(p_technician) end, 'assigned', v_job
  );
  return v_job;
end;
$$;

create function pg_temp.finish(p_job uuid)
returns void
language sql
as $$
  update public.jobs set status = 'finished', finished_at = now() where id = p_job;
$$;

-- First job with a1, asked for them directly: nothing to repeat yet.
create temp table first_job as select pg_temp.booked('c1', 'a1', 'ac', true) as id;
select ok(
  not (select repeat_booking from public.service_requests where job_id = (select id from first_job)),
  'a first booking is not a repeat'
);
select lives_ok($$select pg_temp.finish((select id from first_job))$$, 'the first job finishes');
select is(
  (select job_credits from public.technician_profiles where id = pg_temp.u('a1')),
  4,
  'the first finished job takes one of the technician''s uses'
);

-- Asking a1 again is a repeat; a2 and an open request are not.
create temp table second_job as select pg_temp.booked('c1', 'a1', 'ac', true) as id;
create temp table other_tech_job as select pg_temp.booked('c1', 'a2', 'ac', true) as id;
create temp table open_job as select pg_temp.booked('c1', 'a2', 'ac', false) as id;
select ok(
  (select repeat_booking from public.service_requests where job_id = (select id from second_job)),
  'asking the same technician again is a repeat booking'
);
select ok(
  not (select repeat_booking from public.service_requests where job_id = (select id from other_tech_job)),
  'another technician is not a repeat'
);
select ok(
  not (select repeat_booking from public.service_requests where job_id = (select id from open_job)),
  'a request sent to everyone is not a repeat'
);

-- The client can't claim it.
create temp table claimed as
  with ins as (
    insert into public.service_requests (
      consumer_id, category_id, issue, area_id, address_label, address_details,
      preferred_on, time_window, expires_at, repeat_booking
    )
    values (
      pg_temp.u('c2'), 'ac', 'not_cooling', 'nasr_city', 'البيت', 'عنوان',
      current_date, 'any_time', now() + interval '1 day', true
    )
    returning repeat_booking
  )
  select repeat_booking from ins;
select ok(
  not (select repeat_booking from claimed),
  'a request can''t be marked as a repeat by whoever sends it'
);

select lives_ok($$select pg_temp.finish((select id from second_job))$$, 'the repeat job finishes');
select is(
  (select job_credits from public.technician_profiles where id = pg_temp.u('a1')),
  4,
  'a repeat booking takes nothing from the technician'
);
select is(
  (select count(*)::int from public.credit_ledger
    where user_id = pg_temp.u('a1') and reason = 'job_finished'),
  1,
  'and leaves no charge in the ledger'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  0,
  'two finished jobs earn no gift yet'
);

-- The third finished job gives the consumer a free request.
create temp table third_job as select pg_temp.booked('c1', 'a1', 'ac', true) as id;
select lives_ok($$select pg_temp.finish((select id from third_job))$$, 'the third job finishes');
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  1,
  'the third finished job gives a free request'
);
select is(
  (select count(*)::int from public.credit_ledger
    where user_id = pg_temp.u('c1') and reason = 'loyalty_reward' and delta = 1),
  1,
  'the gift is in the ledger'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('c1') and kind = 'loyalty_reward'),
  1,
  'and the consumer is told'
);

-- Reminders: air conditioners after six months, washing machines after a year.
create temp table old_ac as select pg_temp.booked('c2', 'a2', 'ac', false, 'finished', now() - interval '7 months') as id;
create temp table old_washer as select pg_temp.booked('c2', 'a2', 'washing_machines', false, 'finished', now() - interval '7 months') as id;
select lives_ok('select private.send_maintenance_reminders()', 'the reminders run');
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('c2') and kind = 'maintenance_reminder'),
  1,
  'only the air conditioner is due after seven months'
);
select lives_ok('select private.send_maintenance_reminders()', 'the reminders run');
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('c2') and kind = 'maintenance_reminder'),
  1,
  'the same job is reminded once'
);

select * from finish();
rollback;
