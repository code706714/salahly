-- Push notifications and the technician's "almost there" button.
--
-- * technician_arriving(request): the technician assigned to a confirmed
--   job tells the consumer he is nearly there. It writes an ordinary
--   notification (kind technician_arriving); nothing else changes.
-- * Device tokens: the phones that may be pushed to. Only the register and
--   unregister functions touch them; nobody can read a token back.
-- * Delivery: every notification worth a push is queued in
--   private.push_outbox by a trigger, in the same transaction. The Edge
--   Function send-push (service role) claims the queue, sends the messages
--   through Firebase Cloud Messaging and reports back. It is woken by the
--   trigger through pg_net and, as a retry, by a cron job every minute, with
--   its URL and secret in the vault (push_dispatch_url,
--   push_dispatch_secret), exactly like the storage purge. Without those
--   secrets nothing is sent and the queue just waits.
--
-- The push carries no text of its own: the function builds the Arabic title
-- and body from the kind, and the request id for the deep link. Never a
-- phone number or an address.

alter type public.notification_kind add value if not exists 'technician_arriving';

-- Device tokens ----------------------------------------------------------------

create table public.device_tokens (
  token text primary key check (
    char_length(token) between 20 and 4096 and token ~ '^[A-Za-z0-9_:.-]+$'
  ),
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id, last_seen_at desc);

-- No policy and no grant: a token is a credential to push to someone's
-- phone, so even its owner can't read it back. The service role and the
-- functions below are the only way in.
alter table public.device_tokens enable row level security;
revoke all on table public.device_tokens from anon, authenticated;

-- Remembers this phone for the signed-in person. A token belongs to one
-- person at a time (a phone that changes hands moves with its new owner),
-- and a person keeps their 5 most recently seen phones.
create function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  perform private.assert_active();
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  if p_token is null or char_length(p_token) not between 20 and 4096
     or p_token !~ '^[A-Za-z0-9_:.-]+$'
     or p_platform is null or p_platform not in ('android', 'ios') then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  -- Serializes one person's registrations so the cap below holds.
  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  insert into public.device_tokens (token, user_id, platform, last_seen_at)
  values (p_token, v_user_id, p_platform, clock_timestamp())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        last_seen_at = clock_timestamp();

  delete from public.device_tokens
   where user_id = v_user_id
     and token not in (
       select d.token
         from public.device_tokens d
        where d.user_id = v_user_id
        order by d.last_seen_at desc, d.created_at desc
        limit 5
     );
end;
$$;

-- Forgets this phone (on sign-out). Someone else's token, or one that is
-- already gone, is left alone and says nothing.
create function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_tokens
   where token = p_token and user_id = (select auth.uid());
$$;

-- "Almost there" ------------------------------------------------------------------

