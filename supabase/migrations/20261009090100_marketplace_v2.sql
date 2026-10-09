-- Marketplace v2, part 2.
--
--   * Every verified, non-suspended technician who offers an active service
--     in a request's category and covers its area gets the request (no
--     "nearest five", no weekday rule); a technician approved later, or who
--     adds a service or an area, gets the requests still open.
--   * A request takes up to five offers, only from verified technicians.
--   * Five service categories are open, each with its own services and
--     issue list.
--   * Price talks on an offer: the consumer counters (up to three times),
--     the technician lowers the price (up to twice), accepts the counter or
--     takes the offer back. A price both sides agree on is picked through
--     accept_offer's own code, so uses stay correct.
--   * Technicians browse open requests and edit what they offer; consumers
--     browse technicians.

-- Catalog ------------------------------------------------------------------

update public.service_categories set name_ar = 'كهرباء', sort_order = 3 where id = 'electrical';
update public.service_categories set sort_order = 2 where id = 'plumbing';

insert into public.service_categories (id, name_ar, is_active, sort_order) values
  ('washing_machines', 'غسالات', false, 4),
  ('refrigerators', 'ثلاجات', false, 5);

-- The combined "appliances" category is split in two; it goes away unless
-- something already points at it.
delete from public.service_categories c
 where c.id = 'appliances'
   and not exists (select 1 from public.services s where s.category_id = c.id)
   and not exists (select 1 from public.service_requests r where r.category_id = c.id);
update public.service_categories set is_active = false where id = 'appliances';

update public.service_categories
   set is_active = true
 where id in ('ac', 'plumbing', 'electrical', 'washing_machines', 'refrigerators');

-- Starting prices are hints the technician can change.
insert into public.services (id, category_id, name_ar, suggested_price_piastres, sort_order) values
  ('plumbing_inspection', 'plumbing', 'كشف وتحديد العطل', 15000, 1),
  ('plumbing_leak_repair', 'plumbing', 'إصلاح تسريب مية', 25000, 2),
  ('plumbing_unclogging', 'plumbing', 'تسليك مجاري وصرف', 30000, 3),
  ('plumbing_mixer_replacement', 'plumbing', 'تغيير خلاط', 25000, 4),
  ('plumbing_heater_service', 'plumbing', 'صيانة سخان', 30000, 5),
  ('plumbing_fixtures_installation', 'plumbing', 'تركيب أدوات صحية', 35000, 6),
  ('electrical_inspection', 'electrical', 'كشف وتحديد العطل', 15000, 1),
  ('electrical_outlet_switch', 'electrical', 'تغيير بريزة أو مفتاح', 10000, 2),
  ('electrical_lighting_install', 'electrical', 'تركيب إضاءة ونجف', 20000, 3),
  ('electrical_panel_repair', 'electrical', 'صيانة لوحة الكهرباء', 35000, 4),
  ('electrical_cabling', 'electrical', 'تمديد كابلات وتأسيس', 50000, 5),
  ('washer_inspection', 'washing_machines', 'كشف وتحديد العطل', 15000, 1),
  ('washer_belt_replacement', 'washing_machines', 'تغيير سير', 25000, 2),
  ('washer_motor_replacement', 'washing_machines', 'تغيير موتور', 60000, 3),
  ('washer_pump_drain', 'washing_machines', 'تغيير أو تسليك طلمبة التصريف', 30000, 4),
  ('washer_board_repair', 'washing_machines', 'صيانة بوردة', 50000, 5),
  ('fridge_inspection', 'refrigerators', 'كشف وتحديد العطل', 15000, 1),
  ('fridge_gas_recharge', 'refrigerators', 'شحن غاز', 50000, 2),
  ('fridge_compressor_replacement', 'refrigerators', 'تغيير كمبروسر', 120000, 3),
  ('fridge_thermostat_replacement', 'refrigerators', 'تغيير ترموستات', 25000, 4),
  ('fridge_door_seal_replacement', 'refrigerators', 'تغيير جوان الباب', 25000, 5);

-- What a consumer can say is wrong, per category. Every list ends with
-- "other". The air-conditioning list is what the app has always offered.
create table public.category_issues (
  category_id text not null references public.service_categories (id) on delete cascade,
  issue public.request_issue not null,
  name_ar text not null check (char_length(name_ar) between 2 and 60),
  sort_order smallint not null default 0,
  primary key (category_id, issue)
);

alter table public.category_issues enable row level security;
revoke all on table public.category_issues from anon, authenticated;
grant select on table public.category_issues to authenticated;
create policy "Signed-in users read category issues"
  on public.category_issues for select to authenticated using (true);

insert into public.category_issues (category_id, issue, name_ar, sort_order) values
  ('ac', 'not_cooling', 'مش بيبرّد', 1),
  ('ac', 'leaking', 'بينقّط مية', 2),
  ('ac', 'noisy', 'صوته عالي', 3),
  ('ac', 'needs_cleaning', 'محتاج تنضيف', 4),
  ('ac', 'installation', 'تركيب أو نقل', 5),
  ('ac', 'other', 'حاجة تانية', 6),
  ('plumbing', 'plumbing_leak', 'تسريب مية', 1),
  ('plumbing', 'plumbing_clog', 'الصرف مسدود', 2),
  ('plumbing', 'plumbing_mixer', 'الخلاط بايظ', 3),
  ('plumbing', 'plumbing_heater', 'السخان بايظ', 4),
  ('plumbing', 'plumbing_low_pressure', 'المية ضعيفة', 5),
  ('plumbing', 'installation', 'تركيب', 6),
  ('plumbing', 'other', 'حاجة تانية', 7),
  ('electrical', 'electrical_no_power', 'الكهرباء قاطعة', 1),
  ('electrical', 'electrical_short', 'ماس أو الكهرباء بتفصل', 2),
  ('electrical', 'electrical_outlet', 'بريزة أو مفتاح بايظ', 3),
  ('electrical', 'electrical_lighting', 'إضاءة أو نجف', 4),
  ('electrical', 'electrical_panel', 'لوحة الكهرباء', 5),
  ('electrical', 'installation', 'تركيب', 6),
  ('electrical', 'other', 'حاجة تانية', 7),
  ('washing_machines', 'washer_not_spinning', 'مش بتعصر', 1),
  ('washing_machines', 'washer_not_draining', 'مش بتصرّف المية', 2),
  ('washing_machines', 'washer_leaking', 'بتسرّب مية', 3),
  ('washing_machines', 'washer_noisy', 'صوتها عالي', 4),
  ('washing_machines', 'washer_not_starting', 'مش بتشتغل', 5),
  ('washing_machines', 'other', 'حاجة تانية', 6),
  ('refrigerators', 'fridge_not_cooling', 'مش بتبرّد', 1),
  ('refrigerators', 'fridge_ice_buildup', 'تلج زيادة في الفريزر', 2),
  ('refrigerators', 'fridge_noisy', 'صوتها عالي', 3),
  ('refrigerators', 'fridge_leaking', 'بتسرّب مية', 4),
  ('refrigerators', 'fridge_door_seal', 'جوان الباب بايظ', 5),
  ('refrigerators', 'other', 'حاجة تانية', 6);

