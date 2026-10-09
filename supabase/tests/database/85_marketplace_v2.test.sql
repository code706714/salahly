begin;
create extension if not exists pgtap with schema extensions;

select plan(51);

-- Consumers c1 and c2. Technicians (all with an AC service unless noted):
--   a1 verified, Nasr City            a2 verified, Heliopolis + Nasr City
--   a3 verified, Maadi (other area)   a4 NOT verified yet, Nasr City
--   a5 verified, Nasr City, plumbing only (other category)
--   a6 verified but suspended         a7 verified, works one other weekday
--   a8 verified, Heliopolis, 10 km radius reaches Nasr City
create function pg_temp.ph(p_n text)
returns text
language sql
as $$
  select '20100' || lpad((ascii(left(p_n, 1)) * 10 + right(p_n, 1)::int)::text, 7, '0');
$$;

insert into auth.users (id, phone, aud, role)
select ('00000000-0000-4000-8000-0000000000' || n)::uuid, pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3'), ('a4'), ('a5'), ('a6'), ('a7'), ('a8')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select ('00000000-0000-4000-8000-0000000000' || n)::uuid, '+' || pg_temp.ph(n),
       case n when 'c1' then 'نورهان مصطفى' when 'c2' then 'حسام علي' else 'فني ' || n || ' سيد' end,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3'), ('a4'), ('a5'), ('a6'), ('a7'), ('a8')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 10),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 10);

create function pg_temp.tomorrow()
returns date
language sql
as $$
  select (now() at time zone 'Africa/Cairo')::date + 1;
