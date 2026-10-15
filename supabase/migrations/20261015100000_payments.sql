-- Online payments through a payment provider (Paymob first), replacing the
-- manual transfer + screenshot + admin check for buying uses and for paying
-- a request's price ahead of the work.
--
-- Provider-independent: nothing here names Paymob except the `provider`
-- text on a row. The provider's own ids are kept next to our order, and
-- every change of money state goes through payments_apply_event, which only
-- the Edge Functions (service role) can call after they verified the
-- provider's signature.
--
--   payment_orders    what someone is paying for; the amount is decided here,
--                     from the packs / the chosen offer, never by the app
--   payment_attempts  one row per checkout opened at the provider
--   payment_events    every provider message, once (the key is unique), so a
--                     repeated webhook changes nothing
--
-- Old records stay: credit_topups and job_escrows rows made by transfer are
-- untouched, and an admin can still approve or reject those still waiting.
-- New transfers can no longer be sent (submit_topup / secure_payment are
-- closed to the API).

create type public.payment_purpose as enum ('credit_pack', 'escrow');

-- created    our order exists, nothing opened at the provider yet
-- pending    checkout opened or the provider is still deciding (a wallet
--            payment waits for the person to approve it on their phone)
-- succeeded  the provider confirmed the money reached us
-- failed / cancelled / expired   it did not; the person may try again
-- refunded   the money went back (or the payment was voided)
create type public.payment_status as enum (
  'created', 'pending', 'succeeded', 'failed', 'cancelled', 'expired', 'refunded'
);

create table public.payment_orders (
  id uuid primary key default gen_random_uuid(),
  -- Kept (set null) when an account is deleted: it is a record of money.
  user_id uuid references public.profiles (id) on delete set null,
  role public.user_role not null,
  purpose public.payment_purpose not null,
  pack_id uuid references public.credit_packs (id),
  uses integer check (uses > 0),
  request_id uuid references public.service_requests (id) on delete set null,
  amount_piastres bigint not null check (amount_piastres between 100 and 100000000),
  currency text not null default 'EGP' check (currency = 'EGP'),
  status public.payment_status not null default 'created',
  provider text check (provider ~ '^[a-z]{3,20}$'),
  provider_order_id text check (char_length(provider_order_id) <= 64),
  provider_txn_id text check (char_length(provider_txn_id) <= 64),
  -- How it was paid, as the provider reports it ('card', 'wallet', ...).
  payment_method text check (char_length(payment_method) <= 32),
  -- An admin has to look: the amount did not match, or money arrived for
  -- something that can no longer be fulfilled.
  needs_review boolean not null default false,
  review_note text check (char_length(review_note) <= 300),
  fulfilled_at timestamptz,
  refund_reference text check (char_length(refund_reference) <= 100),
  refunded_at timestamptz,
  expires_at timestamptz not null default now() + interval '1 hour',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (purpose = 'credit_pack' and pack_id is not null and uses is not null)
    or (purpose = 'escrow' and request_id is not null)
  )
);
create index payment_orders_user_idx on public.payment_orders (user_id, created_at desc);
create index payment_orders_open_idx on public.payment_orders (updated_at)
  where status in ('created', 'pending');
create unique index payment_orders_provider_order_idx
  on public.payment_orders (provider, provider_order_id)
  where provider_order_id is not null;
create index payment_orders_request_idx on public.payment_orders (request_id);
create index payment_orders_review_idx on public.payment_orders (created_at)
  where needs_review;

create table public.payment_attempts (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.payment_orders (id) on delete cascade,
  provider text not null,
  provider_order_id text not null,
  created_at timestamptz not null default now()
);
create index payment_attempts_order_idx on public.payment_attempts (order_id);

create table public.payment_events (
  id bigint generated always as identity primary key,
  provider text not null,
  event_key text not null check (char_length(event_key) <= 200),
  order_id uuid references public.payment_orders (id) on delete set null,
  source text not null check (source in ('webhook', 'inquiry', 'refund')),
  status public.payment_status,
  provider_txn_id text,
  amount_piastres bigint,
  currency text,
  -- applied, duplicate, stale, amount_mismatch, unknown_order, ignored
  outcome text not null,
  received_at timestamptz not null default now(),
  unique (provider, event_key)
);
create index payment_events_order_idx on public.payment_events (order_id);

