begin;
create extension if not exists pgtap with schema extensions;

select plan(28);

insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000c1', '201009990001', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', '201229990002', 'authenticated', 'authenticated');

-- Uploaded files: T owns c1/..., U owns d2/...
insert into storage.objects (bucket_id, name, owner_id) values
  ('avatars', '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000003.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000004.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('avatars', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000d2'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000d2'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000003.jpg', '00000000-0000-4000-8000-0000000000d2'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000004.jpg', '00000000-0000-4000-8000-0000000000d2');

-- A service under a category that isn't open (electrical is open in the catalog, so close it here).
insert into public.services (id, category_id, name_ar, suggested_price_piastres)
values ('electrical_wiring', 'electrical', 'تأسيس كهربا', 50000);
update public.service_categories set is_active = false where id = 'electrical';

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

-- Calls onboarding for U with valid input, overriding one argument by name.
create function pg_temp.onboard_u(p_overrides jsonb default '{}')
returns void
language plpgsql
as $$
declare
  v jsonb := jsonb_build_object(
    'full_name', 'وليد حسني',
    'shop_name', null,
    'years', 5,
    'avatar', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000001.jpg',
    'base_area', 'heliopolis',
    'lat', 30.0911,
    'lng', 31.3225,
    'radius', 5,
    'days', '[6, 7, 1]'::jsonb,
    'areas', '["heliopolis"]'::jsonb,
    'services', '[{"service_id": "ac_inspection", "starting_price_piastres": 20000}]'::jsonb,
    'front', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000002.jpg',
    'back', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000003.jpg',
    'selfie', '00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000004.jpg'
  ) || p_overrides;
begin
  perform public.complete_technician_onboarding(
    p_full_name => v ->> 'full_name',
    p_shop_name => v ->> 'shop_name',
    p_years_experience => (v ->> 'years')::smallint,
    p_avatar_path => v ->> 'avatar',
    p_base_area_id => v ->> 'base_area',
    p_base_lat => (v ->> 'lat')::double precision,
    p_base_lng => (v ->> 'lng')::double precision,
    p_service_radius_km => (v ->> 'radius')::smallint,
    p_work_days => array(select jsonb_array_elements_text(v -> 'days')::smallint),
    p_area_ids => array(select jsonb_array_elements_text(v -> 'areas')),
    p_services => v -> 'services',
    p_id_front_path => v ->> 'front',
    p_id_back_path => v ->> 'back',
    p_selfie_path => v ->> 'selfie'
  );
end;
$$;

-- Technician T onboards successfully.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;

select lives_ok(
  $$select public.complete_technician_onboarding(
      p_full_name => 'محمود السيد',
      p_shop_name => '  تكييفات   السيد ',
      p_years_experience => 12::smallint,
      p_avatar_path => '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000001.jpg',
      p_base_area_id => 'nasr_city',
      p_base_lat => 30.0561234,
      p_base_lng => 31.3300987,
      p_service_radius_km => 10::smallint,
      p_work_days => array[6, 7, 1, 2, 3, 4, 4]::smallint[],
      p_area_ids => array['nasr_city', 'heliopolis', 'nasr_city'],
      p_services => '[{"service_id": "ac_inspection", "starting_price_piastres": 15000},
                      {"service_id": "ac_freon_recharge", "starting_price_piastres": 65000}]',
      p_id_front_path => '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000002.jpg',
      p_id_back_path => '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000003.jpg',
      p_selfie_path => '00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000004.jpg'
    )$$,
  'a technician can finish onboarding'
);

select results_eq(
  $$select active_role::text from public.profiles$$,
  $$values ('technician')$$,
  'the profile is a technician'
);

select results_eq(
  $$select shop_name, years_experience::int, base_area_id, base_lat, base_lng,
           service_radius_km::int, work_days::int[], job_credits,
           verification_status::text
      from public.technician_profiles$$,
  $$values ('تكييفات السيد', 12, 'nasr_city', 30.056::double precision, 31.33::double precision,
            10, array[1, 2, 3, 4, 6, 7], 2, 'pending')$$,
  'the technician profile is normalized, rounded and pending verification'
);

