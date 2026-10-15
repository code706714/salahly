-- The technician's wallet, and the work confirmed by both sides.
--
-- Before: the consumer's confirmation sent the held money to an admin's
-- to-do list, who paid the technician by hand.
-- Now:
--   * Both sides confirm the work on the request's screen (the consumer, and
--     the technician once he finished). When both did, the money waits three
--     days for a complaint from either side, then goes to the technician's
--     wallet by itself. A consumer who stays silent for three days after
--     the technician confirmed does not hold the money back.
--   * The wallet is a ledger; the technician withdraws to Vodafone Cash or
--     InstaPay by typing the number to send to. An admin makes the transfer
--     and records its reference, or refuses and the amount returns to the
--     wallet. (A payment provider that can pay out can take over that step
--     later without changing anything above it.)
--
-- Salahly still takes no commission: the wallet receives what the consumer
-- paid for the offer.

alter table public.job_escrows
  add column consumer_confirmed_at timestamptz,
  add column technician_confirmed_at timestamptz,
  -- Set when both confirmed: the money moves to the wallet then.
  add column release_at timestamptz,
  add column disputed_by text check (disputed_by in ('consumer', 'technician'));

-- Held money whose work was already finished counts as confirmed by the
-- technician (he is the one who finished it), so the old rule of
-- "72 hours of silence from the consumer" keeps working for it.
update public.job_escrows e
   set technician_confirmed_at = j.finished_at
  from public.service_requests r
  join public.jobs j on j.id = r.job_id
 where e.request_id = r.id
   and e.status = 'held'
   and j.status in ('finished', 'paid')
   and j.finished_at is not null;

-- The wallet --------------------------------------------------------------------------------

create table public.technician_wallets (
  technician_id uuid primary key references public.technician_profiles (id) on delete cascade,
  balance_piastres bigint not null default 0 check (balance_piastres >= 0),
  updated_at timestamptz not null default now()
);

create type public.withdrawal_status as enum ('requested', 'paid', 'rejected');