-- Tables -------------------------------------------------------------------

-- Requests handed to a technician after the fact (approval, a new service,
-- opening a request) don't buzz their phone one by one.
alter table public.request_recipients add column backfilled boolean not null default false;

drop trigger request_recipients_notify on public.request_recipients;
create trigger request_recipients_notify after insert on public.request_recipients
  for each row
  when (not new.backfilled)
  execute function private.notify_new_request();

-- Where an offer stands in the price talks. The technician's price is
-- price_piastres; counter_price_piastres is the consumer's, waiting for the
-- technician. awaiting says whose move it is.
alter table public.request_offers
  add column counter_price_piastres bigint,
  add column awaiting text not null default 'consumer'
    check (awaiting in ('consumer', 'technician')),
  add column counter_count smallint not null default 0 check (counter_count between 0 and 3),
  add column revision_count smallint not null default 0 check (revision_count between 0 and 2),
  add constraint request_offers_counter_check check (
    (counter_price_piastres is null) = (awaiting = 'consumer')
    and (counter_price_piastres is null
         or (counter_price_piastres >= 100 and counter_price_piastres < price_piastres))
  );

-- The history of an offer's price, oldest first.
create table private.offer_events (
  id bigint generated always as identity primary key,
  offer_id uuid not null references public.request_offers (id) on delete cascade,
  actor public.user_role not null,
  kind text not null check (kind in ('offer', 'counter', 'revise', 'accept_counter', 'withdraw')),
  price_piastres bigint,
  created_at timestamptz not null default clock_timestamp()
);
create index offer_events_offer_idx on private.offer_events (offer_id, id);
alter table private.offer_events enable row level security;

create function private.record_offer_sent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.offer_events (offer_id, actor, kind, price_piastres)
  values (new.id, 'technician', 'offer', new.price_piastres);
  return null;
end;
$$;

create trigger request_offers_record after insert on public.request_offers
  for each row execute function private.record_offer_sent();

-- What people did lately, to keep the calls that write from being spammed.
create table private.action_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  action text not null,
  at timestamptz not null default now()
);
create index action_log_user_idx on private.action_log (user_id, action, at);
alter table private.action_log enable row level security;

-- Refuses (rate_limited) the caller's p_max-th-plus-one p_action within
-- p_window; otherwise records it.
create function private.rate_limit(p_action text, p_max integer, p_window interval)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if (
    select count(*) from private.action_log
     where user_id = v_user_id and action = p_action and at > now() - p_window
  ) >= p_max then
    raise exception 'rate_limited' using errcode = '54000';
  end if;
  insert into private.action_log (user_id, action) values (v_user_id, p_action);
end;
$$;

-- Who gets a request ----------------------------------------------------------

-- A verified, non-suspended technician who offers an active service in the
-- category and covers the area: it is their base area or one they chose,
-- or the area's center is within their service radius.
create function private.technician_covers_area(p_technician_id uuid, p_area_id text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.technician_profiles t
     where t.id = p_technician_id
       and (
         t.base_area_id = p_area_id
         or exists (
           select 1 from public.technician_areas ta
            where ta.technician_id = t.id and ta.area_id = p_area_id
         )
         or exists (
           select 1 from public.service_areas a
            where a.id = p_area_id
              and private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng)
                  <= t.service_radius_km
         )
       )
  );
$$;

create function private.technician_serves(
  p_technician_id uuid,
  p_category_id text,
  p_area_id text
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.technician_profiles t
      join public.profiles pr on pr.id = t.id
     where t.id = p_technician_id
       and t.verification_status = 'approved'
       and pr.suspended_at is null
       and exists (
         select 1
           from public.technician_services ts
           join public.services s on s.id = ts.service_id and s.is_active
          where ts.technician_id = t.id and s.category_id = p_category_id
       )
       and private.technician_covers_area(t.id, p_area_id)
  );
$$;

-- Whether a request is meant for this technician: they serve it, it isn't
-- their own, and, when the consumer asked for one technician, it is them or
-- the request has been opened up to others. Says nothing of whether it is
-- still open.
create function private.request_meant_for(p_request_id uuid, p_technician_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.service_requests r
     where r.id = p_request_id
       and r.consumer_id <> p_technician_id
       and (
         r.preferred_technician_id is null
         or r.preferred_technician_id = p_technician_id
         or r.widened_at is not null
       )
       and private.technician_serves(p_technician_id, r.category_id, r.area_id)
  );
$$;

-- Hands one request to a technician it is meant for, without a
-- notification. Returns whether they hold it afterwards.
create function private.ensure_recipient(p_request_id uuid, p_technician_id uuid)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.request_recipients
     where request_id = p_request_id and technician_id = p_technician_id
  ) then
    return true;
  end if;
  if not private.request_meant_for(p_request_id, p_technician_id) then
    return false;
  end if;
  insert into public.request_recipients (request_id, technician_id, distance_km, backfilled)
  select r.id, t.id,
         private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng), true
    from public.service_requests r
    join public.service_areas a on a.id = r.area_id
    join public.technician_profiles t on t.id = p_technician_id
   where r.id = p_request_id
  on conflict do nothing;
  return true;
end;
$$;

-- Gives a technician the open requests they now match (the 50 newest, not
-- the full ones) and tells them once about the newest.
create function private.backfill_technician_requests(p_technician_id uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_newest uuid;
  v_added integer;
begin
  with added as (
    insert into public.request_recipients (request_id, technician_id, distance_km, backfilled)
    select r.id, t.id,
           private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng), true
      from public.service_requests r
      join public.service_areas a on a.id = r.area_id
      join public.technician_profiles t on t.id = p_technician_id
     where r.status = 'open'
       and r.expires_at > now()
       and private.request_meant_for(r.id, t.id)
       and not exists (
         select 1 from public.request_recipients rr
          where rr.request_id = r.id and rr.technician_id = t.id
       )
       and (
         select count(*) from public.request_offers o
          where o.request_id = r.id and o.status <> 'withdrawn'
       ) < 5
     order by r.created_at desc
     limit 50
    on conflict do nothing
    returning request_id
  )
  select count(*), (
           select a.request_id
             from added a
             join public.service_requests r on r.id = a.request_id
            order by r.created_at desc
            limit 1
         )
    into v_added, v_newest
    from added;
  if v_newest is not null then
    perform private.notify(p_technician_id, 'technician', 'new_request', v_newest);
  end if;
  return v_added;
end;
$$;

create function private.backfill_on_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.backfill_technician_requests(new.id);
  return null;
end;
$$;

