-- Milestone 4: buying uses (credits) by manual transfer, and the ledger.
--
-- Prices and the accounts people transfer to are data, so they change
-- without a release. A person picks a pack, transfers the money, uploads
-- the screenshot and the sender's number; we check the transfer and then
-- approve it (service role only, for now by hand and later from the
-- dashboard). Every movement of a balance lands in the ledger.

create type public.topup_method as enum ('instapay', 'wallet');
create type public.topup_status as enum ('pending', 'approved', 'rejected');
create type public.ledger_reason as enum (
  'free_grant', 'opening_balance', 'request_sent', 'request_refunded', 'topup',
  'admin_adjustment'
);

-- What can be bought: consumers buy request uses, technicians job uses.
create table public.credit_packs (
  id uuid primary key default gen_random_uuid(),
  role public.user_role not null check (role in ('consumer', 'technician')),
  uses integer not null check (uses between 1 and 1000),
  price_piastres bigint not null check (price_piastres between 100 and 100000000),
  sort_order integer not null default 0,
  is_active boolean not null default true
);
alter table public.credit_packs enable row level security;
create policy "Anyone signed in sees the packs on sale"
  on public.credit_packs for select to authenticated
  using (is_active);

-- Where people send the money. Placeholders until amr sets the real ones.
create table public.payment_accounts (
  method public.topup_method primary key,
  account text not null check (char_length(account) between 3 and 64),
  holder_name text not null check (char_length(holder_name) between 2 and 80),
  is_active boolean not null default true
);
alter table public.payment_accounts enable row level security;
create policy "Anyone signed in sees where to transfer"
  on public.payment_accounts for select to authenticated
  using (is_active);

insert into public.credit_packs (role, uses, price_piastres, sort_order)
values
  ('consumer', 1, 2000, 1),
  ('consumer', 5, 8000, 2),
  ('technician', 1, 3000, 1),
  ('technician', 10, 25000, 2);

insert into public.payment_accounts (method, account, holder_name)
values
  ('instapay', 'set-me@instapay', 'اسم الشركة'),
  ('wallet', '01000000000', 'اسم الشركة');

-- A transfer someone says they made, waiting for us to check it.
create table public.credit_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.user_role not null,
  pack_id uuid not null references public.credit_packs (id),
  uses integer not null check (uses > 0),
  amount_piastres bigint not null check (amount_piastres > 0),
  method public.topup_method not null,
  sender_account text not null check (char_length(sender_account) between 3 and 64),
  screenshot_path text not null unique,
  status public.topup_status not null default 'pending',
  reject_reason text check (char_length(reject_reason) <= 200),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index credit_topups_user_idx on public.credit_topups (user_id, created_at desc);
create index credit_topups_pending_idx on public.credit_topups (created_at) where status = 'pending';
alter table public.credit_topups enable row level security;
create policy "People see their own transfers"
  on public.credit_topups for select to authenticated
  using (user_id = (select auth.uid()));

-- Every movement of a balance, newest first in the app.
create table public.credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.user_role not null,
  delta integer not null check (delta <> 0),
  reason public.ledger_reason not null,
  topup_id uuid references public.credit_topups (id),
  created_at timestamptz not null default now()
);
create index credit_ledger_user_idx on public.credit_ledger (user_id, created_at desc);
alter table public.credit_ledger enable row level security;
create policy "People see their own movements"
  on public.credit_ledger for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.credit_packs, public.payment_accounts,
  public.credit_topups, public.credit_ledger from anon, authenticated;
grant select on public.credit_packs, public.payment_accounts,
  public.credit_topups, public.credit_ledger to authenticated;

-- The two functions milestone 3 left as the only places that change a
-- balance now also write the ledger.
create or replace function private.take_use(p_user_id uuid, p_role public.user_role)
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
  insert into public.credit_ledger (user_id, role, delta, reason)
  values (p_user_id, p_role, -1, 'request_sent');
end;
$$;

create or replace function private.return_use(p_user_id uuid, p_role public.user_role)
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
  if found then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (p_user_id, p_role, 1, 'request_refunded');
  end if;
end;
$$;

-- The ledger must add up to the balance: the uses people already hold
-- become an opening balance, and the free uses granted at sign-up are
-- written as they are granted.
insert into public.credit_ledger (user_id, role, delta, reason)
select id, 'consumer'::public.user_role, request_credits, 'opening_balance'::public.ledger_reason
  from public.consumer_profiles where request_credits > 0
union all
select id, 'technician'::public.user_role, job_credits, 'opening_balance'::public.ledger_reason
  from public.technician_profiles where job_credits > 0;

create function private.log_consumer_free_grant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.request_credits > 0 then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (new.id, 'consumer', new.request_credits, 'free_grant');
  end if;
  return null;
end;
$$;

create function private.log_technician_free_grant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.job_credits > 0 then
    insert into public.credit_ledger (user_id, role, delta, reason)
    values (new.id, 'technician', new.job_credits, 'free_grant');
  end if;
  return null;
end;
$$;

create trigger consumer_free_grant after insert on public.consumer_profiles
  for each row execute function private.log_consumer_free_grant();
create trigger technician_free_grant after insert on public.technician_profiles
  for each row execute function private.log_technician_free_grant();

