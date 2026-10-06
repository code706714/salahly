-- Milestone 5: in-app notifications.
--
-- One row per event, written by triggers inside the same transaction that
-- changes the state, so a notification exists exactly when the change
-- committed. People only read their own rows and mark them read through
-- mark_notifications_read(). Push can be added later by sending a message
-- for each new row; nothing here depends on it.
--
-- A notification carries no text: the app builds it from the kind and the
-- request, offer or transfer it points at. Those links are cleared (never
-- the notification) when the thing they point at is deleted.

create type public.notification_kind as enum (
  -- consumer
  'offer_received', 'job_confirmed', 'job_started', 'job_finished',
  'price_change', 'request_cancelled_by_technician', 'request_expired',
  -- technician
  'new_request', 'offer_picked', 'offer_not_picked',
  'request_cancelled_by_consumer', 'verification_approved',
  'verification_rejected',
  -- both
  'topup_approved', 'topup_rejected'
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.user_role not null,
  kind public.notification_kind not null,
  request_id uuid references public.service_requests (id) on delete set null,
  offer_id uuid references public.request_offers (id) on delete set null,
  topup_id uuid references public.credit_topups (id) on delete set null,
  -- The clock, not the transaction: events in one transaction keep their order.
  created_at timestamptz not null default clock_timestamp(),
  read_at timestamptz
);

create index notifications_user_idx
  on public.notifications (user_id, role, created_at desc);
create index notifications_unread_idx
  on public.notifications (user_id, role) where read_at is null;
create index notifications_request_idx on public.notifications (request_id);
create index notifications_offer_idx on public.notifications (offer_id);
create index notifications_topup_idx on public.notifications (topup_id);
create index notifications_age_idx on public.notifications (created_at);

alter table public.notifications enable row level security;
revoke all on table public.notifications from anon, authenticated;
grant select on table public.notifications to authenticated;
create policy "People read their own notifications"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

create function private.notify(
  p_user_id uuid,
  p_role public.user_role,
  p_kind public.notification_kind,
  p_request_id uuid default null,
  p_offer_id uuid default null,
  p_topup_id uuid default null
)
returns void
language sql
set search_path = ''
as $$
  insert into public.notifications (user_id, role, kind, request_id, offer_id, topup_id)
  values (p_user_id, p_role, p_kind, p_request_id, p_offer_id, p_topup_id);
$$;

-- Like notify, but not again when the same person was already told the
-- same thing about the same request in the last 10 minutes. For events a
-- technician's phone can repeat at will (status flips, a new quote time).
create function private.notify_once(
  p_user_id uuid,
  p_role public.user_role,
  p_kind public.notification_kind,
  p_request_id uuid
)
returns void
language sql
set search_path = ''
as $$
  select private.notify(p_user_id, p_role, p_kind, p_request_id)
   where not exists (
     select 1
       from public.notifications n
      where n.user_id = p_user_id
        and n.role = p_role
        and n.kind = p_kind
        and n.request_id = p_request_id
        and n.created_at > now() - interval '10 minutes'
   );
$$;

-- Consumer: an offer arrived.
create function private.notify_offer_received()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    (select consumer_id from public.service_requests where id = new.request_id),
    'consumer', 'offer_received', new.request_id, new.id
  );
  return null;
end;
$$;

create trigger request_offers_notify after insert on public.request_offers
  for each row execute function private.notify_offer_received();

-- Technician: a request was sent to them (when first sent and when
-- widened to more technicians).
create function private.notify_new_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(new.technician_id, 'technician', 'new_request', new.request_id);
  return null;
end;
$$;

create trigger request_recipients_notify after insert on public.request_recipients
  for each row execute function private.notify_new_request();

-- A request changed state: who needs to hear about it.
create function private.notify_request_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_technician record;
begin
  if new.status = 'assigned' then
    perform private.notify(o.technician_id, 'technician',
      case when o.id = new.chosen_offer_id then 'offer_picked' else 'offer_not_picked' end::public.notification_kind,
      new.id, o.id)
      from public.request_offers o
     where o.request_id = new.id;
  elsif new.status = 'cancelled' and new.cancelled_by = 'technician' then
    perform private.notify(new.consumer_id, 'consumer', 'request_cancelled_by_technician', new.id);
  elsif new.status = 'cancelled' and new.cancelled_by = 'consumer' then
    -- Once picked, only the chosen technician is involved; before, everyone
    -- who has an offer waiting.
    for v_technician in
      select o.technician_id, o.id
        from public.request_offers o
       where o.request_id = new.id
         and case when old.status = 'assigned' then o.id = new.chosen_offer_id
                  else o.status = 'sent' end
    loop
      perform private.notify(v_technician.technician_id, 'technician',
        'request_cancelled_by_consumer', new.id, v_technician.id);
    end loop;
  elsif new.status = 'expired'
        and not exists (select 1 from public.request_offers where request_id = new.id) then
    perform private.notify(new.consumer_id, 'consumer', 'request_expired', new.id);
  end if;
  return null;
end;
$$;

create trigger service_requests_notify after update of status on public.service_requests
  for each row
  when (old.status is distinct from new.status)
  execute function private.notify_request_state();

-- Consumer: the technician moved the job along or sent a new price.
create function private.notify_job_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_consumer_id uuid;
  v_kind public.notification_kind;
