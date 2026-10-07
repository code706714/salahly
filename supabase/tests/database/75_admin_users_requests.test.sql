begin;
create extension if not exists pgtap with schema extensions;

select plan(93);

-- Admins AD and AD2. Consumers C1 (has requests, an address and a complaint),
-- C3 (suspended, then deletes the account) and C4 (suspended while a request
-- is open). Technicians T1 (offers, suspended later) and T2 (the control).
insert into auth.users (id, phone, aud, role)
values
  ('00000000-0000-4000-8000-0000000000ad', '201009990001', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000ae', '201009990002', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c1', '201009990031', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c3', '201009990033', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c4', '201009990034', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a1', '201009990041', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', '201009990042', 'authenticated', 'authenticated');

insert into private.admins (user_id)
values ('00000000-0000-4000-8000-0000000000ad'), ('00000000-0000-4000-8000-0000000000ae');

insert into public.profiles (id, phone, full_name, active_role)
values
  ('00000000-0000-4000-8000-0000000000c1', '+201009990031', 'نورهان مصطفى', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c3', '+201009990033', 'عمر طارق', 'consumer'),
  ('00000000-0000-4000-8000-0000000000c4', '+201009990034', 'منى كريم', 'consumer'),
  ('00000000-0000-4000-8000-0000000000a1', '+201009990041', 'محمود السيد', 'technician'),
  ('00000000-0000-4000-8000-0000000000a2', '+201009990042', 'ياسر عبد الحميد', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values
  ('00000000-0000-4000-8000-0000000000c1', 'ms', 'nasr_city', 3),
  ('00000000-0000-4000-8000-0000000000c3', 'mr', 'nasr_city', 2),
  ('00000000-0000-4000-8000-0000000000c4', 'ms', 'maadi', 2);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values
  ('00000000-0000-4000-8000-0000000000a1', 12, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 3, 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 5, 'x', 'nasr_city', 30.056, 31.33, 10, '{1,2,3,4,5,6,7}', 3, 'approved');

insert into public.technician_services (technician_id, service_id, starting_price_piastres)
values
  ('00000000-0000-4000-8000-0000000000a1', 'ac_inspection_cleaning', 35000),
  ('00000000-0000-4000-8000-0000000000a2', 'ac_inspection_cleaning', 35000);

insert into public.consumer_addresses (id, consumer_id, label, area_id, details)
values ('d0000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'البيت', 'nasr_city', 'شارع السر 5 مدينة نصر'),
       ('d0000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000c1', 'الشغل', 'maadi', 'شارع 9 المعادي');

-- C1: one assigned request (T1 chosen), one waiting for a pick (T1's offer),
-- one with no offers for 4 hours. C4: one open for 5 hours.
insert into public.service_requests (
  id, consumer_id, category_id, issue, area_id, address_label, address_details,
  preferred_on, time_window, expires_at, created_at
)
values
  ('a1b2c3d4-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', 'ac', 'not_cooling', 'nasr_city', 'البيت', 'شارع السر 5 مدينة نصر', current_date + 1, 'morning', now() + interval '2 days', now() - interval '30 hours'),
  ('b1b2c3d4-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000c1', 'ac', 'noisy', 'nasr_city', 'البيت', 'شارع السر 5 مدينة نصر', current_date + 1, 'noon', now() + interval '2 days', now() - interval '1 hour'),
  ('c1b2c3d4-0000-4000-8000-000000000003', '00000000-0000-4000-8000-0000000000c1', 'ac', 'leaking', 'nasr_city', 'البيت', 'شارع السر 5 مدينة نصر', current_date + 1, 'evening', now() + interval '2 days', now() - interval '4 hours'),
  ('d1b2c3d4-0000-4000-8000-000000000004', '00000000-0000-4000-8000-0000000000c4', 'ac', 'leaking', 'maadi', 'البيت', 'شارع 9 المعادي', current_date + 1, 'noon', now() + interval '2 days', now() - interval '5 hours');

insert into public.request_offers (id, request_id, technician_id, service_id, price_piastres, arrive_at, status)
values
  ('c0000000-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1', 'ac_inspection_cleaning', 40000, now() + interval '1 day', 'accepted'),
  ('c0000000-0000-4000-8000-000000000002', 'b1b2c3d4-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000a1', 'ac_inspection_cleaning', 45000, now() + interval '1 day', 'sent');
update public.service_requests
   set status = 'assigned', chosen_offer_id = 'c0000000-0000-4000-8000-000000000001', chosen_at = now()
 where id = 'a1b2c3d4-0000-4000-8000-000000000001';

insert into public.reviews (request_id, consumer_id, technician_id, stars, paid_with)
values ('a1b2c3d4-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1', 4, 'cash');
insert into public.complaints (id, request_id, consumer_id, technician_id, reason, details)
values ('e1000000-0000-4000-8000-000000000001', 'a1b2c3d4-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000a1',
        'no_show_or_late', 'الفني ماجاش في المعاد');

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

create function pg_temp.upload(p_bucket text, p_owner uuid)
returns void
language sql
as $$
  insert into storage.objects (bucket_id, name, owner_id)
  values (p_bucket, p_owner || '/' || gen_random_uuid() || '.jpg', p_owner::text);
$$;

create function pg_temp.new_request(p_address uuid)
returns jsonb
language sql
as $$
  select public.create_service_request(
    'ac', 'not_cooling', null, '{}'::text[], p_address, current_date + 1, 'any_time'
  );
$$;

grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;

-- Overview --------------------------------------------------------------------------------

select is(
  (select public.admin_overview('week') #>> '{requests_without_offers,count}'), '2',
  'overview: requests that waited 3 hours with no offer'
);
select is(
  (select public.admin_overview('week') #>> '{requests_without_offers,top_areas,0,area_id}'), 'maadi',
  'and where (ties by area id)'
);
select is(
  (select public.admin_overview('week') #>> '{open_complaints,by_reason,no_show_or_late}'), '1',
  'overview: open complaints by reason'
);
select is(
  (select public.admin_overview('week') #>> '{funnel,sent}' || ',' ||
          (public.admin_overview('week') #>> '{funnel,with_offer}') || ',' ||
          (public.admin_overview('week') #>> '{funnel,chosen}')),
  '4,2,1', 'overview: the request funnel'
);
select ok(
  (select (public.admin_overview('today') #>> '{requests,count}')::int <= 3),
  'overview: today leaves out the request that is 30 hours old'
);
select is(
  (select public.admin_overview('week') #>> '{rating,average}'), '4.0', 'overview: average rating'
);

-- Requests ----------------------------------------------------------------------------------

select is((select public.admin_list_requests(null, null, null, 7, 50, 0) ->> 'total'), '4', 'all four requests list');
select is(
  (select public.admin_list_requests(null, null, 'no_offers', 7, 50, 0) ->> 'total'), '2', 'filter: no offers'
);
select is(
  (select public.admin_list_requests(null, null, 'awaiting_choice', 7, 50, 0) ->> 'total'), '1', 'filter: waiting for a pick'
);
select is(
  (select public.admin_list_requests(null, null, 'in_progress', 7, 50, 0) #>> '{items,0,technician_name}'),
  'محمود ا.', 'filter: in progress, with the chosen technician (first name and initial)'
);
select is(
  (select public.admin_list_requests(null, 'maadi', null, 7, 50, 0) ->> 'total'), '1', 'filter: area'
);
select is(
  (select public.admin_list_requests(null, null, null, 1, 50, 0) ->> 'total'), '3', 'filter: last day'
);
select is(
  (select public.admin_list_requests('0100 999 0031', null, null, 7, 50, 0) ->> 'total'), '3', 'search: by phone'
);
select is(
  (select public.admin_list_requests('r-a1b2c3', null, null, 7, 50, 0) ->> 'total'), '1', 'search: by request code'
);
select is(
  (select public.admin_list_requests('نورهان', null, null, 7, 50, 0) ->> 'total'), '3', 'search: by name'
);
select is(
  (select public.admin_list_requests('%', null, null, 7, 50, 0) ->> 'total'), '0', 'search: a wildcard is not a wildcard'
);
select throws_ok($$select public.admin_list_requests(null, null, 'bogus')$$, '22023', 'invalid_filter', 'an unknown status is refused');
select throws_ok($$select public.admin_list_requests(null, null, null, 0)$$, '22023', 'invalid_filter', 'so is a zero-day window');
select throws_ok(
  $$select public.admin_list_requests(repeat('x', 61))$$, '22023', 'invalid_search', 'and an over-long search'
);
select is(
  (select jsonb_array_length(public.admin_list_requests(null, null, null, 7, 2, 0) -> 'items')), 2, 'paging'
);
select is(
  (select jsonb_array_length(public.admin_list_requests(null, null, null, 7, 2, 3) -> 'items')), 1, 'paging: the last page'
);
select is(
  (select public.admin_list_requests(null, null, 'in_progress', 7, 50, 0) #>> '{items,0,consumer_name}'),
  'نورهان م.', 'the list shows the consumer''s first name and initial'
);
select ok(
  (select public.admin_list_requests(null, null, null, 7, 50, 0)::text !~ 'شارع|2010099900|\+20|address'),
  'and no address or phone number'
);

-- Complaints -------------------------------------------------------------------------------------

select is((select public.admin_list_complaints('open', 50, 0) ->> 'total'), '1', 'one complaint is open');
select is(
  (select public.admin_list_complaints('open', 50, 0) #>> '{items,0,consumer,phone}'), '+201009990031',
  'the complaint has the consumer''s phone for the call'
);
select is(
  (select public.admin_list_complaints('open', 50, 0) #>> '{items,0,technician,phone}'), '+201009990041',
  'and the technician''s'
);
select is(
  (select public.admin_list_complaints('open', 50, 0) #>> '{items,0,request_code}'), 'R-A1B2C3', 'with the request code'
);
select throws_ok($$select public.admin_list_complaints('nope')$$, '22023', 'invalid_filter', 'an unknown filter is refused');
select throws_ok(
  $$select public.admin_resolve_complaint('e1000000-0000-4000-8000-000000000001', 'x')$$,
  '22023', 'invalid_reason', 'resolving needs a note'
);
select throws_ok(
  $$select public.admin_resolve_complaint(gen_random_uuid(), 'اتحلت بالتليفون')$$,
  'P0002', 'complaint_not_found', 'an unknown complaint is refused'
);
select is(
  (select public.admin_resolve_complaint('e1000000-0000-4000-8000-000000000001', 'كلمنا الفني واعتذر') ->> 'already_resolved'),
  'false', 'the admin resolves it'
);
select is(
  (select public.admin_resolve_complaint('e1000000-0000-4000-8000-000000000001', 'كلمنا الفني واعتذر') ->> 'already_resolved'),
  'true', 'resolving twice changes nothing'
);
select is((select public.admin_list_complaints('open', 50, 0) ->> 'total'), '0', 'none are open now');
select is(
  (select public.admin_list_complaints('resolved', 50, 0) #>> '{items,0,resolution_note}'),
  'كلمنا الفني واعتذر', 'the note is kept'
);

-- Users ------------------------------------------------------------------------------------------

select is((select public.admin_list_users('technician', null, null, null, 50, 0) ->> 'total'), '2', 'two technicians');
select is((select public.admin_list_users('consumer', null, null, null, 50, 0) ->> 'total'), '3', 'three consumers');
select is(
  (select public.admin_list_users('technician', null, null, 'verified', 50, 0) ->> 'total'), '2', 'both are verified'
);
select is(
  (select public.admin_list_users('technician', '0100 999 0041', null, null, 50, 0) #>> '{items,0,name}'),
  'محمود السيد', 'search by phone'
);
select is(
  (select public.admin_list_users('technician', 'ياسر', null, null, 50, 0) ->> 'total'), '1', 'search by name'
);
select is(
  (select public.admin_list_users('technician', '_', null, null, 50, 0) ->> 'total'), '0', 'a wildcard is not a wildcard'
);
select is(
  (select public.admin_list_users('technician', 'محمود', null, null, 50, 0) #>> '{items,0,rating}'), '4.0', 'the technician''s rating'
);
select is(
  (select public.admin_list_users('technician', 'محمود', null, null, 50, 0) #>> '{items,0,platform_jobs}'), '1',
  'and platform jobs'
);
select is(
  (select public.admin_list_users('consumer', 'نورهان', null, null, 50, 0) #>> '{items,0,requests_count}'), '3',
  'a consumer''s request count'
);
select is(
  (select public.admin_list_users('consumer', 'نورهان', null, null, 50, 0) #>> '{items,0,complaints_count}'), '1',
  'and complaints'
);
select throws_ok(
  $$select public.admin_list_users('consumer', null, null, 'verified')$$, '22023', 'invalid_filter',
  'a technician status is refused for consumers'
);
select is(
  (select jsonb_array_length(public.admin_list_users('consumer', null, null, null, 2, 0) -> 'items')), 2,
  'users are paged'
);

-- Suspension --------------------------------------------------------------------------------------

select throws_ok(
  $$select public.admin_suspend_user('00000000-0000-4000-8000-0000000000ad', 'تجربة النظام')$$,
  '22023', 'invalid_target', 'an admin can not suspend themselves'
);
select throws_ok(
  $$select public.admin_suspend_user('00000000-0000-4000-8000-0000000000ae', 'تجربة النظام')$$,
  '42501', 'cannot_suspend_admin', 'nor another admin'
);
select throws_ok(
  $$select public.admin_suspend_user('00000000-0000-4000-8000-0000000000a1', 'x')$$,
  '22023', 'invalid_reason', 'a suspension needs a reason'
);
select throws_ok(
  $$select public.admin_suspend_user(gen_random_uuid(), 'شكاوي متكررة')$$,
  'P0002', 'user_not_found', 'an unknown user is refused'
);
select is(
  (select public.admin_suspend_user('00000000-0000-4000-8000-0000000000a1', 'شكاوي متكررة') ->> 'already_suspended'),
  'false', 'the admin suspends a technician'
);
select is(
  (select public.admin_suspend_user('00000000-0000-4000-8000-0000000000a1', 'شكاوي متكررة') ->> 'already_suspended'),
  'true', 'suspending twice changes nothing'
);
select is(
  (select public.admin_list_users('technician', 'محمود', null, null, 50, 0) #>> '{items,0,status}'),
  'suspended', 'the list says so'
);
select is(
  (select public.admin_list_users('technician', null, null, 'suspended', 50, 0) #>> '{items,0,suspension_reason}'),
  'شكاوي متكررة', 'with the reason'
);
select is(
  (select public.admin_overview('week') ->> 'verified_technicians'), '1', 'a suspended technician is not counted as verified'
);
select public.admin_suspend_user('00000000-0000-4000-8000-0000000000c4', 'سلوك مسيء مع الفنيين');
select public.admin_suspend_user('00000000-0000-4000-8000-0000000000c3', 'محاولات احتيال');
reset role;

select is(
  (select status::text from public.service_requests where id = 'd1b2c3d4-0000-4000-8000-000000000004'),
  'cancelled', 'a suspended consumer''s open request is cancelled'
);
select is(
  (select request_credits from public.consumer_profiles where id = '00000000-0000-4000-8000-0000000000c4'),
  3, 'and the held use comes back'
);
select is(
  (select count(*)::int from private.admin_audit_log where action = 'suspend_user'),
  3, 'one audit row per real suspension'
);

-- The suspended technician can't write.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select ok(
  (select suspended_at is not null from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'the person can see their own account is suspended'
);
select throws_ok(
  $$select public.send_offer('c1b2c3d4-0000-4000-8000-000000000003', 'ac_inspection_cleaning', 40000, now() + interval '20 hours', null)$$,
  '42501', 'account_suspended', 'a suspended technician can not send an offer'
);
select throws_ok($$select public.sync_push('[]'::jsonb)$$, '42501', 'account_suspended', 'nor push their records');
select throws_ok(
  $$select public.technician_request('c1b2c3d4-0000-4000-8000-000000000003')$$,
  '42501', 'account_suspended', 'nor open a request'
);
select throws_ok(
  $$select public.dismiss_request('c1b2c3d4-0000-4000-8000-000000000003')$$,
  '42501', 'account_suspended', 'nor dismiss one'
);
select throws_ok(
  $$select public.submit_topup(
      (select id from public.credit_packs where role = 'technician' and uses = 1), 'wallet',
      '01114567720', 'x/y.jpg', 3000)$$,
  '42501', 'account_suspended', 'nor buy uses'
);
select lives_ok($$select public.sync_pull()$$, 'but still reads their own records');
select lives_ok(
  $$select public.mark_notifications_read('technician')$$, 'and marks notifications read'
);
select throws_ok(
  $$select pg_temp.upload('job-photos', '00000000-0000-4000-8000-0000000000a1')$$,
  '42501', null, 'a suspended technician can not upload a job photo'
);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
set local role authenticated;
select lives_ok(
  $$select pg_temp.upload('job-photos', '00000000-0000-4000-8000-0000000000a2')$$,
  'while a technician who is not suspended can (control)'
);
reset role;

-- A suspended technician can't be picked, gets no requests, and isn't counted.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok(
  $$select public.accept_offer('c0000000-0000-4000-8000-000000000002')$$,
  'P0001', 'technician_unavailable', 'his waiting offer can not be accepted'
);
select is(
  (select (pg_temp.new_request('d0000000-0000-4000-8000-000000000001') ->> 'sent_to')::int), 1,
  'a new request goes to the other technician only'
);
select is(
  (select public.available_technician_count('ac', 'nasr_city')), 1, 'and the area count leaves him out'
);
reset role;

-- The suspended consumer can't write.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c4');
set local role authenticated;
select throws_ok(
  $$select public.save_consumer_address(null, 'البيت', 'maadi', 'شارع 9 المعادي')$$,
  '42501', 'account_suspended', 'a suspended consumer can not save an address'
);
select throws_ok(
  $$select pg_temp.new_request(gen_random_uuid())$$, '42501', 'account_suspended', 'nor send a request'
);
select throws_ok(
  $$select public.submit_topup(
      (select id from public.credit_packs where role = 'consumer' and uses = 1), 'wallet',
      '01114567720', 'x/y.jpg', 2000)$$,
  '42501', 'account_suspended', 'nor buy uses'
);
select throws_ok(
  $$select public.cancel_service_request('d1b2c3d4-0000-4000-8000-000000000004')$$,
  '42501', 'account_suspended', 'nor touch a request'
);
select throws_ok(
  $$select public.complete_technician_onboarding('محمد علي', null, 3::smallint, 'x', 'maadi', 29.96, 31.25, 10::smallint,
      '{1}'::smallint[], array['maadi'], '[]'::jsonb, 'a', 'b', 'c')$$,
  '42501', 'account_suspended', 'nor start a second side of the app'
);
select throws_ok(
  $$select pg_temp.upload('request-photos', '00000000-0000-4000-8000-0000000000c4')$$,
  '42501', null, 'nor upload a photo'
);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select lives_ok(
  $$select pg_temp.upload('request-photos', '00000000-0000-4000-8000-0000000000c1')$$,
  'while a consumer who is not suspended can (control)'
);
reset role;

-- A suspended person can still delete their account; signing up again with
-- the same number is suspended from the start.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c3');
set local role authenticated;
select lives_ok($$select public.delete_my_account('DELETE')$$, 'a suspended person can delete their account');
reset role;
select is(
  (select count(*)::int from private.suspensions where user_id = '00000000-0000-4000-8000-0000000000c3'),
  1, 'the suspension record outlives the account'
);
insert into auth.users (id, phone, aud, role)
values ('00000000-0000-4000-8000-0000000000c5', '201009990033', 'authenticated', 'authenticated');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c5');
set local role authenticated;
select throws_ok(
  $$select public.complete_consumer_onboarding('عمر طارق', 'mr', 'nasr_city')$$,
  '42501', 'account_suspended', 'the same number can not start over'
);
reset role;
insert into public.profiles (id, phone, full_name, active_role)
values ('00000000-0000-4000-8000-0000000000c5', '+201009990033', 'عمر طارق', 'consumer');
select ok(
  (select suspended_at is not null from public.profiles where id = '00000000-0000-4000-8000-0000000000c5'),
  'and a profile made for that number starts suspended'
);

-- Restoring.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select is(
  (select public.admin_restore_user('00000000-0000-4000-8000-0000000000a1') ->> 'already_restored'), 'false',
  'the admin restores the technician'
);
select is(
  (select public.admin_restore_user('00000000-0000-4000-8000-0000000000a1') ->> 'already_restored'), 'true',
  'restoring twice changes nothing'
);
select throws_ok(
  $$select public.admin_restore_user(gen_random_uuid())$$, 'P0002', 'user_not_found', 'an unknown user is refused'
);
select is(
  (select public.admin_restore_user('00000000-0000-4000-8000-0000000000c3') ->> 'suspended'), 'false',
  'the number of the deleted account is released'
);
select public.admin_restore_user('00000000-0000-4000-8000-0000000000c4');
reset role;
select is(
  (select count(*)::int from public.profiles where suspended_at is not null), 0,
  'nobody is suspended (the new account of that number was released too)'
);
select is(
  (select count(*)::int from private.suspensions), 0, 'and no record is left'
);

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
set local role authenticated;
select lives_ok($$select public.sync_push('[]'::jsonb)$$, 'the restored technician can write again');
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c4');
set local role authenticated;
select lives_ok(
  $$select public.save_consumer_address(null, 'البيت', 'maadi', 'شارع 9 المعادي')$$, 'and so can the restored consumer'
);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select is(
  (select (pg_temp.new_request('d0000000-0000-4000-8000-000000000001') ->> 'sent_to')::int), 2,
  'a restored technician gets requests again'
);

-- A closed area takes no requests.
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000ad');
set local role authenticated;
select public.admin_set_area_open('maadi', false);
reset role;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000c1');
set local role authenticated;
select throws_ok(
  $$select pg_temp.new_request('d0000000-0000-4000-8000-000000000002')$$,
  '22023', 'area_closed', 'a request for an address in a closed area is refused'
);
select lives_ok(
  $$select pg_temp.new_request('d0000000-0000-4000-8000-000000000001')$$,
  'while an open area still works'
);
reset role;

select * from finish();
rollback;
