begin;
create extension if not exists pgtap with schema extensions;

select plan(26);

-- Consumer C (2 uses), technician A (2 uses), consumer D, who sees nothing of theirs.
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', '201009990032', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c2', '+201009990032', 'حسام علي', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 2),
  ('00000000-0000-4000-8000-0000000000c2', 'mr', 'nasr_city', 2);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 2, 'approved');

insert into storage.objects (bucket_id, name, owner_id) values
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000003.jpg', '00000000-0000-4000-8000-0000000000c1'),
  ('transfer-proofs', '00000000-0000-4000-8000-0000000000a1/60000000-0000-4000-8000-000000000004.jpg', '00000000-0000-4000-8000-0000000000a1');

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

create function pg_temp.pack(p_role public.user_role, p_uses integer)
returns uuid
language sql
as $$
  select id from public.credit_packs where role = p_role and uses = p_uses;
$$;

create function pg_temp.submit(p_pack uuid, p_method public.topup_method, p_sender text, p_path text)
returns uuid
language sql
as $$
  select public.submit_topup(p_pack, p_method, p_sender, p_path,
    (select price_piastres from public.credit_packs where id = p_pack));
$$;

grant execute on all functions in schema pg_temp to authenticated;

-- Packs and accounts: seen by anyone signed in.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select is((select count(*)::int from public.credit_packs), 4, 'the packs on sale are visible');
select is((select count(*)::int from public.payment_accounts), 2, 'the transfer accounts are visible');
select throws_ok(
  $$update public.credit_packs set price_piastres = 1$$,
  '42501', null, 'nobody changes a price from the app'
);

-- Submitting.
select lives_ok(
  $$select pg_temp.submit(
    pg_temp.pack('consumer', 5), 'wallet', '٠١١١ ٤٥٦ ٧٧٢٠',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg')$$,
  'a consumer submits a transfer'
);
select is(
  (select sender_account || ':' || amount_piastres || ':' || uses from public.credit_topups),
  '01114567720:8000:5',
  'the sender is normalised and the pack price is copied'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('technician', 1), 'wallet', '01114567720',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg')$$,
  'P0002', 'pack_not_found', 'a consumer cannot buy a technician pack'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'wallet', '12345',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg')$$,
  '22023', 'invalid_sender', 'a wallet sender must be a mobile number'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'x',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg')$$,
  '22023', 'invalid_sender', 'an InstaPay sender must be at least 3 characters'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000001.jpg')$$,
  '22023', 'invalid_screenshot', 'one screenshot cannot back two transfers'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000a1/60000000-0000-4000-8000-000000000004.jpg')$$,
  '22023', 'invalid_screenshot', 'someone else''s screenshot is refused'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-0000000000ff.jpg')$$,
  '22023', 'invalid_screenshot', 'a screenshot that was never uploaded is refused'
);
select lives_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000002.jpg')$$,
  'a second waiting transfer is allowed'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000003.jpg')$$,
  'P0001', 'too_many_pending', 'a third waiting transfer is refused'
);
select throws_ok(
  $$insert into public.credit_topups (user_id, role, pack_id, uses, amount_piastres, method, sender_account, screenshot_path)
    select user_id, role, pack_id, uses, amount_piastres, method, sender_account, 'x' from public.credit_topups limit 1$$,
  '42501', null, 'a transfer cannot be written around the function'
);

select throws_ok(
  $$select public.submit_topup(pg_temp.pack('consumer', 1), 'instapay', 'nour@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000003.jpg', 1)$$,
  'P0001', 'price_changed', 'a price that moved since it was shown is refused'
);
select throws_ok(
  $$select pg_temp.submit(pg_temp.pack('consumer', 1), 'instapay', U&'nour\202Ex@instapay',
    '00000000-0000-4000-8000-0000000000c1/60000000-0000-4000-8000-000000000003.jpg')$$,
  '22023', 'invalid_sender', 'direction marks in an InstaPay address are refused'
);

-- Privacy.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c2');
select is((select count(*)::int from public.credit_topups), 0, 'another consumer sees none of someone else''s transfers');
select is(
  (select count(*)::int from public.credit_ledger where user_id <> '00000000-0000-4000-8000-0000000000c2'),
  0, 'nor their ledger'
);

-- Technician pack for a technician, and the API can't approve.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select lives_ok(
  $$select pg_temp.submit(pg_temp.pack('technician', 10), 'instapay', 'mahmoud@instapay',
    '00000000-0000-4000-8000-0000000000a1/60000000-0000-4000-8000-000000000004.jpg')$$,
  'a technician buys a technician pack'
);
select throws_ok(
  $$select private.approve_topup((select id from public.credit_topups limit 1))$$,
  '42501', null, 'the API roles cannot approve a transfer'
);

-- The review, as the service role.
reset role;
select private.approve_topup((select id from public.credit_topups where uses = 5));
select is(
  (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c1'),
  7, 'approving adds the pack to the balance'
);
select throws_ok(
  $$select private.approve_topup((select id from public.credit_topups where uses = 5))$$,
  'P0001', 'not_pending', 'a transfer is approved once'
);
select is(
  (select count(*)::int from public.credit_ledger where reason = 'topup' and delta = 5),
  1, 'the approval is in the ledger'
);
select private.reject_topup((select id from public.credit_topups where uses = 1 and role = 'consumer'), 'الصورة مش واضحة');
select is(
  (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c1'),
  7, 'a rejection adds nothing'
);

select is(
  (select sum(delta)::int from public.credit_ledger where user_id = '00000000-0000-4000-8000-0000000000c1'),
  7,
  'the ledger adds up to the balance: the free grant and the approved pack'
);
select is(
  (select count(*)::int from public.credit_ledger where reason = 'free_grant'),
  3, 'every new profile gets its free grant written down'
);

select * from finish();
rollback;
