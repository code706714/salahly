-- In-app chat between a consumer and the technicians who offered on her
-- request, so the two can agree on details without trading phone numbers.
--
-- One conversation per request and technician. It is open while the
-- technician's offer stands (sent or accepted), the request is open or
-- assigned, and, once the job is finished, for the 14 days of its warranty.
-- Messages are written only through send_chat_message and read only through
-- chat_messages, as the people in the conversation.

create table public.request_messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests (id) on delete cascade,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default clock_timestamp()
);

create index request_messages_conversation_idx
  on public.request_messages (request_id, technician_id, created_at);

alter table public.request_messages enable row level security;
revoke all on table public.request_messages from anon, authenticated;

-- Who is in the conversation, and whether it still takes messages. Null
-- when the caller is neither the consumer nor that technician.
create function private.chat_access(p_request_id uuid, p_technician_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'consumer_id', r.consumer_id,
    'offer_id', o.id,
    'open', o.status in ('sent', 'accepted')
            and r.status in ('open', 'assigned')
            and (j.finished_at is null or j.finished_at > now() - interval '14 days')
  )
    from public.service_requests r
    join public.request_offers o
      on o.request_id = r.id and o.technician_id = p_technician_id
    left join public.jobs j on j.id = r.job_id
   where r.id = p_request_id
     and (auth.uid() = r.consumer_id or auth.uid() = p_technician_id);
$$;

-- A phone number, a link or a handle for another app is the one thing the
-- chat exists to keep out. Digits are compared in Western form, with the
-- usual separators dropped, so "٠١٠ 123 45678" counts like "01012345678".
-- Someone spelling a number out in words gets through; the report-a-problem
-- path covers that.
create function private.chat_leaks_contact(p_body text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
           translate(p_body, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'),
           '[\s.\-_/]', '', 'g'
         ) ~ '[0-9]{9,}'
      or p_body ~* '(https?://|www\.|wa\.me|whatsapp|واتس|t\.me|telegram|تيليجرام|تلجرام|@[a-z0-9_]{3,})';
$$;

create function public.send_chat_message(
  p_request_id uuid,
  p_technician_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_access jsonb := private.chat_access(p_request_id, p_technician_id);
  v_body text := btrim(coalesce(p_body, ''));
  v_to uuid;
  v_to_role public.user_role;
  v_message public.request_messages;
begin
  if v_access is null then
    raise exception 'chat_unavailable' using errcode = 'P0001';
  end if;
  if not (v_access ->> 'open')::boolean then
    raise exception 'chat_closed' using errcode = 'P0001';
  end if;
  if char_length(v_body) not between 1 and 1000 then
    raise exception 'invalid_message' using errcode = '22023';
  end if;
  if private.chat_leaks_contact(v_body) then
    raise exception 'contact_blocked' using errcode = 'P0001';
  end if;

  perform private.rate_limit('chat_message', 30, interval '1 minute');

  insert into public.request_messages (request_id, technician_id, sender_id, body)
  values (p_request_id, p_technician_id, auth.uid(), v_body)
  returning * into v_message;

  if auth.uid() = p_technician_id then
    v_to := (v_access ->> 'consumer_id')::uuid;
    v_to_role := 'consumer';
  else
    v_to := p_technician_id;
    v_to_role := 'technician';
  end if;

  -- One notice per conversation until it is read: a burst of messages
  -- rings the phone once.
  if not exists (
    select 1
      from public.notifications n
     where n.user_id = v_to
       and n.role = v_to_role
       and n.kind = 'chat_message'
       and n.offer_id = (v_access ->> 'offer_id')::uuid
       and n.read_at is null
  ) then
    perform private.notify(
      v_to, v_to_role, 'chat_message', p_request_id, (v_access ->> 'offer_id')::uuid
    );
  end if;

  return jsonb_build_object(
    'id', v_message.id,
    'mine', true,
    'body', v_message.body,
    'created_at', v_message.created_at
  );
end;
$$;

-- The conversation: who it is with, whether it is still open, and the
-- last 200 messages. Reading it clears the
-- caller's unread chat notices of this conversation.
create function public.chat_messages(p_request_id uuid, p_technician_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_access jsonb := private.chat_access(p_request_id, p_technician_id);
  v_is_technician boolean := auth.uid() = p_technician_id;
begin
  if v_access is null then
    raise exception 'chat_unavailable' using errcode = 'P0001';
  end if;

  update public.notifications
     set read_at = now()
   where user_id = auth.uid()
     and kind = 'chat_message'
     and offer_id = (v_access ->> 'offer_id')::uuid
     and read_at is null;

  return jsonb_build_object(
    'open', (v_access ->> 'open')::boolean,
    'other_name', case
      when v_is_technician then (
        select private.short_name(p.full_name)
          from public.profiles p where p.id = (v_access ->> 'consumer_id')::uuid
      )
      else (select p.full_name from public.profiles p where p.id = p_technician_id)
    end,
    'other_honorific', case
      when v_is_technician then (
        select c.honorific from public.consumer_profiles c
         where c.id = (v_access ->> 'consumer_id')::uuid
      )
    end,
    'messages', coalesce((
      select jsonb_agg(m.item order by m.created_at, m.id)
        from (
          select x.id, x.created_at, jsonb_build_object(
            'id', x.id,
            'mine', x.sender_id = auth.uid(),
            'body', x.body,
            'created_at', x.created_at
          ) as item
            from public.request_messages x
           where x.request_id = p_request_id
             and x.technician_id = p_technician_id
           order by x.created_at desc, x.id
           limit 200
        ) m
    ), '[]')
  );
end;
$$;

revoke execute on function public.send_chat_message(uuid, uuid, text) from public, anon;
grant execute on function public.send_chat_message(uuid, uuid, text) to authenticated;
revoke execute on function public.chat_messages(uuid, uuid) from public, anon;
grant execute on function public.chat_messages(uuid, uuid) to authenticated;

-- A new message reaches the phone.
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
    'loyalty_reward', 'maintenance_reminder', 'urgent_request', 'chat_message'
  ]);
$function$;

revoke execute on all functions in schema private from public, anon, authenticated;