alter table public.payment_orders enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.payment_events enable row level security;
revoke all on public.payment_orders, public.payment_attempts, public.payment_events
  from anon, authenticated;

-- People read their own orders, without the provider's ids.
create policy "People see their own payments"
  on public.payment_orders for select to authenticated
  using (user_id = (select auth.uid()));
grant select (
  id, role, purpose, pack_id, uses, request_id, amount_piastres, currency,
  status, payment_method, fulfilled_at, refunded_at, expires_at, created_at,
  updated_at
) on public.payment_orders to authenticated;

-- The money that arrived by payment links to what it bought.
alter table public.credit_ledger
  add column payment_order_id uuid references public.payment_orders (id);
alter table public.job_escrows
  add column payment_order_id uuid references public.payment_orders (id);

-- A payment by the provider has no transfer details; a manual one still must.
alter table public.job_escrows
  alter column method drop not null,
  alter column sender_account drop not null,
  alter column screenshot_path drop not null;
alter table public.job_escrows
  add constraint job_escrows_source_check check (
    payment_order_id is not null
    or (method is not null and sender_account is not null and screenshot_path is not null)
  );

-- Order status moves ------------------------------------------------------------------

-- How far a status is along; a message may only move an order forward, so
-- a late "pending" cannot undo a "succeeded". Failed, cancelled and expired
-- may go back to pending or on to succeeded: the person tried again.
create function private.payment_rank(p_status public.payment_status)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_status
    when 'created' then 0
    when 'pending' then 1
    when 'failed' then 2
    when 'cancelled' then 2
    when 'expired' then 2
    when 'succeeded' then 3
    when 'refunded' then 4
  end;
$$;

-- Fulfilment: what the money buys, exactly once ----------------------------------------

-- Gives a paid credit-pack order its uses. Called under the order's lock,
-- once (fulfilled_at is the guard).
create function private.fulfil_credit_pack(p_order public.payment_orders)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  if p_order.role = 'consumer' then
    update public.consumer_profiles
       set request_credits = request_credits + p_order.uses
     where id = p_order.user_id;
  else
    update public.technician_profiles
       set job_credits = job_credits + p_order.uses
     where id = p_order.user_id;
  end if;
  if not found then
    return false;
  end if;
  insert into public.credit_ledger (user_id, role, delta, reason, payment_order_id)
  values (p_order.user_id, p_order.role, p_order.uses, 'topup', p_order.id);
  return true;
end;
$$;

-- Records the consumer's paid money for a request. It is held when the job is
-- still going ahead; if the request or job was cancelled while she paid it is
-- recorded as due back to her. False when it cannot be recorded at all (a
-- live escrow already exists): an admin must refund.
create function private.fulfil_escrow(p_order public.payment_orders)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_request public.service_requests;
  v_job public.jobs;
  v_status public.escrow_status;
  v_id uuid;
begin
  select * into v_request from public.service_requests where id = p_order.request_id;
  if not found then
    return false;
  end if;
  select * into v_job from public.jobs where id = v_request.job_id;
  v_status := case
    when v_request.status = 'assigned'
         and v_job.id is not null
         and v_job.status not in ('cancelled') then 'held'
    else 'refund_due'
  end;
  begin
    insert into public.job_escrows (
      request_id, request_code, consumer_id, technician_id, amount_piastres,
      status, held_at, payment_order_id
    )
    values (
      p_order.request_id, private.request_code(p_order.request_id), p_order.user_id,
      v_job.technician_id, p_order.amount_piastres, v_status,
      case when v_status = 'held' then now() end, p_order.id
    )
    returning id into v_id;
  exception when unique_violation then
    return false;
  end;
  if v_status = 'held' then
    if p_order.user_id is not null then
      perform private.notify(p_order.user_id, 'consumer', 'escrow_held', p_order.request_id);
    end if;
    if v_job.technician_id is not null then
      perform private.notify(v_job.technician_id, 'technician', 'escrow_held', p_order.request_id);
    end if;
  end if;
  return true;
