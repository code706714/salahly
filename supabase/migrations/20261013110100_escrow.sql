-- Money guarantee. A consumer may pay a job's agreed price to Salahly before
-- the work; the money is held until she confirms the work (or 72 hours after
-- the technician finished with no complaint), then Salahly pays the
-- technician. The transfers are manual (InstaPay or a wallet) and checked by
-- an admin, so each step is a row the admin console works through:
--
--   pending   the consumer says she transferred; an admin checks it
--   held      found in our account; the technician is told it's secured
--   released  the work is confirmed; the technician is owed the money
--   paid_out  an admin paid the technician
--   disputed  the consumer objected; an admin decides
--   refund_due the job was cancelled or the dispute went her way
--   refunded  an admin returned the money
--   rejected  the transfer was not found
--
-- Salahly takes no commission here; the technician is paid what the
-- consumer paid for the offer (plus the urgent fee, if any). Anything the
-- price grew by afterwards is settled between them as before.

create type public.escrow_status as enum (
  'pending', 'held', 'released', 'paid_out', 'disputed', 'refund_due',
  'refunded', 'rejected'
);

create table public.job_escrows (
  id uuid primary key default gen_random_uuid(),
  -- Kept when an account or request is deleted: it is a record of money.
  request_id uuid references public.service_requests (id) on delete set null,
  request_code text not null,
  consumer_id uuid references public.profiles (id) on delete set null,
  technician_id uuid references public.technician_profiles (id) on delete set null,
  amount_piastres bigint not null check (amount_piastres between 100 and 100000000),
  method public.topup_method not null,
  sender_account text not null check (char_length(sender_account) between 3 and 64),
  screenshot_path text not null unique,
  status public.escrow_status not null default 'pending',
  reject_reason text check (char_length(reject_reason) <= 200),
  dispute_reason text check (char_length(dispute_reason) <= 300),
  resolution_note text check (char_length(resolution_note) <= 300),
  -- Where the technician is paid, copied when the money is released.
  payout_method public.topup_method,
  payout_account text,
  payout_holder text,
  payout_reference text check (char_length(payout_reference) <= 100),
  refund_reference text check (char_length(refund_reference) <= 100),
  created_at timestamptz not null default now(),
  held_at timestamptz,
  released_at timestamptz,
  paid_out_at timestamptz,
  refunded_at timestamptz
);

-- One live escrow per request; a rejected one can be made again.
create unique index job_escrows_request_idx
  on public.job_escrows (request_id)
  where status <> 'rejected';
create index job_escrows_status_idx on public.job_escrows (status, created_at);
create index job_escrows_consumer_idx on public.job_escrows (consumer_id);
create index job_escrows_technician_idx on public.job_escrows (technician_id);

alter table public.job_escrows enable row level security;
revoke all on table public.job_escrows from anon, authenticated;

-- Where Salahly pays a technician.
create table public.technician_payout_accounts (
  technician_id uuid primary key references public.technician_profiles (id) on delete cascade,
  method public.topup_method not null,
  account text not null check (char_length(account) between 3 and 64),
  holder_name text not null check (char_length(holder_name) between 2 and 80),
  updated_at timestamptz not null default now()
);

alter table public.technician_payout_accounts enable row level security;
revoke all on table public.technician_payout_accounts from anon, authenticated;

-- Moving the money --------------------------------------------------------------------

create function private.escrow_hours_to_release()
returns interval
language sql
immutable
set search_path = ''
as $$
  select interval '72 hours';
$$;

