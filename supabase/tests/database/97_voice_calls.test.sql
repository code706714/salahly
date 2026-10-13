begin;
create extension if not exists pgtap with schema extensions;

select plan(17);

-- Consumer c1 with a request; technicians a1 (offered, then picked), a2
-- (offered) and a3 (no offer). Consumer c2 is a stranger.
create function pg_temp.u(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

create function pg_temp.ph(p_n text)
returns text
language sql
as $$
  select '20100' || lpad((ascii(left(p_n, 1)) * 10 + right(p_n, 1)::int)::text, 7, '0');
$$;

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

insert into auth.users (id, phone, aud, role)
select pg_temp.u(n), pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n), 'اسم ' || n,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 2 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2'), ('a3')) v (n);

create table pg_temp.ids (name text primary key, id uuid);
insert into pg_temp.ids values ('request', gen_random_uuid()), ('job', gen_random_uuid());

insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, status
)
values (
  (select id from pg_temp.ids where name = 'request'), pg_temp.u('c1'), 'ac', 'not_cooling',
  'nasr_city', 'البيت', 'عنوان', current_date + 1, 'noon', now() + interval '1 day', 'open'
);

insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at)
select (select id from pg_temp.ids where name = 'request'), pg_temp.u(n), 35000, now() + interval '1 day'
  from (values ('a1'), ('a2')) v (n);

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- ids: fixed call id holder
create temp table calls (name text primary key, id uuid);
grant all on table calls to authenticated;

-- Ringing -----------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select throws_ok(
  format($$select public.start_call(%L, %L)$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a3')),
  'P0001', 'call_unavailable', 'a technician who did not offer can''t be called'
);

select lives_ok(
  format($$insert into calls select 'one', (public.start_call(%L, %L) ->> 'id')::uuid$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'the consumer calls a technician who offered'
);

select throws_ok(
  format($$select public.start_call(%L, %L)$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a2')),
  'P0001', 'call_in_progress', 'one call at a time'
);

reset role;
select is(
  (select count(*)::integer from public.notifications
    where user_id = pg_temp.u('a1') and kind = 'incoming_call'),
  1, 'the technician''s phone is told'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;

select is(
  public.pending_call() ->> 'caller_name', 'اسم c.',
  'he sees who is calling by her short name'
);

-- The handshake -----------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
select lives_ok(
  format($$select public.send_call_signal(%L, 'offer', '{"sdp": "x"}')$$,
    (select id from calls where name = 'one')),
  'she sends her offer'
);
select throws_ok(
  format($$select public.send_call_signal(%L, 'hack', '{}')$$,
    (select id from calls where name = 'one')),
  '22023', 'invalid_signal', 'only the known kinds pass'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select is(
  jsonb_array_length(public.call_signals_after((select id from calls where name = 'one'), 0)),
  1, 'he gets it'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  format($$select public.send_call_signal(%L, 'offer', '{}')$$,
    (select id from calls where name = 'one')),
  'P0001', 'call_unavailable', 'a stranger can''t send into the call'
);
select is(
  public.call_signals_after((select id from calls where name = 'one'), 0), '[]'::jsonb,
  'nor read from it'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  format($$select public.answer_call(%L)$$, (select id from calls where name = 'one')),
  'P0001', 'call_unavailable', 'the caller can''t answer her own call'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select lives_ok(
  format($$select public.answer_call(%L)$$, (select id from calls where name = 'one')),
  'he answers'
);

-- Hanging up ----------------------------------------------------------------------------

select lives_ok(
  format($$select public.end_call(%L)$$, (select id from calls where name = 'one')),
  'he hangs up'
);

reset role;
select is(
  (select status::text from public.request_calls where id = (select id from calls where name = 'one')),
  'ended', 'and the call is over'
);

-- An unanswered ring is missed ----------------------------------------------------------

set local role authenticated;
select pg_temp.sign_in_as(pg_temp.u('c1'));
select lives_ok(
  format($$insert into calls select 'two', (public.start_call(%L, %L) ->> 'id')::uuid$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('a1')),
  'a second call can start once the first is over'
);

reset role;
update public.request_calls set created_at = now() - interval '2 minutes'
 where id = (select id from calls where name = 'two');

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select is(public.pending_call(), null::jsonb, 'a ring nobody answered in 45 seconds is gone');

reset role;
set local role anon;
select throws_ok($$select public.pending_call()$$, '42501', null, 'a signed-out caller can''t use calls');
reset role;

select * from finish();
rollback;
