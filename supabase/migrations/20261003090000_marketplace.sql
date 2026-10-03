-- The marketplace: a consumer asks for a technician, nearby verified
-- technicians send offers, the consumer picks one, and the job lands in
-- that technician's own records (and phone) as a platform job.
--
-- Privacy: technicians never read requests directly. They see a request
-- through technician_request(), which returns the area and the consumer's
-- first name only. The exact address and phone number reach a technician
-- only when the consumer picks their offer, as a customer and job in their
-- own records.
--
-- Uses: a consumer's free request is held when the request is sent and
-- given back if it is cancelled before a pick or ends with no pick. A
-- technician's free job is taken when the consumer picks their offer and
-- given back if the consumer cancels afterwards.

create type public.request_issue as enum (
  'not_cooling', 'leaking', 'noisy', 'needs_cleaning', 'installation', 'other'
);
-- Cairo time: morning 9-12, noon 12-3, afternoon 3-6, evening 6-9,
-- any_time 9-9.
create type public.request_window as enum (
  'morning', 'noon', 'afternoon', 'evening', 'any_time'
);
create type public.request_status as enum ('open', 'assigned', 'cancelled', 'expired');
create type public.offer_status as enum ('sent', 'accepted', 'not_chosen');
create type public.review_tag as enum (
  'on_time', 'clean_work', 'fair_price', 'explained', 'respectful'
);
create type public.consumer_payment as enum ('cash', 'instapay', 'not_yet');
create type public.complaint_reason as enum (
  'no_show_or_late', 'price_raised', 'poor_work', 'bad_conduct', 'other'
);

-- A consumer's answer to a price change on a platform job.
alter type public.quote_status add value 'declined';