create trigger technician_profiles_backfill
  after update of verification_status on public.technician_profiles
  for each row
  when (old.verification_status is distinct from 'approved' and new.verification_status = 'approved')
  execute function private.backfill_on_approval();

-- A restored technician gets what they missed too.
create function private.backfill_on_restore()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.technician_profiles where id = new.id) then
    perform private.backfill_technician_requests(new.id);
  end if;
  return null;
end;
$$;

create trigger profiles_backfill_on_restore
  after update of suspended_at on public.profiles
  for each row
  when (old.suspended_at is not null and new.suspended_at is null)
  execute function private.backfill_on_restore();

-- Sends a request to every technician who matches and doesn't have it yet.
-- Returns how many were added.
drop function private.dispatch_request(uuid, boolean);
create function private.dispatch_request(p_request_id uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_request public.service_requests;
  v_area public.service_areas;
  v_added integer;
begin
  select * into v_request from public.service_requests where id = p_request_id;
  select * into v_area from public.service_areas where id = v_request.area_id;

  insert into public.request_recipients (request_id, technician_id, distance_km)
  select v_request.id, t.id,
         private.distance_km(t.base_lat, t.base_lng, v_area.center_lat, v_area.center_lng)
    from public.technician_profiles t
   where t.id <> v_request.consumer_id
     and private.technician_serves(t.id, v_request.category_id, v_request.area_id)
     and not exists (
       select 1 from public.request_recipients rr
        where rr.request_id = v_request.id and rr.technician_id = t.id
     );

  get diagnostics v_added = row_count;
  return v_added;
end;
$$;

-- A request the consumer sent to one technician opens up to everyone after
-- two hours with no offer.
create or replace function private.marketplace_housekeeping()
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_request record;
begin
  for v_request in
    update public.service_requests
       set status = 'expired', credit_held = false
     where status = 'open' and expires_at <= now()
    returning consumer_id, credit_held
  loop
    perform private.return_use(v_request.consumer_id, 'consumer');
  end loop;

  for v_request in
    select r.id
      from public.service_requests r
     where r.status = 'open'
       and r.widened_at is null
       and r.preferred_technician_id is not null
       and r.created_at <= now() - interval '2 hours'
       and not exists (select 1 from public.request_offers o where o.request_id = r.id)
     for update skip locked
  loop
    update public.service_requests set widened_at = now() where id = v_request.id;
    perform private.dispatch_request(v_request.id);
  end loop;

  delete from public.notifications where created_at < now() - interval '90 days';
  delete from private.action_log where at < now() - interval '1 day';
end;
$$;

-- "24 فني في منطقتك".
create or replace function public.available_technician_count(p_category_id text, p_area_id text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
    from public.technician_profiles t
   where auth.uid() is not null
     and private.technician_serves(t.id, p_category_id, p_area_id);
$$;

-- Technicians the request was sent to can see its photos, and so can any
-- technician it is meant for while it is open.
create or replace function guard.can_view_request_photo(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(p_name, '/', 1) = (select auth.uid()::text)
      or exists (
        select 1
          from public.service_requests r
         where p_name = any (r.photo_paths)
           and (
             exists (
               select 1 from public.request_recipients rr
                where rr.request_id = r.id and rr.technician_id = (select auth.uid())
             )
             or (
               r.status = 'open'
               and private.request_meant_for(r.id, (select auth.uid()))
             )
           )
      );
$$;

-- Pushes for the price talks too.
create or replace function private.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_kind::text = any (array[
    'offer_received', 'technician_arriving', 'job_confirmed', 'job_started',
    'job_finished', 'price_change', 'request_cancelled_by_technician',
    'request_expired', 'new_request', 'offer_picked',
    'request_cancelled_by_consumer', 'verification_approved',
    'verification_rejected', 'topup_approved', 'topup_rejected',
    'offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted'
  ]);
$$;

-- Existing functions, changed ----------------------------------------------

create or replace function public.my_requests()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.item order by x.created_at desc), '[]')
    from (
      select r.created_at, jsonb_build_object(
        'id', r.id,
        'category_id', r.category_id,
        'issue', r.issue,
        'description', r.description,
        'status', private.request_state(r.status, r.expires_at),
        'cancelled_by', r.cancelled_by,
        'preferred_on', r.preferred_on,
        'time_window', r.time_window,
        'created_at', r.created_at,
        'offer_count', (
          select count(*) from public.request_offers o
           where o.request_id = r.id and o.status <> 'withdrawn'
        ),
        'technician', case when o.id is not null then jsonb_build_object(
          'id', o.technician_id,
          'name', p.full_name
        ) end,
        'price_piastres', o.price_piastres,
        'arrive_at', o.arrive_at,
        'job_status', j.status,
        'scheduled_at', j.scheduled_at,
        'review_stars', (select v.stars from public.reviews v where v.request_id = r.id)
      ) as item
        from public.service_requests r
        left join public.request_offers o on o.id = r.chosen_offer_id
        left join public.profiles p on p.id = o.technician_id
        left join public.jobs j on j.id = r.job_id
       where r.consumer_id = auth.uid()
       order by r.created_at desc
       limit 100
    ) x;
$$;

create or replace function private.create_service_request_impl(
  p_category_id text,
  p_issue public.request_issue,
  p_description text,
  p_photo_paths text[],
  p_address_id uuid,
  p_preferred_on date,
  p_window public.request_window,
  p_technician_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_address public.consumer_addresses;
  v_range tstzrange;
  v_photos text[] := coalesce(p_photo_paths, '{}');
  v_request_id uuid;
  v_sent integer := 0;
begin
  if v_user_id is null or not exists (select 1 from public.consumer_profiles where id = v_user_id) then
    raise exception 'not_consumer' using errcode = '42501';
  end if;
  -- Every request reaches every matching technician, so sending them is limited.
  perform private.rate_limit('create_request', 10, interval '1 hour');
  if not exists (
    select 1 from public.service_categories where id = p_category_id and is_active
  ) then
    raise exception 'invalid_category' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.category_issues where category_id = p_category_id and issue = p_issue
  ) then
    raise exception 'invalid_issue' using errcode = '22023';
  end if;
  select * into v_address
    from public.consumer_addresses
   where id = p_address_id and consumer_id = v_user_id;
  if not found then
    raise exception 'invalid_address' using errcode = '22023';
  end if;
  v_range := private.window_range(p_preferred_on, p_window);
  if upper(v_range) < now() + interval '1 hour'
     or p_preferred_on > (now() at time zone 'Africa/Cairo')::date + 6 then
    raise exception 'invalid_time' using errcode = '22023';
  end if;
  if cardinality(v_photos) > 4
     or cardinality(v_photos) <> (select count(distinct p) from unnest(v_photos) p)
     or exists (
       select 1 from unnest(v_photos) p
        where not private.owns_object(v_user_id, 'request-photos', p)
     ) then
    raise exception 'invalid_photos' using errcode = '22023';
  end if;

  perform private.take_use(v_user_id, 'consumer');

  insert into public.service_requests (
    consumer_id, category_id, issue, description, photo_paths, area_id,
    address_label, address_details, preferred_on, time_window, expires_at,
    preferred_technician_id
  )
  values (
    v_user_id, p_category_id, p_issue, private.normalize_text(p_description),
    v_photos, v_address.area_id, v_address.label, v_address.details,
    p_preferred_on, p_window, upper(v_range), p_technician_id
  )
  returning id into v_request_id;

  -- Asked for one technician (hired before, or picked from the list): only
  -- they first, as long as they are verified and still offer this service;
  -- everyone else joins after two hours with no offer.
  if p_technician_id is not null and exists (
    select 1
      from public.technician_profiles t
     where t.id = p_technician_id
       and t.id <> v_user_id
       and t.verification_status = 'approved'
       and not exists (
         select 1 from public.profiles pr
          where pr.id = t.id and pr.suspended_at is not null
       )
       and exists (
         select 1
           from public.technician_services ts
           join public.services s on s.id = ts.service_id and s.is_active
          where ts.technician_id = t.id and s.category_id = p_category_id
       )
  ) then
    insert into public.request_recipients (request_id, technician_id, distance_km)
    select v_request_id, t.id,
           private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng)
      from public.technician_profiles t, public.service_areas a
     where t.id = p_technician_id and a.id = v_address.area_id;
    v_sent := 1;
  else
    v_sent := private.dispatch_request(v_request_id);
  end if;

  return jsonb_build_object('id', v_request_id, 'sent_to', v_sent);