$$;

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'heliopolis', 30.091, 31.322, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a3', 3, 'x', 'maadi', 29.96, 31.257, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a4', 3, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'pending'),
  ('00000000-0000-4000-8000-0000000000a5', 3, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a6', 3, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a7', 3, 'x', 'nasr_city', 30.056, 31.33, 5,
     array[(extract(isodow from pg_temp.tomorrow())::int % 7) + 1]::smallint[], 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a8', 3, 'x', 'heliopolis', 30.091, 31.322, 10, '{1,2,3,4,5,6,7}', 3, 'approved');

update public.profiles set suspended_at = now() where id = '00000000-0000-4000-8000-0000000000a6';

insert into public.technician_areas (technician_id, area_id)
values
  ('00000000-0000-4000-8000-0000000000a2', 'nasr_city'),
  ('00000000-0000-4000-8000-0000000000a3', 'maadi');

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select t.id, case when t.id = '00000000-0000-4000-8000-0000000000a5' then 'plumbing_inspection' else 'ac_inspection' end, 15000
  from public.technician_profiles t;

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

create function pg_temp.at_cairo(p_hour integer)
returns timestamptz
language sql
as $$
  select (pg_temp.tomorrow() + make_time(p_hour, 0, 0)) at time zone 'Africa/Cairo';
$$;

create function pg_temp.tech(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

create table pg_temp.ids (name text primary key, id uuid);

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- Categories ------------------------------------------------------------------

select is(
  (select array_agg(id order by sort_order) from public.service_categories where is_active),
  array['ac', 'plumbing', 'electrical', 'washing_machines', 'refrigerators'],
  'plumbing, air conditioning, electrical, washing machines and refrigerators are open'
);

select is_empty(
  $$select id from public.service_categories where id = 'appliances' and is_active$$,
  'the combined appliances category is not open'
);

select is_empty(
  $$select c.id
      from public.service_categories c
     where c.is_active
       and ((select count(*) from public.services s where s.category_id = c.id and s.is_active) < 3
            or not exists (
              select 1 from public.category_issues i where i.category_id = c.id and i.issue = 'other'
            ))$$,
  'every open category has services and an "other" issue'
);

select is(
  (select array_agg(issue::text order by sort_order) from public.category_issues where category_id = 'ac'),
  array['not_cooling', 'leaking', 'noisy', 'needs_cleaning', 'installation', 'other'],
  'the air-conditioning issues are the ones the app already knows'
);

-- Who gets a request ------------------------------------------------------------

insert into public.consumer_addresses (consumer_id, label, area_id, details)
values
  ('00000000-0000-4000-8000-0000000000c1', 'البيت', 'nasr_city', '14 شارع عباس العقاد، الدور الخامس'),
  ('00000000-0000-4000-8000-0000000000c2', 'البيت', 'nasr_city', '3 شارع الطيران');

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;

select throws_ok(
  $$select public.create_service_request(
      'ac', 'plumbing_leak', null, null,
      (select id from public.consumer_addresses limit 1), pg_temp.tomorrow(), 'noon')$$,
  '22023',
  'invalid_issue',
  'an issue from another category is refused'
);

insert into pg_temp.ids
select 'r1', (public.create_service_request(
  'ac', 'not_cooling', null, null,
  (select id from public.consumer_addresses limit 1), pg_temp.tomorrow(), 'noon'
) ->> 'id')::uuid;

reset role;

select is(
  (select array_agg(substring(technician_id::text from 35) order by technician_id)
     from public.request_recipients where request_id = (select id from pg_temp.ids where name = 'r1')),
  array['a1', 'a2', 'a7', 'a8'],
  'a request reaches every verified technician who offers the service and covers the area, on any weekday'
);

select is_empty(
  $$select technician_id from public.request_recipients
     where technician_id in (pg_temp.tech('a3'), pg_temp.tech('a4'), pg_temp.tech('a5'), pg_temp.tech('a6'))$$,
  'not the other area, the unverified, the other category or the suspended'
);

select is(
  (select count(*)::int from public.notifications
    where kind = 'new_request' and request_id = (select id from pg_temp.ids where name = 'r1')),
  4,
  'each of them is notified (and so pushed)'
);

select is(
  (select count(*)::int from private.push_outbox o
     join public.notifications n on n.id = o.notification_id
    where n.kind = 'new_request' and n.request_id = (select id from pg_temp.ids where name = 'r1')),
  4,
  'the new-request notifications are queued for push'
);

-- More than five matching technicians: nobody is left out.
insert into auth.users (id, phone, aud, role)
select ('00000000-0000-4000-8000-000000000b' || lpad(n::text, 2, '0'))::uuid, '20100999' || lpad(n::text, 4, '0'), 'authenticated', 'authenticated'
  from generate_series(1, 8) n;
insert into public.profiles (id, phone, full_name, active_role)
select ('00000000-0000-4000-8000-000000000b' || lpad(n::text, 2, '0'))::uuid, '+20100999' || lpad(n::text, 4, '0'), 'فني ' || n, 'technician'
  from generate_series(1, 8) n;
insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select ('00000000-0000-4000-8000-000000000b' || lpad(n::text, 2, '0'))::uuid, 4, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'
  from generate_series(1, 8) n;
insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select ('00000000-0000-4000-8000-000000000b' || lpad(n::text, 2, '0'))::uuid, 'ac_inspection_cleaning', 35000
  from generate_series(1, 8) n;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;

select is(
  public.create_service_request(
    'ac', 'leaking', null, null,
    (select id from public.consumer_addresses where consumer_id = pg_temp.tech('c2')),
    pg_temp.tomorrow(), 'noon'
  ) -> 'sent_to',
  '12'::jsonb,
  'twelve matching technicians all get the request, not just the nearest five'
);
insert into pg_temp.ids
select 'r2', id from public.service_requests where consumer_id = pg_temp.tech('c2');

select is(
  public.available_technician_count('ac', 'nasr_city'),
  12,
  'the home screen counts the same technicians'
);

select is(
  public.available_technician_count('plumbing', 'nasr_city'),
  1,
  'and only those of the category'
);

-- Backfill ------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.tech('a4'));

select is(
  public.update_technician_offering(
    '[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1, 2, 3]::smallint[], 10::smallint
  ),
  0,
  'an unverified technician can edit what they offer, and gets no requests yet'
);
select is(
  (select verification_status::text from public.technician_profiles),
  'pending',
  'editing doesn''t change the verification status'
);
select is(
  public.technician_requests(),
  '[]'::jsonb,
  'the unverified technician sees no requests'
);

reset role;
update public.technician_profiles set verification_status = 'approved'
 where id = pg_temp.tech('a4');

select is(
  (select count(*)::int from public.request_recipients where technician_id = pg_temp.tech('a4')),
  2,
  'a technician approved later gets the still-open matching requests'
);
select is(
  (select array_agg(kind::text order by kind::text) from public.notifications where user_id = pg_temp.tech('a4')),
  array['new_request', 'verification_approved'],
  'they are told once about the newest, and that they were verified'
);

-- A technician adds a service and gets what is open.
select pg_temp.sign_in_as(pg_temp.tech('a5'));
set local role authenticated;

select is(
  jsonb_array_length(public.technician_requests()),
  0,
  'a technician of another category sees none of them'
);
select is(
  public.update_technician_offering(
    '[{"service_id": "plumbing_inspection", "starting_price_piastres": 15000},
      {"service_id": "ac_inspection", "starting_price_piastres": 18000}]',
    array['nasr_city'], array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  ),
  2,
  'adding a service hands the technician the open requests it matches'
);
select is(
  jsonb_array_length(public.technician_requests()),
  2,
  'and they show up in their list'
);

