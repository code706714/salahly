begin;
create extension if not exists pgtap with schema extensions;

-- Sending a transfer by screenshot is closed to the API since the payments
-- migration (20261015090000); these tests keep covering how a transfer that
-- is already waiting is reviewed, so they open the calls for this transaction.
grant execute on function
  public.submit_topup(uuid, public.topup_method, text, text, bigint),
  public.secure_payment(uuid, public.topup_method, text, text)
to authenticated;

select plan(60);

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

insert into storage.objects (bucket_id, name, owner_id)
select 'transfer-proofs', pg_temp.u('c1') || '/7000000' || n || '-0000-4000-8000-000000000001.jpg', pg_temp.u('c1')::text
  from generate_series(1, 4) n;
insert into storage.objects (bucket_id, name, owner_id)
values ('transfer-proofs', pg_temp.u('c2') || '/70000009-0000-4000-8000-000000000001.jpg', pg_temp.u('c2')::text);

create function pg_temp.proof(p_n int)
returns text
language sql
as $$
  select pg_temp.u('c1') || '/7000000' || p_n || '-0000-4000-8000-000000000001.jpg';
$$;

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

grant execute on all functions in schema pg_temp to authenticated;
grant all on table pg_temp.ids to authenticated;

-- Before a technician is picked there is nothing to secure ---------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;

select throws_ok(
  $$select public.secure_payment((select id from pg_temp.ids where name = 'request'), 'instapay', 'nourhan@instapay', pg_temp.proof(1))$$,
  'P0001', 'escrow_unavailable', 'a request nobody was picked for can''t be secured'
);

reset role;
update public.service_requests
   set status = 'assigned', chosen_offer_id = (select id from pg_temp.ids where name = 'offer'),
       job_id = (select id from pg_temp.ids where name = 'job')
 where id = (select id from pg_temp.ids where name = 'request');
update public.request_offers set status = 'accepted' where id = (select id from pg_temp.ids where name = 'offer');
set local role authenticated;

select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) ->> 'amount_piastres')::bigint,
  45000::bigint,
  'the guarantee is the offer plus the urgent fee'
);
select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) ->> 'can_secure')::boolean,
  true, 'and she can secure it'
);
select is(
  public.escrow_info((select id from pg_temp.ids where name = 'request')) -> 'accounts',
  null::jsonb, 'she is no longer told where to transfer: she pays online'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select is(
  public.escrow_info((select id from pg_temp.ids where name = 'request')),
  null::jsonb, 'a stranger gets nothing'
);
select throws_ok(
  format($$select public.secure_payment(%L, 'instapay', 'nourhan@instapay', %L)$$,
    (select id from pg_temp.ids where name = 'request'), pg_temp.u('c2') || '/70000009-0000-4000-8000-000000000001.jpg'),
  'P0002', 'not_found', 'and can''t secure it'
);

-- Securing ------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  $$select public.secure_payment((select id from pg_temp.ids where name = 'request'), 'wallet', '123', pg_temp.proof(1))$$,
  '22023', 'invalid_sender', 'a wallet needs a mobile number'
);
select throws_ok(
  $$select public.secure_payment((select id from pg_temp.ids where name = 'request'), 'instapay', 'nourhan@instapay', 'nope.jpg')$$,
  '22023', 'invalid_screenshot', 'the screenshot has to be hers and uploaded'
);

insert into pg_temp.ids
select 'escrow', public.secure_payment(
  (select id from pg_temp.ids where name = 'request'), 'instapay', 'nourhan@instapay', pg_temp.proof(1)
);

select throws_ok(
  $$select public.secure_payment((select id from pg_temp.ids where name = 'request'), 'instapay', 'nourhan@instapay', pg_temp.proof(2))$$,
  'P0001', 'already_secured', 'a second one while the first is live is refused'
);
select is(
  public.escrow_info((select id from pg_temp.ids where name = 'request')) -> 'escrow' ->> 'status',
  'pending', 'she sees it waiting to be checked'
);
select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) ->> 'can_secure')::boolean,
  false, 'and can''t secure again'
);
select throws_ok(
  $$select public.confirm_work_done((select id from pg_temp.ids where name = 'request'))$$,
  'P0001', 'escrow_unavailable', 'nothing to confirm before the money is held'
);