end;
$$;

create function private.accept_offer_core(p_offer_id uuid, p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := p_user_id;
  v_offer public.request_offers;
  v_request public.service_requests;
  v_consumer public.profiles;
  v_customer_id uuid;
  v_job_id uuid := gen_random_uuid();
begin
  select * into v_offer from public.request_offers where id = p_offer_id;
  select * into v_request
    from public.service_requests
   where id = v_offer.request_id and consumer_id = v_user_id
   for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  select * into v_offer from public.request_offers where id = p_offer_id for update;
  if v_offer.status <> 'sent' then
    raise exception 'offer_unavailable' using errcode = 'P0001';
  end if;
  if not exists (
    select 1
      from public.technician_profiles t
      join public.profiles pr on pr.id = t.id
     where t.id = v_offer.technician_id
       and t.verification_status = 'approved'
       and pr.suspended_at is null
  ) then
    raise exception 'technician_unavailable' using errcode = 'P0001';
  end if;
  if v_offer.arrive_at <= now() then
    raise exception 'offer_expired' using errcode = 'P0001';
  end if;

  begin
    perform private.take_use(v_offer.technician_id, 'technician');
  exception when raise_exception then
    raise exception 'technician_unavailable' using errcode = 'P0001';
  end;

  select * into v_consumer from public.profiles where id = v_user_id;

  select c.id into v_customer_id
    from public.customers c
   where c.technician_id = v_offer.technician_id
     and c.phone = v_consumer.phone
     and c.deleted_at is null
   order by c.created_at
   limit 1;
  if v_customer_id is null then
    v_customer_id := gen_random_uuid();
    insert into public.customers (id, technician_id, name, phone, area_id, address, source)
    values (
      v_customer_id, v_offer.technician_id, v_consumer.full_name, v_consumer.phone,
      v_request.area_id, v_request.address_details, 'platform'
    );
  end if;

  insert into public.jobs (
    id, technician_id, customer_id, tags, description, scheduled_at, address,
    status, quote_status, quote_sent_at, source
  )
  values (
    v_job_id, v_offer.technician_id, v_customer_id,
    case
      when v_request.issue::text in ('not_cooling', 'fridge_not_cooling') then array['not_cooling']
      when v_request.issue::text in ('leaking', 'plumbing_leak', 'washer_leaking', 'fridge_leaking') then array['leaking']
      when v_request.issue::text in ('noisy', 'washer_noisy', 'fridge_noisy') then array['maintenance']
      when v_request.issue::text = 'needs_cleaning' then array['cleaning']
      when v_request.issue::text = 'installation' then array['installation']
      else '{}'::text[]
    end,
    v_request.description, v_offer.arrive_at, v_request.address_details,
    'unconfirmed', 'accepted', now(), 'platform'
  );

  insert into public.job_items (id, technician_id, job_id, title, unit_price_piastres)
  values (
    gen_random_uuid(), v_offer.technician_id, v_job_id,
    coalesce((select name_ar from public.services where id = v_offer.service_id), 'السعر المبدئي'),
    v_offer.price_piastres
  );

  update public.request_offers
     set status = case when id = v_offer.id then 'accepted' else 'not_chosen' end::public.offer_status
   where request_id = v_request.id and status <> 'withdrawn';

  -- A counter still waiting is settled by the pick.
  update public.request_offers
     set counter_price_piastres = null, awaiting = 'consumer'
   where id = v_offer.id and awaiting = 'technician';

  update public.service_requests
     set status = 'assigned',
         chosen_offer_id = v_offer.id,
         chosen_at = now(),
         job_id = v_job_id,
         credit_held = false
   where id = v_request.id;

  return v_job_id;
end;
$$;

create or replace function private.send_offer_impl(
  p_request_id uuid,
  p_service_id text,
  p_price_piastres bigint,
  p_arrive_at timestamptz,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_credits integer;
  v_request public.service_requests;
  v_offer_id uuid;
begin
  if not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.technician_profiles
     where id = v_user_id and verification_status = 'approved'
  ) then
    raise exception 'not_verified' using errcode = '42501';
  end if;
  select r.* into v_request
    from public.service_requests r
   where r.id = p_request_id
   for update of r;
  if not found or not private.ensure_recipient(v_request.id, v_user_id) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open'
     or (
          select count(*) from public.request_offers
           where request_id = v_request.id and status <> 'withdrawn'
        ) >= 5 then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  -- Locked after the request, as accept_offer does, so two offers sent at
  -- once can't both count the same pending offers.
  select job_credits into v_credits
    from public.technician_profiles
   where id = v_user_id
   for update;
  if (
    select count(*)
      from public.request_offers o
      join public.service_requests r on r.id = o.request_id
     where o.technician_id = v_user_id
       and o.status = 'sent'
       and private.request_state(r.status, r.expires_at) = 'open'
  ) >= v_credits then
    raise exception 'no_credits' using errcode = 'P0001';
  end if;
  if p_arrive_at <= now()
     or not private.window_range(v_request.preferred_on, v_request.time_window) @> p_arrive_at then
    raise exception 'invalid_time' using errcode = '22023';
  end if;
  if p_service_id is not null and not exists (
    select 1
      from public.technician_services ts
      join public.services s on s.id = ts.service_id
     where ts.technician_id = v_user_id
       and ts.service_id = p_service_id
       and s.category_id = v_request.category_id
  ) then
    raise exception 'invalid_service' using errcode = '22023';
  end if;

  insert into public.request_offers (
    request_id, technician_id, service_id, price_piastres, arrive_at, note
  )
  values (
    v_request.id, v_user_id, p_service_id, p_price_piastres, p_arrive_at,
    private.normalize_text(p_note)
  )
  returning id into v_offer_id;
  return v_offer_id;
exception when unique_violation then
  raise exception 'already_offered' using errcode = '23505';
end;
$$;

-- accept_offer keeps its name and wrapper; the work lives in the core above
-- so a technician accepting the consumer's counter picks through it too.
create or replace function private.accept_offer_impl(p_offer_id uuid)
returns uuid
language sql
set search_path = ''
as $$
  select private.accept_offer_core(p_offer_id, (select auth.uid()));
$$;

-- Technicians who took their offer back aren't told they weren't picked.
create or replace function private.notify_request_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_technician record;
begin
  if new.status = 'assigned' then
    perform private.notify(o.technician_id, 'technician',
      case when o.id = new.chosen_offer_id then 'offer_picked' else 'offer_not_picked' end::public.notification_kind,
      new.id, o.id)
      from public.request_offers o
     where o.request_id = new.id and o.status <> 'withdrawn';
  elsif new.status = 'cancelled' and new.cancelled_by = 'technician' then
    perform private.notify(new.consumer_id, 'consumer', 'request_cancelled_by_technician', new.id);
  elsif new.status = 'cancelled' and new.cancelled_by = 'consumer' then
    -- Once picked, only the chosen technician is involved; before, everyone
    -- who has an offer waiting.
    for v_technician in
      select o.technician_id, o.id
        from public.request_offers o
       where o.request_id = new.id
         and case when old.status = 'assigned' then o.id = new.chosen_offer_id
                  else o.status = 'sent' end
    loop
      perform private.notify(v_technician.technician_id, 'technician',
        'request_cancelled_by_consumer', new.id, v_technician.id);
    end loop;
  elsif new.status = 'expired'
        and not exists (
          select 1 from public.request_offers
           where request_id = new.id and status <> 'withdrawn'
        ) then
    perform private.notify(new.consumer_id, 'consumer', 'request_expired', new.id);
  end if;
  return null;
end;
$$;

-- What a technician sees of a request: no phone, no address, the
-- consumer's first name and initial, the area and how far it is.
create or replace function private.request_for_technician(p_request_id uuid, p_technician_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id,
    'category_id', r.category_id,
    'issue', r.issue,
    'description', r.description,
    'photo_paths', to_jsonb(r.photo_paths),
    'area_id', r.area_id,
    'distance_km', coalesce(
      rr.distance_km,
      private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng)
    ),
    'preferred_on', r.preferred_on,
    'time_window', r.time_window,
    'expires_at', r.expires_at,
    'created_at', r.created_at,
    'consumer_name', private.short_name(p.full_name),
    'consumer_honorific', cp.honorific,
    'status', private.request_state(r.status, r.expires_at),
    'sent_to', (select count(*) from public.request_recipients x where x.request_id = r.id),
    'offer_count', (
      select count(*) from public.request_offers o
       where o.request_id = r.id and o.status <> 'withdrawn'
    ),
    'dismissed', rr.dismissed_at is not null,
    'my_offer', (
      select jsonb_build_object(
        'id', o.id, 'service_id', o.service_id, 'price_piastres', o.price_piastres,
        'arrive_at', o.arrive_at, 'note', o.note, 'status', o.status,
        'counter_price_piastres', o.counter_price_piastres,
        'awaiting', o.awaiting,
        'revisions_left', 2 - o.revision_count
      )
      from public.request_offers o
      where o.request_id = r.id and o.technician_id = p_technician_id
    )
  )
  from public.service_requests r
  join public.technician_profiles t on t.id = p_technician_id
  join public.service_areas a on a.id = r.area_id
  left join public.request_recipients rr
    on rr.request_id = r.id and rr.technician_id = t.id
  join public.consumer_profiles cp on cp.id = r.consumer_id
  join public.profiles p on p.id = r.consumer_id
  where r.id = p_request_id;
