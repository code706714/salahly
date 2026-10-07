begin;
create extension if not exists pgtap with schema extensions;

select plan(79);

-- Consumers C1 (she) and C2 (he); technicians A1 (picked) and A2 (not).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', '201009990032', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', '201009990042', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c2', '+201009990032', 'حسام علي', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a2', '+201009990042', 'ياسر عبد الحميد', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 5),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 5);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 5, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 5, 'approved');

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
    json_build_object(
      'sub', p_user_id, 'role', 'authenticated',
      'iat', extract(epoch from now())::bigint
    )::text,
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

-- A made-up token of a given letter, long enough to be valid.
create function pg_temp.token(p_letter text)
returns text
language sql
as $$
  select repeat(p_letter, 40);
$$;

create function pg_temp.arrivals(p_request_id uuid)
returns integer
language sql
as $$
  select count(*)::int from public.notifications
   where request_id = p_request_id and kind = 'technician_arriving';
$$;

create table pg_temp.ids (name text primary key, id uuid);
grant execute on all functions in schema pg_temp to authenticated, anon, service_role;
grant all on table pg_temp.ids to authenticated;

-- C1 asks, A1 and A2 offer, C1 picks A1.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'home', public.save_consumer_address(null, 'البيت', 'nasr_city', '14 شارع عباس العقاد');
insert into pg_temp.ids
select 'r1', (public.create_service_request(
  'ac', 'not_cooling', null, null, (select id from pg_temp.ids where name = 'home'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
insert into pg_temp.ids
select 'offer_a', public.send_offer((select id from pg_temp.ids where name = 'r1'),
  'ac_inspection_cleaning', 35000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
insert into pg_temp.ids
select 'offer_b', public.send_offer((select id from pg_temp.ids where name = 'r1'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(14), null);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
insert into pg_temp.ids
select 'job1', public.accept_offer((select id from pg_temp.ids where name = 'offer_a'));
reset role;

-- The job is not confirmed yet.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0001', 'not_confirmed', 'the picked technician can''t say he is coming before he confirmed the job'
);
select is(public.platform_job_request((select id from pg_temp.ids where name = 'job1')) ->> 'request_id',
  (select id::text from pg_temp.ids where name = 'r1'),
  'the technician''s job page finds the request behind its job');
select ok(public.platform_job_request((select id from pg_temp.ids where name = 'job1')) -> 'arriving_sent_at' = 'null'::jsonb,
  'and sees that nothing was sent yet');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "confirmed"}');
reset role;

-- Who may not.
set local role anon;
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  '42501', null, 'signed out nobody can call it'
);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
set local role authenticated;
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0002', 'not_found', 'a technician who was not picked can''t'
);
select is(public.platform_job_request((select id from pg_temp.ids where name = 'job1')), null,
  'nor see the request behind someone else''s job');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0002', 'not_found', 'the consumer can''t say it for him'
);
select is(public.platform_job_request((select id from pg_temp.ids where name = 'job1')), null,
  'nor see the technician''s side');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0002', 'not_found', 'another consumer can''t either'
);
select throws_ok(
  $$select public.technician_arriving('00000000-0000-4000-8000-00000000dead')$$,
  'P0002', 'not_found', 'a request that doesn''t exist looks the same as one that isn''t his'
);
reset role;
select is(pg_temp.arrivals((select id from pg_temp.ids where name = 'r1')), 0,
  'none of those told the consumer anything');

-- A suspended technician can't.
update public.profiles set suspended_at = now() where id = '00000000-0000-4000-8000-0000000000a1';
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  '42501', 'account_suspended', 'a suspended technician can''t'
);
reset role;
update public.profiles set suspended_at = null where id = '00000000-0000-4000-8000-0000000000a1';

-- The picked technician, with the job confirmed.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select is(
  public.technician_arriving((select id from pg_temp.ids where name = 'r1')) ->> 'status',
  'sent', 'the picked technician tells the consumer he is almost there'
);
select is(
  public.technician_arriving((select id from pg_temp.ids where name = 'r1')) ->> 'status',
  'already_sent', 'asking again says it was already sent'
);
select ok(public.platform_job_request((select id from pg_temp.ids where name = 'job1')) ->> 'arriving_sent_at' is not null,
  'and his job page now knows');
reset role;
select is(pg_temp.arrivals((select id from pg_temp.ids where name = 'r1')), 1,
  'the repeat wrote nothing');
