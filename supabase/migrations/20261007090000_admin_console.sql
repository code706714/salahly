-- Milestone 6, step 1: the admin console's backend.
--
-- An internal, online-only console for the platform operators. What it
-- reads and does, and why it can't be abused:
--
-- * Who is an admin: private.admins. Nobody can write to it from the API
--   (no grants, no policies, and no function does); an admin is added from
--   a database session by hand (docs/admin/setup.md). guard.is_admin() is
--   the one check every admin function starts with (private.require_admin).
-- * What an admin can do is a fixed list of public.admin_* functions, all
--   SECURITY DEFINER with an empty search_path. Each validates its input,
--   pages its lists (at most 100 rows), and writes a row to the
--   append-only private.admin_audit_log. Actions that move money or change
--   what people pay or where they send it (reviewing a transfer, prices,
--   free uses, payment accounts) also need a login made in the last 15
--   minutes, like delete_my_account.
-- * Suspension: profiles.suspended_at. Every write function the app calls
--   now goes through a thin wrapper that refuses a suspended account
--   (account_suspended, 42501): the original function moved to the private
--   schema as <name>_impl and a wrapper with the same name, arguments and
--   result took its place, so clients are unchanged. The phone is kept
--   (hashed) so deleting the account and signing up again stays suspended.
--   Reading is not blocked, and neither is deleting one's own account.
-- * Files: admins read transfer proofs, ID documents and request photos
--   through a storage SELECT policy limited to those three buckets.

-- Columns ------------------------------------------------------------------

alter table public.profiles add column suspended_at timestamptz;

-- The "pre-launch target" the overview measures verified technicians against.
alter table public.app_settings
  add column verified_technician_target integer not null default 100
    check (verified_technician_target between 1 and 100000);

alter table public.complaints
  add column resolution_note text check (char_length(resolution_note) <= 500),
  add column resolved_by uuid references auth.users (id) on delete set null;

-- Admin tables (private: no API role can reach them) ------------------------

create table private.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table private.admins enable row level security;

-- Everything an admin did. Append-only: rows can't be changed or removed,
-- not even from a database session, without dropping the triggers first.
-- admin_id is not a foreign key so history outlives an admin's account.
create table private.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null check (char_length(action) between 1 and 60),
  target_type text not null check (char_length(target_type) between 1 and 40),
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);
create index admin_audit_log_created_idx on private.admin_audit_log (created_at desc, id desc);
create index admin_audit_log_target_idx on private.admin_audit_log (target_id, created_at desc);
alter table private.admin_audit_log enable row level security;

create function private.audit_log_is_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log_is_append_only' using errcode = '42501';
end;
$$;

create trigger admin_audit_log_no_change
  before update or delete on private.admin_audit_log
  for each row execute function private.audit_log_is_append_only();
create trigger admin_audit_log_no_truncate
  before truncate on private.admin_audit_log
  for each statement execute function private.audit_log_is_append_only();

-- Who is suspended and why (the reason is for the admins, not the person),
-- with a hash of the phone so a deleted account that signs up again with
-- the same number is suspended from the start. No foreign key on purpose:
-- the record outlives the account.
create table private.suspensions (
  user_id uuid primary key,
  phone_hash text not null,
  reason text not null,
  suspended_by uuid,
  suspended_at timestamptz not null default now()
);
create index suspensions_phone_hash_idx on private.suspensions (phone_hash);
alter table private.suspensions enable row level security;

-- Guards -------------------------------------------------------------------

create function guard.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.admins where user_id = (select auth.uid())
  );
$$;

-- True when the signed-in account is not suspended (used by storage policies).
create function guard.not_suspended()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles
     where id = (select auth.uid()) and suspended_at is not null
  );
$$;

revoke execute on function guard.is_admin(), guard.not_suspended() from public, anon;
grant execute on function guard.is_admin(), guard.not_suspended() to authenticated;

-- Helpers ------------------------------------------------------------------

create function private.require_admin()
returns void
language plpgsql
set search_path = ''
as $$
begin
  if not (select guard.is_admin()) then
    raise exception 'admin_required' using errcode = '42501';
  end if;
end;
$$;

-- Money-moving admin actions need a login made in the last 15 minutes. When
-- the token says when the person last signed in (amr), that time counts; a
-- refreshed token keeps it. Otherwise the age of the token itself.
create function private.require_recent_login()
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_issued_at bigint;
begin
  select coalesce(
           max((a ->> 'timestamp')::bigint),
           (auth.jwt() ->> 'iat')::bigint
         )
    into v_issued_at
    from jsonb_array_elements(
      case when jsonb_typeof(auth.jwt() -> 'amr') = 'array'
           then auth.jwt() -> 'amr' else '[]'::jsonb end
    ) a;
  if v_issued_at is null or v_issued_at < extract(epoch from now()) - 900 then
    raise exception 'recent_login_required' using errcode = 'P0001';
  end if;
end;
$$;

create function private.admin_log(
  p_action text,
  p_target_type text,
  p_target_id text,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
set search_path = ''
as $$
  insert into private.admin_audit_log (admin_id, action, target_type, target_id, details)
  values ((select auth.uid()), p_action, p_target_type, p_target_id, coalesce(p_details, '{}'::jsonb));
$$;

create function private.page_limit(p_limit integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

create function private.page_offset(p_offset integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_offset, 0), 0), 100000);
$$;

