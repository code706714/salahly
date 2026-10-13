begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

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
values (pg_temp.u('c1'), '201000000931', 'authenticated', 'authenticated'),
       (pg_temp.u('a1'), '201000000932', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values (pg_temp.u('c1'), '+201000000931', 'اسم c1', 'consumer'),
       (pg_temp.u('a1'), '+201000000932', 'اسم a1', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values (pg_temp.u('c1'), 'ms', 'nasr_city', 20);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values (pg_temp.u('a1'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved');

-- One request with one offer per price, for the same trade and problem.
create function pg_temp.offer_at(
  p_price bigint,
  p_status public.offer_status default 'accepted',
  p_issue public.request_issue default 'not_cooling',
  p_category text default 'ac'
)
returns void
language plpgsql
as $$
declare
  v_request uuid := gen_random_uuid();
begin
  insert into public.service_requests (
    id, consumer_id, category_id, issue, area_id, address_label, address_details,
    preferred_on, time_window, expires_at, status
  )
  values (
    v_request, pg_temp.u('c1'), p_category, p_issue, 'nasr_city', 'البيت', 'عنوان',
    current_date + 1, 'noon', now() + interval '1 day', 'open'
  );
  insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at, status)
  values (v_request, pg_temp.u('a1'), p_price, now() + interval '1 day', p_status);
end;
$$;

grant execute on all functions in schema pg_temp to authenticated;

-- Without enough history the guide is the catalog's prices ---------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.price_guide('ac', 'not_cooling') ->> 'source', 'catalog',
  'with no accepted offers the guide comes from the catalog'
);

select ok(
  (public.price_guide('ac') ->> 'low_piastres')::bigint
    <= (public.price_guide('ac') ->> 'high_piastres')::bigint,
  'the range is ordered'
);

select is(
  public.price_guide('no_such_trade'), null::jsonb,
  'an unknown trade has no guide'
);

reset role;
select pg_temp.offer_at(p)
  from unnest(array[20000, 25000, 30000, 35000]::bigint[]) p;
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.price_guide('ac', 'not_cooling') ->> 'source', 'catalog',
  'four accepted offers say too little: still the catalog'
);

-- Five accepted offers make the guide -------------------------------------------------

reset role;
select pg_temp.offer_at(40000);
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.price_guide('ac', 'not_cooling'),
  '{"source": "offers", "low_piastres": 22000, "high_piastres": 38000}'::jsonb,
  'five accepted offers give the 10th to 90th percentile, rounded out to 10 pounds'
);

-- Only accepted offers, for the same problem, count ---------------------------------

reset role;
select pg_temp.offer_at(999900, 'sent');
select pg_temp.offer_at(999900, 'not_chosen');
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select is(
  public.price_guide('ac', 'not_cooling') ->> 'high_piastres', '38000',
  'offers nobody accepted are left out'
);

select is(
  public.price_guide('ac', 'noisy') ->> 'source', 'catalog',
  'another problem has its own history'
);

select ok(
  public.price_guide('ac') ->> 'source' = 'offers',
  'without a problem all the trade''s accepted offers count'
);

-- Nobody signed out sees it -----------------------------------------------------------

reset role;
set local role anon;

select throws_ok(
  $$select public.price_guide('ac')$$,
  '42501',
  null,
  'a signed-out caller can''t read the guide'
);

reset role;

select * from finish();
rollback;