-- Browse ---------------------------------------------------------------------------

select ok(
  public.browse_open_requests()::text !~ '(20100|عباس العقاد|الطيران|مصطفى|علي)',
  'browsing open requests shows no phone, no address and no full name'
);
select ok(
  public.browse_open_requests()::text ~ 'حسام ع\.',
  'it shows the consumer''s first name and initial'
);
select is(
  jsonb_array_length(public.browse_open_requests('ac')),
  2,
  'a technician browses open requests in their categories'
);
select is(
  jsonb_array_length(public.browse_open_requests('plumbing')),
  0,
  'a category filter narrows them'
);
select is(
  jsonb_array_length(public.browse_open_requests(null, 1, 1)),
  1,
  'it pages'
);

select pg_temp.sign_in_as(pg_temp.tech('a3'));
select is(
  public.browse_open_requests(),
  '[]'::jsonb,
  'a technician in another area browses nothing'
);
select pg_temp.sign_in_as(pg_temp.tech('a6'));
select is(
  public.browse_open_requests(),
  '[]'::jsonb,
  'a suspended technician browses nothing'
);
select pg_temp.sign_in_as(pg_temp.tech('c1'));
select is(
  public.browse_open_requests(),
  '[]'::jsonb,
  'a consumer browses nothing'
);

-- Technician sees a request nobody sent them (matched later, no row).
reset role;
delete from public.request_recipients
 where request_id = (select id from pg_temp.ids where name = 'r2') and technician_id = pg_temp.tech('a8');
select pg_temp.sign_in_as(pg_temp.tech('a8'));
set local role authenticated;

select is(
  jsonb_array_length(public.browse_open_requests()),
  2,
  'a technician it is meant for browses it without being on its recipients'
);
select is(
  (public.technician_request((select id from pg_temp.ids where name = 'r2')) ->> 'id')::uuid,
  (select id from pg_temp.ids where name = 'r2'),
  'opening it adds them as a recipient'
);

-- Five offers, verified technicians only ---------------------------------------------

select pg_temp.sign_in_as(pg_temp.tech('a1'));
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.tech('a2'));
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.tech('a7'));
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.tech('a8'));
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.tech('a4'));
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);

select pg_temp.sign_in_as(pg_temp.tech('a5'));
select is(
  jsonb_array_length(public.technician_requests()),
  1,
  'a request with five offers leaves the other technicians'' lists'
);
select is(
  jsonb_array_length(public.browse_open_requests()),
  1,
  'and their browse list'
);
select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null)$$,
  'P0001',
  'request_closed',
  'a sixth offer is refused'
);

select pg_temp.sign_in_as(pg_temp.tech('a3'));
select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r2'), null, 30000, pg_temp.at_cairo(13), null)$$,
  'P0002',
  'not_found',
  'a technician the request isn''t meant for can''t offer on it'
);

