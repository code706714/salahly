begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

create function pg_temp.u(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

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

insert into auth.users (id, phone, aud, role)
values (pg_temp.u('c1'), '201000000941', 'authenticated', 'authenticated'),
       (pg_temp.u('c2'), '201000000942', 'authenticated', 'authenticated'),
       (pg_temp.u('a1'), '201000000943', 'authenticated', 'authenticated'),
       (pg_temp.u('a2'), '201000000944', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values (pg_temp.u('c1'), '+201000000941', 'اسم c1', 'consumer'),
       (pg_temp.u('c2'), '+201000000942', 'اسم c2', 'consumer'),
       (pg_temp.u('a1'), '+201000000943', 'اسم a1', 'technician'),
       (pg_temp.u('a2'), '+201000000944', 'اسم a2', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values (pg_temp.u('c1'), 'ms', 'nasr_city', 20),
       (pg_temp.u('c2'), 'ms', 'nasr_city', 20);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values (pg_temp.u('a1'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'),
       (pg_temp.u('a2'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved');

insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, status
)
values
  ('00000000-0000-4000-8000-0000000000a1', pg_temp.u('c1'), 'ac', 'not_cooling', 'nasr_city',
   'البيت', 'عنوان', current_date + 1, 'noon', now() + interval '1 day', 'open'),
  ('00000000-0000-4000-8000-0000000000a2', pg_temp.u('c1'), 'ac', 'not_cooling', 'nasr_city',
   'البيت', 'عنوان', current_date + 1, 'noon', now() + interval '1 day', 'cancelled');

insert into public.request_recipients (request_id, technician_id, distance_km)
values ('00000000-0000-4000-8000-0000000000a1', pg_temp.u('a1'), 1);

insert into storage.objects (bucket_id, name, owner_id) values
  ('request-videos', pg_temp.u('c1') || '/11111111-1111-4111-8111-111111111111.mp4', pg_temp.u('c1')::text),
  ('request-videos', pg_temp.u('c1') || '/22222222-2222-4222-8222-222222222222.mp4', pg_temp.u('c1')::text),
  ('request-videos', pg_temp.u('c2') || '/33333333-3333-4333-8333-333333333333.mp4', pg_temp.u('c2')::text);

-- The consumer attaches a video to her open request ---------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select throws_ok(
  format($$select public.attach_request_video('00000000-0000-4000-8000-0000000000a1', %L)$$,
    pg_temp.u('c2') || '/33333333-3333-4333-8333-333333333333.mp4'),
  '22023', 'invalid_video', 'a video from someone else''s folder is refused'
);

select throws_ok(
  $$select public.attach_request_video('00000000-0000-4000-8000-0000000000a1', 'x.mp4')$$,
  '22023', 'invalid_video', 'a path that is not an uploaded video is refused'
);

select lives_ok(
  format($$select public.attach_request_video('00000000-0000-4000-8000-0000000000a1', %L)$$,
    pg_temp.u('c1') || '/11111111-1111-4111-8111-111111111111.mp4'),
  'her own uploaded video attaches'
);

select throws_ok(
  format($$select public.attach_request_video('00000000-0000-4000-8000-0000000000a1', %L)$$,
    pg_temp.u('c1') || '/22222222-2222-4222-8222-222222222222.mp4'),
  'P0001', 'video_unavailable', 'a request keeps one video'
);

select throws_ok(
  format($$select public.attach_request_video('00000000-0000-4000-8000-0000000000a2', %L)$$,
    pg_temp.u('c1') || '/22222222-2222-4222-8222-222222222222.mp4'),
  'P0001', 'video_unavailable', 'a closed request takes no video'
);

select is(
  public.request_details('00000000-0000-4000-8000-0000000000a1') ->> 'video_path',
  pg_temp.u('c1') || '/11111111-1111-4111-8111-111111111111.mp4',
  'the consumer''s request details carry the video'
);

-- Who can fetch the file ----------------------------------------------------------

select is(
  (select count(*)::integer from storage.objects where bucket_id = 'request-videos'),
  2, 'the consumer sees only her own videos'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'request-videos'),
  1, 'the technician asked sees the attached video'
);

select is(
  public.technician_request('00000000-0000-4000-8000-0000000000a1') ->> 'video_path',
  pg_temp.u('c1') || '/11111111-1111-4111-8111-111111111111.mp4',
  'and her view of the request names it'
);

select pg_temp.sign_in_as(pg_temp.u('a2'));
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'request-videos'),
  0, 'a technician not asked sees nothing'
);

reset role;

select * from finish();
rollback;