select results_eq(
  $$select user_id, role::text, request_id, offer_id, topup_id, read_at is null
      from public.notifications where kind = 'technician_arriving'$$,
  $$select '00000000-0000-4000-8000-0000000000c1'::uuid, 'consumer', id, null::uuid, null::uuid, true
      from pg_temp.ids where name = 'r1'$$,
  'the notification is the consumer''s, unread, about the request'
);
select is(
  (select count(*)::int from public.notifications
    where kind = 'technician_arriving' and user_id <> '00000000-0000-4000-8000-0000000000c1'),
  0, 'and nobody else got one'
);

-- The consumer sees it in the list, in the request and in her own rows.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select is(
  (select e ->> 'technician_name' from jsonb_array_elements(public.my_notifications('consumer')) e
    where e ->> 'kind' = 'technician_arriving'),
  'محمود السيد', 'the list carries the technician for the text'
);
select ok(public.request_details((select id from pg_temp.ids where name = 'r1')) ->> 'technician_arriving_at' is not null,
  'the request page says when he was told');
select is(public.request_details((select id from pg_temp.ids where name = 'r1')) -> 'job' ->> 'status', 'confirmed',
  'and still carries the rest');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select is(public.request_details((select id from pg_temp.ids where name = 'r1')), null,
  'someone else''s request page stays closed');
reset role;

-- Rate limit: once per 10 minutes, three in all.
update public.notifications set created_at = created_at - interval '11 minutes'
 where kind = 'technician_arriving';
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select is(
  public.technician_arriving((select id from pg_temp.ids where name = 'r1')) ->> 'status',
  'sent', 'after 10 minutes he can send it again');
reset role;
update public.notifications set created_at = created_at - interval '11 minutes'
 where kind = 'technician_arriving';
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select is(
  public.technician_arriving((select id from pg_temp.ids where name = 'r1')) ->> 'status',
  'sent', 'and a third time');
reset role;
update public.notifications set created_at = created_at - interval '11 minutes'
 where kind = 'technician_arriving';
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  '54000', 'limit_reached', 'but not a fourth, however long he waits'
);
reset role;
select is(pg_temp.arrivals((select id from pg_temp.ids where name = 'r1')), 3, 'three in all');

-- Once the work started it is too late.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "started"}');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0001', 'not_confirmed', 'not once the job started');
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"status": "finished"}');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r1'))$$,
  'P0001', 'not_confirmed', 'nor once it finished');
reset role;

