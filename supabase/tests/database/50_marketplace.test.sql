begin;
create extension if not exists pgtap with schema extensions;

select plan(62);

-- Consumers C and D; technicians: A and B cover Nasr City (B has no uses
-- left), F covers Maadi only, P covers Nasr City but isn't verified yet.
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', '201009990032', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', '201009990042', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', '201009990043', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a4', '201009990044', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c2', '+201009990032', 'حسام علي', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a2', '+201009990042', 'ياسر عبد الحميد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a3', '+201009990043', 'أحمد رمضان', 'technician'),
  ('00000000-0000-4000-8000-0000000000a4', '+201009990044', 'وليد حسني', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 2),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 2);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'heliopolis', 30.091, 31.322, 10, '{1,2,3,4,5,6,7}', 0, 'approved'),
  ('00000000-0000-4000-8000-0000000000a3', 3, 'x', 'maadi', 29.96, 31.257, 5, '{1,2,3,4,5,6,7}', 2, 'approved'),
  ('00000000-0000-4000-8000-0000000000a4', 3, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'pending');

insert into public.technician_areas (technician_id, area_id)
values
  ('00000000-0000-4000-8000-0000000000a2', 'nasr_city'),
  ('00000000-0000-4000-8000-0000000000a3', 'maadi');

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select t.id, 'ac_inspection_cleaning', 35000
  from (values
    ('00000000-0000-4000-8000-0000000000a1'::uuid),
    ('00000000-0000-4000-8000-0000000000a2'::uuid),
    ('00000000-0000-4000-8000-0000000000a3'::uuid),
    ('00000000-0000-4000-8000-0000000000a4'::uuid)
  ) as t (id);

insert into storage.objects (bucket_id, name, owner_id) values
  ('request-photos', '00000000-0000-4000-8000-0000000000c1/50000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000c1');

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

-- Tomorrow, Cairo time.
create function pg_temp.tomorrow()
returns date
language sql
as $$
  select (now() at time zone 'Africa/Cairo')::date + 1;
$$;

create function pg_temp.at_cairo(p_hour integer)
returns timestamptz
language sql
as $$
  select (pg_temp.tomorrow() + make_time(p_hour, 0, 0)) at time zone 'Africa/Cairo';
$$;

create function pg_temp.request_by(p_consumer uuid)
returns uuid
language sql
as $$
  select id from public.service_requests where consumer_id = p_consumer order by created_at desc, id limit 1;
$$;

create function pg_temp.push_job(p_job_id uuid, p_changes jsonb)
returns jsonb
language sql
as $$
  select public.sync_push(jsonb_build_array(jsonb_build_object(
    'entity', 'jobs',
    'id', p_job_id,
    'row', (select to_jsonb(j) - 'technician_id' - 'sync_txid' - 'version' from public.jobs j where j.id = p_job_id)
           || p_changes
  )));
$$;

create table pg_temp.ids (name text primary key, id uuid);

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- Addresses.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;

insert into pg_temp.ids
select 'home', public.save_consumer_address(null, ' البيت ', 'nasr_city', '14 شارع عباس العقاد، الدور الخامس');

