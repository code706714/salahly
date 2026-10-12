begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

-- Consumers c1 and c2; technicians a1 (free now), a2 (not) and a3 (free now but
-- far away, in another area).
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

insert into auth.users (id, phone, aud, role)
select pg_temp.u(n), pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n), 'اسم ' || n,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 3 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2')) v (n);
-- a3 works in another area, too far to cover Nasr City.
insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u('a3'), 5, 'x', a.id, a.center_lat, a.center_lng, 5,
       '{1,2,3,4,5,6,7}', 5, 'approved'
  from public.service_areas a
 where a.id <> 'nasr_city'
   and private.distance_km(a.center_lat, a.center_lng, 30.056, 31.33) > 20
 order by a.id
 limit 1;

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select pg_temp.u(n), 'ac_inspection_cleaning', 35000 from (values ('a1'), ('a2'), ('a3')) v (n);

insert into public.consumer_addresses (consumer_id, label, area_id, details)
select pg_temp.u(n), 'البيت', 'nasr_city', '14 شارع عباس العقاد' from (values ('c1'), ('c2')) v (n);

-- Being free now -------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select ok(public.set_available_now(true) > now() + interval '3 hours', 'a technician switches on "available now" for hours');
select ok(public.my_availability() is not null, 'and reads it back');

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  $$select public.set_available_now(true)$$, '42501', 'not_verified',
  'a consumer can''t be available'
);
select is(
  public.urgent_info('ac', 'nasr_city') -> 'available_now', '1'::jsonb,
  'the consumer is told how many are free in the area: only a1'
);
select is(
  public.urgent_info('ac', 'nasr_city') -> 'fee_piastres', '10000'::jsonb,
  'and the fee, known before sending'
);

-- Sending ------------------------------------------------------------------------

create temp table sent as
  select public.create_urgent_request(
    'ac', 'not_cooling', null, null, (select id from public.consumer_addresses)
  ) as r;
grant all on table sent to authenticated;
select is((select r ->> 'sent_to' from sent), '1', 'the request reaches the one technician free now');

reset role;
select is(
  (select (urgent, urgent_fee_piastres, expires_at <= now() + interval '30 minutes',
           expires_at > now() + interval '25 minutes', credit_held)::text
     from public.service_requests where id = (select (r ->> 'id')::uuid from sent)),
  '(t,10000,t,t,t)',
  'it is urgent, carries the fee, lives half an hour and holds a use'
);
select is(
  (select array_agg(technician_id::text) from public.request_recipients
    where request_id = (select (r ->> 'id')::uuid from sent)),
  array[pg_temp.u('a1')::text],
  'only a1 got it'
);
select is(
  (select kind::text from public.notifications
    where user_id = pg_temp.u('a1') and request_id = (select (r ->> 'id')::uuid from sent)),
  'urgent_request',
  'and is told it is urgent'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  2,
  'the consumer pays one request like any other'
);

-- Nobody else can pick it up -----------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a2'));
set local role authenticated;
select is(
  public.technician_request((select (r ->> 'id')::uuid from sent)),
  null,
  'a technician who is not free now doesn''t see it'
);
select throws_ok(
  format($$select public.send_offer(%L, null, 30000, now() + interval '1 hour', null)$$,
         (select (r ->> 'id') from sent)),
  'P0002', 'not_found', 'and can''t offer on it'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select throws_ok(
  format($$select public.send_offer(%L, null, 30000, now() + interval '5 hours', null)$$,
         (select (r ->> 'id') from sent)),
  '22023', 'invalid_time', 'an offer must promise to arrive within three hours'
);
select lives_ok(
  format($$select public.send_offer(%L, null, 30000, now() + interval '90 minutes', null)$$,
         (select (r ->> 'id') from sent)),
  'an offer inside three hours is taken'
);

-- Picking it ---------------------------------------------------------------------

reset role;
create temp table the_offer as
  select id from public.request_offers
   where request_id = (select (r ->> 'id')::uuid from sent);
grant select on table the_offer to authenticated;
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select lives_ok(
  format($$select public.accept_offer(%L)$$, (select id from the_offer)),
  'the consumer picks the offer'
);
reset role;
select is(
  (select array_agg(i.title || ':' || i.unit_price_piastres order by i.unit_price_piastres)
     from public.service_requests r
     join public.job_items i on i.job_id = r.job_id
    where r.id = (select (r ->> 'id')::uuid from sent)),
  array['رسوم استعجال:10000', 'السعر المبدئي:30000'],
  'the job carries the price and the urgent fee as its own line'
);

-- When nobody is free ---------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select is(public.set_available_now(false), null, 'switching off clears it');
select is(public.my_availability(), null, 'and reads as nothing');

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  $$select public.create_urgent_request(
      'ac', 'not_cooling', null, null, (select id from public.consumer_addresses))$$,
  'P0001', 'no_technician_available', 'with nobody free the request is refused'
);
reset role;
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c2')),
  3,
  'and no use is taken'
);

-- A client can't claim it --------------------------------------------------------------

create temp table claimed as
  with ins as (
    insert into public.service_requests (
      consumer_id, category_id, issue, area_id, address_label, address_details,
      preferred_on, time_window, expires_at, urgent, urgent_fee_piastres
    )
    values (
      pg_temp.u('c2'), 'ac', 'not_cooling', 'nasr_city', 'البيت', 'عنوان',
      current_date, 'any_time', now() + interval '1 day', true, 5
    )
    returning urgent, urgent_fee_piastres
  )
  select * from ins;
select is(
  (select (urgent, urgent_fee_piastres)::text from claimed),
  '(f,0)',
  'a plain insert can''t make a request urgent or set its fee'
);

select * from finish();
rollback;
