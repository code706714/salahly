begin;
create extension if not exists pgtap with schema extensions;

select plan(28);

-- Consumers c1 and c2. Technicians: t1 (Nasr City, AC, two reviews, one
-- finished job), t2 (Nasr City, plumbing), t5 (Maadi, AC, one review),
-- t3 not verified yet, t4 suspended.
create function pg_temp.ph(p_n text)
returns text
language sql
as $$
  select '20100' || lpad((ascii(left(p_n, 1)) * 10 + right(p_n, 1)::int)::text, 7, '0');
$$;

create function pg_temp.u(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

insert into auth.users (id, phone, aud, role)
select pg_temp.u(n), pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('c1'), ('c2'), ('b1'), ('b2'), ('b3'), ('b4'), ('b5')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n),
       case n when 'c1' then 'نورهان مصطفى' when 'c2' then 'حسام علي'
              when 'b1' then 'محمود السيد عبد الله' when 'b2' then 'ياسر عبد الحميد'
              when 'b3' then 'أحمد رمضان' when 'b4' then 'وليد حسني' else 'كريم فؤاد' end,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('b1'), ('b2'), ('b3'), ('b4'), ('b5')) v (n);

update public.profiles set suspended_at = now() where id = pg_temp.u('b4');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 10 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, shop_name, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  (pg_temp.u('b1'), 'ورشة السيد', 12, 'a/b1.jpg', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  (pg_temp.u('b2'), null, 5, 'a/b2.jpg', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  (pg_temp.u('b3'), null, 3, 'a/b3.jpg', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'pending'),
  (pg_temp.u('b4'), null, 3, 'a/b4.jpg', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 3, 'approved'),
  (pg_temp.u('b5'), null, 8, 'a/b5.jpg', 'maadi', 29.96, 31.257, 5, '{1,2,3,4,5,6,7}', 3, 'approved');

insert into public.technician_areas (technician_id, area_id)
select pg_temp.u(n), a from (values ('b1', 'heliopolis'), ('b5', 'giza')) v (n, a);

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
values
  (pg_temp.u('b1'), 'ac_inspection', 20000),
  (pg_temp.u('b1'), 'ac_freon_recharge', 70000),
  (pg_temp.u('b2'), 'plumbing_inspection', 15000),
  (pg_temp.u('b3'), 'ac_inspection', 10000),
  (pg_temp.u('b4'), 'ac_inspection', 10000),
  (pg_temp.u('b5'), 'ac_inspection', 15000);

-- History: requests c1 made, reviewed, one with a finished platform job.
insert into public.customers (id, technician_id, name, phone, area_id, address, source)
values ('50000000-0000-4000-8000-000000000001', pg_temp.u('b1'), 'نورهان مصطفى', '+' || pg_temp.ph('c1'), 'nasr_city',
        '14 شارع عباس العقاد', 'platform');
insert into public.jobs (id, technician_id, customer_id, status, finished_at, source)
values ('60000000-0000-4000-8000-000000000001', pg_temp.u('b1'), '50000000-0000-4000-8000-000000000001', 'finished', now(), 'platform');

insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, status, job_id
)
select ('70000000-0000-4000-8000-00000000000' || n)::uuid, pg_temp.u('c1'), 'ac', 'not_cooling', 'nasr_city',
       'البيت', '14 شارع عباس العقاد، الدور الخامس', current_date, 'noon', now() + interval '1 day',
       case when n = 1 then 'assigned' else 'cancelled' end::public.request_status,
       case when n = 1 then '60000000-0000-4000-8000-000000000001'::uuid end
  from generate_series(1, 3) n;

insert into public.reviews (request_id, consumer_id, technician_id, stars, comment, paid_with)
values
  ('70000000-0000-4000-8000-000000000001', pg_temp.u('c1'), pg_temp.u('b1'), 5, 'شغل ممتاز ومحترم', 'cash'),
  ('70000000-0000-4000-8000-000000000002', pg_temp.u('c1'), pg_temp.u('b1'), 4, 'جه في معاده', 'cash'),
  ('70000000-0000-4000-8000-000000000003', pg_temp.u('c1'), pg_temp.u('b5'), 3, null, 'cash');

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

create function pg_temp.ids_of(p_list jsonb)
returns text[]
language sql
as $$
  select coalesce(array_agg(right(e ->> 'id', 2) order by ord), '{}')
    from jsonb_array_elements(p_list) with ordinality as t (e, ord);
$$;

grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.sign_in_as(pg_temp.u('c2'));
set local role authenticated;

select is(
  pg_temp.ids_of(public.browse_technicians()),
  array['b1', 'b5', 'b2'],
  'a consumer browses verified, non-suspended technicians, best rated first'
);
select is(
  pg_temp.ids_of(public.browse_technicians('plumbing')),
  array['b2'],
  'by category'
);
select is(
  pg_temp.ids_of(public.browse_technicians('ac', 'maadi')),
  array['b5'],
  'by category and area'
);
select is(
  pg_temp.ids_of(public.browse_technicians(null, 'giza')),
  array['b5'],
  'an area a technician chose counts as covered'
);
select is(
  pg_temp.ids_of(public.browse_technicians(null, null, 'experience')),
  array['b1', 'b5', 'b2'],
  'sorted by experience'
);
select is(
  pg_temp.ids_of(public.browse_technicians('ac', null, 'price')),
  array['b5', 'b1'],
  'sorted by starting price'
);
select is(
  pg_temp.ids_of(public.browse_technicians(null, null, 'reviews')),
  array['b1', 'b5', 'b2'],
  'sorted by review count'
);
select is(
  pg_temp.ids_of(public.browse_technicians(null, null, 'jobs', 1, 0)),
  array['b1'],
  'sorted by finished jobs, and paged'
);
select is(
  pg_temp.ids_of(public.browse_technicians(null, null, 'rating', 1, 1)),
  array['b5'],
  'the next page'
);
select throws_ok($$select public.browse_technicians(null, null, 'popularity')$$, '22023', 'invalid_sort', 'an unknown sort is refused');
select throws_ok($$select public.browse_technicians('unicorn')$$, '22023', 'invalid_category', 'an unknown category is refused');
select throws_ok($$select public.browse_technicians(null, 'atlantis')$$, '22023', 'invalid_area', 'an unknown area is refused');

-- What a card holds -----------------------------------------------------------------------

select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.browse_technicians('ac') -> 0) k),
  array['area_id', 'area_ids', 'avatar_path', 'id', 'jobs_done', 'min_price_piastres', 'name',
        'rating', 'review_count', 'services', 'years_experience'],
  'a card carries exactly what a consumer needs'
);
select is(
  public.browse_technicians('ac') -> 0 ->> 'name',
  'محمود ا.',
  'the name is first name and initial'
);
select is(
  (public.browse_technicians('ac') -> 0 ->> 'rating')::numeric,
  4.5,
  'the rating averages the reviews'
);
select is(
  (public.browse_technicians('ac') -> 0 ->> 'review_count')::int
  || ' ' || (public.browse_technicians('ac') -> 0 ->> 'jobs_done'),
  '2 1',
  'with the review and finished-job counts'
);
select is(
  public.browse_technicians('ac') -> 0 -> 'services',
  '[{"service_id": "ac_inspection", "category_id": "ac", "name_ar": "كشف", "starting_price_piastres": 20000},
    {"service_id": "ac_freon_recharge", "category_id": "ac", "name_ar": "شحن فريون", "starting_price_piastres": 70000}]'::jsonb,
  'and the starting price of each service'
);
select ok(
  public.browse_technicians()::text !~ '(20100|\+20|عباس العقاد|base_lat|base_lng|phone|address_|نورهان|السيد عبد|عبد الحميد)',
  'no phone, address, location or full name'
);

