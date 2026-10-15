begin;
create extension if not exists pgtap with schema extensions;

select plan(53);

-- Admin ad; consumers c1 (pays) and c2 (a stranger); technicians a1 (picked,
-- has a payout account) and a2 (not picked).
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
  select '20100' || lpad((abs(hashtext(p_n)) % 10000000)::text, 7, '0');
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

create function pg_temp.sign_in_stale(p_user_id uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id, 'role', 'authenticated',
      'iat', extract(epoch from now())::bigint - 3600
    )::text,
    true
  );
$$;

insert into auth.users (id, phone, aud, role)
select pg_temp.u(n), pg_temp.ph(n), 'authenticated', 'authenticated'
  from (values ('ad'), ('c1'), ('c2'), ('a1'), ('a2')) v (n);

insert into private.admins (user_id, note) values (pg_temp.u('ad'), 'test admin');

insert into public.profiles (id, phone, full_name, active_role)
select pg_temp.u(n), '+' || pg_temp.ph(n), 'اسم ' || n,
       case when n like 'c%' then 'consumer' else 'technician' end::public.user_role
  from (values ('c1'), ('c2'), ('a1'), ('a2')) v (n);

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
select pg_temp.u(n), 'ms', 'nasr_city', 2 from (values ('c1'), ('c2')) v (n);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
select pg_temp.u(n), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'
  from (values ('a1'), ('a2')) v (n);

create table pg_temp.ids (name text primary key, id uuid);
insert into pg_temp.ids values
  ('request', gen_random_uuid()), ('job', gen_random_uuid()), ('offer', gen_random_uuid()),
  ('other_request', gen_random_uuid());

insert into public.customers (id, technician_id, name, phone, source)
values (pg_temp.u('d1'), pg_temp.u('a1'), 'عميل', '+201000000099', 'platform');
insert into public.jobs (id, technician_id, customer_id, status, quote_status, source)
values ((select id from pg_temp.ids where name = 'job'), pg_temp.u('a1'), pg_temp.u('d1'),
        'unconfirmed', 'accepted', 'platform');

-- Chosen offer 350 pounds and an urgent fee of 100: the guarantee is 450.
select set_config('private.urgent_request', 'on', true);
insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, status, job_id, urgent_fee_piastres
)
values (
  (select id from pg_temp.ids where name = 'request'), pg_temp.u('c1'), 'ac', 'not_cooling',
  'nasr_city', 'البيت', 'عنوان', current_date + 1, 'noon', now() + interval '1 day', 'open',
  null, 10000
);
insert into public.request_offers (id, request_id, technician_id, price_piastres, arrive_at, status)
values ((select id from pg_temp.ids where name = 'offer'), (select id from pg_temp.ids where name = 'request'),
        pg_temp.u('a1'), 35000, now() + interval '1 day', 'sent');

select set_config('private.urgent_request', 'off', true);

grant execute on all functions in schema pg_temp to authenticated, service_role;
grant all on table pg_temp.ids to authenticated, service_role;

create function pg_temp.pack(p_role public.user_role, p_uses integer)
returns uuid
language sql
as $$
  select id from public.credit_packs where role = p_role and uses = p_uses;
$$;