create table public.consumer_addresses (
  id uuid primary key default gen_random_uuid(),
  consumer_id uuid not null references public.consumer_profiles (id) on delete cascade,
  label text not null check (
    char_length(label) between 1 and 30
    and label = btrim(label)
    and label !~ '[[:cntrl:]]'
  ),
  area_id text not null references public.service_areas (id),
  details text not null check (
    char_length(details) between 3 and 300
    and details !~ '[[:cntrl:]]'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index consumer_addresses_consumer_idx on public.consumer_addresses (consumer_id);

create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  consumer_id uuid not null references public.consumer_profiles (id) on delete cascade,
  category_id text not null references public.service_categories (id),
  issue public.request_issue not null,
  description text check (char_length(description) <= 1000),
  photo_paths text[] not null default '{}' check (cardinality(photo_paths) <= 4),
  area_id text not null references public.service_areas (id),
  -- Copied from the address book when sent; only the chosen technician
  -- ever sees them.
  address_label text not null,
  address_details text not null,
  preferred_on date not null,
  time_window public.request_window not null,
  expires_at timestamptz not null,
  -- "Book them again": sent to this technician first.
  preferred_technician_id uuid references public.technician_profiles (id) on delete set null,
  status public.request_status not null default 'open',
  chosen_offer_id uuid,
  chosen_at timestamptz,
  job_id uuid references public.jobs (id) on delete set null,
  cancelled_at timestamptz,
  cancelled_by public.user_role,
  widened_at timestamptz,
  -- Whether the consumer's free request is still held for this request.
  credit_held boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index service_requests_consumer_idx
  on public.service_requests (consumer_id, created_at desc);
create index service_requests_open_idx
  on public.service_requests (expires_at) where status = 'open';
create index service_requests_job_idx on public.service_requests (job_id);

-- Who a request was sent to, and what they did with it.
create table public.request_recipients (
  request_id uuid not null references public.service_requests (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  distance_km numeric(5, 1) not null,
  sent_at timestamptz not null default now(),
  seen_at timestamptz,
  dismissed_at timestamptz,
  primary key (request_id, technician_id)
);

create index request_recipients_technician_idx
  on public.request_recipients (technician_id, sent_at desc);

create table public.request_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  service_id text references public.services (id),
  price_piastres bigint not null check (price_piastres between 100 and 100000000),
  arrive_at timestamptz not null,
  note text check (char_length(note) <= 300),
  status public.offer_status not null default 'sent',
  created_at timestamptz not null default now(),
  unique (request_id, technician_id)
);

create index request_offers_technician_idx on public.request_offers (technician_id, status);

alter table public.service_requests
  add constraint service_requests_chosen_offer_fkey
  foreign key (chosen_offer_id) references public.request_offers (id);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.service_requests (id) on delete cascade,
  consumer_id uuid not null references public.consumer_profiles (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  tags public.review_tag[] not null default '{}',
  comment text check (char_length(comment) <= 500),
  paid_with public.consumer_payment not null,
  created_at timestamptz not null default now()
);

create index reviews_technician_idx on public.reviews (technician_id, created_at desc);

create table public.complaints (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests (id) on delete cascade,
  consumer_id uuid not null references public.consumer_profiles (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  reason public.complaint_reason not null,
  details text check (char_length(details) <= 1000),
  photo_path text,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index complaints_one_open_idx
  on public.complaints (request_id) where resolved_at is null;

create trigger consumer_addresses_set_updated_at
  before update on public.consumer_addresses
  for each row execute function public.set_updated_at();
create trigger service_requests_set_updated_at
  before update on public.service_requests
  for each row execute function public.set_updated_at();

alter table public.consumer_addresses enable row level security;
alter table public.service_requests enable row level security;
alter table public.request_recipients enable row level security;
alter table public.request_offers enable row level security;
alter table public.reviews enable row level security;
alter table public.complaints enable row level security;

revoke all on table
  public.consumer_addresses, public.service_requests, public.request_recipients,
  public.request_offers, public.reviews, public.complaints
from anon, authenticated;

-- Each side reads its own rows; everything that crosses sides goes
-- through the functions below.
grant select on table
  public.consumer_addresses, public.service_requests, public.request_offers,
  public.reviews, public.complaints
to authenticated;

create policy "Consumers read their own addresses"
  on public.consumer_addresses for select to authenticated
  using (consumer_id = (select auth.uid()));
create policy "Consumers read their own requests"
  on public.service_requests for select to authenticated
  using (consumer_id = (select auth.uid()));
create policy "Technicians read their own offers"
  on public.request_offers for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Reviews are read by the technician and the consumer who wrote them"
  on public.reviews for select to authenticated
  using (technician_id = (select auth.uid()) or consumer_id = (select auth.uid()));
create policy "Consumers read their own complaints"
  on public.complaints for select to authenticated
  using (consumer_id = (select auth.uid()));

-- Request photos: private, uploaded by consumers into their own folder,
-- viewable by the consumer and the technicians the request was sent to.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('request-photos', 'request-photos', false, 3145728, array['image/jpeg', 'image/png', 'image/webp']);

create function guard.is_consumer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.consumer_profiles where id = (select auth.uid())
  );
$$;

create function guard.can_view_request_photo(p_name text)
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
          join public.request_recipients rr on rr.request_id = r.id
         where p_name = any (r.photo_paths)
           and rr.technician_id = (select auth.uid())
      );
$$;

revoke execute on function guard.is_consumer(), guard.can_view_request_photo(text)
  from public, anon;
grant execute on function guard.is_consumer(), guard.can_view_request_photo(text)
  to authenticated;

create policy "Consumers upload request photos to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'request-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.is_consumer())
    and guard.upload_quota_left(bucket_id)
  );

create policy "Request photos are seen by their consumer and the technicians asked"
  on storage.objects for select to authenticated
  using (bucket_id = 'request-photos' and guard.can_view_request_photo(name));

-- Helpers ----------------------------------------------------------------

create function private.distance_km(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round((
    6371 * 2 * asin(sqrt(
      power(sin(radians(p_lat2 - p_lat1) / 2), 2)
      + cos(radians(p_lat1)) * cos(radians(p_lat2))
        * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
    ))
  )::numeric, 1);
$$;

-- The hours of a time window on a day, in Cairo time.
create function private.window_range(p_on date, p_window public.request_window)
returns tstzrange
language sql
stable
set search_path = ''
as $$
  select tstzrange(
    (p_on + make_time(h.first_hour, 0, 0)) at time zone 'Africa/Cairo',
    (p_on + make_time(h.last_hour, 0, 0)) at time zone 'Africa/Cairo'
  )
  from (
    select
      case p_window
        when 'morning' then 9 when 'noon' then 12 when 'afternoon' then 15
        when 'evening' then 18 else 9
      end as first_hour,
      case p_window
        when 'morning' then 12 when 'noon' then 15 when 'afternoon' then 18
        else 21
      end as last_hour
  ) h;
$$;

-- "نورهان م.": what the other side sees of someone's name.
create function private.short_name(p_full_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when w[2] is null then w[1]
    else w[1] || ' ' || left(w[2], 1) || '.'
  end
  from regexp_split_to_array(btrim(p_full_name), '\s+') w;
$$;

-- An open request whose time has passed reads as expired, even before the
-- housekeeping job records it.
create function private.request_state(p_status public.request_status, p_expires_at timestamptz)
returns public.request_status
language sql
stable
set search_path = ''
as $$
  select case
    when p_status = 'open' and p_expires_at <= now() then 'expired'::public.request_status
    else p_status
  end;
$$;

-- Uses (free or bought). Milestone 4 records each movement in a ledger;
-- these two functions are the only places that change the balances.
create function private.take_use(p_user_id uuid, p_role public.user_role)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits - 1
     where id = p_user_id and request_credits > 0;
  else
    update public.technician_profiles
       set job_credits = job_credits - 1
     where id = p_user_id and job_credits > 0;
  end if;
  if not found then
    raise exception 'no_credits' using errcode = 'P0001';
  end if;
end;
$$;

create function private.return_use(p_user_id uuid, p_role public.user_role)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits + 1
     where id = p_user_id;
  else
    update public.technician_profiles
       set job_credits = job_credits + 1
     where id = p_user_id;
  end if;
end;
$$;

-- Sends a request to up to five more technicians: first those who cover
-- its area, nearest first; when widening, anyone within 20 km. Returns how
-- many were added.
create function private.dispatch_request(p_request_id uuid, p_wide boolean)
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
  select v_request.id, c.id, c.distance_km
    from (
      select t.id,
             private.distance_km(t.base_lat, t.base_lng, v_area.center_lat, v_area.center_lng)
               as distance_km
        from public.technician_profiles t
       where t.verification_status = 'approved'
         and t.id <> v_request.consumer_id
         and extract(isodow from v_request.preferred_on)::smallint = any (t.work_days)
         and exists (
           select 1
             from public.technician_services ts
             join public.services s on s.id = ts.service_id and s.is_active
            where ts.technician_id = t.id and s.category_id = v_request.category_id
         )
         and (
           p_wide
           or t.base_area_id = v_request.area_id
           or exists (
             select 1 from public.technician_areas ta
              where ta.technician_id = t.id and ta.area_id = v_request.area_id
           )
         )
         and not exists (
           select 1 from public.request_recipients rr
            where rr.request_id = v_request.id and rr.technician_id = t.id
         )
    ) c
   where not p_wide or c.distance_km <= 20
   order by c.distance_km, c.id
   limit 5;

  get diagnostics v_added = row_count;
  return v_added;
end;
$$;

-- Records requests whose time passed without a pick (giving the held use
-- back), and widens requests that got no offer within two hours.
create function private.marketplace_housekeeping()
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
       and r.created_at <= now() - interval '2 hours'
       and not exists (select 1 from public.request_offers o where o.request_id = r.id)
     for update skip locked
  loop
    perform private.dispatch_request(v_request.id, true);
    update public.service_requests set widened_at = now() where id = v_request.id;
  end loop;
end;
$$;

-- Platform jobs ---------------------------------------------------------

-- Rules every write to a platform job follows, whoever writes it: it
-- can't be deleted or moved to another customer, only the consumer
-- accepts or declines a price change, and a job the consumer cancelled
-- stays cancelled. A phone echoing a quote the consumer already answered
-- keeps the consumer's answer.
create function private.guard_platform_job()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.source <> 'platform' then
    return new;
  end if;
  if new.deleted_at is not null and old.deleted_at is null
     or new.customer_id <> old.customer_id then
    raise exception 'platform_job_locked' using errcode = '42501';
  end if;
  if old.status = 'cancelled' and new.status <> 'cancelled' and exists (
    select 1 from public.service_requests r
     where r.job_id = old.id and r.cancelled_by = 'consumer'
  ) then
    raise exception 'cancelled_by_customer' using errcode = '42501';
  end if;
  if new.quote_status = 'sent'
     and old.quote_status in ('accepted', 'declined')
     and new.quote_sent_at is not distinct from old.quote_sent_at then
    new.quote_status := old.quote_status;
  elsif new.quote_status in ('accepted', 'declined')
     and (new.quote_status, new.quote_sent_at) is distinct from (old.quote_status, old.quote_sent_at)
     and current_setting('salahly.answering_customer', true) is distinct from 'on' then
    raise exception 'quote_needs_customer' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger jobs_guard_platform before update on public.jobs
  for each row execute function private.guard_platform_job();

-- When the technician cancels a platform job, the request ends and the
-- consumer gets their use back.
create function private.platform_job_cancelled()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_request public.service_requests;
begin
  update public.service_requests
     set status = 'cancelled', cancelled_at = now(), cancelled_by = 'technician'
   where job_id = new.id and status = 'assigned'
  returning * into v_request;
  if found then
    perform private.return_use(v_request.consumer_id, 'consumer');
  end if;
  return null;
end;
$$;

create trigger jobs_platform_cancelled after update of status on public.jobs
  for each row
  when (old.source = 'platform' and new.status = 'cancelled' and old.status <> 'cancelled')
  execute function private.platform_job_cancelled();

-- What a consumer sees of a technician on an offer.
create function private.technician_card(p_technician_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'name', p.full_name,
    'shop_name', t.shop_name,
    'avatar_path', t.avatar_path,
    'years_experience', t.years_experience,
    'verified', t.verification_status = 'approved',
    'rating', (select round(avg(stars)::numeric, 1) from public.reviews where technician_id = t.id),
    'review_count', (select count(*) from public.reviews where technician_id = t.id),
    'jobs_done', (
      select count(*)
        from public.service_requests r
        join public.jobs j on j.id = r.job_id
       where j.technician_id = t.id and j.status in ('finished', 'paid')
    )
  )
  from public.technician_profiles t
  join public.profiles p on p.id = t.id
  where t.id = p_technician_id;
$$;

-- Consumer functions ------------------------------------------------------

create function public.save_consumer_address(
  p_id uuid,
  p_label text,
  p_area_id text,
  p_details text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null or not exists (select 1 from public.consumer_profiles where id = v_user_id) then
    raise exception 'not_consumer' using errcode = '42501';
  end if;
  if not exists (select 1 from public.service_areas where id = p_area_id) then
    raise exception 'invalid_area' using errcode = '22023';
  end if;
  if p_id is null then
    if (select count(*) from public.consumer_addresses where consumer_id = v_user_id) >= 10 then
      raise exception 'limit_reached' using errcode = '54000';
    end if;
    insert into public.consumer_addresses (consumer_id, label, area_id, details)
    values (
      v_user_id, private.normalize_text(p_label), p_area_id, private.normalize_text(p_details)
    )
    returning id into v_id;
  else
    update public.consumer_addresses
       set label = private.normalize_text(p_label),
           area_id = p_area_id,
           details = private.normalize_text(p_details)
     where id = p_id and consumer_id = v_user_id
    returning id into v_id;
    if v_id is null then
      raise exception 'not_found' using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;

create function public.delete_consumer_address(p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.consumer_addresses where id = p_id and consumer_id = auth.uid();
$$;

-- "24 فني في منطقتك".
create function public.available_technician_count(p_category_id text, p_area_id text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
    from public.technician_profiles t
   where auth.uid() is not null
     and t.verification_status = 'approved'
     and (
       t.base_area_id = p_area_id
       or exists (
         select 1 from public.technician_areas ta
          where ta.technician_id = t.id and ta.area_id = p_area_id
       )
     )
     and exists (
       select 1
         from public.technician_services ts
         join public.services s on s.id = ts.service_id and s.is_active
        where ts.technician_id = t.id and s.category_id = p_category_id
     );
$$;

-- Sends a request and returns its id and how many technicians got it.
create function public.create_service_request(
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
  if not exists (
    select 1 from public.service_categories where id = p_category_id and is_active
  ) then
    raise exception 'invalid_category' using errcode = '22023';
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

  -- Asked for someone they hired before: only that technician first, as
  -- long as they still offer this service; others join after two hours.
  if p_technician_id is not null and exists (
    select 1
      from public.technician_profiles t
     where t.id = p_technician_id
       and t.id <> v_user_id
       and t.verification_status = 'approved'
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
    v_sent := private.dispatch_request(v_request_id, false);
  end if;

  return jsonb_build_object('id', v_request_id, 'sent_to', v_sent);
end;
$$;

-- The consumer's requests, newest first, with what the list and the home
-- screen show about each.
create function public.my_requests()
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
        'offer_count', (select count(*) from public.request_offers o where o.request_id = r.id),
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

-- Everything the consumer's request screens show: the request, how far it
-- got, the offers, and once a technician is picked their phone number, the
-- job's progress, any price change, the invoice, the review and the
-- complaint.
create function public.request_details(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
  v_offer public.request_offers;
  v_job public.jobs;
  v_items jsonb;
  v_total bigint;
begin
  select * into v_request
    from public.service_requests
   where id = p_request_id and consumer_id = auth.uid();
  if not found then
    return null;
  end if;
  select * into v_offer from public.request_offers where id = v_request.chosen_offer_id;
  select * into v_job from public.jobs where id = v_request.job_id;
  if v_job.id is not null then
    select coalesce(jsonb_agg(jsonb_build_object(
             'title', i.title,
             'unit_price_piastres', i.unit_price_piastres,
             'quantity', i.quantity,
             'added_later', i.updated_at > v_request.chosen_at
           ) order by i.sort_order, i.created_at), '[]'),
           coalesce(sum(i.unit_price_piastres * i.quantity), 0)
      into v_items, v_total
      from public.job_items i
     where i.job_id = v_job.id and i.deleted_at is null;
  end if;

  return jsonb_build_object(
    'id', v_request.id,
    'category_id', v_request.category_id,
    'issue', v_request.issue,
    'description', v_request.description,
    'photo_paths', to_jsonb(v_request.photo_paths),
    'area_id', v_request.area_id,
    'address_label', v_request.address_label,
    'address_details', v_request.address_details,
    'preferred_on', v_request.preferred_on,
    'time_window', v_request.time_window,
    'expires_at', v_request.expires_at,
    'status', private.request_state(v_request.status, v_request.expires_at),
    'cancelled_by', v_request.cancelled_by,
    'cancelled_at', v_request.cancelled_at,
    'widened', v_request.widened_at is not null,
    'created_at', v_request.created_at,
    'chosen_at', v_request.chosen_at,
    'sent_to', (select count(*) from public.request_recipients where request_id = v_request.id),
    'seen_by', (
      select count(*) from public.request_recipients
       where request_id = v_request.id and seen_at is not null
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
               'technician', private.technician_card(o.technician_id)
             ) order by o.created_at), '[]')
        from public.request_offers o
        left join public.request_recipients rr
          on rr.request_id = o.request_id and rr.technician_id = o.technician_id
       where o.request_id = v_request.id
    ),
    'chosen_offer_id', v_request.chosen_offer_id,
    'technician_phone', case
      when v_request.status = 'assigned' then
        (select phone from public.profiles where id = v_offer.technician_id)
    end,
    'job', case when v_job.id is not null then jsonb_build_object(
      'status', v_job.status,
      'scheduled_at', v_job.scheduled_at,
      'confirmed_at', v_job.confirmed_at,
      'started_at', v_job.started_at,
      'finished_at', v_job.finished_at,
      'paid_at', v_job.paid_at,
      'cancelled_at', v_job.cancelled_at,
      'quote_status', v_job.quote_status,
      'quote_sent_at', v_job.quote_sent_at,
      'invoice_number', v_job.invoice_number,
      'items', v_items,
      'total_piastres', v_total
    ) end,
    'review', (
      select jsonb_build_object(
        'stars', v.stars, 'tags', to_jsonb(v.tags), 'comment', v.comment,
        'paid_with', v.paid_with, 'created_at', v.created_at
      )
      from public.reviews v where v.request_id = v_request.id
    ),
    'open_complaint', exists (
      select 1 from public.complaints c
       where c.request_id = v_request.id and c.resolved_at is null
    )
  );
end;
$$;

-- A technician's page, for a consumer they made an offer to.
create function public.technician_profile(p_technician_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_on_time record;
begin
  if not exists (
    select 1
      from public.request_offers o
      join public.service_requests r on r.id = o.request_id
     where o.technician_id = p_technician_id and r.consumer_id = auth.uid()
  ) then
    return null;
  end if;

  -- Platform jobs started within 30 minutes of the time offered.
  select count(*) filter (where j.started_at <= o.arrive_at + interval '30 minutes') as on_time,
         count(*) as started
    into v_on_time
    from public.service_requests r
    join public.request_offers o on o.id = r.chosen_offer_id
    join public.jobs j on j.id = r.job_id
   where o.technician_id = p_technician_id and j.started_at is not null;

  return private.technician_card(p_technician_id) || jsonb_build_object(
    'on_time_percent', case
      when v_on_time.started >= 3 then round(100.0 * v_on_time.on_time / v_on_time.started)
    end,
    'area_ids', (
      select coalesce(jsonb_agg(a.area_id order by a.area_id), '[]')
        from (
          select ta.area_id from public.technician_areas ta where ta.technician_id = p_technician_id
          union
          select t.base_area_id from public.technician_profiles t where t.id = p_technician_id
        ) a
    ),
    'services', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'service_id', ts.service_id,
               'starting_price_piastres', ts.starting_price_piastres
             ) order by s.sort_order), '[]')
        from public.technician_services ts
        join public.services s on s.id = ts.service_id and s.is_active
       where ts.technician_id = p_technician_id
    ),
    'reviews', (
      select coalesce(jsonb_agg(x.item order by x.created_at desc), '[]')
        from (
          select v.created_at, jsonb_build_object(
                   'author', private.short_name(p.full_name),
                   'stars', v.stars,
                   'comment', v.comment,
                   'tags', to_jsonb(v.tags),
                   'issue', r.issue,
                   'created_at', v.created_at
                 ) as item
            from public.reviews v
            join public.service_requests r on r.id = v.request_id
            join public.profiles p on p.id = v.consumer_id
           where v.technician_id = p_technician_id
           order by v.created_at desc
           limit 30
        ) x
    )
  );
end;
$$;

-- Picks an offer: the technician's use is taken, the other offers close,
-- and the job (with the consumer's name, phone and address) is written
-- into the technician's records, reusing their customer with the same
-- phone number when there is one. Returns the job id.
create function public.accept_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
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
    case v_request.issue
      when 'not_cooling' then array['not_cooling']
      when 'leaking' then array['leaking']
      when 'noisy' then array['maintenance']
      when 'needs_cleaning' then array['cleaning']
      when 'installation' then array['installation']
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
   where request_id = v_request.id;

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

-- Cancels a request. Before a pick the consumer's use comes back; after a
-- pick (until the work starts) the job is cancelled for the technician and
-- their use comes back instead.
create function public.cancel_service_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
  v_job public.jobs;
  v_state public.request_status;
begin
  select * into v_request
    from public.service_requests
   where id = p_request_id and consumer_id = auth.uid()
   for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  v_state := private.request_state(v_request.status, v_request.expires_at);

  if v_state = 'open' then
    update public.service_requests
       set status = 'cancelled', cancelled_at = now(), cancelled_by = 'consumer',
           credit_held = false
     where id = v_request.id;
    perform private.return_use(v_request.consumer_id, 'consumer');
  elsif v_state = 'assigned' then
    select * into v_job from public.jobs where id = v_request.job_id for update;
    if v_job.status not in ('unconfirmed', 'confirmed') then
      raise exception 'too_late' using errcode = 'P0001';
    end if;
    update public.service_requests
       set status = 'cancelled', cancelled_at = now(), cancelled_by = 'consumer'
     where id = v_request.id;
    update public.jobs
       set status = 'cancelled', cancelled_at = now()
     where id = v_job.id;
    perform private.return_use(v_job.technician_id, 'technician');
  else
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
end;
$$;

-- "وسّعي المعاد": any time that day instead of one part of it.
create function public.widen_request_window(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
begin
  select * into v_request
    from public.service_requests
   where id = p_request_id and consumer_id = auth.uid()
   for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open' then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  update public.service_requests
     set time_window = 'any_time',
         expires_at = upper(private.window_range(preferred_on, 'any_time'))
   where id = v_request.id;
end;
$$;

-- The consumer answers the price change the technician sent
-- (p_quote_sent_at names which one, so a stale screen can't answer a newer
-- one).
create function public.answer_price_change(
  p_request_id uuid,
  p_quote_sent_at timestamptz,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
begin
  select r.job_id into v_job_id
    from public.service_requests r
   where r.id = p_request_id and r.consumer_id = auth.uid() and r.status = 'assigned';
  if v_job_id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  perform set_config('salahly.answering_customer', 'on', true);
  update public.jobs
     set quote_status = case when p_approve then 'accepted' else 'declined' end::public.quote_status
   where id = v_job_id
     and quote_status = 'sent'
     and quote_sent_at = p_quote_sent_at;
  if not found then
    raise exception 'no_price_change' using errcode = 'P0001';
  end if;
  perform set_config('salahly.answering_customer', 'off', true);
end;
$$;

create function public.submit_review(
  p_request_id uuid,
  p_stars smallint,
  p_tags public.review_tag[],
  p_comment text,
  p_paid_with public.consumer_payment
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.service_requests;
  v_job public.jobs;
begin
  select * into v_request
    from public.service_requests
   where id = p_request_id and consumer_id = auth.uid();
  select * into v_job from public.jobs where id = v_request.job_id;
  if v_request.id is null or v_request.status <> 'assigned'
     or v_job.status not in ('finished', 'paid') then
    raise exception 'not_reviewable' using errcode = 'P0001';
  end if;
  insert into public.reviews (
    request_id, consumer_id, technician_id, stars, tags, comment, paid_with
  )
  values (
    v_request.id, v_request.consumer_id, v_job.technician_id, p_stars,
    (select coalesce(array_agg(distinct t order by t), '{}') from unnest(p_tags) t),
    private.normalize_text(p_comment), p_paid_with
  );
exception when unique_violation then
  raise exception 'already_reviewed' using errcode = '23505';
end;
$$;

create function public.submit_complaint(
  p_request_id uuid,
  p_reason public.complaint_reason,
  p_details text,
  p_photo_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_technician_id uuid;
begin
  select o.technician_id into v_technician_id
    from public.service_requests r
    join public.request_offers o on o.id = r.chosen_offer_id
   where r.id = p_request_id and r.consumer_id = v_user_id;
  if v_technician_id is null then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_photo_path is not null
     and not private.owns_object(v_user_id, 'request-photos', p_photo_path) then
    raise exception 'invalid_photos' using errcode = '22023';
  end if;
  insert into public.complaints (request_id, consumer_id, technician_id, reason, details, photo_path)
  values (
    p_request_id, v_user_id, v_technician_id, p_reason,
    private.normalize_text(p_details), p_photo_path
  );
exception when unique_violation then
  raise exception 'already_complained' using errcode = '23505';
end;
$$;

-- Technician functions ----------------------------------------------------

-- A request as a technician sees it: no phone, no address, the consumer's
-- first name and initial.
create function private.request_for_technician(p_request_id uuid, p_technician_id uuid)
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
    'distance_km', rr.distance_km,
    'preferred_on', r.preferred_on,
    'time_window', r.time_window,
    'expires_at', r.expires_at,
    'created_at', r.created_at,
    'consumer_name', private.short_name(p.full_name),
    'consumer_honorific', cp.honorific,
    'status', private.request_state(r.status, r.expires_at),
    'sent_to', (select count(*) from public.request_recipients x where x.request_id = r.id),
    'offer_count', (select count(*) from public.request_offers o where o.request_id = r.id),
    'dismissed', rr.dismissed_at is not null,
    'my_offer', (
      select jsonb_build_object(
        'id', o.id, 'service_id', o.service_id, 'price_piastres', o.price_piastres,
        'arrive_at', o.arrive_at, 'note', o.note, 'status', o.status
      )
      from public.request_offers o
      where o.request_id = r.id and o.technician_id = p_technician_id
    )
  )
  from public.service_requests r
  join public.request_recipients rr
    on rr.request_id = r.id and rr.technician_id = p_technician_id
  join public.consumer_profiles cp on cp.id = r.consumer_id
  join public.profiles p on p.id = r.consumer_id
  where r.id = p_request_id;
$$;

-- Requests waiting for this technician's offer, newest first.
create function public.technician_requests()
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
     and (select count(*) from public.request_offers o where o.request_id = r.id) < 3;
$$;

-- One request, for its page; marks it seen.
create function public.technician_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.request_recipients
     set seen_at = coalesce(seen_at, now())
   where request_id = p_request_id and technician_id = auth.uid();
  if not found then
    return null;
  end if;
  return private.request_for_technician(p_request_id, auth.uid());
end;
$$;

-- Sends an offer. A technician can have as many offers waiting as they
-- have uses left, and a request takes at most three offers.
create function public.send_offer(
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
  v_technician public.technician_profiles;
  v_request public.service_requests;
  v_offer_id uuid;
begin
  select * into v_technician from public.technician_profiles where id = v_user_id;
  if not found then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  select r.* into v_request
    from public.service_requests r
    join public.request_recipients rr
      on rr.request_id = r.id and rr.technician_id = v_user_id
   where r.id = p_request_id
   for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if private.request_state(v_request.status, v_request.expires_at) <> 'open'
     or (select count(*) from public.request_offers where request_id = v_request.id) >= 3 then
    raise exception 'request_closed' using errcode = 'P0001';
  end if;
  if (
    select count(*)
      from public.request_offers o
      join public.service_requests r on r.id = o.request_id
     where o.technician_id = v_user_id
       and o.status = 'sent'
       and private.request_state(r.status, r.expires_at) = 'open'
  ) >= v_technician.job_credits then
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

-- "مش مناسب ليا".
create function public.dismiss_request(p_request_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.request_recipients
     set dismissed_at = coalesce(dismissed_at, now())
   where request_id = p_request_id and technician_id = auth.uid();
$$;

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function
  public.save_consumer_address(uuid, text, text, text),
  public.delete_consumer_address(uuid),
  public.available_technician_count(text, text),
  public.create_service_request(
    text, public.request_issue, text, text[], uuid, date, public.request_window, uuid
  ),
  public.my_requests(),
  public.request_details(uuid),
  public.technician_profile(uuid),
  public.accept_offer(uuid),
  public.cancel_service_request(uuid),
  public.widen_request_window(uuid),
  public.answer_price_change(uuid, timestamptz, boolean),
  public.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment),
  public.submit_complaint(uuid, public.complaint_reason, text, text),
  public.technician_requests(),
  public.technician_request(uuid),
  public.send_offer(uuid, text, bigint, timestamptz, text),
  public.dismiss_request(uuid)
from public, anon;

grant execute on function
  public.save_consumer_address(uuid, text, text, text),
  public.delete_consumer_address(uuid),
  public.available_technician_count(text, text),
  public.create_service_request(
    text, public.request_issue, text, text[], uuid, date, public.request_window, uuid
  ),
  public.my_requests(),
  public.request_details(uuid),
  public.technician_profile(uuid),
  public.accept_offer(uuid),
  public.cancel_service_request(uuid),
  public.widen_request_window(uuid),
  public.answer_price_change(uuid, timestamptz, boolean),
  public.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment),
  public.submit_complaint(uuid, public.complaint_reason, text, text),
  public.technician_requests(),
  public.technician_request(uuid),
  public.send_offer(uuid, text, bigint, timestamptz, text),
  public.dismiss_request(uuid)
to authenticated;

-- Every ten minutes: expire and widen requests.
create extension if not exists pg_cron;
select cron.schedule(
  'marketplace-housekeeping',
  '*/10 * * * *',
  'select private.marketplace_housekeeping()'
);