-- A technician's page --------------------------------------------------------------------------

select is(
  (public.technician_public_profile(pg_temp.u('b1')) -> 'reviews' -> 0 ->> 'stars')::int,
  5,
  'a technician''s page lists their recent reviews'
);
select is(
  public.technician_public_profile(pg_temp.u('b1')) ->> 'shop_name',
  'ورشة السيد',
  'with the shop name'
);
select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.technician_public_profile(pg_temp.u('b1')) -> 'reviews' -> 0) k),
  array['comment', 'created_at', 'issue', 'stars', 'tags'],
  'a review shows no reviewer'
);
select ok(
  public.technician_public_profile(pg_temp.u('b1'))::text !~ '(20100|\+20|عباس العقاد|نورهان|مصطفى|base_lat|consumer)',
  'no consumer name or phone, no address on the page'
);
select is(public.technician_public_profile(pg_temp.u('b3')), null, 'an unverified technician has no page');
select is(public.technician_public_profile(pg_temp.u('b4')), null, 'nor a suspended one');
select is(public.technician_public_profile('00000000-0000-4000-8000-00000000ffff'), null, 'nor one who doesn''t exist');

-- Not for technicians ----------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('b2'));
select throws_ok($$select public.browse_technicians()$$, '42501', 'not_consumer', 'a technician can''t browse technicians');
select throws_ok(
  $$select public.technician_public_profile((select id from public.technician_profiles limit 1))$$,
  '42501', 'not_consumer', 'nor open their pages'
);

-- Picking one to send a request to ------------------------------------------------------------------

reset role;
insert into public.consumer_addresses (consumer_id, label, area_id, details)
values (pg_temp.u('c1'), 'الشغل', 'nasr_city', '3 شارع الطيران');
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.create_service_request(
    'ac', 'not_cooling', null, null,
    (select id from public.consumer_addresses where label = 'الشغل'),
    (now() at time zone 'Africa/Cairo')::date + 1, 'noon', pg_temp.u('b1')
  ) -> 'sent_to',
  '1'::jsonb,
  'a consumer sends a request to the technician they picked, and only to them'
);

reset role;
select * from finish();
rollback;