reset role;
select is(
  (select (status, amount_piastres, request_code, technician_id = pg_temp.u('a1'))::text
     from public.job_escrows where id = (select id from pg_temp.ids where name = 'escrow')),
  '(pending,45000,' || private.request_code((select id from pg_temp.ids where name = 'request')) || ',t)',
  'the row copies the amount and the technician'
);

-- The technician sees only what is his ---------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select is(
  public.technician_escrow((select id from pg_temp.ids where name = 'request')) ->> 'status',
  'pending', 'the picked technician sees the payment'
);
select pg_temp.sign_in_as(pg_temp.u('a2'));
select is(
  public.technician_escrow((select id from pg_temp.ids where name = 'request')),
  null::jsonb, 'another technician sees nothing'
);
select throws_ok(
  $$select * from public.job_escrows$$, '42501', null, 'the table can''t be read directly'
);

-- The admin checks it ---------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
select throws_ok(
  $$select public.admin_list_escrows('pending', 10, 0)$$, '42501', 'admin_required',
  'the queue is for admins'
);

select pg_temp.sign_in_stale(pg_temp.u('ad'));
select throws_ok(
  $$select public.admin_approve_escrow((select id from pg_temp.ids where name = 'escrow'))$$,
  'P0001', 'recent_login_required', 'approving needs a recent login'
);

select pg_temp.sign_in_as(pg_temp.u('ad'));
select is(
  public.admin_list_escrows('pending', 10, 0) -> 'items' -> 0 ->> 'sender_account',
  'nourhan@instapay', 'the admin sees the transfer to check'
);
select is(
  (public.admin_list_escrows('pending', 10, 0) -> 'counts' ->> 'pending')::int,
  1, 'and how many wait'
);
select is(
  public.admin_approve_escrow((select id from pg_temp.ids where name = 'escrow')) ->> 'status',
  'held', 'he finds it and holds it'
);
select is(
  public.admin_approve_escrow((select id from pg_temp.ids where name = 'escrow')) ->> 'already_reviewed',
  'true', 'twice changes nothing'
);
select throws_ok(
  $$select public.admin_reject_escrow((select id from pg_temp.ids where name = 'escrow'), 'مش لاقيينه')$$,
  'P0001', 'not_pending', 'a held one can''t be rejected'
);

reset role;
select is(
  (select array_agg(user_id::text || ':' || kind::text order by user_id::text) from public.notifications
    where kind = 'escrow_held'),
  array[pg_temp.u('a1')::text || ':escrow_held', pg_temp.u('c1')::text || ':escrow_held'],
  'both are told'
);

-- Confirming ------------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) ->> 'can_confirm')::boolean,
  false, 'she can''t confirm before the work is finished'
);
select throws_ok(
  $$select public.confirm_work_done((select id from pg_temp.ids where name = 'request'))$$,
  'P0001', 'escrow_unavailable', 'and is refused if she tries'
);

reset role;
update public.jobs set status = 'finished', finished_at = now()
 where id = (select id from pg_temp.ids where name = 'job');
set local role authenticated;

select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) ->> 'can_confirm')::boolean,
  true, 'once it is finished she can'
);
select ok(
  (public.escrow_info((select id from pg_temp.ids where name = 'request')) -> 'escrow' ->> 'auto_release_at') is not null,
  'and is told when it releases by itself'
);

select pg_temp.sign_in_as(pg_temp.u('c2'));
select throws_ok(
  $$select public.confirm_work_done((select id from pg_temp.ids where name = 'request'))$$,
  'P0001', 'escrow_unavailable', 'a stranger can''t confirm'
);

-- The technician has no payout account: the release copies nothing, the admin is told.
select pg_temp.sign_in_as(pg_temp.u('c1'));
select lives_ok(
  $$select public.confirm_work_done((select id from pg_temp.ids where name = 'request'))$$,
  'she confirms the work'
);
select throws_ok(
  $$select public.confirm_work_done((select id from pg_temp.ids where name = 'request'))$$,
  'P0001', 'escrow_unavailable', 'once'
);
select throws_ok(
  $$select public.dispute_payment((select id from pg_temp.ids where name = 'request'), 'الشغل مش تمام')$$,
  'P0001', 'escrow_unavailable', 'and can''t dispute after'
);