-- A sender or payout account: for a wallet an Egyptian mobile number (Arabic
-- digits allowed); InstaPay also takes an address, but plain characters only.
create function private.clean_account(p_method public.topup_method, p_account text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_account text := btrim(coalesce(p_account, ''));
  v_digits text := translate(btrim(coalesce(p_account, '')), '٠١٢٣٤٥٦٧٨٩ ', '0123456789');
begin
  if p_method = 'wallet' then
    if v_digits !~ '^01[0125][0-9]{8}$' then
      raise exception 'invalid_account' using errcode = '22023';
    end if;
    return v_digits;
  elsif v_digits ~ '^01[0125][0-9]{8}$' then
    return v_digits;
  elsif v_account !~ '^[A-Za-z0-9@._-]{3,64}$' then
    raise exception 'invalid_account' using errcode = '22023';
  end if;
  return v_account;
end;
$$;

-- The price the consumer agreed to for a request: the chosen offer plus the
-- urgent fee. Null when there is nothing to secure (no chosen offer, or a
-- free warranty visit).
create function private.escrow_amount(p_request_id uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select o.price_piastres + r.urgent_fee_piastres
    from public.service_requests r
    join public.request_offers o on o.id = r.chosen_offer_id
   where r.id = p_request_id
     and r.warranty_of is null
     and o.price_piastres + r.urgent_fee_piastres >= 100;
$$;

-- The consumer says she transferred the job's price to us. Allowed once the
-- technician is picked and until he starts.
create function public.secure_payment(
  p_request_id uuid,
  p_method public.topup_method,
  p_sender_account text,
  p_screenshot_path text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_request public.service_requests;
  v_job public.jobs;
  v_amount bigint;
  v_sender text;
  v_id uuid;
  v_constraint text;
begin
  perform private.assert_active();
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;

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

  if not exists (
    select 1 from public.payment_accounts where method = p_method and is_active
  ) then
    raise exception 'method_unavailable' using errcode = '22023';
  end if;
  begin
    v_sender := private.clean_account(p_method, p_sender_account);
  exception when sqlstate '22023' then
    raise exception 'invalid_sender' using errcode = '22023';
  end;

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

  begin
    insert into public.job_escrows (
      request_id, request_code, consumer_id, technician_id, amount_piastres,
      method, sender_account, screenshot_path
    )
    values (
      p_request_id, private.request_code(p_request_id), v_user_id, v_job.technician_id,
      v_amount, p_method, v_sender, p_screenshot_path
    )
    returning id into v_id;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'job_escrows_request_idx' then
      raise exception 'already_secured' using errcode = 'P0001';
    end if;
    raise exception 'invalid_screenshot' using errcode = '22023';
  end;
  return v_id;
end;
$$;

-- What the consumer sees: the amount, where to transfer, and the state.
create function public.escrow_info(p_request_id uuid)
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
    'accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
               'method', a.method, 'account', a.account, 'holder_name', a.holder_name
             ) order by a.method)
        from public.payment_accounts a where a.is_active
    ), '[]'),
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

-- The work is right: the money goes to the technician.
create function public.confirm_work_done(p_request_id uuid)
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
  perform private.release_escrow(v_escrow.id);
end;
$$;

