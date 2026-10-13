-- Invite a friend: everyone has a short invite code. A newcomer who types a
-- friend's code in their first two weeks gets one free use, and so does the
-- friend (up to ten friends, so an invite can't be farmed). The use lands
-- in the role each of them is using now: a request for a consumer, a job
-- for a technician.

alter table public.profiles
  add column referral_code text unique check (referral_code ~ '^[A-HJ-NP-Z2-9]{8}$');

create table public.referrals (
  invitee_id uuid primary key references public.profiles (id) on delete cascade,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (invitee_id <> inviter_id)
);
create index referrals_inviter_idx on public.referrals (inviter_id);
alter table public.referrals enable row level security;
revoke all on public.referrals from anon, authenticated;

-- One free use for [p_user_id] in the role they are using now.
create function private.grant_referral_use(p_user_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_role public.user_role;
begin
  select active_role into v_role from public.profiles where id = p_user_id;
  if v_role = 'consumer' then
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
    values (p_user_id, v_role, 1, 'referral_reward');
  end if;
end;
$$;

-- The caller's invite code, made on first ask, and how many friends came.
create function public.my_referral()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_code text;
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  perform private.assert_active();
  select referral_code into v_code from public.profiles where id = v_user_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  while v_code is null loop
    v_code := (
      select string_agg(substr(v_alphabet, 1 + floor(random() * 32)::integer, 1), '')
        from generate_series(1, 8)
    );
    begin
      update public.profiles set referral_code = v_code where id = v_user_id;
    exception when unique_violation then
      v_code := null;
    end;
  end loop;
  return jsonb_build_object(
    'code', v_code,
    'invited', (select count(*) from public.referrals where inviter_id = v_user_id),
    'max_rewards', 10
  );
end;
$$;

-- A newcomer types a friend's code.
create function public.redeem_referral(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_created_at timestamptz;
  v_inviter_id uuid;
begin
  perform private.assert_active();
  select created_at into v_created_at from public.profiles where id = v_user_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select id into v_inviter_id from public.profiles
   where referral_code = upper(btrim(coalesce(p_code, '')));
  if v_inviter_id is null then
    raise exception 'invalid_code' using errcode = '22023';
  end if;
  if v_inviter_id = v_user_id then
    raise exception 'own_code' using errcode = '22023';
  end if;
  if v_created_at < now() - interval '14 days'
     or exists (select 1 from public.referrals where invitee_id = v_user_id)
     or exists (
       select 1 from public.referrals
        where invitee_id = v_inviter_id and inviter_id = v_user_id
     ) then
    raise exception 'referral_unavailable' using errcode = 'P0001';
  end if;
  insert into public.referrals (invitee_id, inviter_id) values (v_user_id, v_inviter_id);
  perform private.grant_referral_use(v_user_id);
  if (select count(*) from public.referrals where inviter_id = v_inviter_id) <= 10 then
    perform private.grant_referral_use(v_inviter_id);
  end if;
end;
$$;

revoke execute on function public.my_referral(), public.redeem_referral(text) from public, anon;
grant execute on function public.my_referral(), public.redeem_referral(text) to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
