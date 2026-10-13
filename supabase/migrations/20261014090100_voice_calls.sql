-- Voice calls inside the app, between a consumer and a technician who can
-- chat: the audio goes straight between the two phones (WebRTC), so nothing
-- is recorded or stored here. The database only rings the other phone and
-- carries the few small messages two phones trade to find each other
-- (call_signals), which are deleted after a day.
--
-- Who may call: the same two people the chat is open for. One call at a
-- time each; a call nobody picks up within 45 seconds is missed.

create type public.call_status as enum ('ringing', 'answered', 'ended', 'declined', 'missed');

create table public.request_calls (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  caller_id uuid not null references public.profiles (id) on delete cascade,
  callee_id uuid not null references public.profiles (id) on delete cascade,
  status public.call_status not null default 'ringing',
  created_at timestamptz not null default clock_timestamp(),
  answered_at timestamptz,
  ended_at timestamptz,
  check (caller_id <> callee_id)
);
create index request_calls_callee_idx on public.request_calls (callee_id, created_at desc);
create index request_calls_active_idx on public.request_calls (caller_id)
  where status in ('ringing', 'answered');

create table public.call_signals (
  id bigint generated always as identity primary key,
  call_id uuid not null references public.request_calls (id) on delete cascade,
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('offer', 'answer', 'candidate')),
  payload jsonb not null check (char_length(payload::text) <= 8000),
  created_at timestamptz not null default now()
);
create index call_signals_call_idx on public.call_signals (call_id, id);

alter table public.request_calls enable row level security;
alter table public.call_signals enable row level security;
revoke all on public.request_calls, public.call_signals from anon, authenticated;
grant select on public.request_calls, public.call_signals to authenticated;

-- The people in a call see it (Realtime applies the same rule), and each
-- signal is read only by the phone it is for.
create policy "People see their own calls"
  on public.request_calls for select to authenticated
  using ((select auth.uid()) in (caller_id, callee_id));
create policy "People see the signals meant for them"
  on public.call_signals for select to authenticated
  using (to_user_id = (select auth.uid()));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public'
         and tablename = 'request_calls'
    ) then
      alter publication supabase_realtime add table public.request_calls;
    end if;
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public'
         and tablename = 'call_signals'
    ) then
      alter publication supabase_realtime add table public.call_signals;
    end if;
  end if;
end;
$$;

-- A ring nobody answered is missed; a call left open for hours (a phone that
-- died) is over.
create function private.expire_calls()
returns void
language sql
set search_path = ''
as $$
  update public.request_calls
     set status = 'missed', ended_at = now()
   where status = 'ringing' and created_at < now() - interval '45 seconds';
  update public.request_calls
     set status = 'ended', ended_at = now()
   where status = 'answered' and answered_at < now() - interval '3 hours';
$$;

