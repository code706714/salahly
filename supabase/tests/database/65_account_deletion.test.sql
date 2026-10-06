begin;
create extension if not exists pgtap with schema extensions;

select plan(69);

-- Consumers C1 and C2; technicians T1 and T2. T1 is also a consumer (one
-- person on both sides of the app).
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
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 5),
  ('00000000-0000-4000-8000-0000000000a1', 'mr', 'nasr_city', 3);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, '00000000-0000-4000-8000-0000000000a1/90000000-0000-4000-8000-000000000001.jpg', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 5, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 5, 'approved');

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select t.id, 'ac_inspection_cleaning', 35000
  from (values
    ('00000000-0000-4000-8000-0000000000a1'::uuid),
    ('00000000-0000-4000-8000-0000000000a2'::uuid)
  ) as t (id);

insert into public.technician_verifications (technician_id, id_front_path, id_back_path, selfie_path, status)
values ('00000000-0000-4000-8000-0000000000a1', 'f', 'b', 's', 'approved');

insert into storage.objects (bucket_id, name, owner_id) values
  ('request-photos', '00000000-0000-4000-8000-0000000000c1/90000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/90000000-0000-4000-8000-000000000003.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('avatars', '00000000-0000-4000-8000-0000000000a1/90000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000a1'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000a1/90000000-0000-4000-8000-000000000004.jpg', '00000000-0000-4000-8000-0000000000a1'),
  ('job-photos', '00000000-0000-4000-8000-0000000000a1/90000000-0000-4000-8000-000000000005.jpg', '00000000-0000-4000-8000-0000000000a1'),
  ('request-photos', '00000000-0000-4000-8000-0000000000c2/90000000-0000-4000-8000-000000000006.jpg', '00000000-0000-4000-8000-0000000000c2');

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

-- A session whose token was issued (or whose sign-in happened) long ago.
create function pg_temp.sign_in_stale(p_user_id uuid, p_age_seconds integer)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id, 'role', 'authenticated',
      'iat', extract(epoch from now())::bigint - p_age_seconds
    )::text,
    true
  );
$$;

create function pg_temp.sign_in_old_login(p_user_id uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id, 'role', 'authenticated',
      'iat', extract(epoch from now())::bigint,
      'amr', json_build_array(json_build_object(
        'method', 'otp', 'timestamp', extract(epoch from now())::bigint - 3600
      ))
    )::text,
    true
  );
$$;

create function pg_temp.push_customer(p_id uuid, p_changes jsonb)
returns jsonb
language sql
as $$
  select public.sync_push(jsonb_build_array(jsonb_build_object(
    'entity', 'customers',
    'id', p_id,
    'row', (select to_jsonb(c) - 'technician_id' - 'sync_txid' - 'version' from public.customers c where c.id = p_id)
           || p_changes
  )));
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

-- Where a person is still named by a foreign key, as "table.column=rows".
create function pg_temp.leftovers(p_user uuid)
returns text
language plpgsql
as $$
declare
  r record;
  n integer;
  v_out text := '';
begin
  for r in
    select c.conrelid::regclass::text as tbl, a.attname as col
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
     where c.contype = 'f'
       and c.confrelid in (
         'auth.users'::regclass, 'public.profiles'::regclass,
         'public.consumer_profiles'::regclass, 'public.technician_profiles'::regclass
       )
  loop
    execute format('select count(*) from %s where %I = $1', r.tbl, r.col) into n using p_user;
    if n > 0 then
      v_out := v_out || r.tbl || '.' || r.col || '=' || n || ' ';
    end if;
  end loop;
  return v_out;
end;
$$;

-- Tables of ours (public and private) with a row that mentions the text.
create function pg_temp.mentions(p_text text)
returns text
language plpgsql
as $$
declare
  r record;
  n integer;
  v_out text := '';
begin
  for r in
    select schemaname, tablename from pg_tables
     where schemaname in ('public', 'private') order by 1, 2
  loop
    execute format('select count(*) from %I.%I t where to_jsonb(t)::text like %L',
      r.schemaname, r.tablename, '%' || p_text || '%') into n;
    if n > 0 then
      v_out := v_out || r.schemaname || '.' || r.tablename || ' ';
    end if;
  end loop;
  return v_out;
