-- Warranty visits: for 14 days after a job finished through the app, the
-- customer can ask the same technician back for free. Free for both sides:
-- the customer's request costs no use and the technician's job holds and
-- takes none. The visit is booked at once (no offer to wait for); the
-- technician finds it among his jobs like any other pick.

alter table public.service_requests
  add column warranty_of uuid references public.service_requests (id) on delete set null;

-- One visit at a time per job.
create unique index service_requests_one_warranty
  on public.service_requests (warranty_of)
  where warranty_of is not null and status in ('open', 'assigned');

-- A warranty visit is the only offer that may cost nothing.
alter table public.request_offers drop constraint request_offers_price_piastres_check;
alter table public.request_offers add constraint request_offers_price_piastres_check
  check (price_piastres = 0 or price_piastres between 100 and 100000000);

create function private.guard_free_offer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.price_piastres < 100 and not exists (
    select 1 from public.service_requests r
     where r.id = new.request_id and r.warranty_of is not null
  ) then
    raise exception 'invalid_price' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke execute on function private.guard_free_offer() from public, anon, authenticated;

create trigger request_offers_guard_free
  before insert or update of price_piastres on public.request_offers
  for each row execute function private.guard_free_offer();

create or replace function private.take_use(p_user_id uuid, p_role public.user_role)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_credits integer;
begin
  if p_role = 'consumer' then
    -- A warranty visit is free: its request sets this for the one call.
    if current_setting('private.free_request', true) = 'on' then
      return;
    end if;
    update public.consumer_profiles
       set request_credits = request_credits - 1
     where id = p_user_id and request_credits > 0;
    if not found then
      raise exception 'no_credits' using errcode = 'P0001';
    end if;
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (p_user_id, p_role, -1, 'request_sent');
    return;
  end if;

  select job_credits into v_credits
    from public.technician_profiles
   where id = p_user_id
   for update;
  if v_credits is null or v_credits <= (
    select count(*)
      from public.jobs j
     where j.technician_id = p_user_id
       and j.source = 'platform'
       and j.status in ('unconfirmed', 'confirmed', 'started')
       and not exists (
         select 1 from public.service_requests r
          where r.job_id = j.id and r.repeat_booking
       )
  ) then
    raise exception 'no_credits' using errcode = 'P0001';
  end if;
end;
$$;

create or replace function private.accept_offer_core(p_offer_id uuid, p_user_id uuid)
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

-- A warranty visit isn't one of the jobs that earn the gift.
create or replace function private.reward_loyal_consumer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
begin
  select * into v_request from public.service_requests where job_id = new.id;
  if not found or v_request.warranty_of is not null then
    return null;
  end if;
  if (
    select count(*)
      from public.service_requests r
      join public.jobs j on j.id = r.job_id
     where r.consumer_id = v_request.consumer_id
       and r.warranty_of is null
       and j.status in ('finished', 'paid')
  ) % 3 <> 0 then
    return null;
  end if;
  update public.consumer_profiles
     set request_credits = request_credits + 1
   where id = v_request.consumer_id;
  if found then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (v_request.consumer_id, 'consumer', 1, 'loyalty_reward');
    perform private.notify(
      v_request.consumer_id, 'consumer', 'loyalty_reward', v_request.id
    );
  end if;
  return null;
end;
$$;

-- Whether the request's job can still be covered, and until when.
create function private.warranty_until(p_request_id uuid, p_consumer_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select j.finished_at + interval '14 days'
    from public.service_requests r
    join public.jobs j on j.id = r.job_id
   where r.id = p_request_id
     and r.consumer_id = p_consumer_id
     and r.warranty_of is null
     and j.source = 'platform'
     and j.status in ('finished', 'paid')
     and j.finished_at > now() - interval '14 days'
     and not exists (
       select 1 from public.service_requests w
        where w.warranty_of = r.id and w.status in ('open', 'assigned')
     );
$$;
revoke execute on function private.warranty_until(uuid, uuid) from public, anon, authenticated;

-- The request page learns whether a visit can be asked for, and whether the
-- request is one.
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
$$;

-- Books a warranty visit for the job behind [p_original]: a request like any
-- other, to the same technician, that costs the customer no use, picked at
-- once with a free offer.
create function public.request_warranty_visit(
  p_original uuid,
  p_issue public.request_issue,
  p_description text,
  p_photo_paths text[],
  p_address_id uuid,
  p_preferred_on date,
  p_window public.request_window
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_category text;
  v_technician_id uuid;
  v_created jsonb;
  v_request_id uuid;
  v_offer_id uuid;
  v_job_id uuid;
  v_range tstzrange;
begin
  perform private.assert_active();
  if private.warranty_until(p_original, v_user_id) is null then
    raise exception 'warranty_unavailable' using errcode = 'P0001';
  end if;
  select r.category_id, j.technician_id into v_category, v_technician_id
    from public.service_requests r
    join public.jobs j on j.id = r.job_id
   where r.id = p_original;
  -- Only the same technician, as long as he is still verified and works in
  -- the trade: the request must not reach anyone else.
  if not exists (
    select 1
      from public.technician_profiles t
     where t.id = v_technician_id
       and t.verification_status = 'approved'
       and not exists (
         select 1 from public.profiles pr
          where pr.id = t.id and pr.suspended_at is not null
       )
       and exists (
         select 1
           from public.technician_services ts
           join public.services s on s.id = ts.service_id and s.is_active
          where ts.technician_id = t.id and s.category_id = v_category
       )
  ) then
    raise exception 'technician_unavailable' using errcode = 'P0001';
  end if;

  -- Sent like any request, but with no use taken from the customer.
  perform set_config('private.free_request', 'on', true);
  v_created := public.create_service_request(
    v_category, p_issue, p_description, p_photo_paths, p_address_id,
    p_preferred_on, p_window, v_technician_id
  );
  perform set_config('private.free_request', 'off', true);
  v_request_id := (v_created ->> 'id')::uuid;

  update public.service_requests
     set warranty_of = p_original, credit_held = false
   where id = v_request_id;

  v_range := private.window_range(p_preferred_on, p_window);
  insert into public.request_offers (
    request_id, technician_id, price_piastres, arrive_at
  )
  values (
    v_request_id, v_technician_id, 0,
    least(upper(v_range) - interval '1 minute',
          greatest(lower(v_range), now() + interval '1 hour'))
  )
  returning id into v_offer_id;
  v_job_id := private.accept_offer_core(v_offer_id, v_user_id);
  update public.job_items set title = 'زيارة ضمان' where job_id = v_job_id;

  -- Nobody is told of an offer or a new request: the visit is just booked.
  delete from public.notifications
   where request_id = v_request_id and kind in ('offer_received', 'new_request');
  return jsonb_build_object('id', v_request_id, 'sent_to', 1);
end;
$$;

revoke execute on function public.request_warranty_visit(
  uuid, public.request_issue, text, text[], uuid, date, public.request_window
) from public, anon;
grant execute on function public.request_warranty_visit(
  uuid, public.request_issue, text, text[], uuid, date, public.request_window
) to authenticated;