-- Tells the consumer that the technician is nearly there. Only the
-- technician whose offer was picked may, and only while the job is
-- confirmed: not before he confirmed it, and not once the work started,
-- finished or the request was cancelled. Asking again within 10 minutes
-- sends nothing and answers 'already_sent'; a request takes 3 of these at
-- most (limit_reached).
create function public.technician_arriving(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_request public.service_requests;
  v_status text;
  v_last timestamptz;
  v_count integer;
begin
  perform private.assert_active();
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;

  -- Only the picked technician's own request is looked at, and locked so
  -- two taps at once send one. Anyone else learns nothing, not even that
  -- the request exists.
  select r.* into v_request
    from public.service_requests r
    join public.request_offers o on o.id = r.chosen_offer_id
   where r.id = p_request_id
     and o.technician_id = v_user_id
     and o.status = 'accepted'
     for update of r;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  select j.status::text into v_status
    from public.jobs j
   where j.id = v_request.job_id and j.deleted_at is null;
  if v_request.status <> 'assigned' or v_status is distinct from 'confirmed' then
    raise exception 'not_confirmed' using errcode = 'P0001';
  end if;

  select max(n.created_at), count(*) into v_last, v_count
    from public.notifications n
   where n.user_id = v_request.consumer_id
     and n.role = 'consumer'
     and n.kind = 'technician_arriving'
     and n.request_id = p_request_id;
  if v_last > now() - interval '10 minutes' then
    return jsonb_build_object('status', 'already_sent', 'sent_at', v_last);
  end if;
  if v_count >= 3 then
    raise exception 'limit_reached' using errcode = '54000';
  end if;

  perform private.notify(v_request.consumer_id, 'consumer', 'technician_arriving', p_request_id);
  select max(n.created_at) into v_last
    from public.notifications n
   where n.user_id = v_request.consumer_id
     and n.role = 'consumer'
     and n.kind = 'technician_arriving'
     and n.request_id = p_request_id;
  return jsonb_build_object('status', 'sent', 'sent_at', v_last);
end;
$$;

-- The request behind a platform job, for its technician's job page (jobs
-- live on the phone without a link to their request), and whether the
-- consumer was already told he is nearly there. Null for anyone else.
create function public.platform_job_request(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return (
    select jsonb_build_object(
             'request_id', r.id,
             'arriving_sent_at', (
               select max(n.created_at)
                 from public.notifications n
                where n.request_id = r.id
                  and n.user_id = r.consumer_id
                  and n.kind = 'technician_arriving'
             )
           )
      from public.service_requests r
      join public.request_offers o on o.id = r.chosen_offer_id
     where r.job_id = p_job_id
       and o.technician_id = (select auth.uid())
       and o.status = 'accepted'
  );
end;
$$;

-- The consumer's request page also learns when he was told, so the
-- tracking page can say so.
alter function public.request_details(uuid) set schema private;
alter function private.request_details(uuid) rename to request_details_impl;

create function public.request_details(p_request_id uuid)
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
    'technician_arriving_at', (
      select max(n.created_at)
        from public.notifications n
       where n.request_id = p_request_id
         and n.user_id = (select auth.uid())
         and n.role = 'consumer'
         and n.kind = 'technician_arriving'
    )
  );
end;
$$;

-- The push queue ---------------------------------------------------------------------

create table private.push_outbox (
  id bigint generated always as identity primary key,
  notification_id uuid not null unique references public.notifications (id) on delete cascade,
  queued_at timestamptz not null default now(),
  claimed_at timestamptz,
  attempts integer not null default 0
);
alter table private.push_outbox enable row level security;

-- The kinds that deserve a phone buzzing. Left out: offer_not_picked (the
-- list is enough for bad news that needs no action).
create function private.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_kind::text = any (array[
    'offer_received', 'technician_arriving', 'job_confirmed', 'job_started',
    'job_finished', 'price_change', 'request_cancelled_by_technician',
    'request_expired', 'new_request', 'offer_picked',
    'request_cancelled_by_consumer', 'verification_approved',
    'verification_rejected', 'topup_approved', 'topup_rejected'
  ]);
$$;

-- Asks the function to deliver. True when asked; false when the vault has
-- no URL or secret yet (nothing is sent then). pg_net sends only when the
-- surrounding transaction commits.
create function private.send_push_request()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if v_url is null or v_secret is null then
    return false;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret),
    body := '{}'::jsonb
  );
  return true;
end;
$$;

-- A push that can't be queued or requested must never stop the
-- notification itself (nor the change that caused it).
create function private.enqueue_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.push_worthy(new.kind) then
    insert into private.push_outbox (notification_id) values (new.id);
    begin
      perform private.send_push_request();
    exception when others then
      raise warning 'push request failed (sqlstate %)', sqlstate;
    end;
  end if;
  return null;
end;
$$;

create trigger notifications_push after insert on public.notifications
  for each row execute function private.enqueue_push();