$$;

-- Requests waiting for this technician's offer, newest first.
create or replace function public.technician_requests()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
           private.request_for_technician(r.id, rr.technician_id) order by rr.sent_at desc
         ), '[]')
    from public.request_recipients rr
    join public.service_requests r on r.id = rr.request_id
   where rr.technician_id = auth.uid()
     and rr.dismissed_at is null
     and private.request_state(r.status, r.expires_at) = 'open'
     and not exists (
       select 1 from public.request_offers o
        where o.request_id = r.id and o.technician_id = rr.technician_id
     )
     and (
       select count(*) from public.request_offers o
        where o.request_id = r.id and o.status <> 'withdrawn'
     ) < 5;
$$;

-- One request, for its page; marks it seen. A technician it is meant for
-- but who never got it (they matched after it was sent) gets it now.
create or replace function private.technician_request_impl(p_request_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null
     or not exists (select 1 from public.technician_profiles where id = v_user_id) then
    return null;
  end if;
  update public.request_recipients
     set seen_at = coalesce(seen_at, now())
   where request_id = p_request_id and technician_id = v_user_id;
  if not found then
    if not exists (
         select 1 from public.service_requests
          where id = p_request_id and status = 'open' and expires_at > now()
       )
       or not private.ensure_recipient(p_request_id, v_user_id) then
      return null;
    end if;
    update public.request_recipients
       set seen_at = now()
     where request_id = p_request_id and technician_id = v_user_id;
  end if;
  return private.request_for_technician(p_request_id, v_user_id);
end;
$$;

-- Open requests in the technician's categories and areas, newest first,
-- including ones they haven't answered and ones the app hasn't shown them
-- yet. Same privacy as technician_requests; hides ones they dismissed and
-- ones that already have five offers (unless one is theirs).
create function public.browse_open_requests(
  p_category_id text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
           private.request_for_technician(x.id, (select auth.uid())) order by x.created_at desc, x.id
         ), '[]')
    from (
      select r.id, r.created_at
        from public.service_requests r
       where exists (
               select 1 from public.technician_profiles where id = (select auth.uid())
             )
         and r.status = 'open'
         and r.expires_at > now()
         and (p_category_id is null or r.category_id = p_category_id)
         and private.request_meant_for(r.id, (select auth.uid()))
         and not exists (
           select 1 from public.request_recipients rr
            where rr.request_id = r.id
              and rr.technician_id = (select auth.uid())
              and rr.dismissed_at is not null
         )
         and (
           exists (
             select 1 from public.request_offers o
              where o.request_id = r.id and o.technician_id = (select auth.uid())
           )
           or (
             select count(*) from public.request_offers o
              where o.request_id = r.id and o.status <> 'withdrawn'
           ) < 5
         )
       order by r.created_at desc, r.id
       limit private.page_limit(coalesce(p_limit, 20))
      offset private.page_offset(p_offset)
    ) x;