end;
$$;

-- Creating orders (the signed-in person; the Edge Function calls these as them) ---------

create function public.create_credit_pack_payment(
  p_pack_id uuid,
  p_expected_price_piastres bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_pack public.credit_packs;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  perform private.assert_active();

  select * into v_pack from public.credit_packs where id = p_pack_id and is_active;
  if not found then
    raise exception 'pack_not_found' using errcode = 'P0002';
  end if;
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

  perform private.rate_limit('create_payment', 20, interval '1 hour');
  insert into public.payment_orders (user_id, role, purpose, pack_id, uses, amount_piastres)
  values (v_user_id, v_pack.role, 'credit_pack', v_pack.id, v_pack.uses, v_pack.price_piastres)
  returning id into v_id;

  return jsonb_build_object(
    'order_id', v_id,
    'amount_piastres', v_pack.price_piastres,
    'currency', 'EGP',
    'description', v_pack.uses::text
  );
end;
$$;

-- Paying a request's agreed price. Allowed once the technician is picked and
-- until he starts, while nothing is held for the request yet.
create function public.create_escrow_payment(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_request public.service_requests;
  v_job public.jobs;
  v_amount bigint;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  perform private.assert_active();

  select * into v_request from public.service_requests
   where id = p_request_id and consumer_id = v_user_id for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  select * into v_job from public.jobs where id = v_request.job_id;
  v_amount := private.escrow_amount(p_request_id);
  if v_request.status <> 'assigned' or v_amount is null or v_job.id is null
     or v_job.status not in ('unconfirmed', 'confirmed') then
    raise exception 'escrow_unavailable' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.job_escrows
     where request_id = p_request_id and status <> 'rejected'
  ) then
    raise exception 'already_secured' using errcode = 'P0001';
  end if;

  perform private.rate_limit('create_payment', 20, interval '1 hour');
  insert into public.payment_orders (user_id, role, purpose, request_id, amount_piastres)
  values (v_user_id, 'consumer', 'escrow', p_request_id, v_amount)
  returning id into v_id;

  return jsonb_build_object(
    'order_id', v_id,
    'amount_piastres', v_amount,
    'currency', 'EGP',
    'description', private.request_code(p_request_id)
  );
end;
$$;

-- The Edge Functions (service role only) ------------------------------------------------

-- The provider accepted our order: remember its ids and mark it pending.
create function public.payments_attach_provider(
  p_order_id uuid,
  p_provider text,
  p_provider_order_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.payment_orders
     set provider = p_provider,
         provider_order_id = p_provider_order_id,
         status = case when status in ('created', 'failed', 'cancelled', 'expired')
                       then 'pending' else status end,
         expires_at = greatest(expires_at, now() + interval '1 hour'),
         updated_at = now()
   where id = p_order_id and status not in ('succeeded', 'refunded');
  if not found then
    raise exception 'order_not_found' using errcode = 'P0002';
  end if;
  insert into public.payment_attempts (order_id, provider, provider_order_id)
  values (p_order_id, p_provider, p_provider_order_id);
end;
$$;

-- Applies one message from the provider (a webhook, or an inquiry made by the
-- reconciler) to the order it is about. Idempotent: the same event key is
-- applied once. Returns jsonb {outcome, order_id, status}.
create function public.payments_apply_event(
  p_provider text,
  p_event_key text,
  p_source text,
  p_provider_order_id text,
  p_merchant_ref text,
  p_provider_txn_id text,
  p_status public.payment_status,
  p_amount_piastres bigint,
  p_currency text,
  p_payment_method text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.payment_orders;
  v_outcome text;
  v_event_id bigint;
  v_ok boolean;
  v_new public.payment_status;
begin
  insert into public.payment_events (
    provider, event_key, source, status, provider_txn_id, amount_piastres,
    currency, outcome
  )
  values (
    p_provider, p_event_key, p_source, p_status, p_provider_txn_id,
    p_amount_piastres, p_currency, 'received'
  )
  on conflict (provider, event_key) do nothing
  returning id into v_event_id;
  if v_event_id is null then
    select o.id, o.status into v_order.id, v_order.status
      from public.payment_events e
      left join public.payment_orders o on o.id = e.order_id
     where e.provider = p_provider and e.event_key = p_event_key;
    return jsonb_build_object(
      'outcome', 'duplicate', 'order_id', v_order.id, 'status', v_order.status
    );
  end if;

  select * into v_order from public.payment_orders
   where provider = p_provider and provider_order_id = p_provider_order_id
   for update;
  if not found then
    update public.payment_events set outcome = 'unknown_order' where id = v_event_id;
    return jsonb_build_object('outcome', 'unknown_order');
  end if;
  update public.payment_events set order_id = v_order.id where id = v_event_id;

  -- What the provider says it took must be what we asked for.
  if p_amount_piastres is distinct from v_order.amount_piastres
     or upper(coalesce(p_currency, '')) <> v_order.currency
     or (p_merchant_ref is not null and p_merchant_ref <> v_order.id::text) then
    if p_status in ('succeeded', 'refunded') then
      update public.payment_orders
         set needs_review = true,
             review_note = 'amount_or_reference_mismatch',
             updated_at = now()
       where id = v_order.id;
    end if;
    update public.payment_events set outcome = 'amount_mismatch' where id = v_event_id;
    return jsonb_build_object(
      'outcome', 'amount_mismatch', 'order_id', v_order.id, 'status', v_order.status
    );
  end if;

  -- Remember which transaction this is, whatever the order does with the news.
  if v_order.provider_txn_id is null and p_provider_txn_id is not null then
    update public.payment_orders
       set provider_txn_id = p_provider_txn_id,
           payment_method = coalesce(p_payment_method, payment_method)
     where id = v_order.id
    returning * into v_order;
  end if;

  -- A failure of an earlier try must not undo a newer try that is pending.
  if p_status in ('failed', 'cancelled')
     and v_order.status = 'pending'
     and v_order.provider_txn_id is not null
     and p_provider_txn_id is distinct from v_order.provider_txn_id then
    update public.payment_events set outcome = 'stale' where id = v_event_id;
    return jsonb_build_object(
      'outcome', 'stale', 'order_id', v_order.id, 'status', v_order.status
    );
  end if;

  if private.payment_rank(p_status) <= private.payment_rank(v_order.status)
     and not (p_status = 'pending' and v_order.status in ('failed', 'cancelled', 'expired')) then
    update public.payment_events set outcome = 'stale' where id = v_event_id;
    return jsonb_build_object(
      'outcome', 'stale', 'order_id', v_order.id, 'status', v_order.status
    );
  end if;

  v_new := p_status;
  update public.payment_orders
     set status = v_new,
         provider_txn_id = coalesce(p_provider_txn_id, provider_txn_id),
         payment_method = coalesce(p_payment_method, payment_method),
         updated_at = now()
   where id = v_order.id
  returning * into v_order;

  if v_new = 'succeeded' and v_order.fulfilled_at is null then
    v_ok := case v_order.purpose
      when 'credit_pack' then private.fulfil_credit_pack(v_order)
      else private.fulfil_escrow(v_order)
    end;
    if v_ok then
      update public.payment_orders set fulfilled_at = now() where id = v_order.id;
    else
      -- The money arrived but cannot buy anything now: an admin refunds it.
      update public.payment_orders
         set needs_review = true, review_note = 'cannot_fulfil'
       where id = v_order.id;
    end if;
  elsif v_new = 'refunded' then
    update public.payment_orders set refunded_at = now() where id = v_order.id;
    if v_order.purpose = 'escrow' then
      -- Returned to her: a refund we were waiting to make is now done; a
      -- refund made behind our back (from the provider's dashboard) is for
      -- an admin to reconcile.
      update public.job_escrows
         set status = 'refunded', refunded_at = now(),
             refund_reference = coalesce(refund_reference, 'provider')
       where payment_order_id = v_order.id and status = 'refund_due';
      if not found then
        update public.payment_orders
           set needs_review = true, review_note = 'refunded_outside_flow'
         where id = v_order.id;
      end if;
    else
      update public.payment_orders
         set needs_review = true, review_note = 'credit_pack_refunded'
       where id = v_order.id;
    end if;
  end if;

  update public.payment_events set outcome = 'applied' where id = v_event_id;
  select status into v_new from public.payment_orders where id = v_order.id;
  return jsonb_build_object('outcome', 'applied', 'order_id', v_order.id, 'status', v_new);
end;
$$;

-- Orders the reconciler should ask the provider about: still undecided after a
-- few minutes, or marked failed/expired but recent enough that a late payment
-- could still show up.
create function public.payments_unsettled(p_limit integer default 50)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id, 'provider', o.provider,
           'provider_order_id', o.provider_order_id,
           'amount_piastres', o.amount_piastres
         ) order by o.updated_at), '[]')
    from (
      select * from public.payment_orders
       where provider_order_id is not null
         and (
           (status in ('created', 'pending') and updated_at < now() - interval '3 minutes')
           or (status in ('failed', 'expired', 'cancelled')
               and updated_at > now() - interval '2 days'
               and updated_at < now() - interval '3 minutes')
         )
         and created_at > now() - interval '7 days'
       order by updated_at
       limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) o;
$$;

-- An order nobody is paying is closed: no checkout opened, or the provider
-- never decided within a day. A late payment can still be applied after this
-- (see payment_rank).
create function private.expire_stale_payments()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  with closed as (
    update public.payment_orders
       set status = 'expired', updated_at = now()
     where status in ('created', 'pending')
       and ((provider_txn_id is null and expires_at < now() - interval '15 minutes')
            or created_at < now() - interval '1 day')
    returning 1
  )
  select count(*) into v_count from closed;
  return v_count;
end;
$$;

-- Refunds -------------------------------------------------------------------------------

-- The admin asks to refund an escrow that is due back: who to ask the provider
-- to refund. Admin only, with a recent login (it moves money).
create function public.admin_payment_refund_target(p_escrow_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  select o.id, o.provider, o.provider_txn_id, o.amount_piastres, o.status as order_status,
         e.status as escrow_status
    into v_row
    from public.job_escrows e
    join public.payment_orders o on o.id = e.payment_order_id
   where e.id = p_escrow_id;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_row.escrow_status <> 'refund_due' or v_row.order_status <> 'succeeded'
     or v_row.provider_txn_id is null then
    raise exception 'not_refund_due' using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'order_id', v_row.id, 'provider', v_row.provider,
    'provider_txn_id', v_row.provider_txn_id, 'amount_piastres', v_row.amount_piastres
  );
end;
$$;

-- The provider confirmed a refund we asked for. Same effect as the refund
-- event arriving by webhook, and safe to run twice.
create function public.payments_record_refund(
  p_order_id uuid,
  p_reference text,
  p_admin_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.payment_orders;
begin
  select * into v_order from public.payment_orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found' using errcode = 'P0002';
  end if;
  if v_order.status = 'refunded' then
    return;
  end if;
  update public.payment_orders
     set status = 'refunded', refunded_at = now(),
         refund_reference = left(coalesce(p_reference, ''), 100), updated_at = now()
   where id = p_order_id;
  update public.job_escrows
     set status = 'refunded', refunded_at = now(),
         refund_reference = left(coalesce(p_reference, 'provider'), 100)
   where payment_order_id = p_order_id and status = 'refund_due';
  insert into public.payment_events (
    provider, event_key, order_id, source, status, outcome
  )
  values (
    coalesce(v_order.provider, 'unknown'), 'refund:' || p_order_id::text, p_order_id,
    'refund', 'refunded', 'applied'
  )
  on conflict (provider, event_key) do nothing;
  insert into private.admin_audit_log (admin_id, action, target_type, target_id, details)
  values (
    p_admin_id, 'refund_payment', 'payment_order', p_order_id::text,
    jsonb_build_object('amount_piastres', v_order.amount_piastres, 'reference', p_reference)
  );
end;
$$;

-- Admin: orders to look at -----------------------------------------------------------------

create function public.admin_list_payments(
  p_needs_review boolean default null,
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
      select count(*) from public.payment_orders o
       where p_needs_review is null or o.needs_review = p_needs_review
    ),
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', x.id, 'purpose', x.purpose, 'status', x.status,
               'amount_piastres', x.amount_piastres, 'provider', x.provider,
               'payment_method', x.payment_method, 'needs_review', x.needs_review,
               'review_note', x.review_note, 'created_at', x.created_at
             ) order by x.created_at desc), '[]')
        from (
          select * from public.payment_orders o
           where p_needs_review is null or o.needs_review = p_needs_review
           order by o.created_at desc
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- What the consumer sees of a request's payment: the amount, what she can do
-- now, and how the last online payment stands.
create or replace function public.escrow_info(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_request public.service_requests;
  v_job public.jobs;
  v_escrow public.job_escrows;
  v_amount bigint;
  v_order public.payment_orders;
begin
  select * into v_request from public.service_requests
   where id = p_request_id and consumer_id = v_user_id;
  if not found then
    return null;
  end if;
  select * into v_job from public.jobs where id = v_request.job_id;
  v_amount := private.escrow_amount(p_request_id);
  select * into v_escrow from public.job_escrows
   where request_id = p_request_id
   order by (status <> 'rejected') desc, created_at desc
   limit 1;
  select * into v_order from public.payment_orders
   where request_id = p_request_id and user_id = v_user_id and purpose = 'escrow'
   order by created_at desc
   limit 1;

  return jsonb_build_object(
    'amount_piastres', coalesce(v_escrow.amount_piastres, v_amount),
    -- She can pay in only before the work starts and while nothing is live.
    'can_secure', v_request.status = 'assigned'
                  and v_amount is not null
                  and v_job.status in ('unconfirmed', 'confirmed')
                  and (v_escrow.id is null or v_escrow.status = 'rejected'),
    -- She can answer once the work is done and the money is ours.
    'can_confirm', v_escrow.status = 'held' and v_job.status in ('finished', 'paid'),
    'can_dispute', v_escrow.status = 'held' and v_job.status <> 'cancelled',
    -- The online payment in progress, if any, to follow it.
    'payment', case when v_order.id is null then null else jsonb_build_object(
      'order_id', v_order.id, 'status', v_order.status
    ) end,
    'escrow', case when v_escrow.id is null then null else jsonb_build_object(
      'id', v_escrow.id,
      'status', v_escrow.status,
      'method', v_escrow.method,
      'reject_reason', v_escrow.reject_reason,
      'created_at', v_escrow.created_at,
      'held_at', v_escrow.held_at,
      'auto_release_at', case
        when v_escrow.status = 'held' and v_job.finished_at is not null
        then v_job.finished_at + private.escrow_hours_to_release() end
    ) end
  );
end;
$$;

-- The escrow queue also says which payments were made online.
create or replace function public.admin_list_escrows(
  p_status public.escrow_status default 'pending',
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
      select count(*) from public.job_escrows e
       where p_status is null or e.status = p_status
    ),
    'counts', (
      select coalesce(jsonb_object_agg(s.status::text, s.n), '{}')
        from (select status, count(*) as n from public.job_escrows group by status) s
    ),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.rank, x.id), '[]')
        from (
          select e.id,
                 case when e.status in ('pending', 'released', 'disputed', 'refund_due')
                      then extract(epoch from e.created_at)
                      else -extract(epoch from e.created_at) end as rank,
                 jsonb_build_object(
                   'id', e.id,
                   'request_code', e.request_code,
                   'status', e.status,
                   'amount_piastres', e.amount_piastres,
                   'method', e.method,
                   'sender_account', e.sender_account,
                   'screenshot_path', e.screenshot_path,
                   'consumer_name', cp.full_name,
                   'consumer_phone', case when cp.phone like '+20%' then '0' || substr(cp.phone, 4) end,
                   'technician_name', tp.full_name,
                   'technician_phone', case when tp.phone like '+20%' then '0' || substr(tp.phone, 4) end,
                   'payout_method', coalesce(e.payout_method, pa.method),
                   'payout_account', coalesce(e.payout_account, pa.account),
                   'payout_holder', coalesce(e.payout_holder, pa.holder_name),
                   'payout_reference', e.payout_reference,
                   'refund_reference', e.refund_reference,
                   'reject_reason', e.reject_reason,
                   'dispute_reason', e.dispute_reason,
                   'resolution_note', e.resolution_note,
                   'job_finished_at', j.finished_at,
                   'created_at', e.created_at,
                   'held_at', e.held_at,
                   'released_at', e.released_at,
                   'paid_out_at', e.paid_out_at,
                   'refunded_at', e.refunded_at,
                   'online', e.payment_order_id is not null,
                   'online_method', po.payment_method
                 ) as item
            from public.job_escrows e
            left join public.profiles cp on cp.id = e.consumer_id
            left join public.profiles tp on tp.id = e.technician_id
            left join public.technician_payout_accounts pa on pa.technician_id = e.technician_id
            left join public.service_requests r on r.id = e.request_id
            left join public.jobs j on j.id = r.job_id
            left join public.payment_orders po on po.id = e.payment_order_id
           where p_status is null or e.status = p_status
           order by 2, e.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Reconciler wake-up ----------------------------------------------------------------------

-- Asks the payment-reconcile function to check undecided orders. Like push:
-- the URL and the shared secret live in the vault (payment_reconcile_url,
-- payment_reconcile_secret); nothing is sent until they are set.
create function private.run_payment_reconcile()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  perform private.expire_stale_payments();
  if not exists (
    select 1 from public.payment_orders
     where provider_order_id is not null
       and status in ('created', 'pending', 'failed', 'expired', 'cancelled')
       and updated_at < now() - interval '3 minutes'
       and created_at > now() - interval '7 days'
  ) then
    return;
  end if;
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'payment_reconcile_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'payment_reconcile_secret';
  if v_url is null or v_secret is null then
    raise warning 'payments are not reconciled: vault secrets payment_reconcile_url and payment_reconcile_secret are missing';
    return;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-payment-secret', v_secret),
    body := '{}'::jsonb
  );
