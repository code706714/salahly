-- Urgent requests ("دلوقتي"): the consumer presses one button, the request goes
-- only to the nearest technicians who said they are free right now, and
-- the price is known before sending: the technician's offer plus a fixed
-- urgent fee that is shown first and copied onto the request.
--
--   * A technician switches "available now" on for up to four hours.
--   * An urgent request lives 30 minutes, reaches the ten nearest available
--     technicians, and offers must promise to arrive within three hours.
--   * The fee comes from app_settings (change it with an update there) and
--     lands on the job as its own line, so the invoice shows it.
--   * Run 20261013090000_urgent_enums.sql on its own first.

alter table public.app_settings
  add column urgent_fee_piastres bigint not null default 10000
    check (urgent_fee_piastres between 0 and 1000000);

alter table public.technician_profiles add column available_until timestamptz;

alter table public.service_requests
  add column urgent boolean not null default false,
  add column urgent_fee_piastres bigint not null default 0 check (urgent_fee_piastres >= 0);

-- Decided by the server, never by the client: a plain insert can't claim it.
create function private.reset_urgent_flags()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_setting('private.urgent_request', true) is distinct from 'on' then
    new.urgent := false;
    new.urgent_fee_piastres := 0;
  end if;
  return new;
end;
$$;

create trigger service_requests_reset_urgent before insert on public.service_requests
  for each row execute function private.reset_urgent_flags();

create function private.technician_available_now(p_technician_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select available_until > now() from public.technician_profiles where id = p_technician_id),
    false
  );
$$;

-- Switches "available now" on (four hours) or off. Returns until when.
create function public.set_available_now(p_on boolean)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  perform private.assert_active();
  if p_on is null then
    raise exception 'invalid_value' using errcode = '22023';
  end if;
  update public.technician_profiles
     set available_until = case when p_on then now() + interval '4 hours' end
   where id = (select auth.uid()) and verification_status = 'approved'
  returning available_until into v_until;
  if not found then
    raise exception 'not_verified' using errcode = '42501';
  end if;
  return v_until;
end;
$$;

create function public.my_availability()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select available_until
    from public.technician_profiles
   where id = (select auth.uid()) and available_until > now();
$$;

-- The fee and how many technicians are free in the area right now.
create function public.urgent_info(p_category_id text, p_area_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'fee_piastres', (select urgent_fee_piastres from public.app_settings),
    'available_now', (
      select count(*)
        from public.technician_profiles t
       where auth.uid() is not null
         and private.technician_available_now(t.id)
         and private.technician_serves(t.id, p_category_id, p_area_id)
    )
  );
$$;

-- The ten nearest technicians who are free now. Returns how many.
create function private.dispatch_urgent_request(p_request_id uuid)
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
  select v_request.id, x.id, x.distance
    from (
      select t.id,
             private.distance_km(t.base_lat, t.base_lng, v_area.center_lat, v_area.center_lng) as distance
        from public.technician_profiles t
       where t.id <> v_request.consumer_id
         and private.technician_available_now(t.id)
         and private.technician_serves(t.id, v_request.category_id, v_request.area_id)
       order by distance, t.id
       limit 10
    ) x;

  get diagnostics v_added = row_count;
  return v_added;
end;
$$;

-- An urgent request is meant only for technicians who are free now.
create or replace function private.request_meant_for(p_request_id uuid, p_technician_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $function$
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
       and (not r.urgent or private.technician_available_now(p_technician_id))
       and private.technician_serves(p_technician_id, r.category_id, r.area_id)
  );
$function$;

-- The ten get a louder notification.
create or replace function private.notify_new_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    new.technician_id, 'technician',
    case when (select urgent from public.service_requests where id = new.request_id)
         then 'urgent_request' else 'new_request' end::public.notification_kind,
    new.request_id
  );
  return null;
end;
$$;

create or replace function private.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
set search_path = ''
as $function$
  select p_kind::text = any (array[
    'offer_received', 'technician_arriving', 'job_confirmed', 'job_started',
    'job_finished', 'price_change', 'request_cancelled_by_technician',
    'request_expired', 'new_request', 'offer_picked',
    'request_cancelled_by_consumer', 'verification_approved',
    'verification_rejected', 'topup_approved', 'topup_rejected',
    'offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted',
    'loyalty_reward', 'maintenance_reminder', 'urgent_request'
  ]);
