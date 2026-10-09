begin;
create extension if not exists pgtap with schema extensions;

select plan(53);

-- Consumers c1 (asks), c2 and c3 (bystanders); technicians a1 and a2 (offer),
-- a3 (bystander, same area and service).
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
  from (values ('c1'), ('c2'), ('c3'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n), 'اسم ' || n,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('c3'), ('a1'), ('a2'), ('a3')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 10 from (values ('c1'), ('c2'), ('c3')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2'), ('a3')) v (n);

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
select pg_temp.u(n), 'ac_inspection_cleaning', 35000 from (values ('a1'), ('a2'), ('a3')) v (n);

insert into public.consumer_addresses (consumer_id, label, area_id, details)
values (pg_temp.u('c1'), 'البيت', 'nasr_city', '14 شارع عباس العقاد، الدور الخامس');

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

create function pg_temp.tomorrow()
returns date
language sql
as $$
  select (now() at time zone 'Africa/Cairo')::date + 1;
$$;

create function pg_temp.at_cairo(p_hour integer)
returns timestamptz
language sql
as $$
  select (pg_temp.tomorrow() + make_time(p_hour, 0, 0)) at time zone 'Africa/Cairo';
$$;

-- How many notifications of a kind the signed-in user has.
create function pg_temp.notes(p_kind text)
returns bigint
language sql
as $$
  select count(*) from public.notifications where kind::text = p_kind;
$$;

create table pg_temp.ids (name text primary key, id uuid);

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

select is(
  (select array_agg(e::text order by e::text)
     from unnest(enum_range(null::public.notification_kind)) e
    where e::text in ('offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted')),
  array['counter_accepted', 'offer_countered', 'offer_revised', 'offer_withdrawn'],
  'the negotiation notification kinds exist'
);

-- Offers ----------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

insert into pg_temp.ids
select 'r1', (public.create_service_request(
  'ac', 'not_cooling', null, null,
  (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon'
) ->> 'id')::uuid;

select pg_temp.sign_in_as(pg_temp.u('a1'));
insert into pg_temp.ids
select 'o1', public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 50000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.u('a2'));
insert into pg_temp.ids
select 'o2', public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 60000, pg_temp.at_cairo(13), null);

-- Who may negotiate -----------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 40000)$$,
  '42501', 'not_consumer', 'a technician can''t counter'
);
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o2'), 40000)$$,
  'P0002', 'not_found', 'a technician can''t change another technician''s offer'
);
select throws_ok(
  $$select public.withdraw_offer((select id from pg_temp.ids where name = 'o2'))$$,
  'P0002', 'not_found', 'nor withdraw it'
);
select throws_ok(
  $$select public.accept_counter((select id from pg_temp.ids where name = 'o2'))$$,
  'P0002', 'not_found', 'nor accept a counter on it'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 40000)$$,
  'P0002', 'not_found', 'another consumer can''t counter an offer on someone else''s request'
);
select throws_ok(
  $$select public.accept_offer((select id from pg_temp.ids where name = 'o1'))$$,
  'P0002', 'not_found', 'nor accept it'
);
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 40000)$$,
  '42501', 'not_technician', 'a consumer can''t revise'
);

select pg_temp.sign_in_as(pg_temp.u('a3'));
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 40000)$$,
  'P0002', 'not_found', 'a technician with no offer on the request can''t revise someone''s'
);
select is(
  public.offer_thread((select id from pg_temp.ids where name = 'o1')),
  null,
  'nor read the price history'
);

-- The consumer counters -------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));

select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 50000)$$,
  '22023', 'invalid_price', 'a counter must be lower than the offer'
);
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 50)$$,
  '22023', 'invalid_price', 'a counter under one pound is refused'
);
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), null)$$,
  '22023', 'invalid_price', 'a counter needs a price'
);

select is(
  public.counter_offer((select id from pg_temp.ids where name = 'o1'), 40000) ->> 'awaiting',
  'technician',
  'the consumer counters with a lower price'
);
select is(
  public.counter_offer((select id from pg_temp.ids where name = 'o1'), 40000) ->> 'counters_left',
  '2',
  'sending the same counter again changes nothing'
);
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 38000)$$,
  'P0001', 'counter_pending', 'a different counter waits for the technician''s answer'
);

select pg_temp.sign_in_as(pg_temp.u('a1'));
select is(pg_temp.notes('offer_countered'), 1::bigint, 'the technician is told once about the counter');
select is(
  (select my_offer ->> 'counter_price_piastres' from (
     select public.technician_request((select id from pg_temp.ids where name = 'r1')) -> 'my_offer' as my_offer) x),
  '40000',
  'the technician''s request page shows the counter'
);

-- The technician answers --------------------------------------------------------------