$$;

-- Price talks ----------------------------------------------------------------

create function private.offer_state(p_offer_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'offer_id', o.id,
    'request_id', o.request_id,
    'status', o.status,
    'price_piastres', o.price_piastres,
    'counter_price_piastres', o.counter_price_piastres,
    'awaiting', o.awaiting,
    'counters_left', 3 - o.counter_count,
    'revisions_left', 2 - o.revision_count
  )
  from public.request_offers o
  where o.id = p_offer_id;
$$;

-- The consumer answers an offer with a lower price (at most three times
-- per offer; the technician must answer before the next one). The same
-- price again changes nothing.
create function public.counter_offer(p_offer_id uuid, p_price_piastres bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.service_requests;
  v_offer public.request_offers;
begin
  perform private.assert_active();
  if v_user_id is null
     or not exists (select 1 from public.consumer_profiles where id = v_user_id) then
    raise exception 'not_consumer' using errcode = '42501';
  end if;
  perform private.rate_limit('negotiate', 40, interval '1 hour');
  if p_price_piastres is null or p_price_piastres not between 100 and 100000000 then
    raise exception 'invalid_price' using errcode = '22023';
  end if;

  select r.* into v_request
    from public.service_requests r
    join public.request_offers o on o.request_id = r.id
   where o.id = p_offer_id and r.consumer_id = v_user_id
     for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  select * into v_offer from public.request_offers where id = p_offer_id for update;
  if v_offer.status <> 'sent' then
    raise exception 'offer_unavailable' using errcode = 'P0001';
  end if;

  if v_offer.awaiting = 'technician' then
    if v_offer.counter_price_piastres = p_price_piastres then
      return private.offer_state(v_offer.id);
    end if;
    raise exception 'counter_pending' using errcode = 'P0001';
  end if;
  if v_offer.arrive_at <= now() then
    raise exception 'offer_expired' using errcode = 'P0001';
  end if;
  if p_price_piastres >= v_offer.price_piastres then
    raise exception 'invalid_price' using errcode = '22023';
  end if;
  if v_offer.counter_count >= 3 then
    raise exception 'negotiation_limit' using errcode = 'P0001';
  end if;

  update public.request_offers
     set counter_price_piastres = p_price_piastres,
         awaiting = 'technician',
         counter_count = counter_count + 1
   where id = v_offer.id;
  insert into private.offer_events (offer_id, actor, kind, price_piastres)
  values (v_offer.id, 'consumer', 'counter', p_price_piastres);
  perform private.notify(
    v_offer.technician_id, 'technician', 'offer_countered', v_request.id, v_offer.id
  );
  return private.offer_state(v_offer.id);
end;
$$;

-- The technician lowers their price (at most twice per offer). With a
-- counter waiting, the new price must still be above it; at or below it
-- they should accept instead. The same price again changes nothing.
create function public.revise_offer(p_offer_id uuid, p_price_piastres bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.service_requests;
  v_offer public.request_offers;
begin
  perform private.assert_active();
  if v_user_id is null
     or not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  perform private.rate_limit('negotiate', 40, interval '1 hour');
  if p_price_piastres is null or p_price_piastres not between 100 and 100000000 then
    raise exception 'invalid_price' using errcode = '22023';
  end if;

  select r.* into v_request
    from public.service_requests r
    join public.request_offers o on o.request_id = r.id
   where o.id = p_offer_id and o.technician_id = v_user_id
     for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  select * into v_offer from public.request_offers where id = p_offer_id for update;
  if v_offer.status <> 'sent' then
    raise exception 'offer_unavailable' using errcode = 'P0001';
  end if;

  if p_price_piastres = v_offer.price_piastres
     and v_offer.awaiting = 'consumer' and v_offer.revision_count > 0 then
    return private.offer_state(v_offer.id);
  end if;
  if p_price_piastres >= v_offer.price_piastres
     or p_price_piastres <= coalesce(v_offer.counter_price_piastres, 0) then
    raise exception 'invalid_price' using errcode = '22023';
  end if;
  if v_offer.revision_count >= 2 then
    raise exception 'negotiation_limit' using errcode = 'P0001';
  end if;

  update public.request_offers
     set price_piastres = p_price_piastres,
         counter_price_piastres = null,
         awaiting = 'consumer',
         revision_count = revision_count + 1
   where id = v_offer.id;
  insert into private.offer_events (offer_id, actor, kind, price_piastres)
  values (v_offer.id, 'technician', 'revise', p_price_piastres);
  perform private.notify(v_request.consumer_id, 'consumer', 'offer_revised', v_request.id, v_offer.id);
  return private.offer_state(v_offer.id);
end;
$$;

-- The technician takes the consumer's counter-price: the offer becomes
-- that price and the consumer's pick goes through accept_offer's own code.
-- Returns the job id; repeating it returns the same job.
create function public.accept_counter(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.service_requests;
  v_offer public.request_offers;
  v_job_id uuid;
begin
  perform private.assert_active();
  if v_user_id is null
     or not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  perform private.rate_limit('negotiate', 40, interval '1 hour');

  select r.* into v_request
    from public.service_requests r
    join public.request_offers o on o.request_id = r.id
   where o.id = p_offer_id and o.technician_id = v_user_id
     for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select * into v_offer from public.request_offers where id = p_offer_id for update;

  if v_offer.status = 'accepted' and exists (
    select 1 from private.offer_events e
     where e.offer_id = v_offer.id and e.kind = 'accept_counter'
  ) then
    return v_request.job_id;
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  if v_offer.status <> 'sent' then
    raise exception 'offer_unavailable' using errcode = 'P0001';
  end if;
  if v_offer.awaiting <> 'technician' then
    raise exception 'no_counter' using errcode = 'P0001';
  end if;

  update public.request_offers
     set price_piastres = counter_price_piastres,
         counter_price_piastres = null,
         awaiting = 'consumer'
   where id = v_offer.id;
  insert into private.offer_events (offer_id, actor, kind, price_piastres)
  values (v_offer.id, 'technician', 'accept_counter', v_offer.counter_price_piastres);

  v_job_id := private.accept_offer_core(v_offer.id, v_request.consumer_id);
  perform private.notify(v_request.consumer_id, 'consumer', 'counter_accepted', v_request.id, v_offer.id);
  return v_job_id;
end;
$$;

-- The technician takes their offer back while the request is open and
-- before they are picked. The slot frees up; they can't offer again.
create function public.withdraw_offer(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.service_requests;
  v_offer public.request_offers;
begin
  perform private.assert_active();
  if v_user_id is null
     or not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  perform private.rate_limit('negotiate', 40, interval '1 hour');

  select r.* into v_request
    from public.service_requests r
    join public.request_offers o on o.request_id = r.id
   where o.id = p_offer_id and o.technician_id = v_user_id
     for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select * into v_offer from public.request_offers where id = p_offer_id for update;
  if v_offer.status = 'withdrawn' then
    return private.offer_state(v_offer.id);
  end if;
  if v_offer.status <> 'sent' then
    raise exception 'offer_unavailable' using errcode = 'P0001';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;

  update public.request_offers
     set status = 'withdrawn', counter_price_piastres = null, awaiting = 'consumer'
   where id = v_offer.id;
  insert into private.offer_events (offer_id, actor, kind, price_piastres)
  values (v_offer.id, 'technician', 'withdraw', null);
  perform private.notify(v_request.consumer_id, 'consumer', 'offer_withdrawn', v_request.id, v_offer.id);
  return private.offer_state(v_offer.id);
end;
$$;

-- An offer's state and price history, for the consumer it was made to and
-- the technician who made it; null for anyone else.
create function public.offer_thread(p_offer_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'offer', private.offer_state(o.id),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'kind', e.kind, 'actor', e.actor,
               'price_piastres', e.price_piastres, 'created_at', e.created_at
             ) order by e.id), '[]')
        from private.offer_events e
       where e.offer_id = o.id
    )
  )
  from public.request_offers o
  join public.service_requests r on r.id = o.request_id
 where o.id = p_offer_id
   and (o.technician_id = (select auth.uid()) or r.consumer_id = (select auth.uid()));