reset role;
select is(
  (select status::text from public.job_escrows where id = (select id from pg_temp.ids where name = 'escrow')),
  'released', 'the money is the technician''s'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('a1') and kind = 'escrow_released'),
  1, 'he is told'
);

-- Paying him ---------------------------------------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('ad'));
set local role authenticated;
select throws_ok(
  $$select public.admin_mark_escrow_paid((select id from pg_temp.ids where name = 'escrow'), 'x')$$,
  '22023', 'invalid_reason', 'a payout needs a reference'
);
select is(
  public.admin_mark_escrow_paid((select id from pg_temp.ids where name = 'escrow'), 'IP-12345') ->> 'status',
  'paid_out', 'the admin marks it paid'
);
select is(
  public.admin_mark_escrow_paid((select id from pg_temp.ids where name = 'escrow'), 'IP-12345') ->> 'already_reviewed',
  'true', 'twice changes nothing'
);
reset role;
select is(
  (select count(*)::int from private.admin_audit_log
    where target_id = (select id::text from pg_temp.ids where name = 'escrow')
      and action in ('approve_escrow', 'pay_escrow')),
  2, 'the admin''s two steps are logged'
);
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('a1') and kind = 'escrow_paid_out'),
  1, 'and the technician is told he was paid'
);

-- A payout account, as the technician saves it --------------------------------------------------

select pg_temp.sign_in_as(pg_temp.u('a1'));
set local role authenticated;
select throws_ok(
  $$select public.save_payout_account('wallet', '123', 'محمود السيد')$$,
  '22023', 'invalid_account', 'a wallet number must be a mobile number'
);
select lives_ok(
  $$select public.save_payout_account('wallet', '٠١٠٢٣٤٥٦٧٨٩', 'محمود السيد')$$,
  'he saves where to be paid, Arabic digits and all'
);
select is(
  public.my_payout_account() ->> 'account', '01023456789', 'it is kept in Western digits'
);
select pg_temp.sign_in_as(pg_temp.u('a2'));
select is(public.my_payout_account(), null::jsonb, 'another technician has none');

-- Another job: a dispute settled for the technician, then for the consumer ----------------

reset role;
create function pg_temp.assigned_request(p_name text)
returns uuid
language plpgsql
as $$
declare
  v_request uuid := gen_random_uuid();
  v_job uuid := gen_random_uuid();
  v_offer uuid := gen_random_uuid();
begin
  insert into public.jobs (id, technician_id, customer_id, status, quote_status, source)
  values (v_job, pg_temp.u('a1'), pg_temp.u('d1'), 'confirmed', 'accepted', 'platform');
  insert into public.service_requests (
    id, consumer_id, category_id, issue, area_id, address_label, address_details,
    preferred_on, time_window, expires_at, status, job_id, urgent_fee_piastres
  )
  values (
    v_request, pg_temp.u('c1'), 'ac', 'not_cooling', 'nasr_city', 'البيت', 'عنوان',
    current_date + 1, 'noon', now() + interval '1 day', 'assigned', v_job, 0
  );
  insert into public.request_offers (id, request_id, technician_id, price_piastres, arrive_at, status)
  values (v_offer, v_request, pg_temp.u('a1'), 20000, now() + interval '1 day', 'accepted');
  update public.service_requests set chosen_offer_id = v_offer where id = v_request;
  insert into pg_temp.ids values (p_name, v_request), (p_name || '_job', v_job);
  return v_request;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated;
select pg_temp.assigned_request('second');
select pg_temp.assigned_request('third');

select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
insert into pg_temp.ids
select 'escrow2', public.secure_payment((select id from pg_temp.ids where name = 'second'), 'instapay', 'nourhan@instapay', pg_temp.proof(2));
insert into pg_temp.ids
select 'escrow3', public.secure_payment((select id from pg_temp.ids where name = 'third'), 'wallet', '01012345678', pg_temp.proof(3));

select pg_temp.sign_in_as(pg_temp.u('ad'));
select public.admin_approve_escrow((select id from pg_temp.ids where name = 'escrow2'));
select throws_ok(
  $$select public.admin_reject_escrow((select id from pg_temp.ids where name = 'escrow3'), 'x')$$,
  '22023', 'invalid_reason', 'a rejection needs a reason'
);
select is(
  public.admin_reject_escrow((select id from pg_temp.ids where name = 'escrow3'), 'التحويل مش ظاهر عندنا') ->> 'status',
  'rejected', 'a transfer we can''t find is rejected'
);

