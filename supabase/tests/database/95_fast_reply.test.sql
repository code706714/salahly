begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

create function pg_temp.u(p_n text)
returns uuid
language sql
as $$
  select ('00000000-0000-4000-8000-0000000000' || p_n)::uuid;
$$;

insert into auth.users (id, phone, aud, role)
values (pg_temp.u('c1'), '201000000951', 'authenticated', 'authenticated'),
       (pg_temp.u('a1'), '201000000952', 'authenticated', 'authenticated'),
       (pg_temp.u('a2'), '201000000953', 'authenticated', 'authenticated');

insert into public.profiles (id, phone, full_name, active_role)
values (pg_temp.u('c1'), '+201000000951', 'اسم c1', 'consumer'),
       (pg_temp.u('a1'), '+201000000952', 'اسم a1', 'technician'),
       (pg_temp.u('a2'), '+201000000953', 'اسم a2', 'technician');

insert into public.consumer_profiles (id, honorific, area_id, request_credits)
values (pg_temp.u('c1'), 'ms', 'nasr_city', 20);

insert into public.technician_profiles (
  id, years_experience, avatar_path, base_area_id, base_lat, base_lng,
  service_radius_km, work_days, job_credits, verification_status
)
values (pg_temp.u('a1'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved'),
       (pg_temp.u('a2'), 5, 'x', 'nasr_city', 30.056, 31.33, 5, '{1,2,3,4,5,6,7}', 5, 'approved');

-- One request reaching the technician, who answers after p_minutes.
create function pg_temp.answered_after(p_tech uuid, p_minutes integer)
returns void
language plpgsql
as $$
declare
  v_request uuid := gen_random_uuid();
begin
  insert into public.service_requests (
    id, consumer_id, category_id, issue, area_id, address_label, address_details,
    preferred_on, time_window, expires_at, status
  )
  values (
    v_request, pg_temp.u('c1'), 'ac', 'not_cooling', 'nasr_city', 'البيت', 'عنوان',
    current_date + 1, 'noon', now() + interval '1 day', 'open'
  );
  insert into public.request_recipients (request_id, technician_id, distance_km, sent_at)
  values (v_request, p_tech, 1, now() - interval '2 hours');
  insert into public.request_offers (request_id, technician_id, price_piastres, arrive_at, created_at)
  values (v_request, p_tech, 20000, now() + interval '1 day',
          now() - interval '2 hours' + make_interval(mins => p_minutes));
end;
$$;

select ok(not private.is_fast_replier(pg_temp.u('a1')), 'no offers yet: no badge');

select pg_temp.answered_after(pg_temp.u('a1'), 5) from generate_series(1, 4);
select ok(not private.is_fast_replier(pg_temp.u('a1')), 'four quick offers say too little');

select pg_temp.answered_after(pg_temp.u('a1'), 10);
select ok(private.is_fast_replier(pg_temp.u('a1')), 'five offers answered within half an hour earn it');

select pg_temp.answered_after(pg_temp.u('a2'), 90) from generate_series(1, 5);
select ok(not private.is_fast_replier(pg_temp.u('a2')), 'slow answers do not');

select is(
  private.technician_card(pg_temp.u('a1')) -> 'fast_reply', 'true'::jsonb,
  'the card carries the badge'
);

select is(
  private.technician_listing(pg_temp.u('a2'), null) -> 'fast_reply', 'false'::jsonb,
  'and the listing says when there is none'
);

select * from finish();
rollback;