$$;

-- The consumer's request page: offers carry the price talks and leave out
-- withdrawn ones.
create or replace function public.request_details(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_details jsonb := private.request_details_impl(p_request_id);
begin
  if v_details is null then
    return null;
  end if;
  return v_details || jsonb_build_object(
    'technician_arriving_at', (
      select max(n.created_at)
        from public.notifications n
       where n.request_id = p_request_id
         and n.user_id = (select auth.uid())
         and n.role = 'consumer'
         and n.kind = 'technician_arriving'
    ),
    'offers', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', o.id,
               'price_piastres', o.price_piastres,
               'arrive_at', o.arrive_at,
               'note', o.note,
               'status', o.status,
               'distance_km', rr.distance_km,
               'created_at', o.created_at,
               'counter_price_piastres', o.counter_price_piastres,
               'awaiting', o.awaiting,
               'counters_left', 3 - o.counter_count,
               'technician', private.technician_card(o.technician_id)
             ) order by o.created_at), '[]')
        from public.request_offers o
        left join public.request_recipients rr
          on rr.request_id = o.request_id and rr.technician_id = o.technician_id
       where o.request_id = p_request_id and o.status <> 'withdrawn'
    )
  );
end;
$$;

-- Technician: edit what they offer ---------------------------------------------

-- Replaces the technician's services (with their starting prices), areas
-- and work days, and optionally their radius (5, 10 or 15 km), checked as
-- at sign-up. Their verification is untouched. Open requests that now match
-- are handed to them. Returns how many.
--   p_services: [{"service_id": "ac_inspection", "starting_price_piastres": 15000}, ...]
create function public.update_technician_offering(
  p_services jsonb,
  p_area_ids text[],
  p_work_days smallint[],
  p_service_radius_km smallint default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  perform private.assert_active();
  if v_user_id is null
     or not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  perform private.rate_limit('edit_offering', 10, interval '1 hour');

  if jsonb_typeof(p_services) is distinct from 'array'
     or jsonb_array_length(p_services) not between 1 and 40
     or exists (
       select 1
         from jsonb_array_elements(p_services) e
        where jsonb_typeof(e) <> 'object'
           or jsonb_typeof(e -> 'service_id') is distinct from 'string'
           or jsonb_typeof(e -> 'starting_price_piastres') is distinct from 'number'
           or (e ->> 'starting_price_piastres') !~ '^[0-9]{3,9}$'
     ) then
    raise exception 'invalid_services' using errcode = '22023';
  end if;
  if (
       select count(*) <> count(distinct s.service_id)
         from jsonb_to_recordset(p_services) as s (service_id text)
     )
     or exists (
       select 1
         from jsonb_to_recordset(p_services) as s (service_id text, starting_price_piastres bigint)
         left join public.services sv on sv.id = s.service_id and sv.is_active
         left join public.service_categories c on c.id = sv.category_id and c.is_active
        where c.id is null
           or s.starting_price_piastres not between 100 and 100000000
     ) then
    raise exception 'invalid_services' using errcode = '22023';
  end if;

  if coalesce(cardinality(p_area_ids), 0) not between 1 and 60
     or exists (
       select 1
         from unnest(p_area_ids) as a (id)
         left join public.service_areas sa on sa.id = a.id
        where sa.id is null
     ) then
    raise exception 'invalid_areas' using errcode = '22023';
  end if;

  if coalesce(cardinality(p_work_days), 0) not between 1 and 7
     or p_work_days is null
     or not (p_work_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]) then
    raise exception 'invalid_work_days' using errcode = '22023';
  end if;

  if p_service_radius_km is not null and p_service_radius_km not in (5, 10, 15) then
    raise exception 'invalid_radius' using errcode = '22023';
  end if;

  delete from public.technician_services ts
   where ts.technician_id = v_user_id
     and ts.service_id not in (
       select s.service_id from jsonb_to_recordset(p_services) as s (service_id text)
     );
  insert into public.technician_services (technician_id, service_id, starting_price_piastres)
  select v_user_id, s.service_id, s.starting_price_piastres
    from jsonb_to_recordset(p_services) as s (service_id text, starting_price_piastres bigint)
  on conflict (technician_id, service_id)
    do update set starting_price_piastres = excluded.starting_price_piastres;

  delete from public.technician_areas ta
   where ta.technician_id = v_user_id and ta.area_id <> all (p_area_ids);
  insert into public.technician_areas (technician_id, area_id)
  select distinct v_user_id, a.id from unnest(p_area_ids) as a (id)
  on conflict do nothing;

  update public.technician_profiles
     set work_days = (select array_agg(distinct d order by d) from unnest(p_work_days) as d),
         service_radius_km = coalesce(p_service_radius_km, service_radius_km)
   where id = v_user_id;

  return private.backfill_technician_requests(v_user_id);
end;
$$;

-- The technician's own offering, for the edit screen.
create function public.my_technician_offering()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'work_days', to_jsonb(t.work_days),
    'service_radius_km', t.service_radius_km,
    'base_area_id', t.base_area_id,
    'area_ids', (
      select coalesce(jsonb_agg(ta.area_id order by ta.area_id), '[]')
        from public.technician_areas ta where ta.technician_id = t.id
    ),
    'services', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'service_id', ts.service_id,
               'starting_price_piastres', ts.starting_price_piastres
             ) order by s.sort_order), '[]')
        from public.technician_services ts
        join public.services s on s.id = ts.service_id
       where ts.technician_id = t.id
    )
  )
  from public.technician_profiles t
  where t.id = (select auth.uid());
