begin;
create extension if not exists pgtap with schema extensions;

select plan(26);

-- Two technicians (T, U) and a consumer (C).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000e1', '201009990011', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e2', '201009990012', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e3', '201009990013', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000e1', '+201009990011', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000e2', '+201009990012', 'وليد حسني', 'technician'),
  ('00000000-0000-4000-8000-0000000000e3', '+201009990013', 'منى أحمد', 'consumer');

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits
)
values
  ('00000000-0000-4000-8000-0000000000e1', 8, 'x', 'nasr_city', 30.056, 31.33, 10, '{6,7,1}', 2),
  ('00000000-0000-4000-8000-0000000000e2', 3, 'x', 'maadi', 29.96, 31.257, 5, '{6,7,1}', 2);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values ('00000000-0000-4000-8000-0000000000e3', 'ms', 'nasr_city', 2);

insert into storage.objects (bucket_id, name, owner_id) values
  ('job-photos', '00000000-0000-4000-8000-0000000000e1/30000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000e1'),
  ('job-photos', '00000000-0000-4000-8000-0000000000e2/30000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000e2');

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

-- The ids T's phone created offline.
create function pg_temp.first_batch()
returns jsonb
language sql
as $$
  select jsonb_build_array(
    jsonb_build_object('entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000001', 'row', jsonb_build_object(
      'name', '  م. شريف   عادل ', 'phone', '+201002345678', 'area_id', 'heliopolis',
      'address', '12 شارع الأهرام', 'source', 'platform', 'technician_id', '00000000-0000-4000-8000-0000000000e2',
      'created_at', now() + interval '30 days')),
    jsonb_build_object('entity', 'customer_units', 'id', 'a0000000-0000-4000-8000-000000000002', 'row', jsonb_build_object(
      'customer_id', 'a0000000-0000-4000-8000-000000000001', 'brand', 'كارير', 'capacity_hp', 2.25, 'room', 'أوضة النوم')),
    jsonb_build_object('entity', 'jobs', 'id', 'a0000000-0000-4000-8000-000000000003', 'row', jsonb_build_object(
      'customer_id', 'a0000000-0000-4000-8000-000000000001', 'tags', '["installation", "cleaning", "installation"]'::jsonb,
      'description', 'تركيب سبليت 2.25 حصان', 'scheduled_at', '2026-10-02T10:00:00Z', 'status', 'confirmed',
      'source', 'platform')),
    jsonb_build_object('entity', 'job_items', 'id', 'a0000000-0000-4000-8000-000000000004', 'row', jsonb_build_object(
      'job_id', 'a0000000-0000-4000-8000-000000000003', 'title', 'تركيب سبليت', 'unit_price_piastres', 90000, 'quantity', 1)),
    jsonb_build_object('entity', 'payments', 'id', 'a0000000-0000-4000-8000-000000000005', 'row', jsonb_build_object(
      'job_id', 'a0000000-0000-4000-8000-000000000003', 'amount_piastres', 50000, 'method', 'cash',
      'received_at', '2026-10-02T13:00:00Z')),
    jsonb_build_object('entity', 'job_photos', 'id', 'a0000000-0000-4000-8000-000000000006', 'row', jsonb_build_object(
      'job_id', 'a0000000-0000-4000-8000-000000000003', 'kind', 'before',
      'storage_path', '00000000-0000-4000-8000-0000000000e1/30000000-0000-4000-8000-000000000001.jpg'))
  );
$$;

grant execute on all functions in schema pg_temp to authenticated;

-- Access.
set local role anon;
select throws_ok(
  $$select public.sync_pull()$$,
  '42501',
  null,
  'anon cannot pull'
);
reset role;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000e3');
set local role authenticated;
select throws_ok(
  $$select public.sync_push('[]')$$,
  '42501',
  'not_technician',
  'a consumer cannot push technician records'
);

-- T pushes a whole offline session.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000e1');

select is(
  public.sync_push(pg_temp.first_batch()),
  '{"rejected": []}'::jsonb,
  'a technician pushes customers, units, jobs, items, payments and photos together'
);

select is(
  (select name from public.customers where id = 'a0000000-0000-4000-8000-000000000001'),
  'م. شريف عادل',
  'names are trimmed and collapsed'
);

select ok(
  (select technician_id = '00000000-0000-4000-8000-0000000000e1' and source = 'manual'
     from public.customers where id = 'a0000000-0000-4000-8000-000000000001'),
  'the owner comes from the session and the source cannot be set to platform'
);

select ok(
  (select created_at <= now() from public.customers where id = 'a0000000-0000-4000-8000-000000000001'),
  'a creation time in the future is replaced by the server time'
);

select is(
  (select tags from public.jobs where id = 'a0000000-0000-4000-8000-000000000003'),
  array['cleaning', 'installation'],
  'job tags are de-duplicated'
);

select is(
  (select source from public.jobs where id = 'a0000000-0000-4000-8000-000000000003'),
  'manual',
  'the phone cannot mark a job as coming from the platform'
);

-- Pulling everything.
create temp table pulled on commit drop as
  select public.sync_pull() as result;

select is(
  (select jsonb_array_length(result -> 'changes') from pulled),
  6,
  'a first pull returns every own row'
);

select is(
  (select count(*)::integer from pulled, jsonb_array_elements(result -> 'changes') c
    where c -> 'row' ? 'technician_id' or c -> 'row' ? 'sync_txid' or c -> 'row' ? 'version'),
  0,
  'pulled rows leave out the owner and the sync bookkeeping'
);