select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 60000)$$,
  '22023', 'invalid_price', 'revising can only lower the price'
);
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 39000)$$,
  '22023', 'invalid_price', 'a revision at or below the counter should be an accept instead'
);
select is(
  public.revise_offer((select id from pg_temp.ids where name = 'o1'), 45000) ->> 'price_piastres',
  '45000',
  'the technician lowers the price'
);
select is(
  public.revise_offer((select id from pg_temp.ids where name = 'o1'), 45000) ->> 'revisions_left',
  '1',
  'repeating the revision changes nothing'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
select is(pg_temp.notes('offer_revised'), 1::bigint, 'the consumer is told once about the new price');
select is(
  (select o ->> 'price_piastres' from jsonb_array_elements(
     public.request_details((select id from pg_temp.ids where name = 'r1')) -> 'offers') o
    where o ->> 'id' = (select id::text from pg_temp.ids where name = 'o1')),
  '45000',
  'the request page shows the new price'
);

select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 42000);
select pg_temp.sign_in_as(pg_temp.u('a1'));
select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 43500);
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 43000)$$,
  'P0001', 'negotiation_limit', 'a technician revises at most twice'
);
select pg_temp.sign_in_as(pg_temp.u('c1'));
select is(
  public.counter_offer((select id from pg_temp.ids where name = 'o1'), 40000) ->> 'counters_left',
  '0',
  'the third counter is the last'
);

reset role;
update public.request_offers set awaiting = 'consumer', counter_price_piastres = null
 where id = (select id from pg_temp.ids where name = 'o1');
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 39000)$$,
  'P0001', 'negotiation_limit', 'a fourth counter is refused'
);
reset role;
update public.request_offers set awaiting = 'technician', counter_price_piastres = 40000
 where id = (select id from pg_temp.ids where name = 'o1');
set local role authenticated;

-- Withdrawing -------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a2'));
select is(
  public.withdraw_offer((select id from pg_temp.ids where name = 'o2')) ->> 'status',
  'withdrawn',
  'a technician takes their offer back'
);
select is(
  public.withdraw_offer((select id from pg_temp.ids where name = 'o2')) ->> 'status',
  'withdrawn',
  'taking it back twice is fine'
);
select throws_ok(
  $$select public.send_offer((select id from pg_temp.ids where name = 'r1'), null, 30000, pg_temp.at_cairo(13), null)$$,
  '23505', 'already_offered', 'and they can''t offer again on the same request'
);
select pg_temp.sign_in_as(pg_temp.u('c1'));
select is(pg_temp.notes('offer_withdrawn'), 1::bigint, 'the consumer is told once');
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o2'), 30000)$$,
  'P0001', 'offer_unavailable', 'a withdrawn offer can''t be countered'
);
select throws_ok(
  $$select public.accept_offer((select id from pg_temp.ids where name = 'o2'))$$,
  'P0001', 'offer_unavailable', 'nor picked'
);
select is(
  jsonb_array_length(public.request_details((select id from pg_temp.ids where name = 'r1')) -> 'offers'),
  1,
  'the request page leaves it out'
);

-- The price history -------------------------------------------------------------------

select is(
  (select jsonb_agg(e ->> 'kind' order by ord)
     from jsonb_array_elements(public.offer_thread((select id from pg_temp.ids where name = 'o1')) -> 'events')
          with ordinality as t (e, ord)),
  '["offer", "counter", "revise", "counter", "revise", "counter"]'::jsonb,
  'the consumer reads the whole price history'
);
select pg_temp.sign_in_as(pg_temp.u('a1'));
select is(
  jsonb_array_length(public.offer_thread((select id from pg_temp.ids where name = 'o1')) -> 'events'),
  6,
  'so does the technician'
);
select pg_temp.sign_in_as(pg_temp.u('c2'));
select is(public.offer_thread((select id from pg_temp.ids where name = 'o1')), null, 'a bystander reads nothing');

-- Accepting the counter picks through accept_offer -----------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
insert into pg_temp.ids
select 'job1', public.accept_counter((select id from pg_temp.ids where name = 'o1'));

select is(
  public.accept_counter((select id from pg_temp.ids where name = 'o1')),
  (select id from pg_temp.ids where name = 'job1'),
  'accepting twice returns the same job'
);

reset role;
select results_eq(
  $$select o.price_piastres, o.status::text, r.status::text, r.job_id,
           (select sum(unit_price_piastres) from public.job_items where job_id = r.job_id),
           (select job_credits from public.technician_profiles where id = o.technician_id)
      from public.request_offers o join public.service_requests r on r.id = o.request_id
     where o.id = (select id from pg_temp.ids where name = 'o1')$$,
  $$select 40000::bigint, 'accepted', 'assigned', (select id from pg_temp.ids where name = 'job1'), 40000::numeric, 4$$,
  'the counter became the price, the request is assigned, the job carries that price and one use was taken'
);
select is(
  (select status::text from public.request_offers where id = (select id from pg_temp.ids where name = 'o2')),
  'withdrawn',
  'a withdrawn offer stays withdrawn'
);
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select is(pg_temp.notes('counter_accepted'), 1::bigint, 'the consumer is told once the technician accepted');
select ok(
  public.request_details((select id from pg_temp.ids where name = 'r1')) ->> 'technician_phone' is not null,
  'the phone is shared only now that they are picked'
);