-- The sender claims a batch: for each message, who it is for (their phones'
-- tokens), the kind, and the little the text needs. Messages that no longer
-- matter are dropped here: to a suspended person, to someone with no
-- registered phone, and anything over an hour old. A message is claimed
-- again after 2 minutes if the sender never reported it done, and given up
-- after 5 tries.
create function public.push_claim(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids bigint[];
begin
  with picked as (
    select o.id
      from private.push_outbox o
     where o.attempts < 5
       and (o.claimed_at is null or o.claimed_at < now() - interval '2 minutes')
     order by o.id
     limit least(greatest(coalesce(p_limit, 50), 1), 200)
       for update skip locked
  ), claimed as (
    update private.push_outbox q
       set claimed_at = now(), attempts = q.attempts + 1
      from picked
     where q.id = picked.id
    returning q.id
  )
  select coalesce(array_agg(id), '{}') into v_ids from claimed;

  delete from private.push_outbox q
   using public.notifications n
   where q.id = any (v_ids)
     and n.id = q.notification_id
     and (
       n.created_at < now() - interval '1 hour'
       or exists (
         select 1 from public.profiles p where p.id = n.user_id and p.suspended_at is not null
       )
       or not exists (select 1 from public.device_tokens d where d.user_id = n.user_id)
     );

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', q.id,
             'kind', n.kind,
             'role', n.role,
             'request_id', n.request_id,
             'technician_name', case when n.role = 'consumer'
               then split_part(btrim(tp.full_name), ' ', 1) end,
             'honorific', case when n.role = 'consumer' then c.honorific end,
             'tokens', (
               select jsonb_agg(d.token order by d.last_seen_at desc)
                 from public.device_tokens d
                where d.user_id = n.user_id
             )
           ) order by q.id), '[]')
      from private.push_outbox q
      join public.notifications n on n.id = q.notification_id
      left join public.service_requests r on r.id = n.request_id
      left join public.request_offers o
        on o.id = coalesce(n.offer_id, r.chosen_offer_id)
      left join public.profiles tp on tp.id = o.technician_id
      left join public.consumer_profiles c on c.id = n.user_id
     where q.id = any (v_ids)
  );
end;
$$;

-- The sender reports: these messages are finished (sent, or hopeless), and
-- these tokens were refused by Firebase as no longer registered.
create function public.push_done(p_ids bigint[], p_dead_tokens text[] default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.push_outbox where id = any (p_ids);
  delete from public.device_tokens where token = any (p_dead_tokens);
end;
$$;

-- Wakes the sender while messages wait, and tidies up: nothing waits more
-- than a day, and a phone not seen for 60 days is forgotten (the app
-- registers again every time it opens).
create function private.run_push_dispatch()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.push_outbox where queued_at < now() - interval '1 day';
  delete from public.device_tokens where last_seen_at < now() - interval '60 days';
  if exists (
    select 1 from private.push_outbox
     where attempts < 5 and (claimed_at is null or claimed_at < now() - interval '2 minutes')
  ) and not private.send_push_request() then
    raise warning 'push is not configured: vault secrets push_dispatch_url and push_dispatch_secret are missing';
  end if;
end;
$$;

-- How long the oldest message still waiting has waited (null when none).
-- Anything over a few minutes means the sender is not running.
create function private.push_backlog()
returns interval
language sql
stable
set search_path = ''
as $$
  select now() - min(queued_at) from private.push_outbox where attempts < 5;
$$;

-- Who may call what ---------------------------------------------------------------------

revoke execute on all functions in schema private from public, anon, authenticated;
revoke execute on function
  public.register_device_token(text, text),
  public.unregister_device_token(text),
  public.technician_arriving(uuid),
  public.platform_job_request(uuid),
  public.request_details(uuid),
  public.push_claim(integer),
  public.push_done(bigint[], text[])
from public, anon, authenticated;
grant execute on function
  public.register_device_token(text, text),
  public.unregister_device_token(text),
  public.technician_arriving(uuid),
  public.platform_job_request(uuid),
  public.request_details(uuid)
to authenticated;
grant execute on function
  public.push_claim(integer),
  public.push_done(bigint[], text[])
to service_role;

select cron.schedule('push-dispatch', '* * * * *', 'select private.run_push_dispatch()');