-- Something is wrong with the work: the money stays with us until an admin
-- decides.
create function public.dispute_payment(p_request_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
  v_reason text := private.clean_note(p_reason, 3, 300);
begin
  perform private.assert_active();
  select e.* into v_escrow
    from public.job_escrows e
    join public.service_requests r on r.id = e.request_id
    join public.jobs j on j.id = r.job_id
   where e.request_id = p_request_id
     and r.consumer_id = (select auth.uid())
     and e.status = 'held'
     and j.status <> 'cancelled'
   for update of e;
  if not found then
    raise exception 'escrow_unavailable' using errcode = 'P0001';
  end if;
  update public.job_escrows
     set status = 'disputed', dispute_reason = v_reason
   where id = v_escrow.id;
  if v_escrow.technician_id is not null then
    perform private.notify(v_escrow.technician_id, 'technician', 'escrow_disputed', v_escrow.request_id);
  end if;
end;
$$;

-- Marks the money as the technician's and copies where to pay him. Not
-- reachable from the API.
create function private.release_escrow(p_escrow_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
  v_payout public.technician_payout_accounts;
begin
  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found or v_escrow.status not in ('held', 'disputed') then
    raise exception 'not_releasable' using errcode = 'P0001';
  end if;
  select * into v_payout from public.technician_payout_accounts
   where technician_id = v_escrow.technician_id;
  update public.job_escrows
     set status = 'released',
         released_at = now(),
         payout_method = v_payout.method,
         payout_account = v_payout.account,
         payout_holder = v_payout.holder_name
   where id = v_escrow.id;
  if v_escrow.technician_id is not null then
    perform private.notify(v_escrow.technician_id, 'technician', 'escrow_released', v_escrow.request_id);
  end if;
end;
$$;

-- Held money the consumer left unanswered for 72 hours after the work was
-- finished goes to the technician, unless she disputed it.
create function private.release_due_escrows()
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
       and j.status in ('finished', 'paid')
       and j.finished_at <= now() - private.escrow_hours_to_release()
  loop
    perform private.release_escrow(v_escrow.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- A cancelled job or request gives the money back. A transfer still waiting
-- to be checked is included: it may have reached us anyway.
create function private.refund_cancelled_escrow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.job_escrows e
     set status = 'refund_due'
   where e.status in ('pending', 'held')
     and ((tg_table_name = 'jobs' and e.request_id in (
             select r.id from public.service_requests r where r.job_id = new.id))
          or (tg_table_name = 'service_requests' and e.request_id = new.id));
  return null;
end;
$$;

create trigger jobs_refund_escrow
  after update of status on public.jobs
  for each row
  when (new.status = 'cancelled' and old.status is distinct from 'cancelled')
  execute function private.refund_cancelled_escrow();

create trigger service_requests_refund_escrow
  after update of status on public.service_requests
  for each row
  when (new.status in ('cancelled', 'expired') and old.status is distinct from new.status)
  execute function private.refund_cancelled_escrow();

-- The technician ---------------------------------------------------------------------

-- Where Salahly pays him.
create function public.my_payout_account()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'method', a.method, 'account', a.account, 'holder_name', a.holder_name
         )
    from public.technician_payout_accounts a
   where a.technician_id = (select auth.uid());
$$;

create function public.save_payout_account(
  p_method public.topup_method,
  p_account text,
  p_holder_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_account text;
  v_holder text := private.normalize_text(p_holder_name);
begin
  perform private.assert_active();
  if not exists (select 1 from public.technician_profiles where id = v_user_id) then
    raise exception 'not_found' using errcode = 'P0002';
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
  perform private.rate_limit('save_payout_account', 10, interval '1 day');
  insert into public.technician_payout_accounts (technician_id, method, account, holder_name)
  values (v_user_id, p_method, v_account, v_holder)
  on conflict (technician_id) do update
    set method = excluded.method,
        account = excluded.account,
        holder_name = excluded.holder_name,
        updated_at = now();
end;
$$;

-- What the picked technician sees of the consumer's payment: whether the
-- money is secured, and whether it has reached him.
create function public.technician_escrow(p_request_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'status', e.status,
           'amount_piastres', e.amount_piastres
         )
    from public.job_escrows e
   where e.request_id = p_request_id
     and e.technician_id = (select auth.uid())
     and e.status <> 'rejected'
   order by e.created_at desc
   limit 1;
$$;

-- The admin console ------------------------------------------------------------------

-- The queue of one status (null: all). Everything an admin needs to check a
-- transfer or pay someone: who, how much, where from, the screenshot (sign
-- it with the admin's own session), and for a payout, where to pay.
create function public.admin_list_escrows(
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
                   'refunded_at', e.refunded_at
                 ) as item
            from public.job_escrows e
            left join public.profiles cp on cp.id = e.consumer_id
            left join public.profiles tp on tp.id = e.technician_id
            left join public.technician_payout_accounts pa on pa.technician_id = e.technician_id
            left join public.service_requests r on r.id = e.request_id
            left join public.jobs j on j.id = r.job_id
           where p_status is null or e.status = p_status
           order by 2, e.id
           limit private.page_limit(p_limit) offset private.page_offset(p_offset)
        ) x
    )
  );
end;
$$;

-- Found in our account and right.
create function public.admin_approve_escrow(p_escrow_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escrow public.job_escrows;
begin
  perform private.require_admin();
  perform private.require_recent_login();

  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_escrow.status = 'held' then
    return jsonb_build_object('status', 'held', 'already_reviewed', true);
  end if;
  if v_escrow.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  update public.job_escrows set status = 'held', held_at = now() where id = v_escrow.id;
  if v_escrow.consumer_id is not null then
    perform private.notify(v_escrow.consumer_id, 'consumer', 'escrow_held', v_escrow.request_id);
  end if;
  if v_escrow.technician_id is not null then
    perform private.notify(v_escrow.technician_id, 'technician', 'escrow_held', v_escrow.request_id);
  end if;
  perform private.admin_log(
    'approve_escrow', 'job_escrow', v_escrow.id::text,
    jsonb_build_object(
      'request_code', v_escrow.request_code, 'amount_piastres', v_escrow.amount_piastres,
      'method', v_escrow.method, 'sender_account', v_escrow.sender_account
    )
  );
  return jsonb_build_object('status', 'held', 'already_reviewed', false);
end;
$$;

-- Not found: the consumer is told why and can send another screenshot.
create function public.admin_reject_escrow(p_escrow_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_escrow public.job_escrows;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reason := private.clean_note(p_reason, 3, 200);

  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_escrow.status = 'rejected' then
    return jsonb_build_object('status', 'rejected', 'already_reviewed', true);
  end if;
  if v_escrow.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  update public.job_escrows set status = 'rejected', reject_reason = v_reason where id = v_escrow.id;
  if v_escrow.consumer_id is not null then
    perform private.notify(v_escrow.consumer_id, 'consumer', 'escrow_rejected', v_escrow.request_id);
  end if;
  perform private.admin_log(
    'reject_escrow', 'job_escrow', v_escrow.id::text,
    jsonb_build_object(
      'request_code', v_escrow.request_code, 'amount_piastres', v_escrow.amount_piastres,
      'reason', v_reason
    )
  );
  return jsonb_build_object('status', 'rejected', 'already_reviewed', false);
end;
$$;

-- The technician has been paid; p_reference is the transfer's reference.
create function public.admin_mark_escrow_paid(p_escrow_id uuid, p_reference text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference text;
  v_escrow public.job_escrows;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reference := private.clean_note(p_reference, 3, 100);

  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_escrow.status = 'paid_out' then
    return jsonb_build_object('status', 'paid_out', 'already_reviewed', true);
  end if;
  if v_escrow.status <> 'released' then
    raise exception 'not_released' using errcode = 'P0001';
  end if;

  update public.job_escrows
     set status = 'paid_out', paid_out_at = now(), payout_reference = v_reference
   where id = v_escrow.id;
  if v_escrow.technician_id is not null then
    perform private.notify(v_escrow.technician_id, 'technician', 'escrow_paid_out', v_escrow.request_id);
  end if;
  perform private.admin_log(
    'pay_escrow', 'job_escrow', v_escrow.id::text,
    jsonb_build_object(
      'request_code', v_escrow.request_code, 'amount_piastres', v_escrow.amount_piastres,
      'payout_account', v_escrow.payout_account, 'reference', v_reference
    )
  );
  return jsonb_build_object('status', 'paid_out', 'already_reviewed', false);
end;
$$;

-- A dispute is settled: the technician gets the money or the consumer does.
create function public.admin_resolve_escrow(
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
    'status', case when p_pay_technician then 'released' else 'refund_due' end,
    'already_reviewed', false
  );
end;
$$;

-- The consumer has her money back; p_reference is the transfer's reference.
create function public.admin_mark_escrow_refunded(p_escrow_id uuid, p_reference text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference text;
  v_escrow public.job_escrows;
begin
  perform private.require_admin();
  perform private.require_recent_login();
  v_reference := private.clean_note(p_reference, 3, 100);

  select * into v_escrow from public.job_escrows where id = p_escrow_id for update;
  if not found then
    raise exception 'escrow_not_found' using errcode = 'P0002';
  end if;
  if v_escrow.status = 'refunded' then
    return jsonb_build_object('status', 'refunded', 'already_reviewed', true);
  end if;
  if v_escrow.status <> 'refund_due' then
    raise exception 'not_refund_due' using errcode = 'P0001';
  end if;

  update public.job_escrows
     set status = 'refunded', refunded_at = now(), refund_reference = v_reference
   where id = v_escrow.id;
  if v_escrow.consumer_id is not null then
    perform private.notify(v_escrow.consumer_id, 'consumer', 'escrow_refunded', v_escrow.request_id);
  end if;
  perform private.admin_log(
    'refund_escrow', 'job_escrow', v_escrow.id::text,
    jsonb_build_object(
      'request_code', v_escrow.request_code, 'amount_piastres', v_escrow.amount_piastres,
      'sender_account', v_escrow.sender_account, 'reference', v_reference
    )
  );
  return jsonb_build_object('status', 'refunded', 'already_reviewed', false);
end;
$$;

-- Grants --------------------------------------------------------------------------------

revoke execute on function
  public.secure_payment(uuid, public.topup_method, text, text),
  public.escrow_info(uuid),
  public.confirm_work_done(uuid),
  public.dispute_payment(uuid, text),
  public.my_payout_account(),
  public.save_payout_account(public.topup_method, text, text),
  public.technician_escrow(uuid),
  public.admin_list_escrows(public.escrow_status, integer, integer),
  public.admin_approve_escrow(uuid),
  public.admin_reject_escrow(uuid, text),
  public.admin_mark_escrow_paid(uuid, text),
  public.admin_resolve_escrow(uuid, boolean, text),
  public.admin_mark_escrow_refunded(uuid, text)
from public, anon;
grant execute on function
  public.secure_payment(uuid, public.topup_method, text, text),
  public.escrow_info(uuid),
  public.confirm_work_done(uuid),
  public.dispute_payment(uuid, text),
  public.my_payout_account(),
  public.save_payout_account(public.topup_method, text, text),
  public.technician_escrow(uuid),
  public.admin_list_escrows(public.escrow_status, integer, integer),
  public.admin_approve_escrow(uuid),
  public.admin_reject_escrow(uuid, text),
  public.admin_mark_escrow_paid(uuid, text),
  public.admin_resolve_escrow(uuid, boolean, text),
  public.admin_mark_escrow_refunded(uuid, text)
to authenticated;

-- Every hour: pay out what the consumer left unanswered.
select cron.schedule('release-due-escrows', '23 * * * *', 'select private.release_due_escrows()');

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
    'escrow_held', 'escrow_rejected', 'escrow_released', 'escrow_paid_out',
    'escrow_disputed', 'escrow_refunded'
  ]);
$function$;

revoke execute on all functions in schema private from public, anon, authenticated;