-- Old transfers are closed ------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select throws_ok(
  $$select public.submit_topup(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay', 'x.jpg', 2000)$$,
  '42501', null, 'a new transfer by screenshot can no longer be sent'
);
select throws_ok(
  $$select public.payments_apply_event('paymob', 'k', 'webhook', '1', null, '1', 'succeeded', 2000, 'EGP', 'card')$$,
  '42501', null, 'a signed-in person cannot report a payment as made'
);
select throws_ok(
  $$select public.payments_attach_provider(gen_random_uuid(), 'paymob', '1')$$,
  '42501', null, 'nor attach a provider order'
);
select throws_ok(
  $$select public.payments_record_refund(gen_random_uuid(), 'x', null)$$,
  '42501', null, 'nor record a refund'
);

-- Buying uses -------------------------------------------------------------------------------

select throws_ok(
  $$select public.create_credit_pack_payment(pg_temp.pack('technician', 1), 3000)$$,
  'P0002', 'pack_not_found', 'a consumer cannot buy a technician pack'
);
select throws_ok(
  $$select public.create_credit_pack_payment(pg_temp.pack('consumer', 1), 1)$$,
  'P0001', 'price_changed', 'a price the app made up is refused'
);

select pg_temp.sign_in_as(null);
select throws_ok(
  $$select public.create_credit_pack_payment(pg_temp.pack('consumer', 1), 2000)$$,
  '28000', 'not_signed_in', 'nobody signed out can start a payment'
);
select pg_temp.sign_in_as(pg_temp.u('c1'));

create temp table pg_temp.orders (name text primary key, id uuid);
grant all on table pg_temp.orders to authenticated, service_role;
insert into pg_temp.orders
select 'pack1', (public.create_credit_pack_payment(pg_temp.pack('consumer', 1), 2000) ->> 'order_id')::uuid;
insert into pg_temp.orders
select 'pack5', (public.create_credit_pack_payment(pg_temp.pack('consumer', 5), 8000) ->> 'order_id')::uuid;

select is(
  (select amount_piastres from public.payment_orders where id = (select id from pg_temp.orders where name = 'pack1')),
  2000::bigint, 'the amount is the pack''s price'
);
select is(
  (select status::text from public.payment_orders where id = (select id from pg_temp.orders where name = 'pack1')),
  'created', 'the order starts created'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  2, 'and creating an order gives nothing'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select is((select count(*)::int from public.payment_orders), 0, 'nobody sees another person''s payments');
select pg_temp.sign_in_as(pg_temp.u('c1'));
select is((select count(*)::int from public.payment_orders), 2, 'she sees her own');
select throws_ok(
  $$select provider_order_id from public.payment_orders$$,
  '42501', null, 'but not the provider''s ids'
);
select throws_ok(
  $$update public.payment_orders set status = 'succeeded'$$,
  '42501', null, 'and cannot mark an order paid'
);

-- The provider says it was paid -------------------------------------------------------------

reset role;
set local role service_role;
select public.payments_attach_provider((select id from pg_temp.orders where name = 'pack1'), 'paymob', '9001');
select public.payments_attach_provider((select id from pg_temp.orders where name = 'pack5'), 'paymob', '9005');

select is(
  (select status::text from public.payment_orders where id = (select id from pg_temp.orders where name = 'pack1')),
  'pending', 'an order with a checkout is pending'
);

select is(
  public.payments_apply_event('paymob', 'k-unknown', 'webhook', '555', null, '1', 'succeeded', 2000, 'EGP', 'card') ->> 'outcome',
  'unknown_order', 'a payment for an order we never made changes nothing'
);

select is(
  public.payments_apply_event('paymob', 'p1-pending', 'webhook', '9001', null, '7001', 'pending', 2000, 'EGP', 'wallet') ->> 'status',
  'pending', 'a wallet payment waiting for approval stays pending'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  2, 'and gives nothing yet'
);

select is(
  public.payments_apply_event('paymob', 'p1-wrong-amount', 'webhook', '9001', null, '7001', 'succeeded', 1, 'EGP', 'wallet') ->> 'outcome',
  'amount_mismatch', 'a payment of the wrong amount is not accepted'
);
select is(
  public.payments_apply_event('paymob', 'p1-wrong-currency', 'webhook', '9001', null, '7001', 'succeeded', 2000, 'USD', 'wallet') ->> 'outcome',
  'amount_mismatch', 'nor one in another currency'
);
select is(
  (select needs_review from public.payment_orders where id = (select id from pg_temp.orders where name = 'pack1')),
  true, 'an admin is asked to look'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  2, 'and nothing was given'
);

select is(
  public.payments_apply_event('paymob', 'p1-ok', 'webhook', '9001', null, '7001', 'succeeded', 2000, 'EGP', 'wallet') ->> 'outcome',
  'applied', 'the confirmed payment is applied'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  3, 'and the use is added'
);
select is(
  (select count(*)::int from public.credit_ledger where payment_order_id = (select id from pg_temp.orders where name = 'pack1')),
  1, 'with one ledger entry'
);

select is(
  public.payments_apply_event('paymob', 'p1-ok', 'webhook', '9001', null, '7001', 'succeeded', 2000, 'EGP', 'wallet') ->> 'outcome',
  'duplicate', 'the same message again is ignored'
);
select is(
  public.payments_apply_event('paymob', 'p1-ok-again', 'webhook', '9001', null, '7001', 'succeeded', 2000, 'EGP', 'wallet') ->> 'outcome',
  'stale', 'a second confirmation under another key is ignored too'
);
select is(
  public.payments_apply_event('paymob', 'p1-late-pending', 'webhook', '9001', null, '7001', 'pending', 2000, 'EGP', 'wallet') ->> 'status',
  'succeeded', 'a late "pending" does not undo a payment'
);
select is(
  public.payments_apply_event('paymob', 'p1-late-fail', 'webhook', '9001', null, '7099', 'failed', 2000, 'EGP', 'card') ->> 'status',
  'succeeded', 'nor a late failure'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  3, 'the uses were added once'
);

-- A failed try, then a good one --------------------------------------------------------------

select is(
  public.payments_apply_event('paymob', 'p5-fail', 'webhook', '9005', null, '7101', 'failed', 8000, 'EGP', 'card') ->> 'status',
  'failed', 'a declined card marks the order failed'
);
select is(
  public.payments_apply_event('paymob', 'p5-retry', 'webhook', '9005', null, '7102', 'pending', 8000, 'EGP', 'card') ->> 'status',
  'pending', 'a new try on the same order is pending again'
);
select is(
  public.payments_apply_event('paymob', 'p5-fail-old', 'webhook', '9005', null, '7101', 'failed', 8000, 'EGP', 'card') ->> 'outcome',
  'stale', 'the first try''s failure arriving late is ignored'
);
select is(
  public.payments_apply_event('paymob', 'p5-ok', 'webhook', '9005', null, '7102', 'succeeded', 8000, 'EGP', 'card') ->> 'status',
  'succeeded', 'the retry succeeds'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  8, 'and five uses are added'
);

-- Paying after the checkout expired still counts ----------------------------------------------

reset role;
insert into pg_temp.orders values ('late', gen_random_uuid());
insert into public.payment_orders (id, user_id, role, purpose, pack_id, uses, amount_piastres,
                                   provider, provider_order_id, status, expires_at, created_at)
values ((select id from pg_temp.orders where name = 'late'), pg_temp.u('c1'), 'consumer',
        'credit_pack', pg_temp.pack('consumer', 1), 1, 2000, 'paymob', '9100', 'pending',
        now() - interval '3 hours', now() - interval '3 hours');
select is(private.expire_stale_payments(), 1, 'an abandoned checkout is closed');
select is(
  (select status::text from public.payment_orders where id = (select id from pg_temp.orders where name = 'late')),
  'expired', 'as expired'
);
set local role service_role;
select is(
  public.payments_apply_event('paymob', 'late-ok', 'webhook', '9100', null, '7200', 'succeeded', 2000, 'EGP', 'card') ->> 'status',
  'succeeded', 'money that still arrived is accepted'
);
select is(
  (select request_credits from public.consumer_profiles where id = pg_temp.u('c1')),
  9, 'and the use is added'
);
select is(
  jsonb_array_length(public.payments_unsettled(10)),
  0, 'nothing is left undecided'
);

-- Paying a request's price ---------------------------------------------------------------------

reset role;
update public.service_requests
   set status = 'assigned', chosen_offer_id = (select id from pg_temp.ids where name = 'offer'),
       job_id = (select id from pg_temp.ids where name = 'job')
 where id = (select id from pg_temp.ids where name = 'request');
update public.request_offers set status = 'accepted' where id = (select id from pg_temp.ids where name = 'offer');

select pg_temp.sign_in_as(pg_temp.u('c2'));
set local role authenticated;
select throws_ok(
  format($$select public.create_escrow_payment(%L)$$, (select id from pg_temp.ids where name = 'request')),
  'P0002', 'not_found', 'only the request''s consumer can pay for it'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
insert into pg_temp.orders
select 'escrow', (public.create_escrow_payment((select id from pg_temp.ids where name = 'request')) ->> 'order_id')::uuid;
select is(
  (select amount_piastres from public.payment_orders where id = (select id from pg_temp.orders where name = 'escrow')),
  45000::bigint, 'the amount is the offer plus the urgent fee, decided by the server'
);
reset role;
select is(
  (select count(*)::int from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request')),
  0, 'nothing is held before the money arrives'
);

reset role;
set local role service_role;
select public.payments_attach_provider((select id from pg_temp.orders where name = 'escrow'), 'paymob', '9200');
select is(
  public.payments_apply_event('paymob', 'e-ok', 'webhook', '9200', (select id::text from pg_temp.orders where name = 'escrow'), '7300', 'succeeded', 45000, 'EGP', 'card') ->> 'status',
  'succeeded', 'the confirmed payment is applied'
);
select is(
  (select status::text from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request')),
  'held', 'and the money is held for the request'
);
select is(
  (select payment_order_id from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request')),
  (select id from pg_temp.orders where name = 'escrow'), 'linked to its order'
);
select is(
  public.payments_apply_event('paymob', 'e-ok', 'webhook', '9200', null, '7300', 'succeeded', 45000, 'EGP', 'card') ->> 'outcome',
  'duplicate', 'a repeated webhook holds nothing twice'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  format($$select public.create_escrow_payment(%L)$$, (select id from pg_temp.ids where name = 'request')),
  'P0001', 'already_secured', 'a held request cannot be paid again'
);

-- The job is cancelled: the money is due back, and a refund closes it ------------------------------

reset role;
update public.jobs set status = 'cancelled' where id = (select id from pg_temp.ids where name = 'job');
select is(
  (select status::text from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request')),
  'refund_due', 'a cancelled job leaves the money to be returned'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select throws_ok(
  $$select public.admin_payment_refund_target(gen_random_uuid())$$,
  '42501', 'admin_required', 'only an admin can ask who to refund'
);
reset role;
insert into pg_temp.ids
select 'escrow_row', id from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request');
select pg_temp.sign_in_as(pg_temp.u('ad'));
set local role authenticated;
select is(
  public.admin_payment_refund_target((select id from pg_temp.ids where name = 'escrow_row')) ->> 'provider_txn_id',
  '7300', 'the admin is told which provider transaction to refund'
);
reset role;
set local role service_role;
select public.payments_record_refund((select id from pg_temp.orders where name = 'escrow'), 'RF-1', pg_temp.u('ad'));
select public.payments_record_refund((select id from pg_temp.orders where name = 'escrow'), 'RF-1', pg_temp.u('ad'));
select is(
  (select status::text from public.job_escrows where request_id = (select id from pg_temp.ids where name = 'request')),
  'refunded', 'the refund closes the escrow, also when recorded twice'
);
select is(
  (select status::text from public.payment_orders where id = (select id from pg_temp.orders where name = 'escrow')),
  'refunded', 'and the order'
);
reset role;

select * from finish();
rollback;