create table public.wallet_withdrawals (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  amount_piastres bigint not null check (amount_piastres >= 100),
  method public.topup_method not null,
  account text not null check (char_length(account) between 3 and 64),
  holder_name text not null check (char_length(holder_name) between 2 and 80),
  status public.withdrawal_status not null default 'requested',
  reference text check (char_length(reference) <= 100),
  reject_reason text check (char_length(reject_reason) <= 200),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
create index wallet_withdrawals_technician_idx
  on public.wallet_withdrawals (technician_id, created_at desc);
create index wallet_withdrawals_status_idx on public.wallet_withdrawals (status, created_at);

-- Every move of money in or out of a wallet. The balance is their sum.
create table public.wallet_ledger (
  id bigint generated always as identity primary key,
  technician_id uuid not null references public.technician_profiles (id) on delete cascade,
  kind text not null check (kind in ('escrow', 'withdrawal', 'withdrawal_refund')),
  amount_piastres bigint not null check (amount_piastres <> 0),
  escrow_id uuid references public.job_escrows (id),
  withdrawal_id uuid references public.wallet_withdrawals (id),
  request_code text,
  created_at timestamptz not null default now(),
  check (
    (kind = 'escrow' and escrow_id is not null and amount_piastres > 0)
    or (kind = 'withdrawal' and withdrawal_id is not null and amount_piastres < 0)
    or (kind = 'withdrawal_refund' and withdrawal_id is not null and amount_piastres > 0)
  )
);
-- A job's money enters a wallet once; a withdrawal leaves and returns once.
create unique index wallet_ledger_escrow_idx on public.wallet_ledger (escrow_id)
  where escrow_id is not null;
create unique index wallet_ledger_withdrawal_idx on public.wallet_ledger (withdrawal_id, kind)
  where withdrawal_id is not null;
create index wallet_ledger_technician_idx on public.wallet_ledger (technician_id, id desc);

alter table public.technician_wallets enable row level security;
alter table public.wallet_withdrawals enable row level security;
alter table public.wallet_ledger enable row level security;
revoke all on table public.technician_wallets, public.wallet_withdrawals, public.wallet_ledger
  from anon, authenticated;

-- Adds to a wallet (negative: takes out). The balance can't go below zero.
create function private.wallet_move(
  p_technician_id uuid,
  p_kind text,
  p_amount bigint,
  p_escrow_id uuid default null,
  p_withdrawal_id uuid default null,
  p_request_code text default null
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.technician_wallets (technician_id, balance_piastres)
  values (p_technician_id, 0)
  on conflict (technician_id) do nothing;
  update public.technician_wallets
     set balance_piastres = balance_piastres + p_amount, updated_at = now()
   where technician_id = p_technician_id;
  insert into public.wallet_ledger (
    technician_id, kind, amount_piastres, escrow_id, withdrawal_id, request_code
  )
  values (p_technician_id, p_kind, p_amount, p_escrow_id, p_withdrawal_id, p_request_code);
end;
$$;

-- Moving the money --------------------------------------------------------------------------

-- The smallest withdrawal: 50 EGP.
create function private.min_withdrawal_piastres()
returns bigint
language sql
immutable
set search_path = ''
as $$
  select 5000::bigint;
$$;

-- The money is the technician's: it goes to his wallet. Not reachable from
-- the API.
create or replace function private.release_escrow(p_escrow_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
begin
  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found or v_escrow.status not in ('held', 'disputed')
     or v_escrow.technician_id is null then
    raise exception 'not_releasable' using errcode = 'P0001';
  end if;
  update public.job_escrows
     set status = 'paid_out', released_at = now(), paid_out_at = now()
   where id = v_escrow.id;
  perform private.wallet_move(
    v_escrow.technician_id, 'escrow', v_escrow.amount_piastres,
    p_escrow_id => v_escrow.id, p_request_code => v_escrow.request_code
  );
  perform private.notify(v_escrow.technician_id, 'technician', 'escrow_paid_out', v_escrow.request_id);
end;
$$;

-- Money the old way left "released" for an admin to pay out now lands in the
-- wallet. One whose technician is gone goes back to the consumer.
do $$
declare
  v_escrow record;
begin
  for v_escrow in select id, technician_id from public.job_escrows where status = 'released' loop
    if v_escrow.technician_id is null then
      update public.job_escrows set status = 'refund_due' where id = v_escrow.id;
    else
      update public.job_escrows set status = 'held' where id = v_escrow.id;
      perform private.release_escrow(v_escrow.id);
    end if;
  end loop;
end;
$$;

alter table public.job_escrows
  drop column payout_method,
  drop column payout_account,
  drop column payout_holder,
  drop column payout_reference;

-- Both sides said yes, or one said yes: tells the other and, when both did,
-- starts the three days.
create function private.advance_escrow(p_escrow_id uuid, p_by text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
begin
  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if v_escrow.consumer_confirmed_at is not null
     and v_escrow.technician_confirmed_at is not null then
    update public.job_escrows
       set release_at = now() + private.escrow_hours_to_release()
     where id = v_escrow.id and release_at is null;
    if v_escrow.technician_id is not null then
      perform private.notify(
        v_escrow.technician_id, 'technician', 'escrow_release_scheduled', v_escrow.request_id
      );
    end if;
  elsif p_by = 'consumer' and v_escrow.technician_id is not null then
    perform private.notify(
      v_escrow.technician_id, 'technician', 'escrow_work_confirmed', v_escrow.request_id
    );
  elsif p_by = 'technician' and v_escrow.consumer_id is not null then
    perform private.notify(
      v_escrow.consumer_id, 'consumer', 'escrow_work_confirmed', v_escrow.request_id
    );
  end if;
end;
$$;

-- The consumer says the work is right. The money moves once the technician
-- confirmed too and three days passed with no complaint.
create or replace function public.confirm_work_done(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
begin
  perform private.assert_active();
  select e.* into v_escrow
    from public.job_escrows e
    join public.service_requests r on r.id = e.request_id
    join public.jobs j on j.id = r.job_id
   where e.request_id = p_request_id
     and r.consumer_id = (select auth.uid())
     and e.status = 'held'
     and j.status in ('finished', 'paid')
   for update of e;
  if not found then
    raise exception 'escrow_unavailable' using errcode = 'P0001';
  end if;
  if v_escrow.consumer_confirmed_at is not null then
    return;
  end if;
  update public.job_escrows set consumer_confirmed_at = now() where id = v_escrow.id;
  perform private.advance_escrow(v_escrow.id, 'consumer');
end;
$$;

-- The technician says the work is done and right.
create function public.technician_confirm_work_done(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
begin
  perform private.assert_active();
  select e.* into v_escrow
    from public.job_escrows e
    join public.service_requests r on r.id = e.request_id
    join public.jobs j on j.id = r.job_id
   where e.request_id = p_request_id
     and e.technician_id = (select auth.uid())
     and e.status = 'held'
     and j.status in ('finished', 'paid')
   for update of e;
  if not found then
    raise exception 'escrow_unavailable' using errcode = 'P0001';
  end if;
  if v_escrow.technician_confirmed_at is not null then
    return;
  end if;
  update public.job_escrows set technician_confirmed_at = now() where id = v_escrow.id;
  perform private.advance_escrow(v_escrow.id, 'technician');
end;
$$;

-- Something is wrong with the work: the money stays with us until an admin
-- decides. Either side can say so, until the money has moved.
create function private.dispute_escrow(
  p_request_id uuid,
  p_by text,
  p_reason text
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
  v_reason text := private.clean_note(p_reason, 3, 300);
  v_user_id uuid := (select auth.uid());
begin
  perform private.assert_active();
  select e.* into v_escrow
    from public.job_escrows e
    join public.service_requests r on r.id = e.request_id
    join public.jobs j on j.id = r.job_id
   where e.request_id = p_request_id
     and e.status = 'held'
     and j.status <> 'cancelled'
     and case p_by when 'consumer' then r.consumer_id = v_user_id
                   else e.technician_id = v_user_id end
   for update of e;
  if not found then
    raise exception 'escrow_unavailable' using errcode = 'P0001';
  end if;
  update public.job_escrows
     set status = 'disputed', dispute_reason = v_reason, disputed_by = p_by
   where id = v_escrow.id;
  if p_by = 'consumer' and v_escrow.technician_id is not null then
    perform private.notify(v_escrow.technician_id, 'technician', 'escrow_disputed', v_escrow.request_id);
  elsif p_by = 'technician' and v_escrow.consumer_id is not null then
    perform private.notify(v_escrow.consumer_id, 'consumer', 'escrow_disputed', v_escrow.request_id);
  end if;
end;
$$;

create or replace function public.dispute_payment(p_request_id uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  select private.dispute_escrow(p_request_id, 'consumer', p_reason);
$$;

create function public.technician_dispute_payment(p_request_id uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  select private.dispute_escrow(p_request_id, 'technician', p_reason);
$$;

-- Money both sides confirmed goes to the wallet when its three days end; money
-- the consumer left unanswered for three days after the technician confirmed
-- goes too, unless someone complained.
create or replace function private.release_due_escrows()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_escrow record;
  v_count integer := 0;
begin
  for v_escrow in
    select e.id
      from public.job_escrows e
      join public.service_requests r on r.id = e.request_id
      join public.jobs j on j.id = r.job_id
     where e.status = 'held'
       and e.technician_id is not null
       and j.status in ('finished', 'paid')
       and (
         e.release_at <= now()
         or (e.consumer_confirmed_at is null
             and e.technician_confirmed_at <= now() - private.escrow_hours_to_release())
       )
  loop
    perform private.release_escrow(v_escrow.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- What each side sees ----------------------------------------------------------------------

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
    'can_confirm', v_escrow.status = 'held'
                   and v_job.status in ('finished', 'paid')
                   and v_escrow.consumer_confirmed_at is null,
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
      'consumer_confirmed', v_escrow.consumer_confirmed_at is not null,
      'technician_confirmed', v_escrow.technician_confirmed_at is not null,
      'release_at', private.escrow_release_moment(v_escrow)
    ) end
  );
end;
$$;

-- When held money reaches the wallet unless someone complains; null while
-- that depends on a confirmation still missing.
create function private.escrow_release_moment(p_escrow public.job_escrows)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select case
    when p_escrow.status <> 'held' then null
    when p_escrow.release_at is not null then p_escrow.release_at
    when p_escrow.consumer_confirmed_at is null
         and p_escrow.technician_confirmed_at is not null
      then p_escrow.technician_confirmed_at + private.escrow_hours_to_release()
  end;
$$;

create or replace function public.technician_escrow(p_request_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'status', e.status,
           'amount_piastres', e.amount_piastres,
           'can_confirm', e.status = 'held'
                          and j.status in ('finished', 'paid')
                          and e.technician_confirmed_at is null,
           'can_dispute', e.status = 'held' and j.status <> 'cancelled',
           'consumer_confirmed', e.consumer_confirmed_at is not null,
           'technician_confirmed', e.technician_confirmed_at is not null,
           'release_at', private.escrow_release_moment(e)
         )
    from public.job_escrows e
    join public.service_requests r on r.id = e.request_id
    join public.jobs j on j.id = r.job_id
   where e.request_id = p_request_id
     and e.technician_id = (select auth.uid())
     and e.status <> 'rejected'
   order by e.created_at desc
   limit 1;
$$;

-- The technician's wallet ------------------------------------------------------------------

-- The balance, the latest moves and withdrawals, and the number he last
-- withdrew to, to fill the form with.
create function public.my_wallet()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'balance_piastres', coalesce((
      select w.balance_piastres from public.technician_wallets w
       where w.technician_id = v_user_id
    ), 0),
    'min_withdrawal_piastres', private.min_withdrawal_piastres(),
    'last_destination', (
      select jsonb_build_object(
               'method', a.method, 'account', a.account, 'holder_name', a.holder_name
             )
        from public.technician_payout_accounts a
       where a.technician_id = v_user_id
    ),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'kind', l.kind, 'amount_piastres', l.amount_piastres,
               'request_code', l.request_code, 'created_at', l.created_at
             ) order by l.id desc)
        from (
          select * from public.wallet_ledger
           where technician_id = v_user_id
           order by id desc limit 50
        ) l
    ), '[]'),
    'withdrawals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', w.id, 'amount_piastres', w.amount_piastres, 'method', w.method,
               'account', w.account, 'status', w.status, 'reference', w.reference,
               'reject_reason', w.reject_reason, 'created_at', w.created_at,
               'processed_at', w.processed_at
             ) order by w.created_at desc)
        from (
          select * from public.wallet_withdrawals
           where technician_id = v_user_id
           order by created_at desc limit 20
        ) w
    ), '[]')
  );