-- Nor on a cancelled one.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
insert into pg_temp.ids
select 'home2', public.save_consumer_address(null, 'الشغل', 'nasr_city', '3 شارع النصر');
insert into pg_temp.ids
select 'r2', (public.create_service_request(
  'ac', 'not_cooling', null, null, (select id from pg_temp.ids where name = 'home2'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
insert into pg_temp.ids
select 'offer_c', public.send_offer((select id from pg_temp.ids where name = 'r2'),
  'ac_inspection_cleaning', 35000, pg_temp.at_cairo(13), null);
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r2'))$$,
  'P0002', 'not_found', 'a technician whose offer is still waiting can''t');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select public.accept_offer((select id from pg_temp.ids where name = 'offer_c'));
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select pg_temp.push_job((select job_id from public.service_requests where id = (select id from pg_temp.ids where name = 'r2')),
  '{"status": "confirmed"}');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select public.cancel_service_request((select id from pg_temp.ids where name = 'r2'));
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok(
  $$select public.technician_arriving((select id from pg_temp.ids where name = 'r2'))$$,
  'P0001', 'not_confirmed', 'nor once the consumer cancelled');
reset role;

-- Device tokens ---------------------------------------------------------------
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select lives_ok($$select public.register_device_token(pg_temp.token('a'), 'android')$$,
  'a signed-in person registers their phone');
select lives_ok($$select public.register_device_token(pg_temp.token('a'), 'android')$$,
  'registering the same phone again is fine');
select throws_ok($$select public.register_device_token('short', 'android')$$,
  '22023', 'invalid_token', 'a token that is too short is refused');
select throws_ok($$select public.register_device_token(repeat('a', 4097), 'android')$$,
  '22023', 'invalid_token', 'and one that is too long');
select throws_ok($$select public.register_device_token(repeat('a b ', 10), 'android')$$,
  '22023', 'invalid_token', 'and one with spaces');
select throws_ok($$select public.register_device_token(repeat('a''; ', 10), 'android')$$,
  '22023', 'invalid_token', 'and one with quotes');
select throws_ok($$select public.register_device_token(null, 'android')$$,
  '22023', 'invalid_token', 'and a missing one');
select throws_ok($$select public.register_device_token(pg_temp.token('b'), 'windows')$$,
  '22023', 'invalid_token', 'an unknown platform is refused');
reset role;
select is((select count(*)::int from public.device_tokens), 1, 'the same phone twice is one row');

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select public.register_device_token(pg_temp.token(l), 'ios') from unnest(array['b', 'c', 'd', 'e', 'f', 'g']) l;
reset role;
select is((select count(*)::int from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000c1'), 5,
  'a person keeps 5 phones');
select ok(not exists (select 1 from public.device_tokens where token = pg_temp.token('a')),
  'the one not seen for longest is the one forgotten');

-- A token belongs to one person at a time.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
select public.register_device_token(pg_temp.token('g'), 'android');
reset role;
select is((select user_id from public.device_tokens where token = pg_temp.token('g')),
  '00000000-0000-4000-8000-0000000000c2'::uuid, 'a phone that changes hands moves to its new owner');
select is((select count(*)::int from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000c1'), 4,
  'and its old owner no longer has it');

-- Nobody reads tokens back, nobody writes them directly.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok($$select token from public.device_tokens$$, '42501', null,
  'a signed-in person can''t read tokens, not even their own');
select throws_ok($$insert into public.device_tokens (token, user_id, platform) values (repeat('z', 40), auth.uid(), 'ios')$$,
  '42501', null, 'nor write one');
select throws_ok($$update public.device_tokens set user_id = auth.uid()$$, '42501', null,
  'nor take one over');
select throws_ok($$delete from public.device_tokens$$, '42501', null, 'nor delete');
reset role;
set local role anon;
select throws_ok($$select token from public.device_tokens$$, '42501', null, 'signed out nobody reads them');
select throws_ok($$select public.register_device_token(pg_temp.token('h'), 'ios')$$, '42501', null,
  'nor registers one');
reset role;
select ok(
  not has_table_privilege('authenticated', 'public.device_tokens', 'select')
  and not has_table_privilege('anon', 'public.device_tokens', 'select'),
  'neither API role has any right on the table');

-- Unregistering: only your own.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select public.unregister_device_token(pg_temp.token('g'));
select public.unregister_device_token(pg_temp.token('nothing'));
reset role;
select is((select count(*)::int from public.device_tokens where token = pg_temp.token('g')), 1,
  'someone else''s phone can''t be unregistered');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select public.unregister_device_token(pg_temp.token('f'));
reset role;
select is((select count(*)::int from public.device_tokens where token = pg_temp.token('f')), 0,
  'your own phone is forgotten on sign-out');

-- A suspended person registers nothing; the token of a person who has no
-- profile yet can't be stored.
update public.profiles set suspended_at = now() where id = '00000000-0000-4000-8000-0000000000c1';
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok($$select public.register_device_token(pg_temp.token('i'), 'ios')$$,
  '42501', 'account_suspended', 'a suspended person can''t register a phone');
reset role;
update public.profiles set suspended_at = null where id = '00000000-0000-4000-8000-0000000000c1';

-- The push queue --------------------------------------------------------------
-- Only kinds worth a buzz are queued: the job's steps and the offers were;
-- "not picked" was not.
select ok(exists (select 1 from private.push_outbox o join public.notifications n on n.id = o.notification_id
                   where n.kind = 'technician_arriving'),
  'the arriving notification is queued for a push');
select ok(not exists (select 1 from private.push_outbox o join public.notifications n on n.id = o.notification_id
                       where n.kind = 'offer_not_picked'),
  'a notification that needs no buzz is not');

-- The sender's side is closed to the app.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok($$select public.push_claim(10)$$, '42501', null, 'the app can''t claim pushes');
select throws_ok($$select public.push_done('{1}', '{}')$$, '42501', null, 'nor report them');
reset role;
set local role anon;
select throws_ok($$select public.push_claim(10)$$, '42501', null, 'signed out nobody can');
reset role;

-- Claiming: C1 has 3 phones left, A1 and A2 have none (nothing to send).
set local role service_role;
create temp table claimed on commit drop as select public.push_claim(100) as batch;
reset role;
grant select on claimed to service_role;
select ok(
  not exists (
    select 1 from jsonb_array_elements((select batch from claimed)) e
     where e ->> 'kind' in ('new_request', 'offer_picked', 'offer_not_picked')
  ),
  'messages for people with no registered phone are not handed out');
select ok(
  exists (
    select 1 from jsonb_array_elements((select batch from claimed)) e
     where e ->> 'kind' = 'technician_arriving'
       and e ->> 'role' = 'consumer'
       and e ->> 'technician_name' = 'محمود'
       and e ->> 'honorific' = 'ms'
       and e ->> 'request_id' = (select id::text from pg_temp.ids where name = 'r1')
       and jsonb_array_length(e -> 'tokens') = 3
  ),
  'the arriving message carries the kind, his first name, her honorific, the request and her phones');
select is(
  (select count(*)::int from jsonb_array_elements((select batch from claimed)) e where e ->> 'kind' = 'technician_arriving'),
  3, 'once for each of the three notifications');
select ok(
  not exists (
    select 1 from jsonb_array_elements((select batch from claimed)) e
     where e::text ~ '(phone|address|201009990|عباس|النصر)'
  ),
  'no phone number or address travels with it');
select is((select count(*)::int from private.push_outbox o
            join public.notifications n on n.id = o.notification_id
           where n.user_id in ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a2')),
  0, 'and those without phones are dropped from the queue');
select is(
  (select count(*)::int from public.push_claim(100) x, jsonb_array_elements(x) e), 0,
  'a message just claimed isn''t handed out again at once');

-- Reporting back.
set local role service_role;
select public.push_done(
  array(select (e ->> 'id')::bigint from jsonb_array_elements((select batch from claimed)) e),
  array[pg_temp.token('c')]
);
reset role;
select is((select count(*)::int from private.push_outbox), 0, 'finished messages leave the queue');
select ok(not exists (select 1 from public.device_tokens where token = pg_temp.token('c')),
  'a token Firebase refused is forgotten');
select ok(exists (select 1 from public.device_tokens where token = pg_temp.token('d')),
  'the others stay');

-- A suspended person gets no push.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'job1'), '{"description": "تفاصيل"}');
reset role;
select private.notify('00000000-0000-4000-8000-0000000000c1', 'consumer', 'job_finished',
  (select id from pg_temp.ids where name = 'r1'));
update public.profiles set suspended_at = now() where id = '00000000-0000-4000-8000-0000000000c1';
set local role service_role;
select is(public.push_claim(100), '[]'::jsonb, 'a suspended person gets nothing');
reset role;
select is((select count(*)::int from private.push_outbox), 0, 'and it is dropped, not kept');
update public.profiles set suspended_at = null where id = '00000000-0000-4000-8000-0000000000c1';

-- The wake-up call: nothing without the vault's secrets, a request with them.
select is(private.send_push_request(), false, 'without the vault secrets no request is made');
select vault.create_secret('https://example.invalid/functions/v1/send-push', 'push_dispatch_url');
select vault.create_secret(repeat('s', 40), 'push_dispatch_secret');
select is(private.send_push_request(), true, 'with them a request is made');
select ok(
  exists (select 1 from net.http_request_queue where url = 'https://example.invalid/functions/v1/send-push'),
  'through pg_net, with the secret in a header, not in the URL');
select lives_ok(
  $$select private.notify('00000000-0000-4000-8000-0000000000c1', 'consumer', 'job_started',
      (select id from pg_temp.ids where name = 'r1'))$$,
  'a new notification queues its push and wakes the sender');

-- Housekeeping: a stale queue and long unseen phones go.
update private.push_outbox set queued_at = now() - interval '2 days';
update public.device_tokens set last_seen_at = now() - interval '61 days'
 where token = pg_temp.token('d');
select private.run_push_dispatch();
select is((select count(*)::int from private.push_outbox), 0, 'nothing waits for more than a day');
select ok(not exists (select 1 from public.device_tokens where token = pg_temp.token('d')),
  'a phone unseen for 60 days is forgotten');

-- Deleting the account erases the phones and the queue.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
select public.register_device_token(pg_temp.token('j'), 'android');
reset role;
select private.notify('00000000-0000-4000-8000-0000000000c2', 'consumer', 'request_expired',
  (select id from pg_temp.ids where name = 'r2'));
select cmp_ok((select count(*)::int from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000c2'),
  '>', 0, 'C2 has phones registered');
select is((select count(*)::int from private.push_outbox o join public.notifications n on n.id = o.notification_id
            where n.user_id = '00000000-0000-4000-8000-0000000000c2'), 1, 'and a push waiting');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
select public.delete_my_account('DELETE');
reset role;
select is((select count(*)::int from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000c2'), 0,
  'deleting the account erases their phones');
select is((select count(*)::int from private.push_outbox o join public.notifications n on n.id = o.notification_id
            where n.user_id = '00000000-0000-4000-8000-0000000000c2'), 0,
  'and their waiting pushes');

select * from finish();
rollback;