-- A LIKE pattern for a name search (null when there is nothing to search).
create function private.search_like(p_search text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if v_search is null then
    return null;
  end if;
  if char_length(v_search) > 60 then
    raise exception 'invalid_search' using errcode = '22023';
  end if;
  return '%' || replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_') || '%';
end;
$$;

-- A LIKE pattern for a phone search: digits only, the leading zero dropped
-- (phones are stored as +20...). Null when the text doesn't look like one.
create function private.search_phone_like(p_search text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when btrim(coalesce(p_search, '')) ~ '^\+?[0-9 ]{4,20}$'
     and ltrim(regexp_replace(p_search, '[^0-9]', '', 'g'), '0') <> ''
    then '%' || ltrim(regexp_replace(p_search, '[^0-9]', '', 'g'), '0') || '%'
  end;
$$;

-- today = since midnight in Cairo; week = the last 7 days; month = the last
-- 30. prev_since starts the window of the same length just before.
create function private.period_bounds(
  p_period text,
  out since timestamptz,
  out prev_since timestamptz
)
language plpgsql
stable
set search_path = ''
as $$
begin
  case coalesce(p_period, 'week')
    when 'today' then
      since := date_trunc('day', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
      prev_since := since - interval '1 day';
    when 'week' then
      since := now() - interval '7 days';
      prev_since := now() - interval '14 days';
    when 'month' then
      since := now() - interval '30 days';
      prev_since := now() - interval '60 days';
    else
      raise exception 'invalid_period' using errcode = '22023';
  end case;
end;
$$;

-- "R-1A2B3C": a short code people can quote.
create function private.request_code(p_id uuid)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'R-' || upper(left(replace(p_id::text, '-', ''), 6));
$$;

-- Refuses a suspended account. Called first by every write function the
-- app uses. Someone with no profile yet is checked by phone, so a number
-- that was suspended can't start over by signing up again.
create function private.assert_active()
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_suspended_at timestamptz;
  v_phone text;
begin
  if v_user_id is null then
    return;
  end if;
  select suspended_at into v_suspended_at from public.profiles where id = v_user_id;
  if found then
    if v_suspended_at is not null then
      raise exception 'account_suspended' using errcode = '42501';
    end if;
    return;
  end if;
  if exists (select 1 from private.suspensions) then
    select phone into v_phone from auth.users where id = v_user_id;
    if v_phone is not null and exists (
      select 1 from private.suspensions where phone_hash = private.phone_hash(v_phone)
    ) then
      raise exception 'account_suspended' using errcode = '42501';
    end if;
  end if;
end;
$$;

-- A profile created for a suspended number starts suspended.
create function private.inherit_suspension()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text;
  v_suspension private.suspensions;
begin
  if new.suspended_at is not null or not exists (select 1 from private.suspensions) then
    return new;
  end if;
  select phone into v_phone from auth.users where id = new.id;
  if v_phone is null then
    return new;
  end if;
  select * into v_suspension
    from private.suspensions
   where phone_hash = private.phone_hash(v_phone)
   order by suspended_at desc
   limit 1;
  if found then
    new.suspended_at := now();
    insert into private.suspensions (user_id, phone_hash, reason, suspended_by)
    values (new.id, v_suspension.phone_hash, v_suspension.reason, v_suspension.suspended_by)
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger profiles_inherit_suspension
  before insert on public.profiles
  for each row execute function private.inherit_suspension();

-- Suspended accounts can't write ---------------------------------------------
-- Each write function the app calls moves to the private schema as
-- <name>_impl; a wrapper with the original name, arguments and result
-- refuses a suspended account and then calls it.


alter function public.complete_consumer_onboarding(text, public.honorific, text) set schema private;
alter function private.complete_consumer_onboarding(text, public.honorific, text) rename to complete_consumer_onboarding_impl;
alter function public.complete_technician_onboarding(text, text, smallint, text, text, double precision, double precision, smallint, smallint[], text[], jsonb, text, text, text) set schema private;
alter function private.complete_technician_onboarding(text, text, smallint, text, text, double precision, double precision, smallint, smallint[], text[], jsonb, text, text, text) rename to complete_technician_onboarding_impl;
alter function public.sync_push(jsonb) set schema private;
alter function private.sync_push(jsonb) rename to sync_push_impl;
alter function public.save_consumer_address(uuid, text, text, text) set schema private;
alter function private.save_consumer_address(uuid, text, text, text) rename to save_consumer_address_impl;
alter function public.delete_consumer_address(uuid) set schema private;
alter function private.delete_consumer_address(uuid) rename to delete_consumer_address_impl;
alter function public.create_service_request(text, public.request_issue, text, text[], uuid, date, public.request_window, uuid) set schema private;
alter function private.create_service_request(text, public.request_issue, text, text[], uuid, date, public.request_window, uuid) rename to create_service_request_impl;
alter function public.accept_offer(uuid) set schema private;
alter function private.accept_offer(uuid) rename to accept_offer_impl;
alter function public.cancel_service_request(uuid) set schema private;
alter function private.cancel_service_request(uuid) rename to cancel_service_request_impl;
alter function public.widen_request_window(uuid) set schema private;
alter function private.widen_request_window(uuid) rename to widen_request_window_impl;
alter function public.answer_price_change(uuid, timestamptz, boolean) set schema private;
alter function private.answer_price_change(uuid, timestamptz, boolean) rename to answer_price_change_impl;
alter function public.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment) set schema private;
alter function private.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment) rename to submit_review_impl;
alter function public.submit_complaint(uuid, public.complaint_reason, text, text) set schema private;
alter function private.submit_complaint(uuid, public.complaint_reason, text, text) rename to submit_complaint_impl;
alter function public.send_offer(uuid, text, bigint, timestamptz, text) set schema private;
alter function private.send_offer(uuid, text, bigint, timestamptz, text) rename to send_offer_impl;
alter function public.dismiss_request(uuid) set schema private;
alter function private.dismiss_request(uuid) rename to dismiss_request_impl;
alter function public.technician_request(uuid) set schema private;
alter function private.technician_request(uuid) rename to technician_request_impl;
alter function public.submit_topup(uuid, public.topup_method, text, text, bigint) set schema private;
alter function private.submit_topup(uuid, public.topup_method, text, text, bigint) rename to submit_topup_impl;

create function public.complete_consumer_onboarding(p_full_name text, p_honorific public.honorific, p_area_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.complete_consumer_onboarding_impl(p_full_name, p_honorific, p_area_id);
end;
$$;

create function public.complete_technician_onboarding(p_full_name text, p_shop_name text, p_years_experience smallint, p_avatar_path text, p_base_area_id text, p_base_lat double precision, p_base_lng double precision, p_service_radius_km smallint, p_work_days smallint[], p_area_ids text[], p_services jsonb, p_id_front_path text, p_id_back_path text, p_selfie_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.complete_technician_onboarding_impl(p_full_name, p_shop_name, p_years_experience, p_avatar_path, p_base_area_id, p_base_lat, p_base_lng, p_service_radius_km, p_work_days, p_area_ids, p_services, p_id_front_path, p_id_back_path, p_selfie_path);
end;
$$;

create function public.sync_push(p_changes jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  return private.sync_push_impl(p_changes);
end;
$$;

create function public.save_consumer_address(p_id uuid, p_label text, p_area_id text, p_details text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  return private.save_consumer_address_impl(p_id, p_label, p_area_id, p_details);
end;
$$;

create function public.delete_consumer_address(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.delete_consumer_address_impl(p_id);
end;
$$;

create function public.create_service_request(p_category_id text, p_issue public.request_issue, p_description text, p_photo_paths text[], p_address_id uuid, p_preferred_on date, p_window public.request_window, p_technician_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  -- A closed area takes no new requests.
  if exists (
    select 1
      from public.consumer_addresses a
      join public.service_areas s on s.id = a.area_id
     where a.id = p_address_id and a.consumer_id = (select auth.uid()) and not s.is_open
  ) then
    raise exception 'area_closed' using errcode = '22023';
  end if;
  return private.create_service_request_impl(p_category_id, p_issue, p_description, p_photo_paths, p_address_id, p_preferred_on, p_window, p_technician_id);
end;
$$;

create function public.accept_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  -- A technician suspended after sending an offer can't be picked.
  if exists (
    select 1
      from public.request_offers o
      join public.profiles p on p.id = o.technician_id
     where o.id = p_offer_id and p.suspended_at is not null
  ) then
    raise exception 'technician_unavailable' using errcode = 'P0001';
  end if;
  return private.accept_offer_impl(p_offer_id);
end;
$$;

create function public.cancel_service_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.cancel_service_request_impl(p_request_id);
end;
$$;

create function public.widen_request_window(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.widen_request_window_impl(p_request_id);
end;
$$;

create function public.answer_price_change(p_request_id uuid, p_quote_sent_at timestamptz, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.answer_price_change_impl(p_request_id, p_quote_sent_at, p_approve);
end;
$$;

create function public.submit_review(p_request_id uuid, p_stars smallint, p_tags public.review_tag[], p_comment text, p_paid_with public.consumer_payment)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.submit_review_impl(p_request_id, p_stars, p_tags, p_comment, p_paid_with);
end;
$$;

create function public.submit_complaint(p_request_id uuid, p_reason public.complaint_reason, p_details text, p_photo_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.submit_complaint_impl(p_request_id, p_reason, p_details, p_photo_path);
end;
$$;

create function public.send_offer(p_request_id uuid, p_service_id text, p_price_piastres bigint, p_arrive_at timestamptz, p_note text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  return private.send_offer_impl(p_request_id, p_service_id, p_price_piastres, p_arrive_at, p_note);
end;
$$;

create function public.dismiss_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.dismiss_request_impl(p_request_id);
end;
$$;

create function public.technician_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  return private.technician_request_impl(p_request_id);
end;
$$;

create function public.submit_topup(p_pack_id uuid, p_method public.topup_method, p_sender_account text, p_screenshot_path text, p_expected_price_piastres bigint)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  return private.submit_topup_impl(p_pack_id, p_method, p_sender_account, p_screenshot_path, p_expected_price_piastres);
end;
$$;


revoke execute on function
  public.complete_consumer_onboarding(text, public.honorific, text),
  public.complete_technician_onboarding(text, text, smallint, text, text, double precision, double precision, smallint, smallint[], text[], jsonb, text, text, text),
  public.sync_push(jsonb),
  public.save_consumer_address(uuid, text, text, text),
  public.delete_consumer_address(uuid),
  public.create_service_request(text, public.request_issue, text, text[], uuid, date, public.request_window, uuid),
  public.accept_offer(uuid),
  public.cancel_service_request(uuid),
  public.widen_request_window(uuid),
  public.answer_price_change(uuid, timestamptz, boolean),
  public.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment),
  public.submit_complaint(uuid, public.complaint_reason, text, text),
  public.send_offer(uuid, text, bigint, timestamptz, text),
  public.dismiss_request(uuid),
  public.technician_request(uuid),
  public.submit_topup(uuid, public.topup_method, text, text, bigint)
from public, anon;
grant execute on function
  public.complete_consumer_onboarding(text, public.honorific, text),
  public.complete_technician_onboarding(text, text, smallint, text, text, double precision, double precision, smallint, smallint[], text[], jsonb, text, text, text),
  public.sync_push(jsonb),
  public.save_consumer_address(uuid, text, text, text),
  public.delete_consumer_address(uuid),
  public.create_service_request(text, public.request_issue, text, text[], uuid, date, public.request_window, uuid),
  public.accept_offer(uuid),
  public.cancel_service_request(uuid),
  public.widen_request_window(uuid),
  public.answer_price_change(uuid, timestamptz, boolean),
  public.submit_review(uuid, smallint, public.review_tag[], text, public.consumer_payment),
  public.submit_complaint(uuid, public.complaint_reason, text, text),
  public.send_offer(uuid, text, bigint, timestamptz, text),
  public.dismiss_request(uuid),
  public.technician_request(uuid),
  public.submit_topup(uuid, public.topup_method, text, text, bigint)
to authenticated;


-- Suspended technicians get no requests and aren't counted --------------------

create or replace function private.dispatch_request(p_request_id uuid, p_wide boolean)
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
         and not exists (
           select 1 from public.profiles pr
            where pr.id = t.id and pr.suspended_at is not null
         )
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
     and t.verification_status = 'approved'
     and not exists (
       select 1 from public.profiles pr
        where pr.id = t.id and pr.suspended_at is not null
     )
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

-- Storage ------------------------------------------------------------------

-- Uploads need an account that isn't suspended, as well as the checks they
-- already had.
alter policy "Users upload avatars to their own folder" on storage.objects
  with check (
    bucket_id = 'avatars'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.account_exists())
    and (select guard.not_suspended())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Users upload ID documents to their own folder" on storage.objects
  with check (
    bucket_id = 'verification-docs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.account_exists())
    and (select guard.not_suspended())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "People upload transfer proofs to their own folder" on storage.objects
  with check (
    bucket_id = 'transfer-proofs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.not_suspended())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Consumers upload request photos to their own folder" on storage.objects
  with check (
    bucket_id = 'request-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.is_consumer())
    and (select guard.not_suspended())
    and guard.upload_quota_left(bucket_id)
  );
alter policy "Technicians upload job photos to their own folder" on storage.objects
  with check (
    bucket_id = 'job-photos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.is_technician())
    and (select guard.not_suspended())
    and guard.upload_quota_left(bucket_id)
  );

-- The files an admin reviews: transfer screenshots, ID documents, and the
-- photos on a request or complaint. Read only, and only these buckets (not
-- the avatars, which are public anyway, nor job photos).
create policy "Admins read the files they review"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('transfer-proofs', 'verification-docs', 'request-photos')
    and (select guard.is_admin())
  );



-- Admin functions ------------------------------------------------------------
-- Every one starts with private.require_admin() (admin_required, 42501),
-- reads and writes as the definer, and is granted to authenticated only.

-- Reasons and notes typed by an admin: trimmed, no control characters.
create function private.clean_note(p_text text, p_min integer, p_max integer)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := private.normalize_text(p_text);
begin
  if v_text is null
     or char_length(v_text) < p_min
     or char_length(v_text) > p_max
     or v_text ~ '[[:cntrl:]]' then
    raise exception 'invalid_reason' using errcode = '22023';
  end if;
  return v_text;
end;
$$;

-- Overview: numbers for the period (p_period: today | week | month).
create function public.admin_overview(p_period text default 'week')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
  v_prev_since timestamptz;
begin
  perform private.require_admin();
  select b.since, b.prev_since into v_since, v_prev_since from private.period_bounds(p_period) b;

  return jsonb_build_object(
    'period', coalesce(p_period, 'week'),
    'since', v_since,
    'verified_technicians', (
      select count(*)
        from public.technician_profiles t
        join public.profiles p on p.id = t.id
       where t.verification_status = 'approved' and p.suspended_at is null
    ),
    'verified_technician_target', (select verified_technician_target from public.app_settings),
    'requests', jsonb_build_object(
      'count', (select count(*) from public.service_requests where created_at >= v_since),
      'previous_count', (
        select count(*) from public.service_requests
         where created_at >= v_prev_since and created_at < v_since
      )
    ),
    'funnel', (
      select jsonb_build_object(
        'sent', count(*),
        'with_offer', count(*) filter (
          where exists (select 1 from public.request_offers o where o.request_id = r.id)
        ),
        'chosen', count(*) filter (where r.chosen_at is not null),
        'finished', count(*) filter (
          where exists (
            select 1 from public.jobs j
             where j.id = r.job_id and j.status in ('finished', 'paid')
          )
        )
      )
      from public.service_requests r
      where r.created_at >= v_since
    ),
    'rating', (
      select jsonb_build_object('average', round(avg(stars)::numeric, 1), 'count', count(*))
        from public.reviews
       where created_at >= v_since
    ),
    -- Still open, nobody offered, and waiting more than 3 hours.
    'requests_without_offers', jsonb_build_object(
      'older_than_hours', 3,
      'count', (
        select count(*)
          from public.service_requests r
         where r.status = 'open' and r.expires_at > now()
           and r.created_at < now() - interval '3 hours'
           and not exists (select 1 from public.request_offers o where o.request_id = r.id)
      ),
      'top_areas', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'area_id', x.area_id, 'name_ar', x.name_ar, 'count', x.n
               ) order by x.n desc, x.area_id), '[]')
          from (
            select r.area_id, a.name_ar, count(*) as n
              from public.service_requests r
              join public.service_areas a on a.id = r.area_id
             where r.status = 'open' and r.expires_at > now()
               and r.created_at < now() - interval '3 hours'
               and not exists (select 1 from public.request_offers o where o.request_id = r.id)
             group by r.area_id, a.name_ar
             order by n desc, r.area_id
             limit 3
          ) x
      )
    ),
    'pending_verifications', (
      select jsonb_build_object('count', count(*), 'oldest_at', min(created_at))
        from public.technician_verifications where status = 'pending'
    ),
    'open_complaints', jsonb_build_object(
      'count', (select count(*) from public.complaints where resolved_at is null),
      'by_reason', (
        select coalesce(jsonb_object_agg(x.reason::text, x.n), '{}'::jsonb)
          from (
            select reason, count(*) as n from public.complaints
             where resolved_at is null group by reason
          ) x
      )
    ),
    'pending_topups', (
      select jsonb_build_object(
        'count', count(*),
        'technicians', count(*) filter (where role = 'technician'),
        'consumers', count(*) filter (where role = 'consumer')
      )
      from public.credit_topups where status = 'pending'
    ),
    -- Average under 3.5 from at least 5 reviews.
    'low_rated_technicians', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', x.technician_id, 'name', x.full_name,
               'rating', x.average, 'review_count', x.n
             ) order by x.average, x.technician_id), '[]')
        from (
          select v.technician_id, p.full_name,
                 round(avg(v.stars)::numeric, 1) as average, count(*) as n
            from public.reviews v
            join public.profiles p on p.id = v.technician_id
           group by v.technician_id, p.full_name
          having count(*) >= 5 and avg(v.stars) < 3.5
           order by avg(v.stars), v.technician_id
           limit 5
        ) x
    )
  );
end;
$$;

-- Coverage by area for the period. Ads run in an area once it has 10
-- verified technicians (ads_min_technicians).
create function public.admin_list_areas(
  p_period text default 'month',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
begin
  perform private.require_admin();
  select b.since into v_since from private.period_bounds(p_period) b;

  return jsonb_build_object(
    'total', (select count(*) from public.service_areas),
    'ads_min_technicians', 10,
    'items', (
      select coalesce(jsonb_agg(x.item order by x.sort_order, x.id), '[]')
        from (
          select a.sort_order, a.id, jsonb_build_object(
            'id', a.id,
            'name_ar', a.name_ar,
            'city_ar', a.city_ar,
            'is_open', a.is_open,
            'verified_technicians', tc.n,
            'requests', rc.n,
            'got_offer_percent', case when rc.n > 0 then round(100.0 * rc.with_offer / rc.n) end,
            'ads_active', a.is_open and tc.n >= 10
          ) as item
            from public.service_areas a
            cross join lateral (
              select count(*) as n
                from public.technician_profiles t
                join public.profiles p on p.id = t.id
               where t.verification_status = 'approved' and p.suspended_at is null
                 and (
                   t.base_area_id = a.id
                   or exists (
                     select 1 from public.technician_areas ta
                      where ta.technician_id = t.id and ta.area_id = a.id
                   )
                 )
            ) tc
            cross join lateral (
              select count(*) as n,
                     count(*) filter (
                       where exists (select 1 from public.request_offers o where o.request_id = r.id)
                     ) as with_offer
                from public.service_requests r
               where r.area_id = a.id and r.created_at >= v_since
            ) rc
           order by a.sort_order, a.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Technician verification --------------------------------------------------

-- The queue, oldest first for pending ones, newest first for the rest.
create function public.admin_list_verifications(
  p_status public.verification_status default 'pending',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.verification_status := coalesce(p_status, 'pending');
begin
  perform private.require_admin();

  return jsonb_build_object(
    'total', (select count(*) from public.technician_verifications where status = v_status),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.rank, x.id), '[]')
        from (
          select v.id,
                 case when v_status = 'pending' then extract(epoch from v.created_at)
                      else -extract(epoch from v.created_at) end as rank,
                 jsonb_build_object(
                   'verification_id', v.id,
                   'technician_id', v.technician_id,
                   'name', p.full_name,
                   'area_id', t.base_area_id,
                   'area_name', a.name_ar,
                   'status', v.status,
                   'submitted_at', v.created_at,
                   'reviewed_at', v.reviewed_at,
                   'rejection_reason', v.rejection_reason,
                   'suspended', p.suspended_at is not null
                 ) as item
            from public.technician_verifications v
            join public.technician_profiles t on t.id = v.technician_id
            join public.profiles p on p.id = v.technician_id
            join public.service_areas a on a.id = t.base_area_id
           where v.status = v_status
           order by 2, v.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- One submission with what the reviewer checks: the person, what they
-- offer, and the paths of the three photos (the admin opens them with a
-- signed URL from the verification-docs bucket). Looking at someone's ID
-- is itself recorded in the audit log.
create function public.admin_get_verification(p_verification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform private.require_admin();

  select jsonb_build_object(
           'verification_id', v.id,
           'technician_id', v.technician_id,
           'status', v.status,
           'submitted_at', v.created_at,
           'reviewed_at', v.reviewed_at,
           'rejection_reason', v.rejection_reason,
           'id_front_path', v.id_front_path,
           'id_back_path', v.id_back_path,
           'selfie_path', v.selfie_path,
           'name', p.full_name,
           'phone', p.phone,
           'phone_confirmed', u.phone_confirmed_at is not null,
           'shop_name', t.shop_name,
           'years_experience', t.years_experience,
           'avatar_path', t.avatar_path,
           'area_id', t.base_area_id,
           'area_name', a.name_ar,
           'service_radius_km', t.service_radius_km,
           'work_days', to_jsonb(t.work_days),
           'suspended', p.suspended_at is not null,
           'previous_attempts', (
             select count(*) from public.technician_verifications o
              where o.technician_id = v.technician_id and o.id <> v.id and o.created_at < v.created_at
           ),
           'areas', (
             select coalesce(jsonb_agg(jsonb_build_object('id', sa.id, 'name_ar', sa.name_ar)
                      order by sa.sort_order, sa.id), '[]')
               from public.technician_areas ta
               join public.service_areas sa on sa.id = ta.area_id
              where ta.technician_id = v.technician_id
           ),
           'services', (
             select coalesce(jsonb_agg(jsonb_build_object(
                      'service_id', ts.service_id,
                      'name_ar', s.name_ar,
                      'starting_price_piastres', ts.starting_price_piastres
                    ) order by s.sort_order, s.id), '[]')
               from public.technician_services ts
               join public.services s on s.id = ts.service_id
              where ts.technician_id = v.technician_id
           )
         )
    into v_result
    from public.technician_verifications v
    join public.technician_profiles t on t.id = v.technician_id
    join public.profiles p on p.id = v.technician_id
    join public.service_areas a on a.id = t.base_area_id
    left join auth.users u on u.id = v.technician_id
   where v.id = p_verification_id;

  if v_result is null then
    raise exception 'verification_not_found' using errcode = 'P0002';
  end if;
  perform private.admin_log(
    'view_verification', 'technician_verification', p_verification_id::text,
    jsonb_build_object('technician_id', v_result ->> 'technician_id')
  );
  return v_result;
end;
$$;

-- Approving the pending submission makes the technician verified (and the
-- existing trigger tells them). Doing it twice changes nothing.
create function public.admin_approve_verification(p_verification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_verification public.technician_verifications;
begin
  perform private.require_admin();

  select * into v_verification
    from public.technician_verifications where id = p_verification_id for update;
  if not found then
    raise exception 'verification_not_found' using errcode = 'P0002';
  end if;
  if v_verification.status = 'approved' then
    return jsonb_build_object('status', 'approved', 'already_reviewed', true);
  end if;
  if v_verification.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  update public.technician_verifications
     set status = 'approved', reviewed_at = now(), rejection_reason = null
   where id = v_verification.id;
  update public.technician_profiles
     set verification_status = 'approved'
   where id = v_verification.technician_id;

  perform private.admin_log(
    'approve_verification', 'technician_verification', v_verification.id::text,
    jsonb_build_object('technician_id', v_verification.technician_id)
  );
  return jsonb_build_object('status', 'approved', 'already_reviewed', false);
end;
$$;

-- Rejecting needs a reason (3 to 200 characters) the technician can read.
create function public.admin_reject_verification(p_verification_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_verification public.technician_verifications;
begin
  perform private.require_admin();
  v_reason := private.clean_note(p_reason, 3, 200);

  select * into v_verification
    from public.technician_verifications where id = p_verification_id for update;
  if not found then
    raise exception 'verification_not_found' using errcode = 'P0002';
  end if;
  if v_verification.status = 'rejected' then
    return jsonb_build_object('status', 'rejected', 'already_reviewed', true);
  end if;
  if v_verification.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  update public.technician_verifications
     set status = 'rejected', reviewed_at = now(), rejection_reason = v_reason
   where id = v_verification.id;
  update public.technician_profiles
     set verification_status = 'rejected'
   where id = v_verification.technician_id;

  perform private.admin_log(
    'reject_verification', 'technician_verification', v_verification.id::text,
    jsonb_build_object('technician_id', v_verification.technician_id, 'reason', v_reason)
  );
  return jsonb_build_object('status', 'rejected', 'already_reviewed', false);
end;
$$;

-- Transfers (credit top-ups) -----------------------------------------------

-- p_status null lists every status. account_phone is the phone of the
-- account in the app in local form (01...), to compare with sender_account.
-- screenshot_path is the path in the transfer-proofs bucket (sign it with
-- the admin's own session). user_id/name/phone are null when the person
-- deleted their account.
create function public.admin_list_topups(
  p_status public.topup_status default 'pending',
  p_role public.user_role default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();

  return jsonb_build_object(
    'total', (
      select count(*) from public.credit_topups t
       where (p_status is null or t.status = p_status) and (p_role is null or t.role = p_role)
    ),
    'pending_total', (select count(*) from public.credit_topups where status = 'pending'),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.rank, x.id), '[]')
        from (
          select t.id,
                 case when p_status = 'pending' then extract(epoch from t.created_at)
                      else -extract(epoch from t.created_at) end as rank,
                 jsonb_build_object(
                   'id', t.id,
                   'user_id', t.user_id,
                   'name', p.full_name,
                   'account_phone', case when p.phone like '+20%' then '0' || substr(p.phone, 4) end,
                   'role', t.role,
                   'uses', t.uses,
                   'amount_piastres', t.amount_piastres,
                   'method', t.method,
                   'sender_account', t.sender_account,
                   'screenshot_path', t.screenshot_path,
                   'status', t.status,
                   'reject_reason', t.reject_reason,
                   'created_at', t.created_at,
                   'reviewed_at', t.reviewed_at
                 ) as item
            from public.credit_topups t
            left join public.profiles p on p.id = t.user_id
           where (p_status is null or t.status = p_status) and (p_role is null or t.role = p_role)
           order by 2, t.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Found in our account and right: the uses are added once. A second call
-- on an approved transfer changes nothing; on a rejected one it is refused.
create function public.admin_approve_topup(p_topup_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_topup public.credit_topups;
  v_balance integer;
begin
  perform private.require_admin();
  perform private.require_recent_login();

  select * into v_topup from public.credit_topups where id = p_topup_id for update;
  if not found then
    raise exception 'topup_not_found' using errcode = 'P0002';
  end if;
  if v_topup.status = 'approved' then
    return jsonb_build_object('status', 'approved', 'already_reviewed', true);
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  perform private.approve_topup(v_topup.id);

  select case v_topup.role
           when 'consumer' then (select request_credits from public.consumer_profiles where id = v_topup.user_id)
           else (select job_credits from public.technician_profiles where id = v_topup.user_id)
         end
    into v_balance;
  perform private.admin_log(
    'approve_topup', 'credit_topup', v_topup.id::text,
    jsonb_build_object(
      'user_id', v_topup.user_id, 'role', v_topup.role, 'uses', v_topup.uses,
      'amount_piastres', v_topup.amount_piastres, 'method', v_topup.method
    )
  );
  return jsonb_build_object('status', 'approved', 'already_reviewed', false, 'balance', v_balance);
end;
$$;

-- Rejecting needs a reason (3 to 200 characters) the person can read, and
-- they can send another screenshot.
create function public.admin_reject_topup(p_topup_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_topup public.credit_topups;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reason := private.clean_note(p_reason, 3, 200);

  select * into v_topup from public.credit_topups where id = p_topup_id for update;
  if not found then
    raise exception 'topup_not_found' using errcode = 'P0002';
  end if;
  if v_topup.status = 'rejected' then
    return jsonb_build_object('status', 'rejected', 'already_reviewed', true);
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  perform private.reject_topup(v_topup.id, v_reason);
  perform private.admin_log(
    'reject_topup', 'credit_topup', v_topup.id::text,
    jsonb_build_object(
      'user_id', v_topup.user_id, 'role', v_topup.role, 'uses', v_topup.uses,
      'amount_piastres', v_topup.amount_piastres, 'reason', v_reason
    )
  );
  return jsonb_build_object('status', 'rejected', 'already_reviewed', false);
end;
$$;



-- Requests and complaints --------------------------------------------------

-- p_status: no_offers | awaiting_choice | in_progress | done | cancelled |
-- expired (null = all). p_days: only requests from the last N days (1 to
-- 365; null = no limit). p_search: a request code (R-1A2B3C), or part of a
-- name or phone of the consumer or the chosen technician. Names are first
-- name and initial; no phone or address is returned.
create function public.admin_list_requests(
  p_search text default null,
  p_area_id text default null,
  p_status text default null,
  p_days integer default 7,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_like text;
  v_phone text;
  v_code text;
  v_total bigint;
  v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null
     and p_status not in ('no_offers', 'awaiting_choice', 'in_progress', 'done', 'cancelled', 'expired') then
    raise exception 'invalid_filter' using errcode = '22023';
  end if;
  if p_days is not null and p_days not between 1 and 365 then
    raise exception 'invalid_filter' using errcode = '22023';
  end if;
  v_like := private.search_like(p_search);
  v_phone := private.search_phone_like(p_search);
  if btrim(coalesce(p_search, '')) ~* '^r-?[0-9a-f]{1,6}$' then
    v_code := 'R-' || upper(regexp_replace(btrim(p_search), '^r-?', '', 'i'));
  end if;

  with base as (
    select r.id, r.created_at, r.category_id, r.issue, r.area_id, r.consumer_id,
           cp.full_name as consumer_name, tp.id as technician_id, tp.full_name as technician_name,
           oc.n as offer_count, j.status as job_status,
           case
             when r.status = 'cancelled' then 'cancelled'
             when private.request_state(r.status, r.expires_at) = 'expired' then 'expired'
             when r.status = 'open' then case when oc.n = 0 then 'no_offers' else 'awaiting_choice' end
             when j.status in ('finished', 'paid') then 'done'
             else 'in_progress'
           end as status_key
      from public.service_requests r
      left join public.profiles cp on cp.id = r.consumer_id
      left join public.request_offers o on o.id = r.chosen_offer_id
      left join public.profiles tp on tp.id = o.technician_id
      left join public.jobs j on j.id = r.job_id
      cross join lateral (
        select count(*) as n from public.request_offers x where x.request_id = r.id
      ) oc
     where (p_days is null or r.created_at >= now() - make_interval(days => p_days))
       and (p_area_id is null or r.area_id = p_area_id)
       and (
         (v_like is null and v_phone is null and v_code is null)
         or cp.full_name ilike v_like escape '\'
         or tp.full_name ilike v_like escape '\'
         or cp.phone like v_phone
         or tp.phone like v_phone
         or (v_code is not null and starts_with(private.request_code(r.id), v_code))
       )
  ),
  filtered as (
    select * from base where p_status is null or status_key = p_status
  ),
  page as (
    select * from filtered order by created_at desc, id
     limit private.page_limit(p_limit) offset private.page_offset(p_offset)
  )
  select (select count(*) from filtered),
         coalesce(jsonb_agg(jsonb_build_object(
           'id', g.id,
           'code', private.request_code(g.id),
           'created_at', g.created_at,
           'category_id', g.category_id,
           'issue', g.issue,
           'area_id', g.area_id,
           'area_name', (select name_ar from public.service_areas where id = g.area_id),
           'consumer_name', private.short_name(coalesce(g.consumer_name, 'عميل محذوف')),
           'technician_name', private.short_name(g.technician_name),
           'offer_count', g.offer_count,
           'status', g.status_key,
           'stars', (select v.stars from public.reviews v where v.request_id = g.id),
           'has_open_complaint', exists (
             select 1 from public.complaints c where c.request_id = g.id and c.resolved_at is null
           ),
           'has_complaint', exists (select 1 from public.complaints c where c.request_id = g.id)
         ) order by g.created_at desc, g.id), '[]')
    into v_total, v_items
    from page g;

  return jsonb_build_object('total', v_total, 'items', v_items);
end;
$$;

-- p_status: open (default) | resolved | all. The consumer's and the
-- technician's phones are here so the team can call them.
create function public.admin_list_complaints(
  p_status text default 'open',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := coalesce(p_status, 'open');
begin
  perform private.require_admin();
  if v_status not in ('open', 'resolved', 'all') then
    raise exception 'invalid_filter' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'total', (
      select count(*) from public.complaints c
       where v_status = 'all' or (v_status = 'open') = (c.resolved_at is null)
    ),
    'open_total', (select count(*) from public.complaints where resolved_at is null),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.created_at desc, x.id), '[]')
        from (
          select c.id, c.created_at, jsonb_build_object(
                   'id', c.id,
                   'request_id', c.request_id,
                   'request_code', private.request_code(c.request_id),
                   'reason', c.reason,
                   'details', c.details,
                   'photo_path', c.photo_path,
                   'created_at', c.created_at,
                   'resolved_at', c.resolved_at,
                   'resolution_note', c.resolution_note,
                   'issue', r.issue,
                   'area_id', r.area_id,
                   'consumer', jsonb_build_object(
                     'id', c.consumer_id, 'name', cp.full_name, 'phone', cp.phone
                   ),
                   'technician', jsonb_build_object(
                     'id', c.technician_id, 'name', tp.full_name, 'phone', tp.phone,
                     'suspended', tp.suspended_at is not null
                   )
                 ) as item
            from public.complaints c
            join public.service_requests r on r.id = c.request_id
            join public.profiles cp on cp.id = c.consumer_id
            join public.profiles tp on tp.id = c.technician_id
           where v_status = 'all' or (v_status = 'open') = (c.resolved_at is null)
           order by c.created_at desc, c.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Closes a complaint with a note (3 to 500 characters). Closing one that is
-- already closed changes nothing.
create function public.admin_resolve_complaint(p_complaint_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text;
  v_complaint public.complaints;
begin
  perform private.require_admin();
  v_note := private.clean_note(p_note, 3, 500);

  select * into v_complaint from public.complaints where id = p_complaint_id for update;
  if not found then
    raise exception 'complaint_not_found' using errcode = 'P0002';
  end if;
  if v_complaint.resolved_at is not null then
    return jsonb_build_object('resolved', true, 'already_resolved', true);
  end if;

  update public.complaints
     set resolved_at = now(), resolution_note = v_note, resolved_by = (select auth.uid())
   where id = v_complaint.id;
  perform private.admin_log(
    'resolve_complaint', 'complaint', v_complaint.id::text,
    jsonb_build_object('request_id', v_complaint.request_id, 'note', v_note)
  );
  return jsonb_build_object('resolved', true, 'already_resolved', false);
end;
$$;

-- Users --------------------------------------------------------------------

-- Technicians or consumers. p_status for technicians: verified | pending |
-- rejected | suspended; for consumers: active | suspended (null = all).
-- p_search: part of a name or phone. last_sign_in_at is the last login.
create function public.admin_list_users(
  p_role public.user_role default 'technician',
  p_search text default null,
  p_area_id text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.user_role := coalesce(p_role, 'technician');
  v_like text;
  v_phone text;
  v_total bigint;
  v_items jsonb;
begin
  perform private.require_admin();
  v_like := private.search_like(p_search);
  v_phone := private.search_phone_like(p_search);

  if v_role = 'technician' then
    if p_status is not null and p_status not in ('verified', 'pending', 'rejected', 'suspended') then
      raise exception 'invalid_filter' using errcode = '22023';
    end if;
    with base as (
      select p.id, p.full_name, p.phone, p.created_at, p.suspended_at, t.base_area_id,
             t.verification_status, t.job_credits,
             case when p.suspended_at is not null then 'suspended'
                  when t.verification_status = 'approved' then 'verified'
                  else t.verification_status::text end as status_key
        from public.technician_profiles t
        join public.profiles p on p.id = t.id
       where (p_area_id is null or t.base_area_id = p_area_id)
         and (
           (v_like is null and v_phone is null)
           or p.full_name ilike v_like escape '\'
           or p.phone like v_phone
         )
    ),
    filtered as (
      select * from base where p_status is null or status_key = p_status
    ),
    page as (
      select * from filtered order by created_at desc, id
       limit private.page_limit(p_limit) offset private.page_offset(p_offset)
    )
    select (select count(*) from filtered),
           coalesce(jsonb_agg(jsonb_build_object(
             'id', g.id,
             'name', g.full_name,
             'phone', g.phone,
             'area_id', g.base_area_id,
             'area_name', (select name_ar from public.service_areas where id = g.base_area_id),
             'status', g.status_key,
             'verification_status', g.verification_status,
             'suspended_at', g.suspended_at,
             'suspension_reason', (select s.reason from private.suspensions s where s.user_id = g.id),
             'rating', (select round(avg(stars)::numeric, 1) from public.reviews where technician_id = g.id),
             'review_count', (select count(*) from public.reviews where technician_id = g.id),
             'platform_jobs', (
               select count(*)
                 from public.request_offers o
                 join public.service_requests r on r.chosen_offer_id = o.id
                where o.technician_id = g.id
             ),
             'balance', g.job_credits,
             'pending_topup', exists (
               select 1 from public.credit_topups where user_id = g.id and role = 'technician' and status = 'pending'
             ),
             'last_sign_in_at', (select u.last_sign_in_at from auth.users u where u.id = g.id),
             'created_at', g.created_at
           ) order by g.created_at desc, g.id), '[]')
      into v_total, v_items
      from page g;
  else
    if p_status is not null and p_status not in ('active', 'suspended') then
      raise exception 'invalid_filter' using errcode = '22023';
    end if;
    with base as (
      select p.id, p.full_name, p.phone, p.created_at, p.suspended_at, c.area_id, c.request_credits,
             case when p.suspended_at is not null then 'suspended' else 'active' end as status_key
        from public.consumer_profiles c
        join public.profiles p on p.id = c.id
       where (p_area_id is null or c.area_id = p_area_id)
         and (
           (v_like is null and v_phone is null)
           or p.full_name ilike v_like escape '\'
           or p.phone like v_phone
         )
    ),
    filtered as (
      select * from base where p_status is null or status_key = p_status
    ),
    page as (
      select * from filtered order by created_at desc, id
       limit private.page_limit(p_limit) offset private.page_offset(p_offset)
    )
    select (select count(*) from filtered),
           coalesce(jsonb_agg(jsonb_build_object(
             'id', g.id,
             'name', g.full_name,
             'phone', g.phone,
             'area_id', g.area_id,
             'area_name', (select name_ar from public.service_areas where id = g.area_id),
             'status', g.status_key,
             'suspended_at', g.suspended_at,
             'suspension_reason', (select s.reason from private.suspensions s where s.user_id = g.id),
             'requests_count', (select count(*) from public.service_requests where consumer_id = g.id),
             'last_request_at', (select max(created_at) from public.service_requests where consumer_id = g.id),
             'complaints_count', (select count(*) from public.complaints where consumer_id = g.id),
             'balance', g.request_credits,
             'pending_topup', exists (
               select 1 from public.credit_topups where user_id = g.id and role = 'consumer' and status = 'pending'
             ),
             'last_sign_in_at', (select u.last_sign_in_at from auth.users u where u.id = g.id),
             'created_at', g.created_at
           ) order by g.created_at desc, g.id), '[]')
      into v_total, v_items
      from page g;
  end if;

  return jsonb_build_object('total', v_total, 'items', v_items);
end;
$$;

-- Suspends an account (reason 3 to 200 characters, kept for the team). From
-- then on none of the app's write functions accept it, a suspended
-- technician gets no new requests, and a consumer's open requests are
-- cancelled (their use comes back). Admins can't be suspended, nor can you
-- suspend yourself. Suspending twice changes nothing.
create function public.admin_suspend_user(p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_profile public.profiles;
  v_phone text;
  v_request public.service_requests;
begin
  perform private.require_admin();
  v_reason := private.clean_note(p_reason, 3, 200);
  if p_user_id is null or p_user_id = (select auth.uid()) then
    raise exception 'invalid_target' using errcode = '22023';
  end if;
  if exists (select 1 from private.admins where user_id = p_user_id) then
    raise exception 'cannot_suspend_admin' using errcode = '42501';
  end if;

  select * into v_profile from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if v_profile.suspended_at is not null then
    return jsonb_build_object('suspended', true, 'already_suspended', true);
  end if;

  select phone into v_phone from auth.users where id = p_user_id;
  insert into private.suspensions (user_id, phone_hash, reason, suspended_by)
  values (p_user_id, private.phone_hash(v_phone), v_reason, (select auth.uid()))
  on conflict (user_id) do update
    set reason = excluded.reason, suspended_by = excluded.suspended_by, suspended_at = now();
  update public.profiles set suspended_at = now() where id = p_user_id;

  for v_request in
    select * from public.service_requests
     where consumer_id = p_user_id and status = 'open'
     for update
  loop
    update public.service_requests
       set status = 'cancelled', cancelled_at = now(), cancelled_by = 'consumer',
           credit_held = false
     where id = v_request.id;
    if v_request.credit_held then
      perform private.return_use(p_user_id, 'consumer');
    end if;
  end loop;

  perform private.admin_log(
    'suspend_user', 'user', p_user_id::text, jsonb_build_object('reason', v_reason)
  );
  return jsonb_build_object('suspended', true, 'already_suspended', false);
end;
$$;

-- Lifts a suspension (also for the same phone number if it signed up again).
create function public.admin_restore_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_has_profile boolean;
  v_hash text;
begin
  perform private.require_admin();
  if p_user_id is null then
    raise exception 'invalid_target' using errcode = '22023';
  end if;

  select * into v_profile from public.profiles where id = p_user_id for update;
  v_has_profile := found;
  select phone_hash into v_hash from private.suspensions where user_id = p_user_id;
  if not v_has_profile and v_hash is null then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if v_hash is null and v_profile.suspended_at is null then
    return jsonb_build_object('suspended', false, 'already_restored', true);
  end if;

  -- Also the account made later with the same number, if there is one.
  update public.profiles set suspended_at = null
   where id = p_user_id
      or id in (select user_id from private.suspensions where phone_hash = v_hash);
  delete from private.suspensions where user_id = p_user_id or phone_hash = v_hash;

  perform private.admin_log('restore_user', 'user', p_user_id::text, '{}'::jsonb);
  return jsonb_build_object('suspended', false, 'already_restored', false);
end;
$$;

-- Settings -----------------------------------------------------------------

-- Everything the settings page shows: free uses, every pack (including the
-- ones switched off), both payment accounts, and the areas live in
-- admin_list_areas.
create function public.admin_get_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();

  return jsonb_build_object(
    'consumer_free_requests', (select consumer_free_requests from public.app_settings),
    'technician_free_jobs', (select technician_free_jobs from public.app_settings),
    'verified_technician_target', (select verified_technician_target from public.app_settings),
    'ads_min_technicians', 10,
    'packs', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', k.id, 'role', k.role, 'uses', k.uses,
               'price_piastres', k.price_piastres, 'sort_order', k.sort_order,
               'is_active', k.is_active
             ) order by k.role, k.sort_order, k.uses), '[]')
        from public.credit_packs k
    ),
    'payment_accounts', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'method', a.method, 'account', a.account,
               'holder_name', a.holder_name, 'is_active', a.is_active
             ) order by a.method), '[]')
        from public.payment_accounts a
    )
  );
end;
$$;

-- Free uses for new people (0 to 20 each) and the verified-technician target
-- (1 to 100000). Anything left null stays as it is. Changes what new
-- accounts get, not what people already hold. Needs a recent login.
create function public.admin_update_settings(
  p_consumer_free_requests smallint default null,
  p_technician_free_jobs smallint default null,
  p_verified_technician_target integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.app_settings;
  v_new public.app_settings;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  if p_consumer_free_requests is null and p_technician_free_jobs is null
     and p_verified_technician_target is null then
    raise exception 'nothing_to_update' using errcode = '22023';
  end if;
  if p_consumer_free_requests not between 0 and 20
     or p_technician_free_jobs not between 0 and 20
     or p_verified_technician_target not between 1 and 100000 then
    raise exception 'invalid_value' using errcode = '22023';
  end if;

  select * into v_old from public.app_settings for update;
  update public.app_settings
     set consumer_free_requests = coalesce(p_consumer_free_requests, consumer_free_requests),
         technician_free_jobs = coalesce(p_technician_free_jobs, technician_free_jobs),
         verified_technician_target = coalesce(p_verified_technician_target, verified_technician_target),
         updated_at = now()
   returning * into v_new;

  perform private.admin_log(
    'update_settings', 'app_settings', null,
    jsonb_build_object(
      'before', jsonb_build_object(
        'consumer_free_requests', v_old.consumer_free_requests,
        'technician_free_jobs', v_old.technician_free_jobs,
        'verified_technician_target', v_old.verified_technician_target
      ),
      'after', jsonb_build_object(
        'consumer_free_requests', v_new.consumer_free_requests,
        'technician_free_jobs', v_new.technician_free_jobs,
        'verified_technician_target', v_new.verified_technician_target
      )
    )
  );
  return jsonb_build_object(
    'consumer_free_requests', v_new.consumer_free_requests,
    'technician_free_jobs', v_new.technician_free_jobs,
    'verified_technician_target', v_new.verified_technician_target
  );
end;
$$;

-- Adds a pack (p_id null) or changes one. Uses 1 to 1000, price 1 to
-- 1,000,000 EGP in piastres. Packs are never deleted (transfers point at
-- them), only switched off; a role always keeps one pack on sale, and two
-- packs on sale can't have the same number of uses. Transfers already sent
-- keep the price they were made at. Needs a recent login.
create function public.admin_save_credit_pack(
  p_id uuid,
  p_role public.user_role,
  p_uses integer,
  p_price_piastres bigint,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.credit_packs;
  v_pack public.credit_packs;
  v_active boolean := coalesce(p_is_active, true);
begin
  perform private.require_admin();
  perform private.require_recent_login();
  if p_role is null
     or p_uses is null or p_uses not between 1 and 1000
     or p_price_piastres is null or p_price_piastres not between 100 and 100000000
     or coalesce(p_sort_order, 0) not between 0 and 1000 then
    raise exception 'invalid_value' using errcode = '22023';
  end if;

  -- Serialises the admins editing packs of one role.
  perform 1 from public.credit_packs where role = p_role for update;

  if p_id is not null then
    select * into v_old from public.credit_packs where id = p_id for update;
    if not found then
      raise exception 'pack_not_found' using errcode = 'P0002';
    end if;
  end if;

  if v_active and exists (
    select 1 from public.credit_packs
     where role = p_role and uses = p_uses and is_active and id is distinct from p_id
  ) then
    raise exception 'duplicate_pack' using errcode = '23505';
  end if;

  if p_id is null then
    insert into public.credit_packs (role, uses, price_piastres, sort_order, is_active)
    values (p_role, p_uses, p_price_piastres, coalesce(p_sort_order, 0), v_active)
    returning * into v_pack;
  else
    update public.credit_packs
       set role = p_role, uses = p_uses, price_piastres = p_price_piastres,
           sort_order = coalesce(p_sort_order, 0), is_active = v_active
     where id = p_id
    returning * into v_pack;
  end if;

  -- Neither this role nor, if the role changed, the old one may end with
  -- nothing on sale.
  if not exists (select 1 from public.credit_packs where role = v_pack.role and is_active)
     or (v_old.id is not null and not exists (
       select 1 from public.credit_packs where role = v_old.role and is_active
     )) then
    raise exception 'last_active_pack' using errcode = 'P0001';
  end if;

  perform private.admin_log(
    case when p_id is null then 'create_credit_pack' else 'update_credit_pack' end,
    'credit_pack', v_pack.id::text,
    jsonb_build_object(
      'before', case when v_old.id is not null then jsonb_build_object(
        'role', v_old.role, 'uses', v_old.uses, 'price_piastres', v_old.price_piastres,
        'is_active', v_old.is_active) end,
      'after', jsonb_build_object(
        'role', v_pack.role, 'uses', v_pack.uses, 'price_piastres', v_pack.price_piastres,
        'is_active', v_pack.is_active)
    )
  );
  return jsonb_build_object(
    'id', v_pack.id, 'role', v_pack.role, 'uses', v_pack.uses,
    'price_piastres', v_pack.price_piastres, 'sort_order', v_pack.sort_order,
    'is_active', v_pack.is_active
  );
end;
$$;

-- Changes where people send money. An InstaPay address is 3 to 64 plain
-- characters (letters, digits, @ . _ -), a wallet an Egyptian mobile number;
-- at least one account stays on. Needs a recent login.
create function public.admin_update_payment_account(
  p_method public.topup_method,
  p_account text,
  p_holder_name text,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account text := translate(btrim(coalesce(p_account, '')), '٠١٢٣٤٥٦٧٨٩ ', '0123456789');
  v_holder text := private.normalize_text(p_holder_name);
  v_active boolean := coalesce(p_is_active, true);
  v_old public.payment_accounts;
  v_new public.payment_accounts;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  if p_method is null
     or (p_method = 'wallet' and v_account !~ '^01[0125][0-9]{8}$')
     or (p_method = 'instapay' and v_account !~ '^[A-Za-z0-9@._-]{3,64}$')
     or v_holder is null or char_length(v_holder) not between 2 and 80
     or v_holder ~ '[[:cntrl:]]' then
    raise exception 'invalid_value' using errcode = '22023';
  end if;

  perform 1 from public.payment_accounts for update;
  select * into v_old from public.payment_accounts where method = p_method;
  if not found then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;

  update public.payment_accounts
     set account = v_account, holder_name = v_holder, is_active = v_active
   where method = p_method
  returning * into v_new;
  if not exists (select 1 from public.payment_accounts where is_active) then
    raise exception 'last_active_account' using errcode = 'P0001';
  end if;

  perform private.admin_log(
    'update_payment_account', 'payment_account', p_method::text,
    jsonb_build_object(
      'before', jsonb_build_object(
        'account', v_old.account, 'holder_name', v_old.holder_name, 'is_active', v_old.is_active),
      'after', jsonb_build_object(
        'account', v_new.account, 'holder_name', v_new.holder_name, 'is_active', v_new.is_active)
    )
  );
  return jsonb_build_object(
    'method', v_new.method, 'account', v_new.account,
    'holder_name', v_new.holder_name, 'is_active', v_new.is_active
  );
end;
$$;

-- Adds an area or changes one (matched by p_id: lower case letters, digits
-- and _, starting with a letter). Latitude 22 to 32, longitude 24 to 37.
-- p_sort_order null puts a new area last and leaves an existing one alone.
create function public.admin_save_service_area(
  p_id text,
  p_name_ar text,
  p_city_ar text,
  p_center_lat double precision,
  p_center_lng double precision,
  p_is_open boolean default true,
  p_sort_order smallint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := private.normalize_text(p_name_ar);
  v_city text := private.normalize_text(p_city_ar);
  v_exists boolean;
  v_area public.service_areas;
begin
  perform private.require_admin();
  if p_id is null or p_id !~ '^[a-z][a-z0-9_]{1,47}$'
     or v_name is null or char_length(v_name) not between 2 and 40 or v_name ~ '[[:cntrl:]]'
     or v_city is null or char_length(v_city) not between 2 and 40 or v_city ~ '[[:cntrl:]]'
     or p_center_lat is null or p_center_lat not between 22 and 32
     or p_center_lng is null or p_center_lng not between 24 and 37
     or p_is_open is null
     or p_sort_order < 0 then
    raise exception 'invalid_value' using errcode = '22023';
  end if;

  select exists (select 1 from public.service_areas where id = p_id) into v_exists;
  begin
    if v_exists then
      update public.service_areas
         set name_ar = v_name, city_ar = v_city, center_lat = p_center_lat,
             center_lng = p_center_lng, is_open = p_is_open,
             sort_order = coalesce(p_sort_order, sort_order)
       where id = p_id
      returning * into v_area;
    else
      insert into public.service_areas (id, name_ar, city_ar, center_lat, center_lng, is_open, sort_order)
      values (
        p_id, v_name, v_city, p_center_lat, p_center_lng, p_is_open,
        coalesce(p_sort_order, (select coalesce(max(sort_order), 0) + 1 from public.service_areas)::smallint)
      )
      returning * into v_area;
    end if;
  exception when unique_violation then
    raise exception 'duplicate_area' using errcode = '23505';
  end;

  perform private.admin_log(
    case when v_exists then 'update_area' else 'create_area' end,
    'service_area', v_area.id,
    jsonb_build_object('name_ar', v_area.name_ar, 'is_open', v_area.is_open)
  );
  return jsonb_build_object(
    'id', v_area.id, 'name_ar', v_area.name_ar, 'city_ar', v_area.city_ar,
    'is_open', v_area.is_open, 'sort_order', v_area.sort_order
  );
end;
$$;

-- Opens or closes an area for new requests.
create function public.admin_set_area_open(p_area_id text, p_is_open boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_area public.service_areas;
begin
  perform private.require_admin();
  if p_is_open is null then
    raise exception 'invalid_value' using errcode = '22023';
  end if;

  update public.service_areas set is_open = p_is_open where id = p_area_id
  returning * into v_area;
  if not found then
    raise exception 'area_not_found' using errcode = 'P0002';
  end if;

  perform private.admin_log(
    'set_area_open', 'service_area', v_area.id, jsonb_build_object('is_open', p_is_open)
  );
  return jsonb_build_object('id', v_area.id, 'is_open', v_area.is_open);
end;
$$;

-- Audit log -------------------------------------------------------------------

-- Newest first; filter by action and/or target id.
create function public.admin_list_audit_log(
  p_action text default null,
  p_target_id text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();

  return jsonb_build_object(
    'total', (
      select count(*) from private.admin_audit_log l
       where (p_action is null or l.action = p_action)
         and (p_target_id is null or l.target_id = p_target_id)
    ),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.created_at desc, x.id desc), '[]')
        from (
          select l.id, l.created_at, jsonb_build_object(
                   'id', l.id,
                   'admin_id', l.admin_id,
                   'admin_name', p.full_name,
                   'action', l.action,
                   'target_type', l.target_type,
                   'target_id', l.target_id,
                   'details', l.details,
                   'created_at', l.created_at
                 ) as item
            from private.admin_audit_log l
            left join public.profiles p on p.id = l.admin_id
           where (p_action is null or l.action = p_action)
             and (p_target_id is null or l.target_id = p_target_id)
           order by l.created_at desc, l.id desc
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Grants -------------------------------------------------------------------------

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function
  public.admin_overview(text),
  public.admin_list_areas(text, integer, integer),
  public.admin_list_verifications(public.verification_status, integer, integer),
  public.admin_get_verification(uuid),
  public.admin_approve_verification(uuid),
  public.admin_reject_verification(uuid, text),
  public.admin_list_topups(public.topup_status, public.user_role, integer, integer),
  public.admin_approve_topup(uuid),
  public.admin_reject_topup(uuid, text),
  public.admin_list_requests(text, text, text, integer, integer, integer),
  public.admin_list_complaints(text, integer, integer),
  public.admin_resolve_complaint(uuid, text),
  public.admin_list_users(public.user_role, text, text, text, integer, integer),
  public.admin_suspend_user(uuid, text),
  public.admin_restore_user(uuid),
  public.admin_get_settings(),
  public.admin_update_settings(smallint, smallint, integer),
  public.admin_save_credit_pack(uuid, public.user_role, integer, bigint, boolean, integer),
  public.admin_update_payment_account(public.topup_method, text, text, boolean),
  public.admin_save_service_area(text, text, text, double precision, double precision, boolean, smallint),
  public.admin_set_area_open(text, boolean),
  public.admin_list_audit_log(text, text, integer, integer)
from public, anon;

grant execute on function
  public.admin_overview(text),
  public.admin_list_areas(text, integer, integer),
  public.admin_list_verifications(public.verification_status, integer, integer),
  public.admin_get_verification(uuid),
  public.admin_approve_verification(uuid),
  public.admin_reject_verification(uuid, text),
  public.admin_list_topups(public.topup_status, public.user_role, integer, integer),
  public.admin_approve_topup(uuid),
  public.admin_reject_topup(uuid, text),
  public.admin_list_requests(text, text, text, integer, integer, integer),
  public.admin_list_complaints(text, integer, integer),
  public.admin_resolve_complaint(uuid, text),
  public.admin_list_users(public.user_role, text, text, text, integer, integer),
  public.admin_suspend_user(uuid, text),
  public.admin_restore_user(uuid),
  public.admin_get_settings(),
  public.admin_update_settings(smallint, smallint, integer),
  public.admin_save_credit_pack(uuid, public.user_role, integer, bigint, boolean, integer),
  public.admin_update_payment_account(public.topup_method, text, text, boolean),
  public.admin_save_service_area(text, text, text, double precision, double precision, boolean, smallint),
  public.admin_set_area_open(text, boolean),
  public.admin_list_audit_log(text, text, integer, integer)
to authenticated;
