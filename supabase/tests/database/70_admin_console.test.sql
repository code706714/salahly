begin;
create extension if not exists pgtap with schema extensions;

select plan(103);

-- Admin AD; consumers C1 (has 2 uses) and C2; technicians T1 (verified),
-- T2 and T3 (waiting for verification).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000ad', '201009990001', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', '201009990032', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', '201009990042', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', '201009990043', 'authenticated', 'authenticated');

insert into private.admins (user_id, note)
values ('00000000-0000-4000-8000-0000000000ad', 'test admin');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c2', '+201009990032', 'حسام علي', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a2', '+201009990042', 'ياسر عبد الحميد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a3', '+201009990043', 'سامح حسن', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 2),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 2);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'pending'),
  ('00000000-0000-4000-8000-0000000000a3', 8, 'x', 'maadi', 29.96, 31.257, 10, '{1,2,3}', 2, 'pending');

insert into public.technician_areas (technician_id, area_id)
values ('00000000-0000-4000-8000-0000000000a2', 'nasr_city'), ('00000000-0000-4000-8000-0000000000a2', 'heliopolis');
insert into public.technician_services (technician_id, service_id, starting_price_piastres)
values ('00000000-0000-4000-8000-0000000000a2', 'ac_inspection', 15000);

insert into public.technician_verifications (id, technician_id, id_front_path, id_back_path, selfie_path, status, created_at)
values
  ('b0000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000a2',
   '00000000-0000-4000-8000-0000000000a2/70000000-0000-4000-8000-000000000001.jpg',
   '00000000-0000-4000-8000-0000000000a2/70000000-0000-4000-8000-000000000002.jpg',
   '00000000-0000-4000-8000-0000000000a2/70000000-0000-4000-8000-000000000003.jpg',
   'pending', now() - interval '2 days'),
  ('b0000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-0000000000a3', 'f', 'b', 's', 'pending', now() - interval '1 hour');

insert into storage.objects (bucket_id, name, owner_id) values
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000a1/60000000-0000-4000-8000-000000000003.jpg', '00000000-0000-4000-8000-0000000000a1'),
  ('verification-docs', '00000000-0000-4000-8000-0000000000a2/70000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000a2'),
  ('job-photos', '00000000-0000-4000-8000-0000000000a1/80000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000a1');

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

-- A session whose token was issued (and whose login happened) an hour ago.
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

create function pg_temp.pack(p_role public.user_role, p_uses integer)
returns uuid
language sql
as $$
  select id from public.credit_packs where role = p_role and uses = p_uses;
$$;

create function pg_temp.topup_id(p_role public.user_role, p_uses integer)
returns uuid
language sql
security definer
as $$
  select id from public.credit_topups where role = p_role and uses = p_uses;
$$;

create function pg_temp.submit(p_pack uuid, p_method public.topup_method, p_sender text, p_path text)
returns uuid
language sql
as $$
  select public.submit_topup(p_pack, p_method, p_sender, p_path,
    (select price_piastres from public.credit_packs where id = p_pack));
$$;

-- Every admin function once, with arguments that would be valid for an
-- admin. Returns the calls that were NOT refused with 42501 (so: empty
-- when the caller is denied everywhere).
create function pg_temp.not_denied(p_hostile boolean default false)
returns setof text
language plpgsql
as $$
declare
  c text;
  v_path text := current_setting('search_path');
  calls text[] := array[
    $q$select public.admin_overview('week')$q$,
    $q$select public.admin_list_areas('month', 10, 0)$q$,
    $q$select public.admin_list_verifications('pending', 10, 0)$q$,
    $q$select public.admin_get_verification('b0000000-0000-4000-8000-000000000002')$q$,
    $q$select public.admin_approve_verification('b0000000-0000-4000-8000-000000000003')$q$,
    $q$select public.admin_reject_verification('b0000000-0000-4000-8000-000000000003', 'صورة مش واضحة')$q$,
    $q$select public.admin_list_topups('pending', null, 10, 0)$q$,
    $q$select public.admin_approve_topup(gen_random_uuid())$q$,
    $q$select public.admin_reject_topup(gen_random_uuid(), 'مالقيناش التحويل')$q$,
    $q$select public.admin_list_requests(null, null, null, 7, 10, 0)$q$,
    $q$select public.admin_list_complaints('open', 10, 0)$q$,
    $q$select public.admin_resolve_complaint(gen_random_uuid(), 'اتحلت بالتليفون')$q$,
    $q$select public.admin_list_users('technician', null, null, null, 10, 0)$q$,
    $q$select public.admin_suspend_user('00000000-0000-4000-8000-0000000000a1', 'شكاوي متكررة')$q$,
    $q$select public.admin_restore_user('00000000-0000-4000-8000-0000000000a1')$q$,
    $q$select public.admin_get_settings()$q$,
    $q$select public.admin_update_settings(3::smallint, 3::smallint, 100)$q$,
    $q$select public.admin_save_credit_pack(null, 'consumer', 3, 5000, true, 3)$q$,
    $q$select public.admin_update_payment_account('wallet', '01011112222', 'اسم الشركة', true)$q$,
    $q$select public.admin_save_service_area('test_area', 'منطقة تجريبية', 'القاهرة', 30.0, 31.0, true, null)$q$,
    $q$select public.admin_set_area_open('nasr_city', false)$q$,
    $q$select public.admin_list_audit_log(null, null, 10, 0)$q$
  ];
