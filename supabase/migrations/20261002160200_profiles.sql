-- Who the user is: a shared profile plus one profile per side of the
-- marketplace. Rows are created only through the onboarding functions, so
-- users can read their own data but never write it directly.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.user_role as enum ('consumer', 'technician');
create type public.honorific as enum ('mr', 'ms');
create type public.verification_status as enum ('pending', 'approved', 'rejected');

-- Single-row settings the admin dashboard edits.
create table public.app_settings (
  id boolean primary key default true check (id),
  consumer_free_requests smallint not null default 2
    check (consumer_free_requests between 0 and 20),
  technician_free_jobs smallint not null default 2
    check (technician_free_jobs between 0 and 20),
  updated_at timestamptz not null default now()
);

insert into public.app_settings default values;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text not null unique check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  full_name text not null check (
    char_length(full_name) between 2 and 60
    and full_name = btrim(full_name)
    and full_name !~ '[[:cntrl:]]'
  ),
  active_role public.user_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.consumer_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  honorific public.honorific not null,
  area_id text not null references public.service_areas (id),
  request_credits integer not null check (request_credits >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index consumer_profiles_area_id_idx on public.consumer_profiles (area_id);

create table public.technician_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  shop_name text check (
    shop_name is null
    or (
      char_length(shop_name) between 2 and 60
      and shop_name = btrim(shop_name)
      and shop_name !~ '[[:cntrl:]]'
    )
  ),
  years_experience smallint not null check (years_experience between 0 and 60),
  avatar_path text not null,
  base_area_id text not null references public.service_areas (id),
  base_lat double precision not null check (base_lat between 22 and 32),
  base_lng double precision not null check (base_lng between 24 and 37),
  service_radius_km smallint not null check (service_radius_km in (5, 10, 15)),
  -- ISO weekdays: 1 = Monday ... 6 = Saturday, 7 = Sunday.
  work_days smallint[] not null check (
    cardinality(work_days) between 1 and 7
    and work_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  ),
  job_credits integer not null check (job_credits >= 0),
  verification_status public.verification_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index technician_profiles_base_area_id_idx
  on public.technician_profiles (base_area_id);

create table public.technician_services (
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  service_id text not null references public.services (id),
  -- Between 1 and 1,000,000 EGP.
  starting_price_piastres bigint not null
    check (starting_price_piastres between 100 and 100000000),
  primary key (technician_id, service_id)
);

create index technician_services_service_id_idx on public.technician_services (service_id);

create table public.technician_areas (
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  area_id text not null references public.service_areas (id),
  primary key (technician_id, area_id)
);

create index technician_areas_area_id_idx on public.technician_areas (area_id);

-- Every ID submission is kept for audit; the technician's current state
-- lives in technician_profiles.verification_status.
create table public.technician_verifications (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  id_front_path text not null,
  id_back_path text not null,
  selfie_path text not null,
  status public.verification_status not null default 'pending',
  rejection_reason text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index technician_verifications_technician_id_idx
  on public.technician_verifications (technician_id, created_at desc);
create unique index technician_verifications_one_pending_idx
  on public.technician_verifications (technician_id) where status = 'pending';

-- Phones (hashed) that already received the free uses for a role, kept after
-- account deletion so re-registering doesn't grant them again.
create table private.free_credit_grants (
  phone_hash text not null,
  role public.user_role not null,
  granted_at timestamptz not null default now(),
  primary key (phone_hash, role)
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger consumer_profiles_set_updated_at
  before update on public.consumer_profiles
  for each row execute function public.set_updated_at();
create trigger technician_profiles_set_updated_at
  before update on public.technician_profiles
  for each row execute function public.set_updated_at();

alter table public.app_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.consumer_profiles enable row level security;
alter table public.technician_profiles enable row level security;
alter table public.technician_services enable row level security;
alter table public.technician_areas enable row level security;
alter table public.technician_verifications enable row level security;
alter table private.free_credit_grants enable row level security;

revoke all on table
  public.app_settings,
  public.profiles,
  public.consumer_profiles,
  public.technician_profiles,
  public.technician_services,
  public.technician_areas,
  public.technician_verifications
  from anon, authenticated;

grant select on table
  public.app_settings,
  public.profiles,
  public.consumer_profiles,
  public.technician_profiles,
  public.technician_services,
  public.technician_areas,
  public.technician_verifications
  to authenticated;

create policy "Signed-in users read app settings"
  on public.app_settings for select to authenticated using (true);

create policy "Users read their own profile"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "Users read their own consumer profile"
  on public.consumer_profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "Users read their own technician profile"
  on public.technician_profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "Technicians read their own services"
  on public.technician_services for select to authenticated
  using (technician_id = (select auth.uid()));

create policy "Technicians read their own areas"
  on public.technician_areas for select to authenticated
  using (technician_id = (select auth.uid()));

create policy "Technicians read their own verifications"
  on public.technician_verifications for select to authenticated
  using (technician_id = (select auth.uid()));
