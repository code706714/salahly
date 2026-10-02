-- The technician's own business records: customers and their AC units,
-- jobs with quote lines, payments and job photos.
--
-- The app keeps a copy on the phone and works offline. Changes travel
-- through two functions: sync_push sends the phone's edits, and sync_pull
-- returns every row changed since the phone's last checkpoint. Users never
-- write these tables directly.
--
-- Each row records the transaction that last wrote it (sync_txid) and a
-- version from one sequence. A pull only returns rows from transactions
-- that have finished, so a slow writer can never commit "behind" a
-- checkpoint the phone already holds.

create type public.job_status as enum (
  'unconfirmed', 'confirmed', 'started', 'finished', 'paid', 'cancelled'
);
create type public.quote_status as enum ('none', 'draft', 'sent', 'accepted');
create type public.payment_method as enum ('cash', 'instapay', 'vodafone_cash', 'other');
create type public.job_photo_kind as enum ('before', 'after');

create sequence private.sync_version;

-- Stamps every write with its transaction and a fresh version.
create function private.stamp_sync()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.sync_txid := pg_current_xact_id();
  new.version := nextval('private.sync_version');
  new.updated_at := now();
  return new;
end;
$$;

-- A time the phone recorded, kept unless it is implausibly far in the
-- future (a wrong phone clock).
create function private.client_time(p_value timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case
    when p_value is null or p_value > now() + interval '1 day' then now()
    else p_value
  end;
$$;

create table public.customers (
  id uuid primary key,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  name text not null check (
    char_length(name) between 2 and 60
    and name = btrim(name)
    and name !~ '[[:cntrl:]]'
  ),
  phone text check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  area_id text references public.service_areas (id),
  address text check (char_length(address) <= 300),
  notes text check (char_length(notes) <= 1000),
  source text not null default 'manual' check (source in ('manual', 'contacts', 'platform')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  unique (technician_id, id)
);

create table public.customer_units (
  id uuid primary key,
  technician_id uuid not null,
  customer_id uuid not null,
  brand text check (char_length(brand) between 1 and 40),
  capacity_hp numeric(4, 2) check (capacity_hp between 0.75 and 6),
  room text check (char_length(room) between 1 and 40),
  installed_year smallint check (installed_year between 1980 and 2100),
  next_service_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  foreign key (technician_id, customer_id)
    references public.customers (technician_id, id) on delete cascade
);

create table public.jobs (
  id uuid primary key,
  technician_id uuid not null,
  customer_id uuid not null,
  tags text[] not null default '{}' check (
    tags <@ array[
      'cleaning', 'freon', 'installation', 'not_cooling', 'leaking',
      'maintenance', 'removal'
    ]
  ),
  description text check (char_length(description) <= 1000),
  scheduled_at timestamptz,
  duration_minutes smallint not null default 60 check (duration_minutes between 15 and 720),
  address text check (char_length(address) <= 300),
  status public.job_status not null default 'unconfirmed',
  confirmed_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  paid_at timestamptz,
  cancelled_at timestamptz,
  quote_status public.quote_status not null default 'none',
  quote_sent_at timestamptz,
  quote_valid_days smallint not null default 3 check (quote_valid_days between 1 and 30),
  payment_promised_on date,
  invoice_number integer check (invoice_number between 1 and 999999),
  source text not null default 'manual' check (source in ('manual', 'platform')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  unique (technician_id, id),
  foreign key (technician_id, customer_id)
    references public.customers (technician_id, id) on delete cascade
);

create table public.job_items (
  id uuid primary key,
  technician_id uuid not null,
  job_id uuid not null,
  title text not null check (
    char_length(title) between 1 and 80
    and title = btrim(title)
    and title !~ '[[:cntrl:]]'
  ),
  unit_price_piastres bigint not null check (unit_price_piastres between 0 and 100000000),
  quantity integer not null default 1 check (quantity between 1 and 999),
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  foreign key (technician_id, job_id)
    references public.jobs (technician_id, id) on delete cascade
);

create table public.payments (
  id uuid primary key,
  technician_id uuid not null,
  job_id uuid not null,
  amount_piastres bigint not null check (amount_piastres between 1 and 100000000),
  method public.payment_method not null,
  received_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  foreign key (technician_id, job_id)
    references public.jobs (technician_id, id) on delete cascade
);

create table public.job_photos (
  id uuid primary key,
  technician_id uuid not null,
  job_id uuid not null,
  kind public.job_photo_kind not null,
  storage_path text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_txid xid8 not null default pg_current_xact_id(),
  version bigint not null default nextval('private.sync_version'),
  foreign key (technician_id, job_id)
    references public.jobs (technician_id, id) on delete cascade
);

create index customers_sync_idx on public.customers (technician_id, sync_txid, version);
create index customer_units_sync_idx on public.customer_units (technician_id, sync_txid, version);
create index customer_units_customer_idx on public.customer_units (technician_id, customer_id);
create index jobs_sync_idx on public.jobs (technician_id, sync_txid, version);
create index jobs_customer_idx on public.jobs (technician_id, customer_id);
create index job_items_sync_idx on public.job_items (technician_id, sync_txid, version);
create index job_items_job_idx on public.job_items (technician_id, job_id);
create index payments_sync_idx on public.payments (technician_id, sync_txid, version);
create index payments_job_idx on public.payments (technician_id, job_id);
create index job_photos_sync_idx on public.job_photos (technician_id, sync_txid, version);
create index job_photos_job_idx on public.job_photos (technician_id, job_id);

create trigger customers_stamp_sync before insert or update on public.customers
  for each row execute function private.stamp_sync();
create trigger customer_units_stamp_sync before insert or update on public.customer_units
  for each row execute function private.stamp_sync();
create trigger jobs_stamp_sync before insert or update on public.jobs
  for each row execute function private.stamp_sync();
create trigger job_items_stamp_sync before insert or update on public.job_items
  for each row execute function private.stamp_sync();
create trigger payments_stamp_sync before insert or update on public.payments
  for each row execute function private.stamp_sync();
create trigger job_photos_stamp_sync before insert or update on public.job_photos
  for each row execute function private.stamp_sync();

alter table public.customers enable row level security;
alter table public.customer_units enable row level security;
alter table public.jobs enable row level security;
alter table public.job_items enable row level security;
alter table public.payments enable row level security;
alter table public.job_photos enable row level security;

revoke all on table
  public.customers, public.customer_units, public.jobs, public.job_items,
  public.payments, public.job_photos
from anon, authenticated;

grant select on table
  public.customers, public.customer_units, public.jobs, public.job_items,
  public.payments, public.job_photos
to authenticated;

create policy "Technicians read their own customers"
  on public.customers for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Technicians read their own customer units"
  on public.customer_units for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Technicians read their own jobs"
  on public.jobs for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Technicians read their own job items"
  on public.job_items for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Technicians read their own payments"
  on public.payments for select to authenticated
  using (technician_id = (select auth.uid()));
create policy "Technicians read their own job photos"
  on public.job_photos for select to authenticated
  using (technician_id = (select auth.uid()));

-- Job photos: private, written into the technician's own folder like the
-- other buckets, with a higher daily limit.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('job-photos', 'job-photos', false, 3145728, array['image/jpeg', 'image/png', 'image/webp']);

create or replace function guard.upload_quota_left(p_bucket text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) < case p_bucket when 'job-photos' then 60 else 10 end
  from storage.objects
  where bucket_id = p_bucket
    and owner_id = (select auth.uid()::text)
    and created_at > now() - interval '1 day';
$$;

create policy "Technicians upload job photos to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'job-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and guard.upload_quota_left(bucket_id)
  );

create policy "Technicians view their own job photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'job-photos'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

-- How many rows of each kind one technician may keep, so an account can't
-- fill the database.
create function private.sync_row_limit(p_entity text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_entity
    when 'customers' then 5000
    when 'customer_units' then 10000
    when 'jobs' then 20000
    when 'job_items' then 100000
    when 'payments' then 50000
    when 'job_photos' then 20000
  end;
$$;

create function private.sync_row_count(p_user_id uuid, p_entity text)
returns bigint
language plpgsql
stable
set search_path = ''
as $$
declare
  v_count bigint;
begin
  execute format('select count(*) from public.%I where technician_id = $1', p_entity)
    into v_count
    using p_user_id;
  return v_count;
end;
$$;

-- Applies one change from the phone. Raises a named error when the change
-- is invalid; sync_push turns that into a rejection.
create function private.sync_apply(
  p_user_id uuid,
  p_entity text,
  p_id uuid,
  p_row jsonb
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_exists boolean;
  v_count integer;
begin
  if p_entity not in ('customers', 'customer_units', 'jobs', 'job_items', 'payments', 'job_photos') then
    raise exception 'unknown_entity' using errcode = '22023';
  end if;

  execute format('select exists (select 1 from public.%I where id = $1)', p_entity)
    into v_exists
    using p_id;
  if not v_exists
     and private.sync_row_count(p_user_id, p_entity) >= private.sync_row_limit(p_entity) then
    raise exception 'limit_reached' using errcode = '54000';
  end if;

  case p_entity
  when 'customers' then
    insert into public.customers as t (
      id, technician_id, name, phone, area_id, address, notes, source,
      created_at, deleted_at
    )
    select p_id, p_user_id, private.normalize_text(r.name), r.phone, r.area_id,
           private.normalize_text(r.address), private.normalize_text(r.notes),
           case when r.source = 'contacts' then 'contacts' else 'manual' end,
           private.client_time(r.created_at), r.deleted_at
      from jsonb_populate_record(null::public.customers, p_row) r
    on conflict (id) do update
      set name = excluded.name,
          phone = excluded.phone,
          area_id = excluded.area_id,
          address = excluded.address,
          notes = excluded.notes,
          deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;

  when 'customer_units' then
    insert into public.customer_units as t (
      id, technician_id, customer_id, brand, capacity_hp, room,
      installed_year, next_service_on, created_at, deleted_at
    )
    select p_id, p_user_id, r.customer_id, private.normalize_text(r.brand),
           r.capacity_hp, private.normalize_text(r.room), r.installed_year,
           r.next_service_on, private.client_time(r.created_at), r.deleted_at
      from jsonb_populate_record(null::public.customer_units, p_row) r
    on conflict (id) do update
      set customer_id = excluded.customer_id,
          brand = excluded.brand,
          capacity_hp = excluded.capacity_hp,
          room = excluded.room,
          installed_year = excluded.installed_year,
          next_service_on = excluded.next_service_on,
          deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;

  when 'jobs' then
    insert into public.jobs as t (
      id, technician_id, customer_id, tags, description, scheduled_at,
      duration_minutes, address, status, confirmed_at, started_at,
      finished_at, paid_at, cancelled_at, quote_status, quote_sent_at,
      quote_valid_days, payment_promised_on, invoice_number, created_at,
      deleted_at
    )
    select p_id, p_user_id, r.customer_id,
           (select coalesce(array_agg(distinct tag order by tag), '{}') from unnest(r.tags) tag),
           private.normalize_text(r.description), r.scheduled_at,
           coalesce(r.duration_minutes, 60), private.normalize_text(r.address),
           coalesce(r.status, 'unconfirmed'), r.confirmed_at, r.started_at,
           r.finished_at, r.paid_at, r.cancelled_at,
           coalesce(r.quote_status, 'none'), r.quote_sent_at,
           coalesce(r.quote_valid_days, 3), r.payment_promised_on,
           r.invoice_number, private.client_time(r.created_at), r.deleted_at
      from jsonb_populate_record(null::public.jobs, p_row) r
    on conflict (id) do update
      set customer_id = excluded.customer_id,
          tags = excluded.tags,
          description = excluded.description,
          scheduled_at = excluded.scheduled_at,
          duration_minutes = excluded.duration_minutes,
          address = excluded.address,
          status = excluded.status,
          confirmed_at = excluded.confirmed_at,
          started_at = excluded.started_at,
          finished_at = excluded.finished_at,
          paid_at = excluded.paid_at,
          cancelled_at = excluded.cancelled_at,
          quote_status = excluded.quote_status,
          quote_sent_at = excluded.quote_sent_at,
          quote_valid_days = excluded.quote_valid_days,
          payment_promised_on = excluded.payment_promised_on,
          invoice_number = excluded.invoice_number,
          deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;

  when 'job_items' then
    insert into public.job_items as t (
      id, technician_id, job_id, title, unit_price_piastres, quantity,
      sort_order, created_at, deleted_at
    )
    select p_id, p_user_id, r.job_id, private.normalize_text(r.title),
           r.unit_price_piastres, coalesce(r.quantity, 1),
           coalesce(r.sort_order, 0), private.client_time(r.created_at),
           r.deleted_at
      from jsonb_populate_record(null::public.job_items, p_row) r
    on conflict (id) do update
      set job_id = excluded.job_id,
          title = excluded.title,
          unit_price_piastres = excluded.unit_price_piastres,
          quantity = excluded.quantity,
          sort_order = excluded.sort_order,
          deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;

  when 'payments' then
    insert into public.payments as t (
      id, technician_id, job_id, amount_piastres, method, received_at,
      created_at, deleted_at
    )
    select p_id, p_user_id, r.job_id, r.amount_piastres, r.method,
           private.client_time(r.received_at),
           private.client_time(r.created_at), r.deleted_at
      from jsonb_populate_record(null::public.payments, p_row) r
    on conflict (id) do update
      set job_id = excluded.job_id,
          amount_piastres = excluded.amount_piastres,
          method = excluded.method,
          received_at = excluded.received_at,
          deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;

  when 'job_photos' then
    if not private.owns_object(p_user_id, 'job-photos', p_row ->> 'storage_path') then
      raise exception 'invalid_photo' using errcode = '22023';
    end if;
    insert into public.job_photos as t (
      id, technician_id, job_id, kind, storage_path, created_at, deleted_at
    )
    select p_id, p_user_id, r.job_id, r.kind, r.storage_path,
           private.client_time(r.created_at), r.deleted_at
      from jsonb_populate_record(null::public.job_photos, p_row) r
    on conflict (id) do update
      set deleted_at = excluded.deleted_at
      where t.technician_id = p_user_id;
  end case;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    -- The id exists and belongs to someone else.
    raise exception 'not_owner' using errcode = '42501';
  end if;
end;
$$;

-- Applies the phone's changes in order. A change that fails is rejected
-- on its own (with the server's copy of the row, when there is one, so
-- the phone can put it back) and the rest still apply.
create function public.sync_push(p_changes jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_change jsonb;
  v_entity text;
  v_id uuid;
  v_rejected jsonb := '[]';
  v_server_row jsonb;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_technician' using errcode = '42501';
  end if;
  if jsonb_typeof(p_changes) is distinct from 'array' or jsonb_array_length(p_changes) > 200 then
    raise exception 'invalid_changes' using errcode = '22023';
  end if;

  for v_change in select value from jsonb_array_elements(p_changes) loop
    v_entity := v_change ->> 'entity';
    begin
      v_id := (v_change ->> 'id')::uuid;
      if jsonb_typeof(v_change -> 'row') is distinct from 'object' then
        raise exception 'invalid_change' using errcode = '22023';
      end if;
      perform private.sync_apply(v_user_id, v_entity, v_id, v_change -> 'row');
    exception when others then
      v_server_row := null;
      if v_id is not null and v_entity in (
        'customers', 'customer_units', 'jobs', 'job_items', 'payments', 'job_photos'
      ) then
        execute format(
          'select to_jsonb(t) - ''technician_id'' - ''sync_txid'' - ''version''
             from public.%I t where id = $1 and technician_id = $2',
          v_entity
        )
          into v_server_row
          using v_id, v_user_id;
      end if;
      v_rejected := v_rejected || jsonb_build_object(
        'entity', v_entity,
        'id', v_change ->> 'id',
        'code', sqlerrm,
        'row', v_server_row
      );
    end;
  end loop;

  return jsonb_build_object('rejected', v_rejected);
end;
$$;

-- Every own row changed after the checkpoint, oldest first. The checkpoint
-- is opaque to the phone: it sends back what the last pull returned.
create function public.sync_pull(p_checkpoint jsonb default null, p_limit integer default 500)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_since_txid xid8 := coalesce((p_checkpoint ->> 'txid')::xid8, '0'::xid8);
  v_since_version bigint := coalesce((p_checkpoint ->> 'version')::bigint, 0);
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  -- Transactions older than this have all finished.
  v_horizon xid8 := pg_snapshot_xmin(pg_current_snapshot());
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  with changes as (
    select 'customers' as entity, t.sync_txid, t.version, to_jsonb(t) as row
      from public.customers t where t.technician_id = v_user_id
    union all
    select 'customer_units', t.sync_txid, t.version, to_jsonb(t)
      from public.customer_units t where t.technician_id = v_user_id
    union all
    select 'jobs', t.sync_txid, t.version, to_jsonb(t)
      from public.jobs t where t.technician_id = v_user_id
    union all
    select 'job_items', t.sync_txid, t.version, to_jsonb(t)
      from public.job_items t where t.technician_id = v_user_id
    union all
    select 'payments', t.sync_txid, t.version, to_jsonb(t)
      from public.payments t where t.technician_id = v_user_id
    union all
    select 'job_photos', t.sync_txid, t.version, to_jsonb(t)
      from public.job_photos t where t.technician_id = v_user_id
  ),
  page as (
    select *
      from changes
     where (sync_txid, version) > (v_since_txid, v_since_version)
       -- A pull never writes, so the second case only matters when one
       -- transaction both writes and pulls, as the database tests do.
       and (sync_txid < v_horizon or sync_txid = pg_current_xact_id_if_assigned())
     order by sync_txid, version
     limit v_limit
  ),
  last_row as (
    select sync_txid, version from page order by sync_txid desc, version desc limit 1
  )
  select jsonb_build_object(
    'changes', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'entity', entity,
           'row', row - 'technician_id' - 'sync_txid' - 'version'
         )
         order by sync_txid, version
       ) from page),
      '[]'
    ),
    'checkpoint', coalesce(
      (select jsonb_build_object('txid', sync_txid::text, 'version', version) from last_row),
      p_checkpoint
    ),
    'has_more', (select count(*) from page) = v_limit
  )
  into v_result;

  return v_result;
end;
$$;

revoke execute on function
  private.stamp_sync(),
  private.client_time(timestamptz),
  private.sync_row_limit(text),
  private.sync_row_count(uuid, text),
  private.sync_apply(uuid, text, uuid, jsonb)
from public, anon, authenticated;

revoke execute on function public.sync_push(jsonb) from public, anon;
grant execute on function public.sync_push(jsonb) to authenticated;
revoke execute on function public.sync_pull(jsonb, integer) from public, anon;
grant execute on function public.sync_pull(jsonb, integer) to authenticated;