begin
  if p_hostile then
    perform set_config('search_path', 'pg_temp, public', true);
  end if;
  foreach c in array calls loop
    begin
      execute c;
      return next c;
    exception
      when insufficient_privilege then null;
      when others then return next c || ' => ' || sqlerrm;
    end;
  end loop;
  perform set_config('search_path', v_path, true);
end;
$$;

grant execute on all functions in schema pg_temp to authenticated, anon;

-- Catalog -------------------------------------------------------------------

select is_empty(
  $$select p.oid::regprocedure::text
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname like 'admin\_%'
       and (has_function_privilege('anon', p.oid, 'execute')
            or not has_function_privilege('authenticated', p.oid, 'execute')
            or not p.prosecdef
            or p.proconfig is null
            or not exists (select 1 from unnest(p.proconfig) c where c = 'search_path=""'))$$,
  'every admin function is definer, pins an empty search_path, and is closed to anon'
);
select is(
  (select count(*)::int from pg_proc where pronamespace = 'public'::regnamespace and proname like 'admin\_%'),
  22,
  'there are 22 admin functions (update the lists in this file when adding one)'
);
select ok(
  not has_table_privilege('authenticated', 'private.admins', 'select')
  and not has_table_privilege('authenticated', 'private.admins', 'insert')
  and not has_table_privilege('authenticated', 'private.admin_audit_log', 'select')
  and not has_table_privilege('authenticated', 'private.admin_audit_log', 'insert')
  and not has_schema_privilege('authenticated', 'private', 'usage'),
  'the API roles can not read or write the admin tables'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'private.admins'::regclass)
  and (select relrowsecurity from pg_class where oid = 'private.admin_audit_log'::regclass)
  and (select relrowsecurity from pg_class where oid = 'private.suspensions'::regclass),
  'row level security is on for the admin tables'
);
select is_empty(
  $$select p.oid::regprocedure::text
      from pg_proc p
     where p.pronamespace = 'private'::regnamespace
       and (has_function_privilege('authenticated', p.oid, 'execute')
            or has_function_privilege('anon', p.oid, 'execute'))$$,
  'no private function (helpers, moved originals) is callable from the API'
);
select ok(
  not has_function_privilege('anon', 'guard.is_admin()', 'execute')
  and has_function_privilege('authenticated', 'guard.is_admin()', 'execute'),
  'guard.is_admin is for signed-in users only'
);

-- Anonymous -----------------------------------------------------------------

set local role anon;
select is_empty($$select * from pg_temp.not_denied()$$, 'anonymous is refused on every admin function');
select throws_ok($$select guard.is_admin()$$, '42501', null, 'anonymous cannot even ask guard.is_admin');
select throws_ok($$select * from private.admins$$, '42501', null, 'anonymous cannot read the admin list');
reset role;