select is(
  (select label from public.consumer_addresses),
  'البيت',
  'a consumer saves an address to their address book'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');

select is_empty(
  $$select id from public.consumer_addresses$$,
  'another consumer sees nobody else''s addresses'
);

select throws_ok(
  $$select public.create_service_request(
      'ac', 'not_cooling', null, null, (select id from pg_temp.ids where name = 'home'),
      pg_temp.tomorrow(), 'noon')$$,
  '22023',
  'invalid_address',
  'nobody can send a request to someone else''s address'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select throws_ok(
  $$select public.save_consumer_address(null, 'الورشة', 'nasr_city', 'شارع مصطفى النحاس')$$,
  '42501',
  'not_consumer',
  'a technician has no consumer address book'
);

-- Sending a request.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select throws_ok(
  $$select public.create_service_request(
      'ac', 'not_cooling', null, null, (select id from pg_temp.ids where name = 'home'),
      (now() at time zone 'Africa/Cairo')::date - 1, 'noon')$$,
  '22023',
  'invalid_time',
  'a request can''t ask for a time that has passed'
);

select throws_ok(
  $$select public.create_service_request(
      'electrical', 'other', null, null, (select id from pg_temp.ids where name = 'home'),
      pg_temp.tomorrow(), 'noon')$$,
  '22023',
  'invalid_category',
  'a request can''t ask for a service that isn''t open yet'
);

select throws_ok(
  $$select public.create_service_request(
      'ac', 'not_cooling', null,
      array['00000000-0000-4000-8000-0000000000c2/50000000-0000-4000-8000-000000000009.jpg'],
      (select id from pg_temp.ids where name = 'home'), pg_temp.tomorrow(), 'noon')$$,
  '22023',
  'invalid_photos',
  'a request can only carry the consumer''s own photos'
);

select is(
  public.create_service_request(
    'ac', 'not_cooling', 'التكييف شغال بس الهوا مش ساقع',
    array['00000000-0000-4000-8000-0000000000c1/50000000-0000-4000-8000-000000000001.jpg'],
    (select id from pg_temp.ids where name = 'home'), pg_temp.tomorrow(), 'noon'
  ) -> 'sent_to',
  '2'::jsonb,
  'a request reaches the verified technicians who cover its area'
);

insert into pg_temp.ids values ('r1', pg_temp.request_by('00000000-0000-4000-8000-0000000000c1'));

select is(
  (select request_credits from public.consumer_profiles),
  1,
  'sending a request holds one of the consumer''s uses'
);

select is(
  public.available_technician_count('ac', 'nasr_city'),
  2,
  'the home screen counts the verified technicians in the area'
);

-- What technicians see.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select is_empty(
  $$select id from public.service_requests$$,
  'technicians can''t read requests directly'
);

select is(
  jsonb_array_length(public.technician_requests()),
  1,
  'the request shows in the technician''s new requests'
);

select ok(
  public.technician_requests()::text !~ '(201009990031|عباس العقاد|مصطفى)',
  'a technician sees neither the phone number, the address nor the full name before being picked'
);

select is(
  public.technician_request((select id from pg_temp.ids where name = 'r1')) ->> 'consumer_name',
  'نورهان م.',
  'a technician sees the consumer''s first name and initial'
);

select ok(
  exists (
    select 1 from storage.objects
     where name = '00000000-0000-4000-8000-0000000000c1/50000000-0000-4000-8000-000000000001.jpg'
  ),
  'a technician who got the request can see its photos'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');

select is(
  public.technician_request((select id from pg_temp.ids where name = 'r1')),
  null,
  'a technician who didn''t get the request can''t open it'
);

select is_empty(
  $$select name from storage.objects where bucket_id = 'request-photos'$$,
  'a technician who didn''t get the request can''t see its photos'
);

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null)$$,
  'P0002',
  'not_found',
  'a technician who didn''t get the request can''t offer on it'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'request-photos',
      '00000000-0000-4000-8000-0000000000a3/50000000-0000-4000-8000-000000000002.jpg',
      '00000000-0000-4000-8000-0000000000a3')$$,
  '42501',
  null,
  'technicians can''t upload request photos'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a4');

select is(
  jsonb_array_length(public.technician_requests()),
  0,
  'a technician who isn''t verified yet gets no requests'
);

-- Offers.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(17), null)$$,
  '22023',
  'invalid_time',
  'an offer must come within the time the consumer asked for'
);

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), 'ac_freon_recharge', 30000, pg_temp.at_cairo(13), null)$$,
  '22023',
  'invalid_service',
  'an offer can only name a service the technician offers'
);

insert into pg_temp.ids
select 'offer_a', public.send_offer(
  (select id from pg_temp.ids where name = 'r1'), 'ac_inspection_cleaning', 35000,
  pg_temp.at_cairo(13), ' السعر شامل الكشف والتنظيف '
);

