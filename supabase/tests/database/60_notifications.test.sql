begin;
create extension if not exists pgtap with schema extensions;

select plan(33);

-- Consumers C1 and C2, technicians A1 and A2 (both cover Nasr City, two
-- uses each) and A3 (waiting for verification).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', '201009990032', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', '201009990042', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', '201009990043', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c2', '+201009990032', 'حسام علي', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a2', '+201009990042', 'ياسر عبد الحميد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a3', '+201009990043', 'أحمد رمضان', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 5),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 5);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'approved'),
  ('00000000-0000-4000-8000-0000000000a3', 3, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'pending');

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select t.id, 'ac_inspection_cleaning', 35000
  from (values
    ('00000000-0000-4000-8000-0000000000a1'::uuid),
    ('00000000-0000-4000-8000-0000000000a2'::uuid)
  ) as t (id);

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

create function pg_temp.at_cairo(p_hour integer)
returns timestamptz
language sql
as $$
  select (pg_temp.tomorrow() + make_time(p_hour, 0, 0)) at time zone 'Africa/Cairo';
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

-- The kinds a person has, oldest first, on one side.
create function pg_temp.kinds(p_user uuid, p_role public.user_role)
returns text
language sql
as $$
  select coalesce(string_agg(kind::text, ',' order by created_at, kind::text), '')
    from public.notifications where user_id = p_user and role = p_role;
$$;

create table pg_temp.ids (name text primary key, id uuid);
grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- A request goes to the two technicians who cover it.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'home', public.save_consumer_address(null, 'البيت', 'nasr_city', '14 شارع عباس العقاد');
insert into pg_temp.ids
select 'r1', (public.create_service_request(
  'ac', 'not_cooling', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
reset role;

select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a1', 'technician'), 'new_request',
  'a technician is told about a request sent to them');
select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a2', 'technician'), 'new_request',
  'every technician it was sent to is told');
select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a3', 'technician'), '',
  'a technician it was not sent to is not');
select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000c1', 'consumer'), '',
  'sending a request tells the consumer nothing');

-- Offers.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
insert into pg_temp.ids
select 'offer_a', public.send_offer((select id from pg_temp.ids where name = 'r1'),
  'ac_inspection_cleaning', 35000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
insert into pg_temp.ids
select 'offer_b', public.send_offer((select id from pg_temp.ids where name = 'r1'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(14), null);
reset role;

select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000c1', 'consumer'), 'offer_received,offer_received',
  'the consumer is told about each offer');

-- Picking.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'job1', public.accept_offer((select id from pg_temp.ids where name = 'offer_a'));
reset role;

select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a1', 'technician'), 'new_request,offer_picked',
  'the picked technician is told');
select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a2', 'technician'), 'new_request,offer_not_picked',
  'the other technician is told it went elsewhere');

-- The technician moves the job along.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "confirmed"}');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'),
  '{"quote_status": "sent", "quote_sent_at": "2026-10-03T10:00:00Z"}');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "started"}');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "finished"}');
reset role;

select is(
  pg_temp.kinds('00000000-0000-4000-8000-0000000000c1', 'consumer'),
  'offer_received,offer_received,job_confirmed,price_change,job_started,job_finished',
  'the consumer hears each step of the job and a new price'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"description": "تفاصيل"}');
reset role;
select is(
  (select count(*)::int from public.notifications
    where user_id = '00000000-0000-4000-8000-0000000000c1' and role = 'consumer'),
  6,
  'saving the job again without a step or a new price tells nobody'
);

-- Reading: own rows only, shaped for the text.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select is((select count(*)::int from public.notifications), 6, 'a consumer sees only their own notifications');
select is(
  (select count(*)::int from public.notifications where read_at is null), 6,
  'new notifications are unread'
);
select is(
  (public.my_notifications('consumer') -> 0 ->> 'kind'), 'job_finished',
  'the list comes newest first'
);
select is(
  (select count(*)::int from jsonb_array_elements(public.my_notifications('consumer')) e
    where e ->> 'kind' = 'offer_received' and e ->> 'technician_name' is not null
      and (e ->> 'price_piastres')::int in (35000, 30000)),
  2,
  'an offer notification carries the technician and the price'
);
select is(
  (select e ->> 'technician_name' from jsonb_array_elements(public.my_notifications('consumer')) e
    where e ->> 'kind' = 'job_started'),
  'محمود السيد',
  'a job notification carries the chosen technician'
);
select is(public.my_notifications('technician'), '[]'::jsonb,
  'the other side of the same person is separate');
