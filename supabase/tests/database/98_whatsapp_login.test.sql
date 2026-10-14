begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

select ok(
  not has_function_privilege('anon', 'public.login_start()', 'execute')
  and not has_function_privilege('authenticated', 'public.login_start()', 'execute')
  and not has_function_privilege('anon', 'public.login_bind(text, text)', 'execute')
  and not has_function_privilege('authenticated', 'public.login_bind(text, text)', 'execute')
  and not has_function_privilege('anon', 'public.login_status(uuid, text)', 'execute')
  and not has_function_privilege('authenticated', 'public.login_status(uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.login_claim(uuid, text)', 'execute')
  and not has_function_privilege('authenticated', 'public.login_claim(uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.login_user_id(text)', 'execute')
  and not has_function_privilege('authenticated', 'public.login_user_id(text)', 'execute'),
  'only the service role can run the WhatsApp sign-in functions'
);

select ok(
  has_function_privilege('service_role', 'public.login_start()', 'execute')
  and has_function_privilege('service_role', 'public.login_bind(text, text)', 'execute')
  and has_function_privilege('service_role', 'public.login_status(uuid, text)', 'execute')
  and has_function_privilege('service_role', 'public.login_claim(uuid, text)', 'execute')
  and has_function_privilege('service_role', 'public.login_user_id(text)', 'execute'),
  'the service role can run them'
);

select ok(
  not has_table_privilege('anon', 'private.login_challenges', 'select')
  and not has_table_privilege('authenticated', 'private.login_challenges', 'select'),
  'nobody but the service reads the challenges'
);

create table pg_temp.started as select public.login_start() as r;

select matches(
  (select r ->> 'code' from pg_temp.started),
  '^[A-HJ-NP-Z2-9]{8}$',
  'a code is 8 characters without the look-alikes'
);

select matches(
  (select r ->> 'poll_secret' from pg_temp.started),
  '^[0-9a-f]{64}$',
  'the phone gets a 64 character secret'
);

select is(
  (select count(*)::int from private.login_challenges
    where poll_hash = sha256(convert_to((select r ->> 'poll_secret' from pg_temp.started), 'UTF8'))
      and poll_hash::text <> (select r ->> 'poll_secret' from pg_temp.started)),
  1,
  'only the hash of the secret is stored'
);

select is(
  (select public.login_status((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.started),
  'pending',
  'nobody has sent the code yet'
);

select is(
  (select public.login_status((r ->> 'id')::uuid, repeat('0', 64)) from pg_temp.started),
  'unknown',
  'a wrong secret learns nothing'
);

select is(
  public.login_bind((select r ->> 'code' from pg_temp.started), '+12025550100'),
  false,
  'a number that is not an Egyptian mobile is refused'
);

select is(
  public.login_bind('ZZZZZZZZ', '+201000000321'),
  false,
  'an unknown code ties to nothing'
);

select is(
  public.login_bind(lower((select r ->> 'code' from pg_temp.started)), '+201000000321'),
  true,
  'the code ties to the number that sent it, in any case'
);

select is(
  public.login_bind((select r ->> 'code' from pg_temp.started), '+201000000322'),
  false,
  'a second number cannot take the code over'
);

select is(
  (select public.login_status((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.started),
  'ready',
  'the phone sees the code was sent'
);

select is(
  (select public.login_claim((r ->> 'id')::uuid, repeat('0', 64)) from pg_temp.started),
  null::text,
  'a wrong secret claims nothing'
);

select is(
  (select public.login_claim((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.started),
  '+201000000321',
  'the phone that holds the secret gets the first number'
);

select is(
  (select public.login_claim((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.started),
  null::text,
  'it can be claimed only once'
);

select is(
  (select public.login_status((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.started),
  'unknown',
  'a claimed code is gone'
);

create table pg_temp.late as select public.login_start() as r;
update private.login_challenges
   set expires_at = now() - interval '1 second'
 where id = (select (r ->> 'id')::uuid from pg_temp.late);

select is(
  (select public.login_status((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.late),
  'expired',
  'a code is good for a few minutes only'
);

select is(
  public.login_bind((select r ->> 'code' from pg_temp.late), '+201000000323'),
  false,
  'an expired code ties to nothing'
);

select is(
  (select public.login_claim((r ->> 'id')::uuid, r ->> 'poll_secret') from pg_temp.late),
  null::text,
  'an expired code cannot be claimed'
);

insert into auth.users (id, phone, aud, role)
values ('00000000-0000-4000-8000-000000000321', '201000000321', 'authenticated', 'authenticated');

select is(
  public.login_user_id('+201000000321'),
  '00000000-0000-4000-8000-000000000321'::uuid,
  'a number finds its account, with or without the plus sign'
);

select is(
  public.login_user_id('+201000000399'),
  null::uuid,
  'a number without an account finds none'
);

select * from finish();
rollback;