begin
  select id, consumer_id into v_request_id, v_consumer_id
    from public.service_requests
   where job_id = new.id and status = 'assigned';
  if v_request_id is null then
    return null;
  end if;
  if new.status is distinct from old.status then
    v_kind := case new.status
      when 'confirmed' then 'job_confirmed'
      when 'started' then 'job_started'
      when 'finished' then 'job_finished'
    end;
    if v_kind is not null then
      perform private.notify_once(v_consumer_id, 'consumer', v_kind, v_request_id);
    end if;
  end if;
  if new.quote_status = 'sent' and new.quote_sent_at is distinct from old.quote_sent_at then
    perform private.notify_once(v_consumer_id, 'consumer', 'price_change', v_request_id);
  end if;
  return null;
end;
$$;

create trigger jobs_notify after update on public.jobs
  for each row
  when (
    old.source = 'platform'
    and (
      old.status is distinct from new.status
      or old.quote_sent_at is distinct from new.quote_sent_at
    )
  )
  execute function private.notify_job_progress();

-- A transfer was checked.
create function private.notify_topup_reviewed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id is not null then
    perform private.notify(
      new.user_id, new.role,
      case new.status when 'approved' then 'topup_approved' else 'topup_rejected' end::public.notification_kind,
      null, null, new.id
    );
  end if;
  return null;
end;
$$;

create trigger credit_topups_notify after update of status on public.credit_topups
  for each row
  when (old.status = 'pending' and new.status in ('approved', 'rejected'))
  execute function private.notify_topup_reviewed();

-- A technician's documents were checked.
create function private.notify_verification_reviewed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    new.id, 'technician',
    case new.verification_status
      when 'approved' then 'verification_approved'
      else 'verification_rejected'
    end::public.notification_kind
  );
  return null;
end;
$$;

create trigger technician_profiles_notify
  after update of verification_status on public.technician_profiles
  for each row
  when (old.verification_status = 'pending' and new.verification_status in ('approved', 'rejected'))
  execute function private.notify_verification_reviewed();

-- The list, newest first, with what the text needs: the request, the
-- offer, the other person's first name and the transfer. Whatever was
-- deleted since reads as null, and the app falls back to plain text.
-- The chosen offer's price, time and technician are joined only for the
-- consumer: a technician sees the offer he sent himself and nothing of a
-- competitor's.
create function public.my_notifications(p_role public.user_role, p_limit integer default 50)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.item order by x.created_at desc, x.id), '[]')
    from (
      select n.id, n.created_at, jsonb_build_object(
        'id', n.id,
        'kind', n.kind,
        'request_id', n.request_id,
        'topup_id', n.topup_id,
        'created_at', n.created_at,
        'read_at', n.read_at,
        'category_id', r.category_id,
        'issue', r.issue,
        'area_id', r.area_id,
        'preferred_on', r.preferred_on,
        'time_window', r.time_window,
        'price_piastres', coalesce(o.price_piastres, tr.price_piastres),
        'arrive_at', coalesce(o.arrive_at, tr.arrive_at),
        'technician_name', case when p_role = 'consumer' then tp.full_name end,
        'consumer_name', case when p_role = 'technician' and rr.technician_id is not null
                              then private.short_name(cp.full_name) end,
        'consumer_honorific', case when p_role = 'technician' and rr.technician_id is not null
                                   then c.honorific end,
        'distance_km', rr.distance_km,
        'topup_uses', t.uses
      ) as item
        from public.notifications n
        left join public.service_requests r on r.id = n.request_id
        left join public.request_offers o on o.id = n.offer_id
        left join public.request_offers tr
          on tr.id = r.chosen_offer_id and o.id is null and p_role = 'consumer'
        left join public.profiles tp on tp.id = coalesce(o.technician_id, tr.technician_id)
        left join public.request_recipients rr
          on rr.request_id = r.id and rr.technician_id = n.user_id
        left join public.profiles cp on cp.id = r.consumer_id
        left join public.consumer_profiles c on c.id = r.consumer_id
        left join public.credit_topups t on t.id = n.topup_id
       where n.user_id = auth.uid() and n.role = p_role
       order by n.created_at desc, n.id
       limit least(greatest(coalesce(p_limit, 50), 1), 100)
    ) x;
$$;

-- All of the person's unread notifications of one side, or just these.
-- Returns how many were marked.
create function public.mark_notifications_read(
  p_role public.user_role,
  p_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.notifications
     set read_at = now()
   where user_id = auth.uid()
     and role = p_role
     and read_at is null
     and (p_ids is null or id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on all functions in schema private from public, anon, authenticated;
revoke execute on function
  public.my_notifications(public.user_role, integer),
  public.mark_notifications_read(public.user_role, uuid[])
from public, anon;
grant execute on function
  public.my_notifications(public.user_role, integer),
  public.mark_notifications_read(public.user_role, uuid[])
to authenticated;

-- Housekeeping also keeps 90 days of notifications.
create or replace function private.marketplace_housekeeping()
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_request record;
begin
  for v_request in
    update public.service_requests
       set status = 'expired', credit_held = false
     where status = 'open' and expires_at <= now()
    returning consumer_id, credit_held
  loop
    perform private.return_use(v_request.consumer_id, 'consumer');
  end loop;

  for v_request in
    select r.id
      from public.service_requests r
     where r.status = 'open'
       and r.widened_at is null
       and r.created_at <= now() - interval '2 hours'
       and not exists (select 1 from public.request_offers o where o.request_id = r.id)
     for update skip locked
  loop
    perform private.dispatch_request(v_request.id, true);
    update public.service_requests set widened_at = now() where id = v_request.id;
  end loop;

  delete from public.notifications where created_at < now() - interval '90 days';
end;
$$;
revoke execute on function private.marketplace_housekeeping() from public, anon, authenticated;