select results_eq(
  $$select service_id, starting_price_piastres from public.technician_services order by service_id$$,
  $$values ('ac_freon_recharge', 65000::bigint), ('ac_inspection', 15000::bigint)$$,
  'services and starting prices are saved'
);

select results_eq(
  $$select area_id from public.technician_areas order by area_id$$,
  $$values ('heliopolis'), ('nasr_city')$$,
  'areas are saved once each'
);

select results_eq(
  $$select status::text from public.technician_verifications$$,
  $$values ('pending')$$,
  'an ID submission is waiting for review'
);

select throws_ok(
  $$select pg_temp.onboard_u()$$,
  '23505', 'already_onboarded',
  'onboarding twice is rejected'
);

reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000d2');
set local role authenticated;

select is_empty($$select * from public.technician_profiles$$, 'U cannot read T''s technician profile');
select is_empty($$select * from public.technician_verifications$$, 'U cannot read T''s ID submission');
select is_empty($$select * from public.technician_services$$, 'U cannot read T''s services');

select throws_ok(
  $$select pg_temp.onboard_u('{"front": "00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000002.jpg"}')$$,
  '22023', 'invalid_documents', 'someone else''s ID photo is rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"avatar": "00000000-0000-4000-8000-0000000000c1/10000000-0000-4000-8000-000000000001.jpg"}')$$,
  '22023', 'invalid_avatar', 'someone else''s avatar is rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"avatar": "00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000002.jpg"}')$$,
  '22023', 'invalid_avatar', 'an ID photo cannot be used as the avatar');
select throws_ok(
  $$select pg_temp.onboard_u('{"back": "00000000-0000-4000-8000-0000000000d2/20000000-0000-4000-8000-000000000002.jpg"}')$$,
  '22023', 'invalid_documents', 'the same photo cannot be both sides of the ID');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": []}')$$,
  '22023', 'invalid_services', 'at least one service is required');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": [{"service_id": "ac_unicorn", "starting_price_piastres": 100}]}')$$,
  '22023', 'invalid_services', 'unknown services are rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": [{"service_id": "electrical_wiring", "starting_price_piastres": 50000}]}')$$,
  '22023', 'invalid_services', 'services in a category that is not open are rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": [{"service_id": "ac_inspection", "starting_price_piastres": 100},
                                             {"service_id": "ac_inspection", "starting_price_piastres": 200}]}')$$,
  '22023', 'invalid_services', 'duplicate services are rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": {"service_id": "ac_inspection"}}')$$,
  '22023', 'invalid_services', 'services must be a list');
select throws_ok(
  $$select pg_temp.onboard_u('{"services": [{"service_id": "ac_inspection", "starting_price_piastres": 0}]}')$$,
  '23514', null, 'a zero price is rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"areas": []}')$$,
  '22023', 'invalid_areas', 'at least one area is required');
select throws_ok(
  $$select pg_temp.onboard_u('{"areas": ["heliopolis", "atlantis"]}')$$,
  '22023', 'invalid_areas', 'unknown areas are rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"radius": 7}')$$,
  '23514', null, 'only 5, 10 or 15 km is allowed');
select throws_ok(
  $$select pg_temp.onboard_u('{"days": [8]}')$$,
  '23514', null, 'work days must be ISO weekdays');
select throws_ok(
  $$select pg_temp.onboard_u('{"lat": 48.85, "lng": 2.35}')$$,
  '23514', null, 'a base location outside Egypt is rejected');
select throws_ok(
  $$select pg_temp.onboard_u('{"years": 70}')$$,
  '23514', null, 'implausible years of experience are rejected');

-- A consumer can add the technician side later.
select lives_ok(
  $$select public.complete_consumer_onboarding('وليد حسني', 'mr', 'heliopolis')$$,
  'U starts as a consumer'
);
select lives_ok($$select pg_temp.onboard_u()$$, 'U then joins as a technician');

select * from finish();
rollback;
