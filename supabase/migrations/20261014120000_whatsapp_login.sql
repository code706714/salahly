-- Sign-in by WhatsApp message, free of any paid code-sending service.
--
-- The phone asks for a short code, opens WhatsApp with a ready message that
-- carries it, and the person only presses send. WhatsApp itself tells our
-- webhook which number sent the message, so no code is ever sent to the
-- person and nothing is billed. The phone then trades its secret for a
-- session (the whatsapp-login function does that with the service role).
--
-- Nothing here is reachable by anon or signed-in users: only the Edge
-- Functions call these, with the service role.

create table private.login_challenges (
  id uuid primary key default gen_random_uuid(),
  -- 8 characters, no I, O, 0 or 1, so it can be read out loud if it must.
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  -- Only the hash of the secret the phone holds is kept.
  poll_hash bytea not null,
  -- The number that sent the code through WhatsApp; null until it does.
  phone text check (phone ~ '^\+201[0125][0-9]{8}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);
alter table private.login_challenges enable row level security;
create index login_challenges_expires_idx on private.login_challenges (expires_at);

-- A new code for a phone that wants to sign in. Returns what the phone keeps
-- (id and secret) and what it shows (the code).
create function public.login_start()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
  v_bytes bytea := uuid_send(gen_random_uuid());
  v_code text := '';
  v_secret text := encode(uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid()), 'hex');
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_expires timestamptz := now() + interval '5 minutes';
begin
  -- Anyone can ask for a code, so the table is capped instead of growing
  -- without limit.
  if (select count(*) from private.login_challenges where expires_at > now()) >= 20000 then
    raise exception 'busy' using errcode = '53300';
  end if;

  for i in 0..7 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) & 31) + 1, 1);
  end loop;

  insert into private.login_challenges (id, code, poll_hash, expires_at)
  values (v_id, v_code, sha256(convert_to(v_secret, 'UTF8')), v_expires);

  return jsonb_build_object(
    'id', v_id,
    'code', v_code,
    'poll_secret', v_secret,
    'expires_at', v_expires
  );
end;
$$;

-- Ties the code in a WhatsApp message to the number that sent it. Only the
-- first message with a live code counts. Returns whether it tied.
create function public.login_bind(p_code text, p_phone text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_phone is null or p_phone !~ '^\+201[0125][0-9]{8}$' then
    return false;
  end if;

  update private.login_challenges c
     set phone = p_phone
   where c.code = upper(coalesce(p_code, ''))
     and c.phone is null
     and c.consumed_at is null
     and c.expires_at > now();
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;

-- pending: nobody has sent the code yet. ready: a number sent it and the
-- phone can claim the session. unknown: no such code, or the secret is wrong
-- or the session was already claimed (the phone cannot tell which).
create function public.login_status(p_id uuid, p_poll_secret text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select case
               when c.consumed_at is not null then 'unknown'
               when c.expires_at <= now() then 'expired'
               when c.phone is null then 'pending'
               else 'ready'
             end
        from private.login_challenges c
       where c.id = p_id
         and c.poll_hash = sha256(convert_to(coalesce(p_poll_secret, ''), 'UTF8'))
    ),
    'unknown'
  );
$$;

-- Hands over the number once, to the phone that holds the secret.
create function public.login_claim(p_id uuid, p_poll_secret text)
returns text
language sql
security definer
set search_path = ''
as $$
  update private.login_challenges c
     set consumed_at = now()
   where c.id = p_id
     and c.poll_hash = sha256(convert_to(coalesce(p_poll_secret, ''), 'UTF8'))
     and c.phone is not null
     and c.consumed_at is null
     and c.expires_at > now()
  returning c.phone;
$$;

-- The account of a phone number, if it has one. Auth keeps numbers without
-- the plus sign.
create function public.login_user_id(p_phone text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id from auth.users u where u.phone = ltrim(p_phone, '+') limit 1;
$$;

revoke execute on function
  public.login_start(),
  public.login_bind(text, text),
  public.login_status(uuid, text),
  public.login_claim(uuid, text),
  public.login_user_id(text)
from public, anon, authenticated;
grant execute on function
  public.login_start(),
  public.login_bind(text, text),
  public.login_status(uuid, text),
  public.login_claim(uuid, text),
  public.login_user_id(text)
to service_role;

select cron.schedule(
  'login-challenges-cleanup',
  '*/10 * * * *',
  $$delete from private.login_challenges where expires_at < now() - interval '1 hour'$$
);