-- Transfer proofs: private, insert-only into the sender's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('transfer-proofs', 'transfer-proofs', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']);

create policy "People upload transfer proofs to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'transfer-proofs'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and guard.upload_quota_left(bucket_id)
  );

-- Says a transfer was made. The pack's price is copied, so a later price
-- change doesn't alter what was paid. Two waiting transfers at most, so
-- nobody floods the queue.
create function public.submit_topup(
  p_pack_id uuid,
  p_method public.topup_method,
  p_sender_account text,
  p_screenshot_path text,
  p_expected_price_piastres bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_pack public.credit_packs;
  v_sender text := btrim(coalesce(p_sender_account, ''));
  v_digits text;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;

  select * into v_pack from public.credit_packs where id = p_pack_id and is_active;
  if not found then
    raise exception 'pack_not_found' using errcode = 'P0002';
  end if;
  -- What the person saw and transferred is what the pack must still cost.
  if v_pack.price_piastres is distinct from p_expected_price_piastres then
    raise exception 'price_changed' using errcode = 'P0001';
  end if;
  if (
    v_pack.role = 'consumer'
    and not exists (select 1 from public.consumer_profiles where id = v_user_id)
  ) or (
    v_pack.role = 'technician'
    and not exists (select 1 from public.technician_profiles where id = v_user_id)
  ) then
    raise exception 'pack_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.payment_accounts where method = p_method and is_active
  ) then
    raise exception 'method_unavailable' using errcode = '22023';
  end if;

  -- The number or handle the money came from: for a wallet, an Egyptian
  -- mobile number (digits may be Arabic-Indic); InstaPay also takes an
  -- address, but no control characters.
  v_digits := translate(v_sender, '٠١٢٣٤٥٦٧٨٩ ', '0123456789');
  if p_method = 'wallet' then
    if v_digits !~ '^01[0125][0-9]{8}$' then
      raise exception 'invalid_sender' using errcode = '22023';
    end if;
    v_sender := v_digits;
  elsif v_digits ~ '^01[0125][0-9]{8}$' then
    v_sender := v_digits;
  elsif v_sender !~ '^[A-Za-z0-9@._-]{3,64}$' then
    -- An InstaPay address: plain characters only, so nothing odd (control
    -- or direction marks, markup) reaches whoever reviews the transfer.
    raise exception 'invalid_sender' using errcode = '22023';
  end if;

  if p_screenshot_path is null
     or split_part(p_screenshot_path, '/', 1) <> v_user_id::text
     or not exists (
       select 1 from storage.objects
        where bucket_id = 'transfer-proofs'
          and name = p_screenshot_path
          and owner_id = v_user_id::text
     ) then
    raise exception 'invalid_screenshot' using errcode = '22023';
  end if;

  -- One waiting transfer at a time per role, serialised on the profile.
  perform 1 from public.profiles where id = v_user_id for update;
  if (
    select count(*) from public.credit_topups
     where user_id = v_user_id and role = v_pack.role and status = 'pending'
  ) >= 2 then
    raise exception 'too_many_pending' using errcode = 'P0001';
  end if;

  begin
    insert into public.credit_topups (
      user_id, role, pack_id, uses, amount_piastres, method,
      sender_account, screenshot_path
    )
    values (
      v_user_id, v_pack.role, v_pack.id, v_pack.uses, v_pack.price_piastres,
      p_method, v_sender, p_screenshot_path
    )
    returning id into v_id;
  exception when unique_violation then
    raise exception 'invalid_screenshot' using errcode = '22023';
  end;
  return v_id;
end;
$$;

revoke execute on function public.submit_topup(uuid, public.topup_method, text, text, bigint)
  from public, anon;
grant execute on function public.submit_topup(uuid, public.topup_method, text, text, bigint)
  to authenticated;

-- Checked and found right: the uses are added exactly once. Not reachable
-- from the API.
create function private.approve_topup(p_topup_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_topup public.credit_topups;
begin
  select * into v_topup from public.credit_topups where id = p_topup_id for update;
  if not found then
    raise exception 'topup_not_found' using errcode = 'P0002';
  end if;
  if v_topup.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  if v_topup.role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits + v_topup.uses
     where id = v_topup.user_id;
  else
    update public.technician_profiles
       set job_credits = job_credits + v_topup.uses
     where id = v_topup.user_id;
  end if;
  if not found then
    raise exception 'topup_not_found' using errcode = 'P0002';
  end if;

  insert into public.credit_ledger (user_id, role, delta, reason, topup_id)
  values (v_topup.user_id, v_topup.role, v_topup.uses, 'topup', v_topup.id);
  update public.credit_topups
     set status = 'approved', reviewed_at = now()
   where id = v_topup.id;
end;
$$;

create function private.reject_topup(p_topup_id uuid, p_reason text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.credit_topups
     set status = 'rejected',
         reject_reason = left(btrim(coalesce(p_reason, '')), 200),
         reviewed_at = now()
   where id = p_topup_id and status = 'pending';
  if not found then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;
end;
$$;

-- The review calls live in the private schema, which no API role can enter;
-- they run from a database session (the SQL editor, or the dashboard's
-- backend later). Nothing else may execute them either.
revoke execute on function private.approve_topup(uuid), private.reject_topup(uuid, text)
  from public;