-- Signed in, not an admin ------------------------------------------------------

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select is_empty($$select * from pg_temp.not_denied()$$, 'a consumer is refused on every admin function');
select throws_ok($$select public.admin_overview()$$, '42501', 'admin_required', 'the refusal says admin_required');
select ok(not guard.is_admin(), 'a consumer is not an admin');
select throws_ok(
  $$insert into private.admins (user_id) values ('00000000-0000-4000-8000-0000000000c1')$$,
  '42501', null, 'a user can not make themselves an admin'
);
select throws_ok(
  $$select * from private.admin_audit_log$$, '42501', null, 'nobody reads the audit log directly'
);
-- A search_path of their choosing changes nothing.
select is_empty($$select * from pg_temp.not_denied(true)$$, 'a hostile search_path does not open the admin functions');
reset role;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select is_empty($$select * from pg_temp.not_denied()$$, 'a technician is refused on every admin function');
reset role;

-- An admin signed in with someone else's id claim is still just that person.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
select ok(not guard.is_admin(), 'the check follows the signed-in id');
reset role;

-- Admin ------------------------------------------------------------------------

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select ok(guard.is_admin(), 'the admin is recognised');

select is(
  (select public.admin_overview('week') -> 'verified_technicians'),
  '1'::jsonb, 'overview counts verified technicians'
);
select is(
  (select public.admin_overview('week') #>> '{pending_verifications,count}'),
  '2', 'overview counts pending verifications'
);
select is(
  (select public.admin_overview('week') ->> 'verified_technician_target'),
  '100', 'overview has the target'
);
select throws_ok($$select public.admin_overview('year')$$, '22023', 'invalid_period', 'an unknown period is refused');

-- Verification queue ------------------------------------------------------------

select is(
  (select public.admin_list_verifications('pending', 50, 0) ->> 'total'),
  '2', 'two submissions are waiting'
);
select is(
  (select public.admin_list_verifications('pending', 50, 0) #>> '{items,0,technician_id}'),
  '00000000-0000-4000-8000-0000000000a2',
  'the oldest waits first'
);
select is(
  (select jsonb_array_length(public.admin_list_verifications('pending', 1, 0) -> 'items')),
  1, 'the page size is honoured'
);
select is(
  (select jsonb_array_length(public.admin_list_verifications('pending', 100000, 0) -> 'items')),
  2, 'a huge limit is capped, not refused'
);
select is(
  (select public.admin_get_verification('b0000000-0000-4000-8000-000000000002') ->> 'id_front_path'),
  '00000000-0000-4000-8000-0000000000a2/70000000-0000-4000-8000-000000000001.jpg',
  'the reviewer gets the photo paths'
);
select is(
  (select public.admin_get_verification('b0000000-0000-4000-8000-000000000002') #>> '{areas,1,id}'),
  'heliopolis', 'and the areas the technician works in'
);
select throws_ok(
  $$select public.admin_get_verification(gen_random_uuid())$$,
  'P0002', 'verification_not_found', 'an unknown submission is refused'
);
reset role;
select is(
  (select count(*)::int from private.admin_audit_log where action = 'view_verification'),
  2, 'looking at ID photos is audited'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select throws_ok(
  $$select public.admin_reject_verification('b0000000-0000-4000-8000-000000000002', 'x')$$,
  '22023', 'invalid_reason', 'a rejection needs a real reason'
);
select throws_ok(
  $$select public.admin_reject_verification('b0000000-0000-4000-8000-000000000002', repeat('ا', 201))$$,
  '22023', 'invalid_reason', 'and not a novel'
);
select is(
  (select public.admin_reject_verification('b0000000-0000-4000-8000-000000000002', 'صورة البطاقة مش واضحة') ->> 'already_reviewed'),
  'false', 'the admin rejects a submission'
);
select is(
  (select public.admin_reject_verification('b0000000-0000-4000-8000-000000000002', 'صورة البطاقة مش واضحة') ->> 'already_reviewed'),
  'true', 'rejecting twice changes nothing'
);
select throws_ok(
  $$select public.admin_approve_verification('b0000000-0000-4000-8000-000000000002')$$,
  'P0001', 'not_pending', 'a rejected submission can not be approved'
);
select is(
  (select public.admin_approve_verification('b0000000-0000-4000-8000-000000000003') ->> 'status'),
  'approved', 'the admin approves the other one'
);
select is(
  (select public.admin_approve_verification('b0000000-0000-4000-8000-000000000003') ->> 'already_reviewed'),
  'true', 'approving twice changes nothing'
);
reset role;
select is(
  (select array_agg(verification_status::text order by id)
     from public.technician_profiles where id in (
       '00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000a3')),
  array['rejected', 'approved'], 'the technicians'' status followed'
);
select is(
  (select array_agg(kind::text order by user_id)
     from public.notifications where kind in ('verification_approved', 'verification_rejected')),
  array['verification_rejected', 'verification_approved'],
  'each technician was told (once)'
);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
set local role authenticated;
select is(
  (select rejection_reason from public.technician_verifications),
  'صورة البطاقة مش واضحة', 'the technician can read why'
);
reset role;

-- Transfers ------------------------------------------------------------------------

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select pg_temp.submit(
  pg_temp.pack('consumer', 5), 'wallet', '01114567720',
  '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg');
select pg_temp.submit(
  pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
  '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg');
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select pg_temp.submit(
  pg_temp.pack('technician', 10), 'instapay', 'mahmoud@instapay',
  '00000000-0000-4000-8000-0000000000a1/60000000-0000-4000-8000-000000000003.jpg');
reset role;

update public.credit_topups set created_at = now() - interval '3 hours' where role = 'consumer' and uses = 5;
update public.credit_topups set created_at = now() - interval '2 hours' where role = 'consumer' and uses = 1;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select is(
  (select public.admin_list_topups('pending', null, 50, 0) ->> 'total'), '3', 'three transfers wait'
);
select is(
  (select public.admin_list_topups('pending', 'technician', 50, 0) #>> '{items,0,amount_piastres}'),
  '25000', 'the technician filter works and money is in piastres'
);
select is(
  (select public.admin_list_topups('pending', 'consumer', 50, 0) #>> '{items,0,screenshot_path}'),
  '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg',
  'the list gives the screenshot path, oldest first'
);
select is(
  (select public.admin_list_topups('pending', 'consumer', 50, 0) #>> '{items,0,account_phone}'),
  '01009990031', 'and the phone of the account to compare the sender with'
);
select is(
  (select (public.admin_list_topups(null, null, 50, 0) -> 'items' -> 0) ? 'phone'),
  false, 'a transfer row carries no raw phone field'
);

-- The money moves only after a recent login.
select pg_temp.sign_in_stale('00000000-0000-4000-8000-0000000000ad');
select throws_ok(
  $$select public.admin_approve_topup(pg_temp.topup_id('consumer', 5))$$,
  'P0001', 'recent_login_required', 'approving needs a recent login'
);
select throws_ok(
  $$select public.admin_reject_topup(pg_temp.topup_id('consumer', 1), 'مالقيناش التحويل')$$,
  'P0001', 'recent_login_required', 'so does rejecting'
);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
select throws_ok(
  $$select public.admin_approve_topup(gen_random_uuid())$$, 'P0002', 'topup_not_found', 'an unknown transfer is refused'
);
select is(
  (select public.admin_approve_topup(pg_temp.topup_id('consumer', 5)) ->> 'balance'),
  '7', 'approving adds the uses and says the new balance'
);
select is(
  (select public.admin_approve_topup(pg_temp.topup_id('consumer', 5)) ->> 'already_reviewed'),
  'true', 'approving twice changes nothing'
);
select throws_ok(
  $$select public.admin_reject_topup(pg_temp.topup_id('consumer', 5), 'مالقيناش التحويل')$$,
  'P0001', 'not_pending', 'an approved transfer can not be rejected'
);
select throws_ok(
  $$select public.admin_reject_topup(pg_temp.topup_id('consumer', 1), 'ab')$$,
  '22023', 'invalid_reason', 'a rejection needs a reason'
);
select is(
  (select public.admin_reject_topup(pg_temp.topup_id('consumer', 1), 'المبلغ مش مظبوط') ->> 'status'),
  'rejected', 'the admin rejects a transfer'
);
select is(
  (select public.admin_reject_topup(pg_temp.topup_id('consumer', 1), 'المبلغ مش مظبوط') ->> 'already_reviewed'),
  'true', 'rejecting twice changes nothing'
);
select throws_ok(
  $$select public.admin_approve_topup(pg_temp.topup_id('consumer', 1))$$,
  'P0001', 'not_pending', 'a rejected transfer can not be approved afterwards'
);
select is(
  (select public.admin_approve_topup(pg_temp.topup_id('technician', 10)) ->> 'balance'),
  '12', 'a technician transfer adds job uses'
);
reset role;

select is(
  (select array_agg(delta || ':' || reason order by id)
     from public.credit_ledger where reason = 'topup'),
  array['5:topup', '10:topup'], 'the ledger has exactly one entry per approved transfer'
);
select is(
  (select sum(delta)::int from public.credit_ledger where user_id = '00000000-0000-4000-8000-0000000000c1'),
  (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c1'),
  'and the consumer''s ledger adds up to the balance'
);
select is(
  (select reject_reason from public.credit_topups where role = 'consumer' and uses = 1),
  'المبلغ مش مظبوط', 'the rejection reason is stored for the person'
);
select is(
  (select array_agg(kind::text order by kind) from public.notifications where kind in ('topup_approved', 'topup_rejected')),
  array['topup_approved', 'topup_approved', 'topup_rejected'], 'people are told once per review'
);

-- Settings ----------------------------------------------------------------------------

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select is(
  (select jsonb_array_length(public.admin_get_settings() -> 'packs')), 4, 'settings list the packs'
);
select is(
  (select jsonb_array_length(public.admin_get_settings() -> 'payment_accounts')), 2, 'and both payment accounts'
);

select pg_temp.sign_in_stale('00000000-0000-4000-8000-0000000000ad');
select throws_ok(
  $$select public.admin_update_settings(3::smallint, null, null)$$,
  'P0001', 'recent_login_required', 'free uses need a recent login'
);
select throws_ok(
  $$select public.admin_save_credit_pack(null, 'consumer', 3, 5000)$$,
  'P0001', 'recent_login_required', 'prices need a recent login'
);
select throws_ok(
  $$select public.admin_update_payment_account('wallet', '01011112222', 'اسم الشركة')$$,
  'P0001', 'recent_login_required', 'and so do the payment accounts'
);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
select throws_ok(
  $$select public.admin_update_settings(21::smallint, null, null)$$, '22023', 'invalid_value', 'free uses are capped at 20'
);
select throws_ok(
  $$select public.admin_update_settings(null, null, null)$$, '22023', 'nothing_to_update', 'an empty update is refused'
);
select is(
  (select public.admin_update_settings(3::smallint, null, null) ->> 'consumer_free_requests'),
  '3', 'free uses change'
);
select is(
  (select public.admin_get_settings() ->> 'technician_free_jobs'), '2', 'and what was not sent stays'
);
select throws_ok(
  $$select public.admin_save_credit_pack(null, 'consumer', 5, 9000)$$,
  '23505', 'duplicate_pack', 'two packs on sale can not have the same size'
);
select throws_ok(
  $$select public.admin_save_credit_pack(null, 'consumer', 3, 50)$$,
  '22023', 'invalid_value', 'a price under 1 EGP is refused'
);
select throws_ok(
  $$select public.admin_save_credit_pack(null, 'consumer', 0, 5000)$$,
  '22023', 'invalid_value', 'a pack of nothing is refused'
);
select is(
  (select public.admin_save_credit_pack(null, 'consumer', 3, 5500, true, 3) ->> 'price_piastres'),
  '5500', 'a pack is added'
);
select is(
  (select public.admin_save_credit_pack(pg_temp.pack('consumer', 5), 'consumer', 5, 9000, true, 2) ->> 'price_piastres'),
  '9000', 'a price changes'
);
select throws_ok(
  $$select public.admin_save_credit_pack(gen_random_uuid(), 'consumer', 7, 9000)$$,
  'P0002', 'pack_not_found', 'an unknown pack is refused'
);
select is(
  (select public.admin_save_credit_pack(pg_temp.pack('technician', 1), 'technician', 1, 3000, false, 1) ->> 'is_active'),
  'false', 'a pack can be switched off while another is on'
);
select throws_ok(
  $$select public.admin_save_credit_pack(pg_temp.pack('technician', 10), 'technician', 10, 25000, false, 2)$$,
  'P0001', 'last_active_pack', 'the last pack on sale for a role can not be switched off'
);
select throws_ok(
  $$select public.admin_update_payment_account('wallet', '12345', 'اسم الشركة')$$,
  '22023', 'invalid_value', 'a wallet must be a mobile number'
);
select throws_ok(
  $$select public.admin_update_payment_account('instapay', 'a b', 'اسم الشركة')$$,
  '22023', 'invalid_value', 'an InstaPay address must be plain characters'
);
select is(
  (select public.admin_update_payment_account('wallet', '٠١٠١١١١٢٢٢٢', 'شركة صلحلي') ->> 'account'),
  '01011112222', 'a wallet number is normalised'
);
select is(
  (select public.admin_update_payment_account('instapay', 'set-me@instapay', 'اسم الشركة', false) ->> 'is_active'),
  'false', 'one account can be switched off'
);
select throws_ok(
  $$select public.admin_update_payment_account('wallet', '01011112222', 'شركة صلحلي', false)$$,
  'P0001', 'last_active_account', 'but not both'
);
select is(
  (select public.admin_save_service_area('test_area', 'منطقة تجريبية', 'القاهرة', 30.0, 31.0, true, null) ->> 'sort_order'),
  '34', 'an area is added last'
);
select throws_ok(
  $$select public.admin_save_service_area('Bad Id', 'منطقة', 'القاهرة', 30.0, 31.0)$$,
  '22023', 'invalid_value', 'an area id must be a plain slug'
);
select throws_ok(
  $$select public.admin_save_service_area('far_away', 'منطقة بعيدة', 'القاهرة', 10.0, 31.0)$$,
  '22023', 'invalid_value', 'an area outside Egypt is refused'
);
select throws_ok(
  $$select public.admin_save_service_area('twin', 'منطقة تجريبية', 'القاهرة', 30.0, 31.0)$$,
  '23505', 'duplicate_area', 'two areas can not share a name'
);
select is(
  (select public.admin_set_area_open('test_area', false) ->> 'is_open'), 'false', 'an area is closed'
);
select throws_ok(
  $$select public.admin_set_area_open('nowhere', true)$$, 'P0002', 'area_not_found', 'an unknown area is refused'
);
select is(
  (select public.admin_list_areas('month', 100, 0) #>> '{items,0,verified_technicians}'),
  '1', 'coverage counts the verified technicians of an area (T2 was rejected)'
);
reset role;

-- Audit log -------------------------------------------------------------------------------

select is(
  (select count(*)::int from private.admin_audit_log
    where admin_id = '00000000-0000-4000-8000-0000000000ad'),
  (select count(*)::int from private.admin_audit_log),
  'every row says who did it'
);
select is(
  (select array_agg(distinct action order by action) filter (where action like '%topup')
     from private.admin_audit_log),
  array['approve_topup', 'reject_topup'], 'transfers are audited'
);
select is(
  (select details ->> 'reason' from private.admin_audit_log where action = 'reject_topup'),
  'المبلغ مش مظبوط', 'with the reason'
);
select is(
  (select count(*)::int from private.admin_audit_log where action = 'approve_topup'),
  2, 'one entry per real approval, none for the repeated call'
);
select is(
  (select details -> 'after' ->> 'price_piastres' from private.admin_audit_log
    where action = 'update_credit_pack' and details -> 'after' ->> 'uses' = '5'),
  '9000', 'price changes record before and after'
);
select throws_ok(
  $$update private.admin_audit_log set action = 'x'$$, '42501', 'audit_log_is_append_only', 'the log can not be edited'
);
select throws_ok(
  $$delete from private.admin_audit_log$$, '42501', 'audit_log_is_append_only', 'nor emptied row by row'
);
select throws_ok(
  $$truncate private.admin_audit_log$$, '42501', 'audit_log_is_append_only', 'nor truncated'
);
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select ok(
  (select jsonb_array_length(public.admin_list_audit_log('approve_topup', null, 50, 0) -> 'items')) = 2,
  'an admin reads the log through the function'
);
select is(
  (select jsonb_array_length(public.admin_list_audit_log(null, null, 3, 0) -> 'items')), 3, 'and it is paged'
);

-- Files -------------------------------------------------------------------------------------

select is(
  (select count(*)::int from storage.objects where bucket_id = 'transfer-proofs'),
  3, 'an admin sees the transfer screenshots'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'verification-docs'),
  1, 'and the ID documents'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'job-photos'),
  0, 'but not the technicians'' job photos'
);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
set local role authenticated;
select is(
  (select count(*)::int from storage.objects where bucket_id in ('transfer-proofs', 'verification-docs')),
  0, 'anyone else sees none of them'
);
reset role;

select * from finish();
rollback;