-- The other person of call [p_call] for the caller, null when the caller is
-- not in it.
create function private.call_peer(p_call_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when c.caller_id = auth.uid() then c.callee_id else c.caller_id end
    from public.request_calls c
   where c.id = p_call_id and auth.uid() in (c.caller_id, c.callee_id);
$$;

create function public.start_call(p_request_id uuid, p_technician_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_access jsonb;
  v_callee uuid;
  v_callee_role public.user_role;
  v_call public.request_calls;
begin
  perform private.assert_active();
  perform private.expire_calls();
  v_access := private.chat_access(p_request_id, p_technician_id);
  if v_access is null or not (v_access ->> 'open')::boolean then
    raise exception 'call_unavailable' using errcode = 'P0001';
  end if;
  if v_user_id = p_technician_id then
    v_callee := (v_access ->> 'consumer_id')::uuid;
    v_callee_role := 'consumer';
  else
    v_callee := p_technician_id;
    v_callee_role := 'technician';
  end if;
  if exists (
    select 1 from public.request_calls
     where status in ('ringing', 'answered') and v_user_id in (caller_id, callee_id)
  ) then
    raise exception 'call_in_progress' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.request_calls
     where status in ('ringing', 'answered') and v_callee in (caller_id, callee_id)
  ) then
    raise exception 'callee_busy' using errcode = 'P0001';
  end if;

  perform private.rate_limit('start_call', 10, interval '10 minutes');

  insert into public.request_calls (request_id, technician_id, caller_id, callee_id)
  values (p_request_id, p_technician_id, v_user_id, v_callee)
  returning * into v_call;

  perform private.notify(
    v_callee, v_callee_role, 'incoming_call', p_request_id, (v_access ->> 'offer_id')::uuid
  );

  return jsonb_build_object('id', v_call.id);
end;
$$;

create function public.answer_call(p_call_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_active();
  perform private.expire_calls();
  update public.request_calls
     set status = 'answered', answered_at = now()
   where id = p_call_id and callee_id = auth.uid() and status = 'ringing';
  if not found then
    raise exception 'call_unavailable' using errcode = 'P0001';
  end if;
end;
$$;

-- Hangs up, declines or cancels, whichever the moment is. Ending a call
-- that is over already does nothing.
create function public.end_call(p_call_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.expire_calls();
  update public.request_calls
     set status = case
           when status = 'ringing' and callee_id = auth.uid() then 'declined'
           else 'ended'
         end::public.call_status,
         ended_at = now()
   where id = p_call_id
     and auth.uid() in (caller_id, callee_id)
     and status in ('ringing', 'answered');
  delete from public.call_signals where call_id = p_call_id
     and exists (
       select 1 from public.request_calls c
        where c.id = p_call_id and c.status not in ('ringing', 'answered')
     );
end;
$$;

-- One message of the handshake, for the other phone.
create function public.send_call_signal(p_call_id uuid, p_kind text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_peer uuid := private.call_peer(p_call_id);
begin
  perform private.assert_active();
  perform private.expire_calls();
  if v_peer is null
     or not exists (
       select 1 from public.request_calls
        where id = p_call_id and status in ('ringing', 'answered')
     ) then
    raise exception 'call_unavailable' using errcode = 'P0001';
  end if;
  if p_kind not in ('offer', 'answer', 'candidate')
     or p_payload is null
     or char_length(p_payload::text) > 8000 then
    raise exception 'invalid_signal' using errcode = '22023';
  end if;
  perform private.rate_limit('call_signal', 300, interval '1 minute');
  insert into public.call_signals (call_id, to_user_id, kind, payload)
  values (p_call_id, v_peer, p_kind, p_payload);
end;
$$;

-- The handshake messages for me that I may have missed (Realtime delivers
-- the new ones), oldest first.
create function public.call_signals_after(p_call_id uuid, p_after bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'kind', s.kind, 'payload', s.payload
         ) order by s.id), '[]')
    from public.call_signals s
   where s.call_id = p_call_id
     and s.to_user_id = auth.uid()
     and s.id > coalesce(p_after, 0);
$$;

-- A call ringing for me now, for when I open the app from its notice.
create function public.pending_call()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_call public.request_calls;
begin
  perform private.expire_calls();
  select * into v_call from public.request_calls
   where callee_id = v_user_id and status = 'ringing'
   order by created_at desc limit 1;
  if not found then
    return null;
  end if;
  return jsonb_build_object(
    'id', v_call.id,
    'request_id', v_call.request_id,
    'technician_id', v_call.technician_id,
    'caller_name', case
      when v_call.caller_id = v_call.technician_id then (
        select p.full_name from public.profiles p where p.id = v_call.caller_id
      )
      else (
        select private.short_name(p.full_name)
          from public.profiles p where p.id = v_call.caller_id
      )
    end,
    'created_at', v_call.created_at
  );
end;
$$;

revoke execute on function
  public.start_call(uuid, uuid), public.answer_call(uuid), public.end_call(uuid),
  public.send_call_signal(uuid, text, jsonb), public.call_signals_after(uuid, bigint),
  public.pending_call()
  from public, anon;
grant execute on function
  public.start_call(uuid, uuid), public.answer_call(uuid), public.end_call(uuid),
  public.send_call_signal(uuid, text, jsonb), public.call_signals_after(uuid, bigint),
  public.pending_call()
  to authenticated;

-- Hand-shake messages and old calls are not kept.
create function private.purge_calls()
returns void
language sql
set search_path = ''
as $$
  delete from public.call_signals where created_at < now() - interval '1 day';
  delete from public.request_calls where created_at < now() - interval '90 days';
$$;
select cron.schedule('purge-calls', '30 3 * * *', 'select private.purge_calls()');

-- The ring reaches the phone too.
create or replace function private.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
set search_path = ''
as $function$
  select p_kind::text = any (array[
    'offer_received', 'technician_arriving', 'job_confirmed', 'job_started',
    'job_finished', 'price_change', 'request_cancelled_by_technician',
    'request_expired', 'new_request', 'offer_picked',
    'request_cancelled_by_consumer', 'verification_approved',
    'verification_rejected', 'topup_approved', 'topup_rejected',
    'offer_countered', 'offer_revised', 'offer_withdrawn', 'counter_accepted',
    'loyalty_reward', 'maintenance_reminder', 'urgent_request', 'chat_message',
    'escrow_held', 'escrow_rejected', 'escrow_released', 'escrow_paid_out',
    'escrow_disputed', 'escrow_refunded', 'incoming_call'
  ]);
$function$;

revoke execute on all functions in schema private from public, anon, authenticated;