end;
$$;

create table pg_temp.ids (name text primary key, id uuid);
grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- A request asked by `p_consumer`, picked from `p_tech`, taken to `p_steps`.
create function pg_temp.make_job(p_name text, p_consumer uuid, p_address uuid, p_tech uuid, p_status text)
returns void
language plpgsql
as $$
declare
  v_request uuid;
  v_offer uuid;
  v_job uuid;
begin
  perform pg_temp.sign_in_as(p_consumer);
  v_request := (public.create_service_request(
    'ac', 'not_cooling', 'بلاغ ' || right(p_consumer::text, 2), null, p_address, pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
  perform pg_temp.sign_in_as(p_tech);
  v_offer := public.send_offer(v_request, 'ac_inspection_cleaning', 35000, pg_temp.at_cairo(13), null);
  perform pg_temp.sign_in_as(p_consumer);
  v_job := public.accept_offer(v_offer);
  insert into pg_temp.ids values ('r_' || p_name, v_request), ('j_' || p_name, v_job);
  perform pg_temp.sign_in_as(p_tech);
  if p_status <> 'unconfirmed' then
    perform pg_temp.push_job(v_job, '{"status": "confirmed"}');
  end if;
  if p_status in ('started', 'finished') then
    perform pg_temp.push_job(v_job, '{"status": "started"}');
  end if;
  if p_status = 'finished' then
    perform pg_temp.push_job(v_job, '{"status": "finished"}');
  end if;
end;
$$;

-- Setup: C1's requests in every state; C2's with T1.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
insert into pg_temp.ids
select 'home1', public.save_consumer_address(null, 'البيت', 'nasr_city', '14 شارع عباس العقاد');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
insert into pg_temp.ids
select 'home2', public.save_consumer_address(null, 'البيت', 'nasr_city', '9 شارع النصر');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
insert into pg_temp.ids
select 'home_t1', public.save_consumer_address(null, 'شقتي', 'nasr_city', '3 شارع الثورة');

select pg_temp.make_job('b', '00000000-0000-4000-8000-0000000000c1', (select id from pg_temp.ids where name = 'home1'),
  '00000000-0000-4000-8000-0000000000a1', 'unconfirmed');
select pg_temp.make_job('c', '00000000-0000-4000-8000-0000000000c1', (select id from pg_temp.ids where name = 'home1'),
  '00000000-0000-4000-8000-0000000000a2', 'started');
select pg_temp.make_job('d', '00000000-0000-4000-8000-0000000000c1', (select id from pg_temp.ids where name = 'home1'),
  '00000000-0000-4000-8000-0000000000a1', 'finished');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
select public.submit_review((select id from pg_temp.ids where name = 'r_d'), 5::smallint, '{on_time}', 'ممتاز', 'cash');

-- An open request of C1's with an offer waiting from T2.
insert into pg_temp.ids
select 'r_a', (public.create_service_request(
  'ac', 'leaking', null, null, (select id from pg_temp.ids where name = 'home1'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select public.send_offer((select id from pg_temp.ids where name = 'r_a'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(13), null);

-- C2: one job with T1 not started, one finished, one open with T1's offer.
select pg_temp.make_job('f', '00000000-0000-4000-8000-0000000000c2', (select id from pg_temp.ids where name = 'home2'),
  '00000000-0000-4000-8000-0000000000a1', 'unconfirmed');
select pg_temp.make_job('g', '00000000-0000-4000-8000-0000000000c2', (select id from pg_temp.ids where name = 'home2'),
  '00000000-0000-4000-8000-0000000000a1', 'finished');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select public.submit_review((select id from pg_temp.ids where name = 'r_g'), 4::smallint, '{}', null, 'cash');
insert into pg_temp.ids
select 'r_h', (public.create_service_request(
  'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home2'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select public.send_offer((select id from pg_temp.ids where name = 'r_h'),
  'ac_inspection_cleaning', 33000, pg_temp.at_cairo(13), null);

-- T1's own open request as a consumer, with an offer from T2.
insert into pg_temp.ids
select 'r_e', (public.create_service_request(
  'ac', 'noisy', null, null, (select id from pg_temp.ids where name = 'home_t1'),
  pg_temp.tomorrow(), 'noon') ->> 'id')::uuid;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select public.send_offer((select id from pg_temp.ids where name = 'r_e'),
  'ac_inspection_cleaning', 30000, pg_temp.at_cairo(13), null);
reset role;

-- Transfers: C1's approved one, and the shots that go with them.
insert into public.credit_topups (
  id, user_id, role, pack_id, uses, amount_piastres, method, sender_account, screenshot_path, reject_reason
)
select '00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000c1', 'consumer',
       p.id, p.uses, p.price_piastres, 'wallet', '01011112222',
       '00000000-0000-4000-8000-0000000000c1/90000000-0000-4000-8000-000000000003.jpg', null
  from public.credit_packs p where p.role = 'consumer' and p.uses = 5;
select private.approve_topup('00000000-0000-4000-8000-0000000000f1');

select is(
  (select count(*)::int from public.service_requests
    where consumer_id = '00000000-0000-4000-8000-0000000000c1'),
  4,
  'setup: C1 has four requests in four states'
);
create temp table before_c1 as
  select (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c1') as consumer_uses,
         (select count(*) from public.credit_ledger where user_id = '00000000-0000-4000-8000-0000000000c1') as ledger_rows,
         (select job_credits from public.technician_profiles where id = '00000000-0000-4000-8000-0000000000a1') as t1_uses,
         (select job_credits from public.technician_profiles where id = '00000000-0000-4000-8000-0000000000a2') as t2_uses;
grant select on before_c1 to authenticated;

-- Who may call it.
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok(
  $$select public.delete_my_account('DELETE')$$,
  '28000', 'not_signed_in', 'nobody signed out can delete an account'
);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select throws_ok(
  $$select public.delete_my_account('yes')$$,
  '22023', 'confirmation_required', 'deleting needs the explicit confirmation word'
);
select throws_ok(
  $$select public.delete_my_account(null)$$,
  '22023', 'confirmation_required', 'a missing confirmation is refused too'
);
select throws_ok(
  $$select public.storage_purge_claim(10)$$,
  '42501', null, 'the file queue is not reachable from the app'
);
select ok(
  not has_function_privilege('anon', 'public.delete_my_account(text)', 'execute'),
  'a signed-out caller cannot even run it'
);
reset role;
select is(
  (select count(*)::int from auth.users where id = '00000000-0000-4000-8000-0000000000c1'), 1,
  'nothing was deleted by the refusals'
);

-- A transfer nobody checked yet is money in flight.
insert into public.credit_topups (
  id, user_id, role, pack_id, uses, amount_piastres, method, sender_account, screenshot_path
)
select '00000000-0000-4000-8000-0000000000f9', '00000000-0000-4000-8000-0000000000c1', 'consumer',
       p.id, p.uses, p.price_piastres, 'wallet', '01011112222', 'c1/waiting.jpg'
  from public.credit_packs p where p.role = 'consumer' and p.uses = 5;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok(
  $$select public.delete_my_account('DELETE')$$,
  'P0001', 'topup_pending', 'a transfer still waiting to be checked holds the deletion back'
);
reset role;
delete from public.credit_topups where id = '00000000-0000-4000-8000-0000000000f9';

-- Deleting needs a recent sign-in.
select pg_temp.sign_in_stale('00000000-0000-4000-8000-0000000000c1', 1000);
set local role authenticated;
select throws_ok(
  $$select public.delete_my_account('DELETE')$$,
  'P0001', 'recent_login_required', 'a token issued over 15 minutes ago cannot delete the account'
);
select pg_temp.sign_in_old_login('00000000-0000-4000-8000-0000000000c1');
select throws_ok(
  $$select public.delete_my_account('DELETE')$$,
  'P0001', 'recent_login_required', 'nor can a fresh token of a sign-in made an hour ago'
);
reset role;

-- C1 deletes their account.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select lives_ok($$select public.delete_my_account('DELETE')$$, 'a consumer deletes their account');
reset role;

select is(
  (select count(*)::int from auth.users where id = '00000000-0000-4000-8000-0000000000c1'), 0,
  'the sign-in is gone'
);
select is(pg_temp.leftovers('00000000-0000-4000-8000-0000000000c1'), '',
  'no table still points at the person');
select is(
  (select job_credits from public.technician_profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  (select t1_uses + 1 from before_c1),
  'the technician of a job that had not started gets their use back'
);
select is(
  (select status::text from public.jobs where id = (select id from pg_temp.ids where name = 'j_b')),
  'cancelled', 'and that job is cancelled'
);
select is(
  (select status::text from public.jobs where id = (select id from pg_temp.ids where name = 'j_c')),
  'started', 'a job already under way stays with its technician'
);
select is(
  (select job_credits from public.technician_profiles where id = '00000000-0000-4000-8000-0000000000a2'),
  (select t2_uses from before_c1),
  'and nothing is refunded for it'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = '00000000-0000-4000-8000-0000000000a2' and kind = 'request_cancelled_by_consumer'),
  2,
  'T2 is told about the job under way and about the open request they had an offer on'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = '00000000-0000-4000-8000-0000000000a1' and kind = 'request_cancelled_by_consumer'
      and role = 'technician'),
  1,
  'T1 is told about the job that had not started and not about the finished one'
);
select is(
  (select count(*)::int from public.customers where name = 'عميل محذوف' and phone is null and address is null),
  1,
  'the technician keeps the job but the customer of finished work is just "a deleted customer"'
);
select is(
  (select count(*)::int from public.jobs j join public.customers c on c.id = j.customer_id
    where c.name = 'عميل محذوف' and j.address is null and j.description is null),
  2,
  'the jobs of that customer lose the address and the request text'
);
select is(
  (select (j.address is not null)::text || ':' || (c.phone is not null)::text
     from public.jobs j join public.customers c on c.id = j.customer_id
    where j.id = (select id from pg_temp.ids where name = 'j_c')),
  'true:true',
  'a job under way keeps the address and the customer''s phone for the technician on site'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'j_c'),
  '{"description": "leak", "address": "leak"}');
reset role;
select isnt(
  (select coalesce(description, '') || coalesce(address, '') from public.jobs
    where id = (select id from pg_temp.ids where name = 'j_c')),
  'leakleak',
  'a sync can''t write new details onto the job of a deleted consumer'
);
select is(
  (select count(*)::int from public.jobs where description = 'leak' or address = 'leak'), 0,
  'not even a part of them'
);

-- The technician finishes it: now the details go too.
set local role authenticated;
select pg_temp.push_job((select id from pg_temp.ids where name = 'j_c'), '{"status": "finished"}');
reset role;
select is(
  (select coalesce(address, 'null') || ':' || coalesce(description, 'null') from public.jobs
    where id = (select id from pg_temp.ids where name = 'j_c')),
  'null:null', 'a finished job of a deleted consumer loses address and text'
);
select is(
  (select c.name || ':' || coalesce(c.phone, 'null') from public.jobs j join public.customers c on c.id = j.customer_id
    where j.id = (select id from pg_temp.ids where name = 'j_c')),
  'عميل محذوف:null', 'and its customer becomes "a deleted customer"'
);
set local role authenticated;
select pg_temp.push_customer(
  (select customer_id from public.jobs where id = (select id from pg_temp.ids where name = 'j_c')),
  '{"name": "نورهان مصطفى", "phone": "+201009990031", "address": "14 شارع عباس العقاد", "notes": "نورهان"}');
reset role;
select is(
  (select name || ':' || coalesce(phone, 'null') || ':' || coalesce(address, 'null') || ':' || coalesce(notes, 'null')
     from public.customers
    where id = (select customer_id from public.jobs where id = (select id from pg_temp.ids where name = 'j_c'))),
  'عميل محذوف:null:null:null', 'a sync can''t write the person back onto the customer'
);

-- A deleted person's token can't upload any more.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'avatars', '00000000-0000-4000-8000-0000000000c1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'a deleted person can''t upload an avatar'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'verification-docs', '00000000-0000-4000-8000-0000000000c1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'nor documents'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'transfer-proofs', '00000000-0000-4000-8000-0000000000c1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'nor transfer proofs'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'request-photos', '00000000-0000-4000-8000-0000000000c1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'nor request photos'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values (
      'job-photos', '00000000-0000-4000-8000-0000000000c1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'nor job photos'
);
reset role;

select is(pg_temp.mentions('01009990031'), '', 'their phone number appears nowhere');
select is(pg_temp.mentions('نورهان'), '', 'their name appears nowhere');
select is(pg_temp.mentions('عباس العقاد'), '', 'their address appears nowhere');
select is(pg_temp.mentions('بلاغ c1'), '', 'their request text appears nowhere');


select is(
  (select count(*)::int from public.reviews where request_id = (select id from pg_temp.ids where name = 'r_d')),
  0, 'their review goes with them'
);

select is(
  (select count(*)::int from public.credit_ledger where user_id is null),
  (select ledger_rows::int + 1 from before_c1),
  'the ledger stays, linked to nobody (and shows the use given back for the open request)'
);
select is(
  (select sender_account || ' ' || screenshot_path from public.credit_topups
    where id = '00000000-0000-4000-8000-0000000000f1'),
  'deleted deleted/00000000-0000-4000-8000-0000000000f1',
  'the transfer stays without the sender''s account or the screenshot'
);
select is(
  (select user_id::text from public.credit_topups where id = '00000000-0000-4000-8000-0000000000f1'),
  null, 'and without the person'
);
select is(
  (select count(*)::int from private.free_credit_grants
    where phone_hash = encode(sha256(convert_to('201009990031', 'UTF8')), 'hex') and role = 'consumer'),
  1, 'the hash of their phone stays, so signing up again earns no new free uses'
);
select is(
  (select string_agg(bucket_id, ',' order by bucket_id) from private.storage_purge
    where name like '00000000-0000-4000-8000-0000000000c1/%'),
  'request-photos,transfer-proofs',
  'their files are queued for removal'
);
select is(
  (select count(*)::int from private.storage_purge where name like '%0000000000c2/%'), 0,
  'and nobody else''s are'
);

-- Again, from a stale session: nothing happens and nothing fails.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select lives_ok($$select public.delete_my_account('DELETE')$$, 'deleting twice is harmless');
reset role;

-- T1, a technician who is also a consumer, deletes theirs.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select lives_ok($$select public.delete_my_account('DELETE')$$, 'a technician who is also a consumer deletes their account');
reset role;

select is(pg_temp.leftovers('00000000-0000-4000-8000-0000000000a1'), '',
  'no table still points at them either');
select is(pg_temp.mentions('01009990041'), '', 'their phone number appears nowhere');
select is(pg_temp.mentions('محمود السيد'), '', 'their name appears nowhere');
select is(pg_temp.mentions('3 شارع الثورة'), '', 'their address as a consumer appears nowhere');
select is(
  (select status::text || ':' || (chosen_offer_id is null) from public.service_requests
    where id = (select id from pg_temp.ids where name = 'r_f')),
  'cancelled:true',
  'a request whose job had not started is cancelled for the consumer'
);
select is(
  (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c2'),
  3,
  'the consumer of a job cancelled that way gets their use back'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = '00000000-0000-4000-8000-0000000000c2' and kind = 'request_cancelled_by_technician'),
  1, 'and is told'
);
select is(
  (select count(*)::int from public.service_requests where id = (select id from pg_temp.ids where name = 'r_g')),
  0, 'a finished job of a technician who left is no longer shown to the consumer'
);
select is(
  (select count(*)::int from public.request_offers where request_id = (select id from pg_temp.ids where name = 'r_h')),
  0, 'the offers of a technician who left disappear from open requests'
);
select is(
  (select count(*)::int from public.service_requests where id = (select id from pg_temp.ids where name = 'r_h')
      and status = 'open'),
  1, 'and those requests stay open'
);
select is(
  (select string_agg(distinct bucket_id, ',' order by bucket_id) from private.storage_purge
    where name like '00000000-0000-4000-8000-0000000000a1/%'),
  'avatars,job-photos,verification-docs',
  'their avatar, documents and job photos are queued for removal'
);
select is(
  (select count(*)::int from private.free_credit_grants
    where phone_hash = encode(sha256(convert_to('201009990041', 'UTF8')), 'hex')),
  2, 'both sides of their phone hash are kept'
);

-- The purge queue --------------------------------------------------------
delete from vault.secrets where name in ('purge_storage_url', 'purge_storage_secret');
delete from private.storage_purge;
insert into private.storage_purge (bucket_id, name, attempts, queued_at)
values ('avatars', 'x/old.jpg', 9, now() - interval '3 hours');

select is(
  (select count(*)::int from public.storage_purge_claim(10)), 1,
  'a file tried 9 times is claimed once more'
);
update private.storage_purge set claimed_at = now() - interval '1 hour';
select is(
  (select count(*)::int from public.storage_purge_claim(10)), 0,
  'after 10 tries it is not claimed again'
);
select is(
  (select failed from private.storage_purge where name = 'x/old.jpg'), true,
  'and stays in the queue flagged as failed'
);
select ok(
  (select private.purge_backlog() between interval '2 hours' and interval '4 hours'),
  'the backlog is the age of the oldest file waiting'
);
select private.run_storage_purge();
select is(
  (select problem from private.purge_status), null,
  'only failed files wait: nothing to report'
);
insert into private.storage_purge (bucket_id, name) values ('avatars', 'x/new.jpg');
select private.run_storage_purge();
select is(
  (select problem from private.purge_status), 'vault_secrets_missing',
  'missing vault secrets are recorded, not silently skipped'
);

insert into storage.objects (bucket_id, name, owner_id, created_at) values
  ('avatars', '00000000-0000-4000-8000-0000000000e1/90000000-0000-4000-8000-0000000000e1.jpg', null, now() - interval '2 days'),
  ('avatars', '00000000-0000-4000-8000-0000000000e2/90000000-0000-4000-8000-0000000000e2.jpg', null, now() - interval '1 hour'),
  ('avatars', '00000000-0000-4000-8000-0000000000c2/90000000-0000-4000-8000-0000000000e3.jpg', null, now() - interval '2 days');
select private.run_storage_purge();
select is(
  (select string_agg(split_part(name, '/', 1), ',') from private.storage_purge where name like '00000000%'),
  '00000000-0000-4000-8000-0000000000e1',
  'files of nobody are queued once a day old, and not the others'
);

-- The phone hash ----------------------------------------------------------
select is(
  private.phone_hash('201009990031'), private.legacy_phone_hash('201009990031'),
  'without a pepper the hash is the plain one'
);
select vault.create_secret('a-long-random-pepper', 'free_credit_pepper');
select is(
  private.phone_hash('201009990031'),
  encode(extensions.hmac('201009990031', 'a-long-random-pepper', 'sha256'), 'hex'),
  'with a pepper it is an HMAC-SHA256 of the number'
);
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000d1', '201009990061', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', '201009990062', 'authenticated', 'authenticated');
insert into private.free_credit_grants (phone_hash, role)
values (private.legacy_phone_hash('201009990061'), 'consumer');
select is(
  private.claim_free_credits('00000000-0000-4000-8000-0000000000d1', 'consumer'), 0,
  'a phone recorded with the old plain hash still gets no free uses'
);
select is(
  private.claim_free_credits('00000000-0000-4000-8000-0000000000d2', 'consumer'),
  (select consumer_free_requests::int from public.app_settings),
  'a new phone gets them'
);
select is(
  (select count(*)::int from private.free_credit_grants
    where phone_hash = private.phone_hash('201009990062')),
  1, 'recorded with the peppered hash'
);

select * from finish();
rollback;