end;
$$;

-- Who may call what ------------------------------------------------------------------------

-- No more transfers by screenshot: the old calls are closed. Rows already
-- made stay and the admin console still reviews them.
revoke execute on function
  public.submit_topup(uuid, public.topup_method, text, text, bigint),
  public.secure_payment(uuid, public.topup_method, text, text)
from public, anon, authenticated;

revoke execute on function
  public.create_credit_pack_payment(uuid, bigint),
  public.create_escrow_payment(uuid),
  public.payments_attach_provider(uuid, text, text),
  public.payments_apply_event(
    text, text, text, text, text, text, public.payment_status, bigint, text, text
  ),
  public.payments_unsettled(integer),
  public.admin_payment_refund_target(uuid),
  public.payments_record_refund(uuid, text, uuid),
  public.admin_list_payments(boolean, integer, integer)
from public, anon, authenticated;
grant execute on function
  public.create_credit_pack_payment(uuid, bigint),
  public.create_escrow_payment(uuid),
  public.admin_payment_refund_target(uuid),
  public.admin_list_payments(boolean, integer, integer)
to authenticated;
grant execute on function
  public.payments_attach_provider(uuid, text, text),
  public.payments_apply_event(
    text, text, text, text, text, text, public.payment_status, bigint, text, text
  ),
  public.payments_unsettled(integer),
  public.payments_record_refund(uuid, text, uuid)
to service_role;

revoke execute on all functions in schema private from public, anon, authenticated;

select cron.schedule(
  'payments-reconcile', '*/10 * * * *', 'select private.run_payment_reconcile()'
);

-- Rollback / recovery: see docs/payments/README.md. In short, the old tables are
-- untouched, so re-granting execute on submit_topup / secure_payment brings the
-- manual flow back; payment_* tables can be left in place.