select is(
  (select note from public.request_offers),
  'السعر شامل الكشف والتنظيف',
  'a technician sends an offer and reads it back'
);

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null)$$,
  '23505',
  'already_offered',
  'a technician sends one offer per request'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(14), null)$$,
  'P0001',
  'no_credits',
  'a technician with no uses left can''t send an offer'
);

-- What the consumer sees.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select is(
  public.request_details((select id from pg_temp.ids where name = 'r1')) #>> '{offers,0,technician,name}',
  'محمود السيد',
  'the consumer sees each offer with its technician'
);

select is(
  public.request_details((select id from pg_temp.ids where name = 'r1')) ->> 'technician_phone',
  null,
  'the consumer doesn''t get a technician''s number before picking them'
);

select is(
  (public.request_details((select id from pg_temp.ids where name = 'r1')) ->> 'seen_by')::integer,
  1,
  'the consumer sees how many technicians opened the request'
);

select isnt(
  public.technician_profile('00000000-0000-4000-8000-0000000000a1'),
  null,
  'the consumer can open the page of a technician who made them an offer'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');

select is(
  public.request_details((select id from pg_temp.ids where name = 'r1')),
  null,
  'another consumer can''t open the request'
);

select is(
  public.technician_profile('00000000-0000-4000-8000-0000000000a1'),
  null,
  'technician pages are only open to consumers they made an offer to'
);

select throws_ok(
  $$select public.accept_offer((select id from pg_temp.ids where name = 'offer_a'))$$,
  'P0002',
  'not_found',
  'another consumer can''t pick an offer on the request'
);

-- Picking an offer.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

insert into pg_temp.ids
select 'job1', public.accept_offer((select id from pg_temp.ids where name = 'offer_a'));

select is(
  public.request_details((select id from pg_temp.ids where name = 'r1')) ->> 'technician_phone',
  '+201009990041',
  'after picking, the consumer gets the technician''s number'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select results_eq(
  $$select c.name, c.phone, j.address, j.status::text, j.source, j.scheduled_at
      from public.jobs j join public.customers c on c.id = j.customer_id
     where j.id = (select id from pg_temp.ids where name = 'job1')$$,
  $$values ('نورهان مصطفى', '+201009990031', '14 شارع عباس العقاد، الدور الخامس', 'unconfirmed', 'platform', pg_temp.at_cairo(13))$$,
  'the picked technician gets the job with the consumer''s name, phone and address'
);

select is(
  (select job_credits from public.technician_profiles),
  1,
  'being picked takes one of the technician''s uses'
);

select is(
  (select title || ' ' || unit_price_piastres from public.job_items),
  'كشف وتنظيف 35000',
  'the offer becomes the job''s agreed price'
);

-- A platform job's rules hold when the phone syncs.
select is(
  pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"deleted_at": "2026-10-03T10:00:00Z"}') #>> '{rejected,0,code}',
  'platform_job_locked',
  'a technician can''t delete a job a consumer booked'
);

select is(
  pg_temp.push_job(
    (select id from pg_temp.ids where name = 'job1'),
    jsonb_build_object('quote_status', 'accepted', 'quote_sent_at', now() + interval '1 minute')
  ) #>> '{rejected,0,code}',
  'quote_needs_customer',
  'only the consumer can accept a price change'
);

select is(
  pg_temp.push_job(
    (select id from pg_temp.ids where name = 'job1'),
    '{"quote_status": "sent", "quote_sent_at": "2026-10-03T10:00:00Z"}'
  ) -> 'rejected',
  '[]'::jsonb,
  'the technician sends a price change for the consumer to answer'
);

-- The consumer answers a price change.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select throws_ok(
  $$select public.answer_price_change(
      (select id from pg_temp.ids where name = 'r1'), '2026-10-03T09:00:00Z', true)$$,
  'P0001',
  'no_price_change',
  'an answer to an older price change is refused'
);

select public.answer_price_change(
  (select id from pg_temp.ids where name = 'r1'), '2026-10-03T10:00:00Z', true
);

select is(
  public.request_details((select id from pg_temp.ids where name = 'r1')) #>> '{job,quote_status}',
  'accepted',
  'the consumer accepts the price change'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select is(
  pg_temp.push_job(
    (select id from pg_temp.ids where name = 'job1'),
    '{"quote_status": "sent", "quote_sent_at": "2026-10-03T10:00:00Z"}'
  ) -> 'rejected',
  '[]'::jsonb,
  'a phone that hasn''t pulled the answer yet still syncs'
);

select is(
  (select quote_status::text from public.jobs where id = (select id from pg_temp.ids where name = 'job1')),
  'accepted',
  'a phone that still says "sent" keeps the consumer''s answer'
);

-- Reviews and complaints.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select throws_ok(
  $$select public.submit_review(
      (select id from pg_temp.ids where name = 'r1'), 5::smallint, '{}', null, 'cash')$$,
  'P0001',
  'not_reviewable',
  'a job can only be rated after it''s done'
);

select lives_ok(
  $$select public.submit_complaint(
      (select id from pg_temp.ids where name = 'r1'), 'no_show_or_late', 'اتأخر ساعة', null)$$,
  'the consumer reports a problem with the technician they picked'
);

select throws_ok(
  $$select public.submit_complaint(
      (select id from pg_temp.ids where name = 'r1'), 'other', null, null)$$,
  '23505',
  'already_complained',
  'one open complaint per request'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select is(
  pg_temp.push_job(
    (select id from pg_temp.ids where name = 'job1'),
    jsonb_build_object('status', 'finished', 'started_at', now(), 'finished_at', now())
  ) -> 'rejected',
  '[]'::jsonb,
  'the technician finishes the platform job'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select lives_ok(
  $$select public.submit_review(
      (select id from pg_temp.ids where name = 'r1'), 5::smallint,
      '{on_time,clean_work,on_time}', 'شغله نضيف', 'cash')$$,
  'the consumer rates the job once it''s done'
);

select throws_ok(
  $$select public.submit_review(
      (select id from pg_temp.ids where name = 'r1'), 1::smallint, '{}', null, 'cash')$$,
  '23505',
  'already_reviewed',
  'a job is rated once'
);

select is(
  public.technician_profile('00000000-0000-4000-8000-0000000000a1') #>> '{reviews,0,author}',
  'نورهان م.',
  'reviews show the author''s first name and initial'
);

-- Cancelling.
insert into pg_temp.ids
select 'r2', (public.create_service_request(
  'ac', 'leaking', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'afternoon'
) ->> 'id')::uuid;

select throws_ok(
  $$select public.create_service_request(
      'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home'),
      pg_temp.tomorrow(), 'evening')$$,
  'P0001',
  'no_credits',
  'a consumer with no uses left can''t send a request'
);

select public.cancel_service_request((select id from pg_temp.ids where name = 'r2'));

select is(
  (select request_credits from public.consumer_profiles),
  1,
  'cancelling before picking gives the use back'
);

insert into pg_temp.ids
select 'r3', (public.create_service_request(
  'ac', 'leaking', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'afternoon'
) ->> 'id')::uuid;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

insert into pg_temp.ids
select 'offer_b', public.send_offer(
  (select id from pg_temp.ids where name = 'r3'), null, 40000, pg_temp.at_cairo(16), null
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

insert into pg_temp.ids
select 'job3', public.accept_offer((select id from pg_temp.ids where name = 'offer_b'));

select public.cancel_service_request((select id from pg_temp.ids where name = 'r3'));

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select results_eq(
  $$select j.status::text, t.job_credits
      from public.jobs j, public.technician_profiles t
     where j.id = (select id from pg_temp.ids where name = 'job3')$$,
  $$values ('cancelled', 1)$$,
  'when the consumer cancels after picking, the job is cancelled and the technician gets the use back'
);

select is(
  pg_temp.push_job((select id from pg_temp.ids where name = 'job3'), '{"status": "confirmed"}') #>> '{rejected,0,code}',
  'cancelled_by_customer',
  'a phone can''t bring back a job the consumer cancelled'
);

-- The technician cancels.
reset role;
update public.consumer_profiles set request_credits = 1 where id = '00000000-0000-4000-8000-0000000000c1';
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

insert into pg_temp.ids
select 'r4', (public.create_service_request(
  'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'evening'
) ->> 'id')::uuid;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

insert into pg_temp.ids
select 'offer_c', public.send_offer(
  (select id from pg_temp.ids where name = 'r4'), null, 40000, pg_temp.at_cairo(19), null
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

insert into pg_temp.ids
select 'job4', public.accept_offer((select id from pg_temp.ids where name = 'offer_c'));

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');

select is(
  pg_temp.push_job(
    (select id from pg_temp.ids where name = 'job4'),
    jsonb_build_object('status', 'cancelled', 'cancelled_at', now())
  ) -> 'rejected',
  '[]'::jsonb,
  'the technician cancels a platform job'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select results_eq(
  $$select r.status::text, r.cancelled_by::text, c.request_credits
      from public.service_requests r, public.consumer_profiles c
     where r.id = (select id from pg_temp.ids where name = 'r4')$$,
  $$values ('cancelled', 'technician', 1)$$,
  'when the technician cancels, the request ends and the consumer gets the use back'
);

-- Time running out, and widening.
insert into pg_temp.ids
select 'r5', (public.create_service_request(
  'ac', 'needs_cleaning', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'morning'
) ->> 'id')::uuid;

select public.widen_request_window((select id from pg_temp.ids where name = 'r5'));

select is(
  (select time_window::text || ' ' || (expires_at = pg_temp.at_cairo(21)) from public.service_requests
    where id = (select id from pg_temp.ids where name = 'r5')),
  'any_time true',
  'the consumer widens the time to any time that day'
);

reset role;
update public.service_requests
   set created_at = now() - interval '3 hours'
 where id = (select id from pg_temp.ids where name = 'r5');
select private.marketplace_housekeeping();

select ok(
  exists (
    select 1 from public.request_recipients
     where request_id = (select id from pg_temp.ids where name = 'r5')
       and technician_id = '00000000-0000-4000-8000-0000000000a3'
  ),
  'a request with no offer after two hours reaches technicians a bit further away'
);

update public.service_requests
   set expires_at = now() - interval '1 minute'
 where id = (select id from pg_temp.ids where name = 'r5');

set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');

select is(
  public.request_details((select id from pg_temp.ids where name = 'r5')) ->> 'status',
  'expired',
  'a request reads as expired once its time passed'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');

select is(
  jsonb_array_length(public.technician_requests()),
  0,
  'an expired request leaves the technicians'' new requests'
);

reset role;
select private.marketplace_housekeeping();

select results_eq(
  $$select r.status::text, c.request_credits
      from public.service_requests r, public.consumer_profiles c
     where r.id = (select id from pg_temp.ids where name = 'r5') and c.id = r.consumer_id$$,
  $$values ('expired', 1)$$,
  'housekeeping records the expiry and gives the use back'
);

-- At most three offers.
update public.technician_profiles set job_credits = 5;
insert into public.request_recipients (request_id, technician_id, distance_km)
select (select id from pg_temp.ids where name = 'r1'), id, 1
  from public.technician_profiles
 where id not in (
   select technician_id from public.request_recipients
    where request_id = (select id from pg_temp.ids where name = 'r1')
 );
update public.service_requests
   set status = 'open', chosen_offer_id = null, job_id = null
 where id = (select id from pg_temp.ids where name = 'r1');
update public.request_offers
   set status = 'sent'
 where request_id = (select id from pg_temp.ids where name = 'r1');
set local role authenticated;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');
select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a4');

select throws_ok(
  $$select public.send_offer(
      (select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null)$$,
  'P0001',
  'request_closed',
  'a request takes at most three offers'
);

select * from finish();
rollback;
