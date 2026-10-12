begin;
create extension if not exists pgtap with schema extensions;

select plan(17);

-- Consumers c1 (with no uses left) and c2; technician a1 (and a2, who offers
-- the service too).
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

create function pg_temp.sign_in_as(p_user_id uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text,
    true
  );
$$;

create function pg_temp.tomorrow()
returns date
language sql
as $$
  select (now() at time zone 'Africa/Cairo')::date + 1;
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

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select pg_temp.u(n), 'ac_inspection_cleaning', 35000 from (values ('a1'), ('a2')) v (n);

insert into public.consumer_addresses (consumer_id, label, area_id, details)
values (pg_temp.u('c1'), 'البيت', 'nasr_city', '14 شارع عباس العقاد');

insert into public.customers (id, technician_id, name, phone, source)
values (pg_temp.u('d1'), pg_temp.u('a1'), 'عميل', '+201000000099', 'platform');

-- A job a1 finished for c1 through the app, and the request behind it.
create function pg_temp.finished_job(p_consumer text, p_ago interval)
returns uuid
language plpgsql
as $$
declare
  v_job uuid := gen_random_uuid();
  v_request uuid := gen_random_uuid();
begin
  insert into public.jobs (id, technician_id, customer_id, status, finished_at, quote_status, source)
  values (v_job, pg_temp.u('a1'), pg_temp.u('d1'), 'finished', now() - p_ago, 'accepted', 'platform');
  insert into public.service_requests (
    id, consumer_id, category_id, issue, area_id, address_label, address_details,
    preferred_on, time_window, expires_at, status, job_id
  )
  values (
    v_request, pg_temp.u(p_consumer), 'ac', 'not_cooling', 'nasr_city', 'البيت',
    'عنوان', current_date, 'any_time', now() + interval '1 day', 'assigned', v_job
  );
  return v_request;
end;
$$;

create table pg_temp.ids (name text primary key, id uuid);
insert into pg_temp.ids values
  ('fresh', pg_temp.finished_job('c1', interval '2 days')),
  ('old', pg_temp.finished_job('c1', interval '15 days'));

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

select ok(
  private.warranty_until((select id from pg_temp.ids where name = 'fresh'), pg_temp.u('c1')) > now(),
  'a job finished two days ago is still covered'
);
select ok(
  private.warranty_until((select id from pg_temp.ids where name = 'old'), pg_temp.u('c1')) is null,
  'one finished fifteen days ago is not'
);
select ok(
  private.warranty_until((select id from pg_temp.ids where name = 'fresh'), pg_temp.u('c2')) is null,
  'and nobody else can claim a job'
);

select throws_ok(
  $$insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at)
    values ((select id from pg_temp.ids where name = 'fresh'), pg_temp.u('a2'), 50, now() + interval '2 hours')$$,
  '22023', 'invalid_price', 'an offer that is not for a warranty visit can''t cost less than a pound'
);

-- Booking the visit -----------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select throws_ok(
  $$select public.request_warranty_visit(
      (select id from pg_temp.ids where name = 'old'), 'not_cooling', null, null,
      (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon')$$,
  'P0001', 'warranty_unavailable', 'a job past its fourteen days gets no visit'
);

insert into pg_temp.ids
select 'visit', (public.request_warranty_visit(
  (select id from pg_temp.ids where name = 'fresh'), 'not_cooling', null, null,
  (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon'
) ->> 'id')::uuid;

select throws_ok(
  $$select public.request_warranty_visit(
      (select id from pg_temp.ids where name = 'fresh'), 'not_cooling', null, null,
      (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon')$$,
  'P0001', 'warranty_unavailable', 'one visit at a time'
);

select is(
  (public.request_details((select id from pg_temp.ids where name = 'visit')) ->> 'is_warranty')::boolean,
  true,
  'the request page says it is a warranty visit'
);
select is(
  public.request_details((select id from pg_temp.ids where name = 'fresh')) -> 'warranty_until',
  'null'::jsonb,
  'and the first job offers no second visit while one is booked'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  $$select public.request_warranty_visit(
      (select id from pg_temp.ids where name = 'fresh'), 'not_cooling', null, null,
      (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon')$$,
  'P0001', 'warranty_unavailable', 'another customer can''t book a visit on it'
);

reset role;

select is(
  (select (status, warranty_of, repeat_booking, credit_held)::text
     from public.service_requests where id = (select id from pg_temp.ids where name = 'visit')),
  '(assigned,' || (select id from pg_temp.ids where name = 'fresh') || ',t,f)',
  'the visit is booked at once, as a repeat, holding no use'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  0,
  'it costs the customer nothing'
);
select is(
  (select count(*)::int from public.credit_ledger where user_id = pg_temp.u('c1')),
  0,
  'and leaves no trace in the ledger'
);
select is(
  (select (j.source, j.technician_id = pg_temp.u('a1'), i.title, i.unit_price_piastres)::text
     from public.service_requests r
     join public.jobs j on j.id = r.job_id
     join public.job_items i on i.job_id = j.id
    where r.id = (select id from pg_temp.ids where name = 'visit')),
  '(platform,t,"زيارة ضمان",0)',
  'the technician gets a free job'
);
select is(
  (select array_agg(kind::text order by kind::text) from public.notifications
    where user_id = pg_temp.u('a1') and request_id = (select id from pg_temp.ids where name = 'visit')),
  array['offer_picked'],
  'he is told of the visit only'
);
select is(
  (select count(*)::int from public.notifications where user_id = pg_temp.u('c1')),
  0,
  'and the customer is told nothing'
);

-- Finishing it ----------------------------------------------------------------------

update public.jobs set status = 'finished', finished_at = now()
 where id = (select job_id from public.service_requests where id = (select id from pg_temp.ids where name = 'visit'));
select is(
  (select job_credits from public.technician_profiles where id = pg_temp.u('a1')),
  5,
  'finishing it takes nothing from the technician'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  0,
  'and a visit never counts toward a gift'
);

select * from finish();
rollback;