end;
$$;

-- He asks for money out: it leaves the wallet at once and an admin sends it
-- to the number he typed.
create function public.request_withdrawal(
  p_amount_piastres bigint,
  p_method public.topup_method,
  p_account text,
  p_holder_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_account text;
  v_holder text := private.normalize_text(p_holder_name);
  v_id uuid;
begin
  perform private.assert_active();
  if not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if p_amount_piastres is null or p_amount_piastres < private.min_withdrawal_piastres() then
    raise exception 'amount_too_small' using errcode = '22023';
  end if;
  if v_holder is null or char_length(v_holder) not between 2 and 80
     or v_holder ~ '[[:cntrl:]]' then
    raise exception 'invalid_holder' using errcode = '22023';
  end if;
  begin
    v_account := private.clean_account(p_method, p_account);
  exception when sqlstate '22023' then
    raise exception 'invalid_account' using errcode = '22023';
  end;
  perform private.rate_limit('request_withdrawal', 5, interval '1 day');

  perform 1 from public.technician_wallets where technician_id = v_user_id for update;
  if not found
     or (select balance_piastres from public.technician_wallets
          where technician_id = v_user_id) < p_amount_piastres then
    raise exception 'insufficient_balance' using errcode = 'P0001';
  end if;

  insert into public.wallet_withdrawals (technician_id, amount_piastres, method, account, holder_name)
  values (v_user_id, p_amount_piastres, p_method, v_account, v_holder)
  returning id into v_id;
  perform private.wallet_move(v_user_id, 'withdrawal', -p_amount_piastres, p_withdrawal_id => v_id);
  insert into public.technician_payout_accounts (technician_id, method, account, holder_name)
  values (v_user_id, p_method, v_account, v_holder)
  on conflict (technician_id) do update
    set method = excluded.method,
        account = excluded.account,
        holder_name = excluded.holder_name,
        updated_at = now();
  return v_id;
end;
$$;

drop function public.my_payout_account();
drop function public.save_payout_account(public.topup_method, text, text);
drop function public.admin_mark_escrow_paid(uuid, text);

-- The admin console --------------------------------------------------------------------------

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
                 case when e.status in ('pending', 'disputed', 'refund_due')
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
                   'refund_reference', e.refund_reference,
                   'reject_reason', e.reject_reason,
                   'dispute_reason', e.dispute_reason,
                   'disputed_by', e.disputed_by,
                   'resolution_note', e.resolution_note,
                   'job_finished_at', j.finished_at,
                   'created_at', e.created_at,
                   'held_at', e.held_at,
                   'paid_out_at', e.paid_out_at,
                   'refunded_at', e.refunded_at,
                   'online', e.payment_order_id is not null,
                   'online_method', po.payment_method
                 ) as item
            from public.job_escrows e
            left join public.profiles cp on cp.id = e.consumer_id
            left join public.profiles tp on tp.id = e.technician_id
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

