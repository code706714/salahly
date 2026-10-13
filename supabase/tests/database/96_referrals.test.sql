begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

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
values (pg_temp.u('c1'), '201000000961', 'authenticated', 'authenticated'),
       (pg_temp.u('c2'), '201000000962', 'authenticated', 'authenticated'),
       (pg_temp.u('c3'), '201000000963', 'authenticated', 'authenticated'),
       (pg_temp.u('a1'), '201000000964', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role, created_at)
values (pg_temp.u('c1'), '+201000000961', 'اسم c1', 'consumer', now()),
       (pg_temp.u('c2'), '+201000000962', 'اسم c2', 'consumer', now()),
       (pg_temp.u('c3'), '+201000000963', 'اسم c3', 'consumer', now() - interval '30 days'),
       (pg_temp.u('a1'), '+201000000964', 'اسم a1', 'technician', now());

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values (pg_temp.u('c1'), 'ms', 'nasr_city', 2),
       (pg_temp.u('c2'), 'ms', 'nasr_city', 2),
       (pg_temp.u('c3'), 'ms', 'nasr_city', 2);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values (pg_temp.u('a1'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 2, 'approved');

grant execute on all functions in schema pg_temp to authenticated;

-- A code is made once and kept -------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select ok(
  public.my_referral() ->> 'code' ~ '^[A-HJ-NP-Z2-9]{8}$',
  'asking makes an eight-letter code'
);
select is(
  public.my_referral() ->> 'code',
  (select referral_code from public.profiles where id = pg_temp.u('c1')),
  'and the same one comes back'
);

-- A newcomer redeems it ------------------------------------------------------------

reset role;
create temp table codes as
select referral_code as code from public.profiles where id = pg_temp.u('c1');
grant select on codes to authenticated;
select pg_temp.sign_in_as(pg_temp.u('c2'));
set local role authenticated;

select throws_ok(
  $$select public.redeem_referral('NOSUCHXX')$$, '22023', 'invalid_code', 'an unknown code is refused'
);
select lives_ok(
  $$select public.redeem_referral((select lower(code) from codes))$$,
  'a friend''s code works in any case'
);

reset role;
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c2')),
  3, 'the newcomer gets a free use'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  3, 'and so does the friend'
);
select is(
  (select count(*)::integer from public.credit_ledger where reason = 'referral_reward'),
  2, 'both are in the ledger'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
set local role authenticated;

select throws_ok(
  $$select public.redeem_referral((select code from codes))$$,
  'P0001', 'referral_unavailable', 'a code can be used once per person'
);

-- Not for oneself, not back and forth, not for old accounts --------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  $$select public.redeem_referral((select code from codes))$$,
  '22023', 'own_code', 'your own code is refused'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select public.my_referral();
reset role;
create temp table codes2 as
select referral_code as code from public.profiles where id = pg_temp.u('c2');
grant select on codes2 to authenticated;
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  $$select public.redeem_referral((select code from codes2))$$,
  'P0001', 'referral_unavailable', 'a friend you invited can''t invite you back'
);

select pg_temp.sign_in_as(pg_temp.u('c3'));
select throws_ok(
  $$select public.redeem_referral((select code from codes))$$,
  'P0001', 'referral_unavailable', 'an account older than two weeks is too late'
);

-- A technician gets a job use ------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
select lives_ok(
  $$select public.redeem_referral((select code from codes))$$,
  'a technician redeems it too'
);

reset role;
select is(
  (select job_credits from public.technician_profiles where id = pg_temp.u('a1')),
  3, 'and gets a job use'
);

-- Nobody signed out ------------------------------------------------------------------

set local role anon;
select throws_ok(
  $$select public.my_referral()$$, '42501', null, 'a signed-out caller has no code'
);
reset role;

select * from finish();
rollback;