$function$;

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
as $function$
declare
  v_user_id uuid := auth.uid();
  v_address public.consumer_addresses;
  v_range tstzrange;
  v_photos text[] := coalesce(p_photo_paths, '{}');
  v_request_id uuid;
  v_sent integer := 0;
  v_urgent boolean := current_setting('private.urgent_request', true) = 'on';
  v_fee bigint := 0;
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
  if v_urgent then
    -- Free now means free within the half hour the request lives; a request
    -- for one technician is never urgent.
    if p_technician_id is not null then
      raise exception 'invalid_time' using errcode = '22023';
    end if;
    v_range := tstzrange(now(), now() + interval '30 minutes');
    select urgent_fee_piastres into v_fee from public.app_settings;
  else
    v_range := private.window_range(p_preferred_on, p_window);
    if upper(v_range) < now() + interval '1 hour'
       or p_preferred_on > (now() at time zone 'Africa/Cairo')::date + 6 then
      raise exception 'invalid_time' using errcode = '22023';
    end if;
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
    preferred_technician_id, urgent, urgent_fee_piastres
  )
  values (
    v_user_id, p_category_id, p_issue, private.normalize_text(p_description),
    v_photos, v_address.area_id, v_address.label, v_address.details,
    p_preferred_on, p_window, upper(v_range), p_technician_id, v_urgent, v_fee
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
  elsif v_urgent then
    v_sent := private.dispatch_urgent_request(v_request_id);
    if v_sent = 0 then
      raise exception 'no_technician_available' using errcode = 'P0001';
    end if;
  else
    v_sent := private.dispatch_request(v_request_id);
  end if;

  return jsonb_build_object('id', v_request_id, 'sent_to', v_sent);
end;
$function$;

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
as $function$
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
     or (v_request.urgent and p_arrive_at > now() + interval '3 hours')
     or (
       not v_request.urgent
       and not private.window_range(v_request.preferred_on, v_request.time_window) @> p_arrive_at
     ) then
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
$function$;

create or replace function private.accept_offer_core(p_offer_id uuid, p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
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

  -- A repeat booking or a warranty visit holds none of the technician's uses.
  if not v_request.repeat_booking then
    begin
      perform private.take_use(v_offer.technician_id, 'technician');
    exception when raise_exception then
      raise exception 'technician_unavailable' using errcode = 'P0001';
    end;
  end if;

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

  if v_request.urgent_fee_piastres > 0 then
    insert into public.job_items (id, technician_id, job_id, title, unit_price_piastres)
    values (
      gen_random_uuid(), v_offer.technician_id, v_job_id, 'رسوم استعجال',
      v_request.urgent_fee_piastres
    );
  end if;

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
$function$;

create or replace function private.request_for_technician(p_request_id uuid, p_technician_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $function$
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
    'urgent', r.urgent,
    'urgent_fee_piastres', r.urgent_fee_piastres,
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
$function$;

create or replace function public.request_details(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_details jsonb := private.request_details_impl(p_request_id);
begin
  if v_details is null then
    return null;
  end if;
  return v_details || jsonb_build_object(
    'urgent', (select urgent from public.service_requests where id = p_request_id),
    'urgent_fee_piastres', (
      select urgent_fee_piastres from public.service_requests where id = p_request_id
    ),
    'warranty_until', private.warranty_until(p_request_id, (select auth.uid())),
    'is_warranty', exists (
      select 1 from public.service_requests
       where id = p_request_id and warranty_of is not null
    ),
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
$function$;

-- Sends an urgent request: today, any time, to the technicians free now.
-- Refused (no_technician_available) when nobody is.
create function public.create_urgent_request(
  p_category_id text,
  p_issue public.request_issue,
  p_description text,
  p_photo_paths text[],
  p_address_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_created jsonb;
begin
  perform set_config('private.urgent_request', 'on', true);
  v_created := public.create_service_request(
    p_category_id, p_issue, p_description, p_photo_paths, p_address_id,
    (now() at time zone 'Africa/Cairo')::date, 'any_time', null
  );
  perform set_config('private.urgent_request', 'off', true);
  return v_created;
end;
$$;

revoke execute on function public.set_available_now(boolean) from public, anon;
grant execute on function public.set_available_now(boolean) to authenticated;
revoke execute on function public.my_availability() from public, anon;
grant execute on function public.my_availability() to authenticated;
revoke execute on function public.urgent_info(text, text) from public, anon;
grant execute on function public.urgent_info(text, text) to authenticated;
revoke execute on function public.create_urgent_request(
  text, public.request_issue, text, text[], uuid
) from public, anon;
grant execute on function public.create_urgent_request(
  text, public.request_issue, text, text[], uuid
) to authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