select pg_temp.sign_in_as(pg_temp.u('c1'));
select is(
  public.escrow_info((select id from pg_temp.ids where name = 'third')) -> 'escrow' ->> 'reject_reason',
  'التحويل مش ظاهر عندنا', 'she reads why'
);
select is(
  (public.escrow_info((select id from pg_temp.ids where name = 'third')) ->> 'can_secure')::boolean,
  true, 'and can send another'
);
select lives_ok(
  format($$select public.secure_payment(%L, 'wallet', '01012345678', %L)$$,
    (select id from pg_temp.ids where name = 'third'), pg_temp.proof(4)),
  'she sends another screenshot'
);

-- She disputes the second job.
select throws_ok(
  $$select public.dispute_payment((select id from pg_temp.ids where name = 'second'), 'ab')$$,
  '22023', 'invalid_reason', 'a complaint needs words'
);
select lives_ok(
  $$select public.dispute_payment((select id from pg_temp.ids where name = 'second'), 'الفني مجاش')$$,
  'she disputes the payment'
);
reset role;
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('a1') and kind = 'escrow_disputed'),
  1, 'the technician is told'
);

select pg_temp.sign_in_as(pg_temp.u('ad'));
set local role authenticated;
select throws_ok(
  $$select public.admin_resolve_escrow((select id from pg_temp.ids where name = 'escrow'), true, 'تمام')$$,
  'P0001', 'not_disputed', 'only a dispute is resolved'
);
select is(
  public.admin_resolve_escrow((select id from pg_temp.ids where name = 'escrow2'), false, 'الفني ماجاش فعلا') ->> 'status',
  'refund_due', 'the admin sides with her'
);
select throws_ok(
  $$select public.admin_mark_escrow_refunded((select id from pg_temp.ids where name = 'escrow'), 'RF-1')$$,
  'P0001', 'not_refund_due', 'only a refund due is refunded'
);
select is(
  public.admin_mark_escrow_refunded((select id from pg_temp.ids where name = 'escrow2'), 'RF-22') ->> 'status',
  'refunded', 'and returns the money'
);
reset role;
select is(
  (select count(*)::int from public.notifications
    where user_id = pg_temp.u('c1') and kind = 'escrow_refunded'),
  1, 'she is told'
);

-- A cancelled job returns the money; the third is still waiting for a check.
update public.jobs set status = 'cancelled' where id = (select id from pg_temp.ids where name = 'third_job');
select is(
  (select status::text from public.job_escrows where id = (
     select id from public.job_escrows
      where request_id = (select id from pg_temp.ids where name = 'third') and status <> 'rejected')),
  'refund_due', 'a cancelled job leaves the money to be returned, even before it was checked'
);

-- Nobody answers: the money goes to the technician 72 hours after the work.
select pg_temp.assigned_request('fourth');
insert into storage.objects (bucket_id, name, owner_id)
values ('transfer-proofs', pg_temp.u('c1') || '/70000005-0000-4000-8000-000000000001.jpg', pg_temp.u('c1')::text);
select pg_temp.sign_in_as(pg_temp.u('c1'));
set local role authenticated;
insert into pg_temp.ids
select 'escrow4', public.secure_payment((select id from pg_temp.ids where name = 'fourth'), 'instapay', 'nourhan@instapay', pg_temp.proof(5));
reset role;
update public.job_escrows set status = 'held', held_at = now() where id = (select id from pg_temp.ids where name = 'escrow4');
update public.jobs set status = 'finished', finished_at = now() - interval '71 hours'
 where id = (select id from pg_temp.ids where name = 'fourth_job');
select is(private.release_due_escrows(), 0, 'seventy-one hours is too early');
update public.jobs set finished_at = now() - interval '73 hours'
 where id = (select id from pg_temp.ids where name = 'fourth_job');
select is(private.release_due_escrows(), 1, 'seventy-three hours is not');
select is(
  (select (status, payout_account is null)::text from public.job_escrows
    where id = (select id from pg_temp.ids where name = 'escrow4')),
  '(released,f)', 'and the payout account is copied for the admin'
);

select * from finish();
rollback;