select pg_temp.sign_in_as(pg_temp.tech('a6'));
select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r2'), null, 30000, pg_temp.at_cairo(13), null)$$,
  '42501',
  'account_suspended',
  'a suspended technician can''t offer'
);

select pg_temp.sign_in_as(pg_temp.tech('c1'));
select is(
  jsonb_array_length(public.request_details((select id from pg_temp.ids where name = 'r1')) -> 'offers'),
  5,
  'the consumer sees the five offers'
);

-- A request meant for one technician stays with them until widened.
select pg_temp.sign_in_as(pg_temp.tech('c1'));
select is(
  public.create_service_request(
    'ac', 'noisy', null, null,
    (select id from public.consumer_addresses where consumer_id = pg_temp.tech('c1')),
    pg_temp.tomorrow(), 'noon', pg_temp.tech('a1')
  ) -> 'sent_to',
  '1'::jsonb,
  'a consumer can pick a technician to send a request to'
);
select pg_temp.sign_in_as(pg_temp.tech('a2'));
select is(
  jsonb_array_length(public.browse_open_requests('ac')),
  2,
  'other technicians don''t browse it'
);

-- Editing what a technician offers ------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.tech('a2'));

select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_unicorn", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[])$$,
  '22023', 'invalid_services', 'unknown services are refused'
);
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 5}]', array['nasr_city'], array[1]::smallint[])$$,
  '22023', 'invalid_services', 'a price under one pound is refused'
);
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array[]::text[], array[1]::smallint[])$$,
  '22023', 'invalid_areas', 'at least one area is needed'
);
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[8]::smallint[])$$,
  '22023', 'invalid_work_days', 'work days are 1 to 7'
);
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[], 7::smallint)$$,
  '22023', 'invalid_radius', 'the radius is 5, 10 or 15'
);
select is(
  public.update_technician_offering(
    '[{"service_id": "ac_inspection", "starting_price_piastres": 22000},
      {"service_id": "washer_inspection", "starting_price_piastres": 17000}]',
    array['nasr_city', 'maadi'], array[6, 7]::smallint[], 15::smallint
  ) >= 0,
  true,
  'a technician replaces their services, areas, work days and radius'
);
select is(
  (select jsonb_array_length(public.my_technician_offering() -> 'services')),
  2,
  'the edit screen reads them back'
);
select is(
  (select starting_price_piastres from public.technician_services where service_id = 'ac_inspection'),
  22000::bigint,
  'the price changed'
);

select pg_temp.sign_in_as(pg_temp.tech('c1'));
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[])$$,
  '42501', 'not_technician', 'a consumer can''t edit a technician''s offering'
);

select pg_temp.sign_in_as(pg_temp.tech('a6'));
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[])$$,
  '42501', 'account_suspended', 'a suspended technician can''t edit'
);

-- Spam: the eleventh edit in an hour is refused.
select pg_temp.sign_in_as(pg_temp.tech('a8'));
select public.update_technician_offering(
  '[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[]
) from generate_series(1, 10);
select throws_ok(
  $$select public.update_technician_offering('[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]', array['nasr_city'], array[1]::smallint[])$$,
  '54000', 'rate_limited', 'editing is rate limited'
);

-- Spam: a request reaches everyone, so sending them is limited.
reset role;
insert into private.action_log (user_id, action)
select pg_temp.tech('c2'), 'create_request' from generate_series(1, 10);
select pg_temp.sign_in_as(pg_temp.tech('c2'));
set local role authenticated;
select throws_ok(
  $$select public.create_service_request(
      'ac', 'noisy', null, null,
      (select id from public.consumer_addresses where consumer_id = pg_temp.tech('c2')),
      pg_temp.tomorrow(), 'noon')$$,
  '54000', 'rate_limited', 'sending requests is rate limited'
);

select is_empty(
  $$select 1 where has_table_privilege('authenticated', 'public.category_issues', 'insert')$$,
  'the issue lists can''t be written by app users'
);

reset role;
select * from finish();
rollback;