$$;

-- Consumer: browse technicians ---------------------------------------------------

-- What a consumer may see of a technician in a list or on their page: first
-- name and initial, avatar, rating, how long they've worked, what they
-- offer and from what price, and where. Never a phone, an address or a
-- location.
create function private.technician_listing(p_technician_id uuid, p_category_id text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'name', private.short_name(p.full_name),
    'avatar_path', t.avatar_path,
    'rating', (select round(avg(v.stars)::numeric, 1) from public.reviews v where v.technician_id = t.id),
    'review_count', (select count(*) from public.reviews v where v.technician_id = t.id),
    'years_experience', t.years_experience,
    'jobs_done', (
      select count(*)
        from public.service_requests r
        join public.jobs j on j.id = r.job_id
       where j.technician_id = t.id
         and r.status = 'assigned'
         and j.status in ('finished', 'paid')
    ),
    'area_id', t.base_area_id,
    'area_ids', (
      select coalesce(jsonb_agg(a.area_id order by a.area_id), '[]')
        from (
          select ta.area_id from public.technician_areas ta where ta.technician_id = t.id
          union
          select t.base_area_id
        ) a
    ),
    'services', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'service_id', ts.service_id,
               'category_id', s.category_id,
               'name_ar', s.name_ar,
               'starting_price_piastres', ts.starting_price_piastres
             ) order by s.category_id, s.sort_order), '[]')
        from public.technician_services ts
        join public.services s on s.id = ts.service_id and s.is_active
       where ts.technician_id = t.id
         and (p_category_id is null or s.category_id = p_category_id)
    ),
    'min_price_piastres', (
      select min(ts.starting_price_piastres)
        from public.technician_services ts
        join public.services s on s.id = ts.service_id and s.is_active
       where ts.technician_id = t.id
         and (p_category_id is null or s.category_id = p_category_id)
    )
  )
  from public.technician_profiles t
  join public.profiles p on p.id = t.id
  where t.id = p_technician_id;
$$;

-- Verified, non-suspended technicians, optionally for one category and an
-- area. p_sort: 'rating' (default), 'reviews', 'experience', 'jobs', 'price'.
-- At most 50 a page.
create function public.browse_technicians(
  p_category_id text default null,
  p_area_id text default null,
  p_sort text default 'rating',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_sort text := coalesce(p_sort, 'rating');
begin
  if not exists (select 1 from public.consumer_profiles where id = (select auth.uid())) then
    raise exception 'not_consumer' using errcode = '42501';
  end if;
  if v_sort not in ('rating', 'reviews', 'experience', 'jobs', 'price') then
    raise exception 'invalid_sort' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.service_categories where id = p_category_id and is_active
  ) then
    raise exception 'invalid_category' using errcode = '22023';
  end if;
  if p_area_id is not null and not exists (
    select 1 from public.service_areas where id = p_area_id
  ) then
    raise exception 'invalid_area' using errcode = '22023';
  end if;

  return (
    select coalesce(jsonb_agg(y.item order by y.rn), '[]')
      from (
        select x.item, row_number() over (
                 order by
                   (case when v_sort = 'rating' then x.rating end) desc nulls last,
                   (case when v_sort = 'reviews' then x.review_count end) desc nulls last,
                   (case when v_sort = 'experience' then x.years end) desc nulls last,
                   (case when v_sort = 'jobs' then x.jobs_done end) desc nulls last,
                   (case when v_sort = 'price' then x.min_price end) asc nulls last,
                   x.review_count desc, x.id
               ) as rn
          from (
            select t.id,
                   l.item,
                   (l.item ->> 'rating')::numeric as rating,
                   (l.item ->> 'review_count')::integer as review_count,
                   t.years_experience as years,
                   (l.item ->> 'jobs_done')::integer as jobs_done,
                   (l.item ->> 'min_price_piastres')::bigint as min_price
              from public.technician_profiles t
              join public.profiles p on p.id = t.id
              cross join lateral (
                select private.technician_listing(t.id, p_category_id) as item
              ) l
             where t.verification_status = 'approved'
               and p.suspended_at is null
               and (
                 p_category_id is null or exists (
                   select 1
                     from public.technician_services ts
                     join public.services s on s.id = ts.service_id and s.is_active
                    where ts.technician_id = t.id and s.category_id = p_category_id
                 )
               )
               and (p_area_id is null or private.technician_covers_area(t.id, p_area_id))
          ) x
         order by rn
         limit least(private.page_limit(coalesce(p_limit, 20)), 50)
        offset private.page_offset(p_offset)
      ) y
  );
end;
$$;

-- One technician's page: the listing plus the shop name and recent reviews
-- (stars, tags, comment; never who wrote them). Null unless they are
-- verified and not suspended.
create function public.technician_public_profile(p_technician_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.consumer_profiles where id = (select auth.uid())) then
    raise exception 'not_consumer' using errcode = '42501';
  end if;
  return (
    select private.technician_listing(t.id, null) || jsonb_build_object(
             'shop_name', t.shop_name,
             'reviews', (
               select coalesce(jsonb_agg(jsonb_build_object(
                        'stars', v.stars,
                        'tags', to_jsonb(v.tags),
                        'comment', v.comment,
                        'issue', r.issue,
                        'created_at', v.created_at
                      ) order by v.created_at desc), '[]')
                 from (
                   select * from public.reviews
                    where technician_id = t.id
                    order by created_at desc
                    limit 20
                 ) v
                 join public.service_requests r on r.id = v.request_id
             )
           )
      from public.technician_profiles t
      join public.profiles p on p.id = t.id
     where t.id = p_technician_id
       and t.verification_status = 'approved'
       and p.suspended_at is null
  );
end;
$$;

-- Grants -------------------------------------------------------------------------

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function
  public.browse_open_requests(text, integer, integer),
  public.counter_offer(uuid, bigint),
  public.revise_offer(uuid, bigint),
  public.accept_counter(uuid),
  public.withdraw_offer(uuid),
  public.offer_thread(uuid),
  public.update_technician_offering(jsonb, text[], smallint[], smallint),
  public.my_technician_offering(),
  public.browse_technicians(text, text, text, integer, integer),
  public.technician_public_profile(uuid)
from public, anon;

grant execute on function
  public.browse_open_requests(text, integer, integer),
  public.counter_offer(uuid, bigint),
  public.revise_offer(uuid, bigint),
  public.accept_counter(uuid),
  public.withdraw_offer(uuid),
  public.offer_thread(uuid),
  public.update_technician_offering(jsonb, text[], smallint[], smallint),
  public.my_technician_offering(),
  public.browse_technicians(text, text, text, integer, integer),
  public.technician_public_profile(uuid)
to authenticated;
