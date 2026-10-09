-- Onboarding writes every row for a side of the marketplace in one
-- transaction, after validating the input against the catalog and the
-- caller's own uploads. These are the only way app users create profiles.

create function private.normalize_text(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(btrim(p_value), '\s+', ' ', 'g'), '');
$$;

create function private.upsert_profile(
  p_user_id uuid,
  p_full_name text,
  p_role public.user_role
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_phone text;
begin
  select phone into v_phone from auth.users where id = p_user_id;
  if coalesce(v_phone, '') = '' then
    raise exception 'phone_missing' using errcode = '22023';
  end if;

  insert into public.profiles (id, phone, full_name, active_role)
  values (p_user_id, '+' || v_phone, private.normalize_text(p_full_name), p_role)
  on conflict (id) do update
    set full_name = excluded.full_name,
        active_role = excluded.active_role;
end;
$$;

-- Returns the free uses to grant: the configured amount the first time a
-- phone number joins as this role, zero afterwards.
create function private.claim_free_credits(p_user_id uuid, p_role public.user_role)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_phone_hash text;
begin
  select encode(sha256(convert_to(phone, 'UTF8')), 'hex')
    into v_phone_hash
    from auth.users
   where id = p_user_id;

  insert into private.free_credit_grants (phone_hash, role)
  values (v_phone_hash, p_role)
  on conflict do nothing;

  if not found then
    return 0;
  end if;

  return (
    select case p_role
      when 'consumer' then s.consumer_free_requests
      else s.technician_free_jobs
    end
    from public.app_settings s
  );
end;
$$;

create function private.owns_object(p_user_id uuid, p_bucket text, p_path text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from storage.objects o
     where o.bucket_id = p_bucket
       and o.name = p_path
       and o.owner_id = p_user_id::text
       and split_part(o.name, '/', 1) = p_user_id::text
  );
$$;

create function public.complete_consumer_onboarding(
  p_full_name text,
  p_honorific public.honorific,
  p_area_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if exists (select 1 from public.consumer_profiles where id = v_user_id) then
    raise exception 'already_onboarded' using errcode = '23505';
  end if;

  if not exists (select 1 from public.service_areas where id = p_area_id) then
    raise exception 'invalid_area' using errcode = '22023';
  end if;

  perform private.upsert_profile(v_user_id, p_full_name, 'consumer');

  insert into public.consumer_profiles (id, honorific, area_id, request_credits)
  values (
    v_user_id,
    p_honorific,
    p_area_id,
    private.claim_free_credits(v_user_id, 'consumer')
  );
end;
$$;

-- p_services: [{"service_id": "ac_inspection", "starting_price_piastres": 15000}, ...]
create function public.complete_technician_onboarding(
  p_full_name text,
  p_shop_name text,
  p_years_experience smallint,
  p_avatar_path text,
  p_base_area_id text,
  p_base_lat double precision,
  p_base_lng double precision,
  p_service_radius_km smallint,
  p_work_days smallint[],
  p_area_ids text[],
  p_services jsonb,
  p_id_front_path text,
  p_id_back_path text,
  p_selfie_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'already_onboarded' using errcode = '23505';
  end if;

  if not private.owns_object(v_user_id, 'avatars', p_avatar_path) then
    raise exception 'invalid_avatar' using errcode = '22023';
  end if;

  if p_id_front_path = p_id_back_path
     or p_id_front_path = p_selfie_path
     or p_id_back_path = p_selfie_path
     or not private.owns_object(v_user_id, 'verification-docs', p_id_front_path)
     or not private.owns_object(v_user_id, 'verification-docs', p_id_back_path)
     or not private.owns_object(v_user_id, 'verification-docs', p_selfie_path) then
    raise exception 'invalid_documents' using errcode = '22023';
  end if;

  if jsonb_typeof(p_services) is distinct from 'array'
     or jsonb_array_length(p_services) = 0
     or exists (
       select 1
         from jsonb_array_elements(p_services) e
        where jsonb_typeof(e) <> 'object'
     )
     or (
       select count(*) <> count(distinct s.service_id)
         from jsonb_to_recordset(p_services) as s (service_id text)
     )
     or exists (
       select 1
         from jsonb_to_recordset(p_services) as s (service_id text)
         left join public.services sv
           on sv.id = s.service_id and sv.is_active
         left join public.service_categories c
           on c.id = sv.category_id and c.is_active
        where c.id is null
     ) then
    raise exception 'invalid_services' using errcode = '22023';
  end if;

  if not exists (select 1 from public.service_areas where id = p_base_area_id)
     or coalesce(cardinality(p_area_ids), 0) = 0
     or exists (
       select 1
         from unnest(p_area_ids) as a (id)
         left join public.service_areas sa on sa.id = a.id
        where sa.id is null
     ) then
    raise exception 'invalid_areas' using errcode = '22023';
  end if;

  perform private.upsert_profile(v_user_id, p_full_name, 'technician');

  insert into public.technician_profiles (
    id,
    shop_name,
    years_experience,
    avatar_path,
    base_area_id,
    base_lat,
    base_lng,
    service_radius_km,
    work_days,
    job_credits
  )
  values (
    v_user_id,
    private.normalize_text(p_shop_name),
    p_years_experience,
    p_avatar_path,
    p_base_area_id,
    -- About 100 m precision: enough to match by distance, without storing
    -- the exact spot the technician stood in.
    round(p_base_lat::numeric, 3)::double precision,
    round(p_base_lng::numeric, 3)::double precision,
    p_service_radius_km,
    (select array_agg(distinct d order by d) from unnest(p_work_days) as d),
    private.claim_free_credits(v_user_id, 'technician')
  );

  insert into public.technician_services (technician_id, service_id, starting_price_piastres)
  select v_user_id, s.service_id, s.starting_price_piastres
    from jsonb_to_recordset(p_services) as s (service_id text, starting_price_piastres bigint);

  insert into public.technician_areas (technician_id, area_id)
  select distinct v_user_id, a.id
    from unnest(p_area_ids) as a (id);

  insert into public.technician_verifications (
    technician_id,
    id_front_path,
    id_back_path,
    selfie_path
  )
  values (v_user_id, p_id_front_path, p_id_back_path, p_selfie_path);
end;
$$;

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function public.complete_consumer_onboarding(text, public.honorific, text)
  from public, anon;
grant execute on function public.complete_consumer_onboarding(text, public.honorific, text)
  to authenticated;

revoke execute on function public.complete_technician_onboarding(
  text, text, smallint, text, text, double precision, double precision,
  smallint, smallint[], text[], jsonb, text, text, text
) from public, anon;
grant execute on function public.complete_technician_onboarding(
  text, text, smallint, text, text, double precision, double precision,
  smallint, smallint[], text[], jsonb, text, text, text
) to authenticated;
