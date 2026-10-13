begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

-- Consumer c1 with a request; technicians a1 (offered, then picked), a2
-- (offered) and a3 (no offer). Consumer c2 is a stranger.
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
select pg_temp.u(n), 'ms', 'nasr_city', 2 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2'), ('a3')) v (n);

create table pg_temp.ids (name text primary key, id uuid);
insert into pg_temp.ids values ('request', gen_random_uuid()), ('job', gen_random_uuid());

insert into public.customers (id, technician_id, name, phone, source)
values (pg_temp.u('d1'), pg_temp.u('a1'), 'عميل', '+201000000099', 'platform');
insert into public.jobs (id, technician_id, customer_id, status, finished_at, quote_status, source)
values ((select id from pg_temp.ids where name = 'job'), pg_temp.u('a1'), pg_temp.u('d1'),
        'finished', now() - interval '3 days', 'accepted', 'platform');

insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, status
)
values (
  (select id from pg_temp.ids where name = 'request'), pg_temp.u('c1'), 'ac', 'not_cooling',
  'nasr_city', 'البيت', 'عنوان', current_date + 1, 'noon', now() + interval '1 day', 'open'
);

insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at)
select (select id from pg_temp.ids where name = 'request'), pg_temp.u(n), 35000, now() + interval '1 day'
  from (values ('a1'), ('a2')) v (n);

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- Talking -----------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.send_chat_message(
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), '  الجهاز بيفصل كتير  '
  ) ->> 'body',
  'الجهاز بيفصل كتير',
  'the consumer writes to a technician who offered, and the text is trimmed'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select is(
  public.send_chat_message(
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), 'تمام، هجيلك بكره'
  ) ->> 'mine',
  'true',
  'and he answers'
);

select is(
  (public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')) -> 'messages' -> 0 ->> 'mine'),
  'false',
  'he sees her message as hers'
);
select is(
  (public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')) ->> 'other_name'),
  'اسم c.',
  'a technician sees the consumer by her short name only'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
select is(
  jsonb_array_length(public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')) -> 'messages'),
  2,
  'she reads both messages, in order'
);
select is(
  public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')) ->> 'other_name',
  'اسم a1',
  'and sees the technician by name'
);

-- Who can not -------------------------------------------------------------------------

select throws_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a3'), 'مرحبا')$$,
  'P0001', 'chat_unavailable', 'she can''t write to a technician who made no offer'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), 'مرحبا')$$,
  'P0001', 'chat_unavailable', 'a stranger can''t write'
);
select throws_ok(
  $$select public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'))$$,
  'P0001', 'chat_unavailable', 'or read'
);

select pg_temp.sign_in_as(pg_temp.u('a2'));
select throws_ok(
  $$select public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'))$$,
  'P0001', 'chat_unavailable', 'a competing technician can''t read another''s talk'
);
select is(
  jsonb_array_length(public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a2')) -> 'messages'),
  0,
  'his own conversation with her is separate'
);

select throws_ok(
  $$select * from public.request_messages$$,
  '42501', null, 'the table can''t be read directly'
);

-- What stays out ----------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  format($$select public.send_chat_message(%L, %L, 'كلمني على 01012345678')$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'P0001', 'contact_blocked', 'a phone number is refused'
);
select throws_ok(
  format($$select public.send_chat_message(%L, %L, 'رقمي ٠١٠ ١٢٣ ٤٥٦٧٨')$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'P0001', 'contact_blocked', 'also in Arabic digits with spaces'
);
select throws_ok(
  format($$select public.send_chat_message(%L, %L, 'كلمني واتساب')$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'P0001', 'contact_blocked', 'and another app'
);
select lives_ok(
  format($$select public.send_chat_message(%L, %L, 'السعر 350 جنيه والحضور 12 الضهر')$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'a price and a time are fine'
);
select throws_ok(
  format($$select public.send_chat_message(%L, %L, '   ')$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  '22023', 'invalid_message', 'an empty message is refused'
);

-- Notices -----------------------------------------------------------------------------

reset role;
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('a1') and kind = 'chat_message' and read_at is null),
  1,
  'two messages to a technician, one unread notice'
);

-- A suspended account can not write ---------------------------------------------------

reset role;
update public.profiles set suspended_at = now() where id = pg_temp.u('a1');
select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select throws_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), 'مرحبا')$$,
  '42501', 'account_suspended', 'a suspended technician can''t write'
);
reset role;
update public.profiles set suspended_at = null where id = pg_temp.u('a1');

-- Closing -----------------------------------------------------------------------------

update public.request_offers set status = 'not_chosen'
 where technician_id = pg_temp.u('a2');
select pg_temp.sign_in_as(pg_temp.u('a2'));
set local role authenticated;
select throws_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a2'), 'مرحبا')$$,
  'P0001', 'chat_closed', 'when someone else is picked, the talk with the others closes'
);
select is(
  (public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a2')) ->> 'open')::boolean,
  false,
  'it can still be read'
);

-- The picked technician's talk lasts 14 days past the job.
reset role;
update public.request_offers set status = 'accepted' where technician_id = pg_temp.u('a1');
update public.service_requests
   set status = 'assigned', job_id = (select id from pg_temp.ids where name = 'job')
 where id = (select id from pg_temp.ids where name = 'request');
select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select lives_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), 'وصلت')$$,
  'the picked technician can still write after a job finished three days ago'
);

reset role;
update public.jobs set finished_at = now() - interval '15 days';
set local role authenticated;
select throws_ok(
  $$select public.send_chat_message((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'), 'وصلت')$$,
  'P0001', 'chat_closed', 'but not after the fourteen days'
);

-- Reading marks the notice read.
select pg_temp.sign_in_as(pg_temp.u('c1'));
select lives_ok(
  $$select public.chat_messages((select id from pg_temp.ids where name = 'request'), pg_temp.u('a1'))$$,
  'she opens the chat'
);
reset role;
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('c1') and kind = 'chat_message' and read_at is null),
  0,
  'opening the chat clears its notices'
);

select * from finish();
rollback;