select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o1'), 30000)$$,
  'P0001', 'request_closed', 'no counters once the request is assigned'
);
select pg_temp.sign_in_as(pg_temp.u('a1'));
select throws_ok(
  $$select public.revise_offer((select id from pg_temp.ids where name = 'o1'), 30000)$$,
  'P0001', 'request_closed', 'no revisions either'
);
select throws_ok(
  $$select public.withdraw_offer((select id from pg_temp.ids where name = 'o1'))$$,
  'P0001', 'offer_unavailable', 'a picked technician can''t withdraw through the offer'
);

-- A revised price is picked with accept_offer ------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
insert into pg_temp.ids
select 'r2', (public.create_service_request(
  'ac', 'noisy', null, null,
  (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon'
) ->> 'id')::uuid;
select pg_temp.sign_in_as(pg_temp.u('a1'));
insert into pg_temp.ids
select 'o3', public.send_offer((select id from pg_temp.ids where name = 'r2'), null, 30000, pg_temp.at_cairo(13), null);
select public.revise_offer((select id from pg_temp.ids where name = 'o3'), 25000);
select pg_temp.sign_in_as(pg_temp.u('c1'));
insert into pg_temp.ids select 'job2', public.accept_offer((select id from pg_temp.ids where name = 'o3'));

reset role;
select results_eq(
  $$select sum(unit_price_piastres)::bigint from public.job_items where job_id = (select id from pg_temp.ids where name = 'job2')$$,
  $$values (25000::bigint)$$,
  'the consumer picks the lowered price'
);

-- A technician with no uses left can't take a counter ----------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
insert into pg_temp.ids
select 'r3', (public.create_service_request(
  'ac', 'leaking', null, null,
  (select id from public.consumer_addresses), pg_temp.tomorrow(), 'noon'
) ->> 'id')::uuid;
select pg_temp.sign_in_as(pg_temp.u('a2'));
insert into pg_temp.ids
select 'o4', public.send_offer((select id from pg_temp.ids where name = 'r3'), null, 30000, pg_temp.at_cairo(13), null);
select pg_temp.sign_in_as(pg_temp.u('c1'));
select public.counter_offer((select id from pg_temp.ids where name = 'o4'), 20000);
reset role;
update public.technician_profiles set job_credits = 0 where id = pg_temp.u('a2');
select pg_temp.sign_in_as(pg_temp.u('a2'));
set local role authenticated;
select throws_ok(
  $$select public.accept_counter((select id from pg_temp.ids where name = 'o4'))$$,
  'P0001', 'technician_unavailable', 'a technician with no uses can''t take the counter'
);
select is(
  (select awaiting from public.request_offers where id = (select id from pg_temp.ids where name = 'o4')),
  'technician',
  'and the offer is as it was'
);
select throws_ok(
  $$select public.accept_counter((select id from pg_temp.ids where name = 'o1'))$$,
  'P0002', 'not_found', 'accepting someone else''s offer is refused'
);

-- A technician who lost verification can't be picked ---------------------------------------------------

reset role;
update public.technician_profiles set job_credits = 3, verification_status = 'rejected' where id = pg_temp.u('a2');
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  $$select public.accept_offer((select id from pg_temp.ids where name = 'o4'))$$,
  'P0001', 'technician_unavailable', 'an offer from a technician who is no longer verified can''t be picked'
);

reset role;
select is(
  (select count(*)::int from private.push_outbox o join public.notifications n on n.id = o.notification_id
    where n.kind::text in ('offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted')),
  (select count(*)::int from public.notifications
    where kind::text in ('offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted')),
  'every negotiation notification is queued for push'
);

-- Rate limit ------------------------------------------------------------------------------------------------

reset role;
insert into private.action_log (user_id, action)
select pg_temp.u('c1'), 'negotiate' from generate_series(1, 40);
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  $$select public.counter_offer((select id from pg_temp.ids where name = 'o4'), 15000)$$,
  '54000', 'rate_limited', 'negotiating is rate limited'
);

-- No direct access ----------------------------------------------------------------------------------------------

select is_empty(
  $$select 1 where has_table_privilege('authenticated', 'public.request_offers', 'update')
                or has_table_privilege('authenticated', 'public.request_offers', 'insert')
                or has_schema_privilege('authenticated', 'private', 'usage')$$,
  'app users can''t write offers or reach the price history directly'
);

reset role;
select * from finish();
rollback;
