begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

-- Two technicians (T, U) and a consumer (C).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000f1', '201009990021', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f2', '201009990022', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f3', '201009990023', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000f1', '+201009990021', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000f2', '+201009990022', 'وليد حسني', 'technician'),
  ('00000000-0000-4000-8000-0000000000f3', '+201009990023', 'منى أحمد', 'consumer');

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits
)
values
  ('00000000-0000-4000-8000-0000000000f1', 8, 'x', 'nasr_city', 30.056, 31.33, 10, '{6,7,1}', 2),
  ('00000000-0000-4000-8000-0000000000f2', 3, 'x', 'maadi', 29.96, 31.257, 5, '{6,7,1}', 2);

insert into storage.objects (bucket_id, name, owner_id) values
  ('job-photos', '00000000-0000-4000-8000-0000000000f2/40000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000f2');

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

-- Inserts the object row the storage API writes for an upload.
create function pg_temp.upload(p_name text, p_owner text)
returns void
language sql
as $$
  insert into storage.objects (bucket_id, name, owner_id)
  values ('job-photos', p_name, p_owner);
$$;

grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000f1');
set local role authenticated;

select lives_ok(
  $$select pg_temp.upload(
      '00000000-0000-4000-8000-0000000000f1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000f1'
    )$$,
  'a technician uploads a job photo into their own folder'
);

select throws_ok(
  $$select pg_temp.upload(
      '00000000-0000-4000-8000-0000000000f2/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000f1'
    )$$,
  '42501',
  null,
  'a technician cannot upload into another technician''s folder'
);

select is(
  (select count(*)::integer from storage.objects where bucket_id = 'job-photos'),
  1,
  'a technician sees their own job photos and no one else''s'
);

select lives_ok(
  $$select pg_temp.upload(
      '00000000-0000-4000-8000-0000000000f1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000f1'
    )
    from generate_series(1, 59)$$,
  'a technician can upload sixty job photos in a day'
);

select throws_ok(
  $$select pg_temp.upload(
      '00000000-0000-4000-8000-0000000000f1/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000f1'
    )$$,
  '42501',
  null,
  'the sixty-first job photo in a day is refused'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000f3');

select throws_ok(
  $$select pg_temp.upload(
      '00000000-0000-4000-8000-0000000000f3/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-0000000000f3'
    )$$,
  '42501',
  null,
  'a consumer cannot upload job photos, even into their own folder'
);

select is_empty(
  $$select name from storage.objects where bucket_id = 'job-photos'$$,
  'a consumer sees no job photos'
);

select * from finish();
rollback;