-- A dispute is settled: the technician's wallet gets the money or the
-- consumer does.
create or replace function public.admin_resolve_escrow(
  p_escrow_id uuid,
  p_pay_technician boolean,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text;
  v_escrow public.job_escrows;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_note := private.clean_note(p_note, 3, 300);

  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_escrow.status <> 'disputed' then
    raise exception 'not_disputed' using errcode = 'P0001';
  end if;

  update public.job_escrows set resolution_note = v_note where id = v_escrow.id;
  if p_pay_technician then
    perform private.release_escrow(v_escrow.id);
  else
    update public.job_escrows set status = 'refund_due' where id = v_escrow.id;
  end if;
  perform private.admin_log(
    'resolve_escrow', 'job_escrow', v_escrow.id::text,
    jsonb_build_object(
      'request_code', v_escrow.request_code, 'amount_piastres', v_escrow.amount_piastres,
      'pay_technician', p_pay_technician, 'note', v_note
    )
  );
  return jsonb_build_object(
    'status', case when p_pay_technician then 'paid_out' else 'refund_due' end,
    'already_reviewed', false
  );
end;
$$;

-- The queue of withdrawals of one status (null: all), oldest first for the
-- ones waiting.
create function public.admin_list_withdrawals(
  p_status public.withdrawal_status default 'requested',
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
      select count(*) from public.wallet_withdrawals w
       where p_status is null or w.status = p_status
    ),
    'counts', (
      select coalesce(jsonb_object_agg(s.status::text, s.n), '{}')
        from (select status, count(*) as n from public.wallet_withdrawals group by status) s
    ),
    'items', (
      select coalesce(jsonb_agg(x.item order by x.rank, x.id), '[]')
        from (
          select w.id,
                 case when w.status = 'requested'
                      then extract(epoch from w.created_at)
                      else -extract(epoch from w.created_at) end as rank,
                 jsonb_build_object(
                   'id', w.id,
                   'status', w.status,
                   'amount_piastres', w.amount_piastres,
                   'method', w.method,
                   'account', w.account,
                   'holder_name', w.holder_name,
                   'technician_name', tp.full_name,
                   'technician_phone', case when tp.phone like '+20%' then '0' || substr(tp.phone, 4) end,
                   'reference', w.reference,
                   'reject_reason', w.reject_reason,
                   'created_at', w.created_at,
                   'processed_at', w.processed_at
                 ) as item
            from public.wallet_withdrawals w
            left join public.profiles tp on tp.id = w.technician_id
           where p_status is null or w.status = p_status
           order by 2, w.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- The money was sent; p_reference is the transfer's reference.
create function public.admin_mark_withdrawal_paid(p_withdrawal_id uuid, p_reference text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference text;
  v_withdrawal public.wallet_withdrawals;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reference := private.clean_note(p_reference, 3, 100);

  select * into v_withdrawal from public.wallet_withdrawals
   where id = p_withdrawal_id for update;
  if not found then
    raise exception 'withdrawal_not_found' using errcode = 'P0002';
  end if;
  if v_withdrawal.status = 'paid' then
    return jsonb_build_object('status', 'paid', 'already_reviewed', true);
  end if;
  if v_withdrawal.status <> 'requested' then
    raise exception 'not_requested' using errcode = 'P0001';
  end if;

  update public.wallet_withdrawals
     set status = 'paid', reference = v_reference, processed_at = now()
   where id = v_withdrawal.id;
  perform private.notify(v_withdrawal.technician_id, 'technician', 'withdrawal_paid');
  perform private.admin_log(
    'pay_withdrawal', 'wallet_withdrawal', v_withdrawal.id::text,
    jsonb_build_object(
      'amount_piastres', v_withdrawal.amount_piastres, 'method', v_withdrawal.method,
      'account', v_withdrawal.account, 'reference', v_reference
    )
  );
  return jsonb_build_object('status', 'paid', 'already_reviewed', false);
end;
$$;

-- Not sent (a wrong number, say): the amount returns to the wallet and he is
-- told why.
create function public.admin_reject_withdrawal(p_withdrawal_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_withdrawal public.wallet_withdrawals;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reason := private.clean_note(p_reason, 3, 200);

  select * into v_withdrawal from public.wallet_withdrawals
   where id = p_withdrawal_id for update;
  if not found then
    raise exception 'withdrawal_not_found' using errcode = 'P0002';
  end if;
  if v_withdrawal.status = 'rejected' then
    return jsonb_build_object('status', 'rejected', 'already_reviewed', true);
  end if;
  if v_withdrawal.status <> 'requested' then
    raise exception 'not_requested' using errcode = 'P0001';
  end if;

  update public.wallet_withdrawals
     set status = 'rejected', reject_reason = v_reason, processed_at = now()
   where id = v_withdrawal.id;
  perform private.wallet_move(
    v_withdrawal.technician_id, 'withdrawal_refund', v_withdrawal.amount_piastres,
    p_withdrawal_id => v_withdrawal.id
  );
  perform private.notify(v_withdrawal.technician_id, 'technician', 'withdrawal_rejected');
  perform private.admin_log(
    'reject_withdrawal', 'wallet_withdrawal', v_withdrawal.id::text,
    jsonb_build_object(
      'amount_piastres', v_withdrawal.amount_piastres, 'reason', v_reason
    )
  );
  return jsonb_build_object('status', 'rejected', 'already_reviewed', false);
end;
$$;

-- Grants --------------------------------------------------------------------------------------

revoke execute on function
  public.technician_confirm_work_done(uuid),
  public.technician_dispute_payment(uuid, text),
  public.my_wallet(),
  public.request_withdrawal(bigint, public.topup_method, text, text),
  public.admin_list_withdrawals(public.withdrawal_status, integer, integer),
  public.admin_mark_withdrawal_paid(uuid, text),
  public.admin_reject_withdrawal(uuid, text)
from public, anon;
grant execute on function
  public.technician_confirm_work_done(uuid),
  public.technician_dispute_payment(uuid, text),
  public.my_wallet(),
  public.request_withdrawal(bigint, public.topup_method, text, text),
  public.admin_list_withdrawals(public.withdrawal_status, integer, integer),
  public.admin_mark_withdrawal_paid(uuid, text),
  public.admin_reject_withdrawal(uuid, text)
to authenticated;

-- Money is no longer "released" for a manual payout: it goes to the wallet,
-- so nothing sends the old notice any more.
delete from public.notifications where kind = 'escrow_released';

-- Each of these reaches the phone.
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
    'escrow_held', 'escrow_rejected', 'escrow_paid_out',
    'escrow_disputed', 'escrow_refunded', 'incoming_call',
    'escrow_work_confirmed', 'escrow_release_scheduled', 'withdrawal_paid',
    'withdrawal_rejected'
  ]);
$function$;

revoke execute on all functions in schema private from public, anon, authenticated;