select throws_ok(
  $$insert into public.notifications (user_id, role, kind) values (auth.uid(), 'consumer', 'job_started')$$,
  '42501', null, 'nobody writes notifications from the app'
);
select throws_ok(
  $$update public.notifications set read_at = null$$,
  '42501', null, 'nobody edits notifications directly'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select is((select count(*)::int from public.notifications), 0, 'another consumer sees none of them');
select is(public.mark_notifications_read('consumer'), 0, 'marking read touches nobody else''s');

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
select is(
  public.mark_notifications_read('consumer', array[(select id from public.notifications order by created_at, id limit 1)]),
  1, 'marking by id marks just that one'
);
select is((select count(*)::int from public.notifications where read_at is null), 5, 'the rest stay unread');
select is(public.mark_notifications_read('consumer'), 5, 'marking all marks every unread one');
select is(public.mark_notifications_read('consumer'), 0, 'marking again changes nothing');
reset role;

-- A technician sees the consumer's first name and the distance.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
set local role authenticated;
select is(
  (select e ->> 'consumer_name' || ' ' || (e ->> 'consumer_honorific')
     from jsonb_array_elements(public.my_notifications('technician')) e
    where e ->> 'kind' = 'new_request'),
  'نورهان م. ms',
  'a technician sees the consumer''s first name and initial only'
);
reset role;

-- Cancelling: before a pick, offers waiting hear about it; after, the picked one.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
insert into pg_temp.ids
select 'home2', public.save_consumer_address(null, 'البيت', 'nasr_city', '9 شارع النصر');
insert into pg_temp.ids
select 'r2', (public.create_service_request(
  'ac', 'leaking', null, null, (select id from pg_temp.ids where name = 'home2'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select public.send_offer((select id from pg_temp.ids where name = 'r2'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select public.cancel_service_request((select id from pg_temp.ids where name = 'r2'));
reset role;

select is(
  (select string_agg(user_id::text, ',' order by user_id) from public.notifications
    where kind = 'request_cancelled_by_consumer'
      and request_id = (select id from pg_temp.ids where name = 'r2')),
  '00000000-0000-4000-8000-0000000000a2',
  'cancelling before a pick tells the technician who made an offer, not the others'
);

-- A technician cancelling tells the consumer.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'r3', (public.create_service_request(
  'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
insert into pg_temp.ids
select 'offer_r3', public.send_offer((select id from pg_temp.ids where name = 'r3'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
insert into pg_temp.ids
select 'job3', public.accept_offer((select id from pg_temp.ids where name = 'offer_r3'));
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job3'), '{"status": "cancelled"}');
reset role;

select is(
  (select count(*)::int from public.notifications
    where user_id = '00000000-0000-4000-8000-0000000000c1' and kind = 'request_cancelled_by_technician'
      and request_id = (select id from pg_temp.ids where name = 'r3')),
  1,
  'a technician cancelling tells the consumer'
);

-- The consumer cancelling after a pick tells the picked technician only.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'r4', (public.create_service_request(
  'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
insert into pg_temp.ids
select 'offer_r4a', public.send_offer((select id from pg_temp.ids where name = 'r4'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select public.send_offer((select id from pg_temp.ids where name = 'r4'),
  'ac_inspection_cleaning', 31000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
select public.accept_offer((select id from pg_temp.ids where name = 'offer_r4a'));
select public.cancel_service_request((select id from pg_temp.ids where name = 'r4'));
reset role;

select is(
  (select string_agg(user_id::text, ',') from public.notifications
    where kind = 'request_cancelled_by_consumer'
      and request_id = (select id from pg_temp.ids where name = 'r4')),
  '00000000-0000-4000-8000-0000000000a1',
  'cancelling after a pick tells only the picked technician'
);

-- Expiry: no offers tells the consumer; with offers it doesn't.
insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at
)
values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000c2', 'ac', 'noisy',
   'nasr_city', 'x', 'xxx', pg_temp.tomorrow(), 'noon', now() - interval '1 minute'),
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000c2', 'ac', 'noisy',
   'nasr_city', 'x', 'xxx', pg_temp.tomorrow(), 'noon', now() - interval '1 minute');
insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at)
values ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000a1', 30000, now() + interval '1 day');
select private.marketplace_housekeeping();

select is(
  (select string_agg(request_id::text, ',') from public.notifications where kind = 'request_expired'),
  '00000000-0000-4000-8000-0000000000e1',
  'a request that ends without offers tells the consumer, one with offers does not'
);

-- Transfers and verification.
insert into public.credit_topups (
  id, user_id, role, pack_id, uses, amount_piastres, method, sender_account, screenshot_path
)
select '00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000c1', 'consumer',
       p.id, p.uses, p.price_piastres, 'wallet', '01011112222', 'c1/a.jpg'
  from public.credit_packs p where p.role = 'consumer' and p.uses = 5;
select private.approve_topup('00000000-0000-4000-8000-0000000000f1');
insert into public.credit_topups (
  id, user_id, role, pack_id, uses, amount_piastres, method, sender_account, screenshot_path
)
select '00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000a1', 'technician',
       p.id, p.uses, p.price_piastres, 'wallet', '01011112222', 'a1/a.jpg'
  from public.credit_packs p where p.role = 'technician' and p.uses = 1;
select private.reject_topup('00000000-0000-4000-8000-0000000000f2', 'x');

select is(
  (select kind::text || ':' || topup_id::text from public.notifications
    where kind = 'topup_approved'),
  'topup_approved:00000000-0000-4000-8000-0000000000f1',
  'an approved transfer tells the person who sent it'
);
select is(
  (select user_id::text || ':' || role::text from public.notifications where kind = 'topup_rejected'),
  '00000000-0000-4000-8000-0000000000a1:technician',
  'a rejected transfer tells the technician on their side'
);

update public.technician_profiles set verification_status = 'approved'
 where id = '00000000-0000-4000-8000-0000000000a3';
select is(pg_temp.kinds('00000000-0000-4000-8000-0000000000a3', 'technician'), 'verification_approved',
  'an approved technician is told');

-- Retention.
update public.notifications set created_at = now() - interval '91 days'
 where kind = 'verification_approved';
select private.marketplace_housekeeping();
select is(
  (select count(*)::int from public.notifications where kind = 'verification_approved'), 0,
  'housekeeping drops notifications older than 90 days'
);
select is(
  (select count(*)::int from public.notifications where kind = 'topup_approved'), 1,
  'and keeps recent ones'
);

select * from finish();
rollback;