select is(
  (select result -> 'has_more' from pulled),
  'false'::jsonb,
  'a short pull says there is nothing more'
);

select is(
  jsonb_array_length(public.sync_pull((select result -> 'checkpoint' from pulled)) -> 'changes'),
  0,
  'pulling from the latest checkpoint returns nothing new'
);

select is(
  jsonb_array_length(public.sync_pull(null, 2) -> 'changes'),
  2,
  'a pull returns at most the requested page'
);

select is(
  public.sync_pull(null, 2) -> 'has_more',
  'true'::jsonb,
  'a full page says there is more'
);

-- An edit comes back on the next pull, alone.
select is(
  public.sync_push(jsonb_build_array(jsonb_build_object(
    'entity', 'jobs', 'id', 'a0000000-0000-4000-8000-000000000003', 'row', jsonb_build_object(
      'customer_id', 'a0000000-0000-4000-8000-000000000001', 'status', 'started',
      'started_at', '2026-10-02T10:05:00Z')))),
  '{"rejected": []}'::jsonb,
  'a technician updates their job'
);

select is(
  (select jsonb_agg(c -> 'row' ->> 'status')
     from jsonb_array_elements(public.sync_pull((select result -> 'checkpoint' from pulled)) -> 'changes') c),
  '["started"]'::jsonb,
  'the next pull returns only the changed row'
);

-- Bad changes are rejected one by one.
create temp table second_push on commit drop as
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000011', 'row', jsonb_build_object('name', 'م')),
    jsonb_build_object('entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000012', 'row', jsonb_build_object('name', 'أ. هالة فتحي')),
    jsonb_build_object('entity', 'profiles', 'id', 'a0000000-0000-4000-8000-000000000013', 'row', '{}'::jsonb),
    jsonb_build_object('entity', 'job_photos', 'id', 'a0000000-0000-4000-8000-000000000014', 'row', jsonb_build_object(
      'job_id', 'a0000000-0000-4000-8000-000000000003', 'kind', 'after',
      'storage_path', '00000000-0000-4000-8000-0000000000e2/30000000-0000-4000-8000-000000000002.jpg'))
  )) as result;

select is(
  (select jsonb_agg(r ->> 'id' order by r ->> 'id') from second_push, jsonb_array_elements(result -> 'rejected') r),
  '["a0000000-0000-4000-8000-000000000011", "a0000000-0000-4000-8000-000000000013", "a0000000-0000-4000-8000-000000000014"]'::jsonb,
  'invalid rows, unknown tables and someone else''s photos are rejected'
);

select ok(
  exists (select 1 from public.customers where id = 'a0000000-0000-4000-8000-000000000012'),
  'the valid change in the same push still applies'
);

-- U cannot touch T's rows.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000e2');

create temp table hijack on commit drop as
  select public.sync_push(jsonb_build_array(
    jsonb_build_object('entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000001', 'row', jsonb_build_object('name', 'مسروق')),
    jsonb_build_object('entity', 'jobs', 'id', 'b0000000-0000-4000-8000-000000000001', 'row', jsonb_build_object(
      'customer_id', 'a0000000-0000-4000-8000-000000000001'))
  )) as result;

select ok(
  (select bool_and(case r ->> 'id'
     when 'a0000000-0000-4000-8000-000000000001' then r ->> 'code' = 'not_owner'
     else r ->> 'code' like '%foreign key%'
   end) and count(*) = 2
   from hijack, jsonb_array_elements(result -> 'rejected') r),
  'another technician can neither overwrite a row nor attach a job to it'
);

select is(
  (select jsonb_agg(r -> 'row') from hijack, jsonb_array_elements(result -> 'rejected') r),
  '[null, null]'::jsonb,
  'rejections never hand back someone else''s row'
);

select is_empty(
  $$select id from public.customers$$,
  'a technician cannot read another technician''s customers'
);

select is(
  jsonb_array_length(public.sync_pull() -> 'changes'),
  0,
  'a pull never returns another technician''s rows'
);

-- T's row is unchanged.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000e1');
select is(
  (select name from public.customers where id = 'a0000000-0000-4000-8000-000000000001'),
  'م. شريف عادل',
  'the owner''s row survives the attempt'
);

-- A rejected edit hands back the server's copy so the phone can restore it.
select is(
  (select r -> 'row' ->> 'name'
     from jsonb_array_elements(public.sync_push(jsonb_build_array(jsonb_build_object(
       'entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000001',
       'row', jsonb_build_object('name', 'x')))) -> 'rejected') r),
  'م. شريف عادل',
  'a rejected edit returns the current row'
);

select throws_ok(
  $$insert into public.customers (id, technician_id, name)
    values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000e1', 'مباشر')$$,
  '42501',
  null,
  'technicians cannot write the tables directly'
);

-- Row limits.
reset role;
insert into public.customers (id, technician_id, name)
select gen_random_uuid(), '00000000-0000-4000-8000-0000000000e1', 'عميل ' || g
  from generate_series(1, 5000) g;
set local role authenticated;

select is(
  (select r ->> 'code'
     from jsonb_array_elements(public.sync_push(jsonb_build_array(jsonb_build_object(
       'entity', 'customers', 'id', 'a0000000-0000-4000-8000-000000000099',
       'row', jsonb_build_object('name', 'عميل زيادة')))) -> 'rejected') r),
  'limit_reached',
  'a technician cannot keep more than the row limit'
);

select * from finish();
rollback;
