begin;
create extension if not exists pgtap with schema extensions;

select plan(17);

insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000a1', '201001112223', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2', '201551112224', 'authenticated', 'authenticated');

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

-- User A completes onboarding.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;

select lives_ok(
  $$select public.complete_consumer_onboarding('  نورهان    محمد ', 'ms', 'nasr_city')$$,
  'a signed-in user can finish consumer onboarding'
);

select results_eq(
  $$select phone, full_name, active_role::text from public.profiles$$,
  $$values ('+201001112223', 'نورهان محمد', 'consumer')$$,
  'the profile takes the verified phone and a normalized name'
);

select results_eq(
  $$select honorific::text, area_id, request_credits from public.consumer_profiles$$,
  $$values ('ms', 'nasr_city', 2)$$,
  'the consumer profile gets the configured free requests'
);

select throws_ok(
  $$select public.complete_consumer_onboarding('نورهان', 'ms', 'nasr_city')$$,
  '23505', 'already_onboarded',
  'onboarding twice is rejected'
);

select throws_ok(
  $$update public.consumer_profiles set request_credits = 999$$,
  '42501', null,
  'users cannot change their own credits'
);

select throws_ok(
  $$insert into public.profiles (id, phone, full_name, active_role)
    values ('00000000-0000-4000-8000-0000000000b2', '+201551112224', 'Hacker', 'consumer')$$,
  '42501', null,
  'users cannot insert profiles directly'
);

-- User B tries invalid input and cannot see A.
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000b2');
set local role authenticated;

select is_empty($$select * from public.profiles$$, 'users cannot read other profiles');
select is_empty($$select * from public.consumer_profiles$$, 'users cannot read other consumer profiles');

select throws_ok(
  $$select public.complete_consumer_onboarding('x', 'mr', 'nasr_city')$$,
  '23514', null,
  'a one-letter name is rejected'
);

select throws_ok(
  $$select public.complete_consumer_onboarding('   ', 'mr', 'nasr_city')$$,
  '23502', null,
  'a blank name is rejected'
);

select throws_ok(
  $$select public.complete_consumer_onboarding('كريم منصور', 'mr', 'atlantis')$$,
  '22023', 'invalid_area',
  'an unknown area is rejected'
);

select is_empty($$select * from public.profiles$$, 'failed attempts leave nothing behind');

-- Anonymous callers are refused.
reset role;
set local role anon;
select throws_ok(
  $$select public.complete_consumer_onboarding('كريم منصور', 'mr', 'nasr_city')$$,
  '42501', null,
  'anonymous callers cannot onboard'
);

-- A deleted account that signs up again with the same phone gets no new free requests.
reset role;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000a1';
insert into auth.users (id, phone, aud, role)
values ('00000000-0000-4000-8000-0000000000a3', '201001112223', 'authenticated', 'authenticated');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');
set local role authenticated;
select lives_ok(
  $$select public.complete_consumer_onboarding('نورهان محمد', 'ms', 'nasr_city')$$,
  'a returning phone can onboard again'
);
select results_eq(
  $$select request_credits from public.consumer_profiles$$,
  $$values (0)$$,
  'a returning phone does not get the free requests twice'
);

-- New users get whatever free amount is configured at the time.
reset role;
update public.app_settings set consumer_free_requests = 3;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000b2');
set local role authenticated;
select lives_ok(
  $$select public.complete_consumer_onboarding('كريم منصور', 'mr', 'heliopolis')$$,
  'user B onboards'
);
select results_eq(
  $$select request_credits from public.consumer_profiles$$,
  $$values (3)$$,
  'free requests follow app settings'
);

select * from finish();
rollback;
