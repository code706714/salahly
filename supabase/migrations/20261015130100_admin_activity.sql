-- The dashboard shows the day's money and what every technician did, and a
-- complaint's answer reaches the person who made it.
--
-- Needs 20261015130000_complaint_reply_enums.sql applied first.

-- The notification list also carries the team's answer to a complaint.
create or replace function public.my_notifications(p_role public.user_role, p_limit integer default 50)
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
        'topup_uses', t.uses,
        'resolution_note', case when n.kind = 'complaint_resolved' then cr.resolution_note end
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
        left join lateral (
          select k.resolution_note
            from public.complaints k
           where k.request_id = n.request_id and k.resolved_at is not null
           order by k.resolved_at desc
           limit 1
        ) cr on n.kind = 'complaint_resolved'
       where n.user_id = auth.uid() and n.role = p_role
       order by n.created_at desc, n.id
       limit least(greatest(coalesce(p_limit, 50), 1), 100)
    ) x;
$$;


-- The team's answer to a complaint reaches the consumer as a notification
-- that carries the written reply.
create or replace function public.admin_resolve_complaint(p_complaint_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text;
  v_complaint public.complaints;
begin
  perform private.require_admin();
  v_note := private.clean_note(p_note, 3, 500);

  select * into v_complaint from public.complaints where id = p_complaint_id for update;
  if not found then
    raise exception 'complaint_not_found' using errcode = 'P0002';
  end if;
  if v_complaint.resolved_at is not null then
    return jsonb_build_object('resolved', true, 'already_resolved', true);
  end if;

  update public.complaints
     set resolved_at = now(), resolution_note = v_note, resolved_by = (select auth.uid())
   where id = v_complaint.id;
  perform private.admin_log(
    'resolve_complaint', 'complaint', v_complaint.id::text,
    jsonb_build_object('request_id', v_complaint.request_id, 'note', v_note)
  );
  perform private.notify(
    v_complaint.consumer_id, 'consumer', 'complaint_resolved', v_complaint.request_id
  );
  return jsonb_build_object('resolved', true, 'already_resolved', false);
end;
$$;


-- Where today, this week (from Saturday) or this month starts, in Egypt's
-- time. The overview counts the last 7 and 30 days; the dashboard's money
-- and activity pages count the calendar periods people mean by "today",
-- "this week" and "this month".
create function private.calendar_since(p_period text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_now timestamp := now() at time zone 'Africa/Cairo';
begin
  return case coalesce(p_period, 'today')
    when 'today' then date_trunc('day', v_now) at time zone 'Africa/Cairo'
    when 'week' then (
      date_trunc('week', v_now + interval '2 days') - interval '2 days'
    ) at time zone 'Africa/Cairo'
    when 'month' then date_trunc('month', v_now) at time zone 'Africa/Cairo'
    else null
  end;
end;
$$;

-- Money in a period (today | week | month): what people paid, what the app
-- earned, what went to technicians' wallets and out of them, and the
-- movements themselves, newest first.
create function public.admin_money_summary(p_period text default 'today')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz := private.calendar_since(p_period);
begin
  perform private.require_admin();
  if v_since is null then
    raise exception 'invalid_period' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'period', coalesce(p_period, 'today'),
    'since', v_since,
    -- Credit packs bought: what the app itself earned. Transfers approved by
    -- hand before online payments count too.
    'earned_piastres', (
      select coalesce(sum(o.amount_piastres), 0)
        from public.payment_orders o
       where o.purpose = 'credit_pack' and o.status = 'succeeded' and o.updated_at >= v_since
    ) + (
      select coalesce(sum(t.amount_piastres), 0)
        from public.credit_topups t
       where t.status = 'approved' and t.reviewed_at >= v_since
    ),
    -- Everything customers paid online, for packs and for jobs held with us.
    'paid_in', (
      select jsonb_build_object(
        'count', count(*),
        'total_piastres', coalesce(sum(o.amount_piastres), 0),
        'escrow_piastres', coalesce(sum(o.amount_piastres) filter (where o.purpose = 'escrow'), 0)
      )
        from public.payment_orders o
       where o.status = 'succeeded' and o.updated_at >= v_since
    ),
    -- Moved into technicians' wallets, and what they asked to take out.
    'released_to_wallets_piastres', (
      select coalesce(sum(l.amount_piastres), 0)
        from public.wallet_ledger l
       where l.kind = 'escrow' and l.created_at >= v_since
    ),
    'withdrawals', (
      select jsonb_build_object(
        'requested_count', count(*) filter (where w.created_at >= v_since),
        'requested_piastres', coalesce(sum(w.amount_piastres) filter (where w.created_at >= v_since), 0),
        'paid_count', count(*) filter (where w.status = 'paid' and w.processed_at >= v_since),
        'paid_piastres', coalesce(
          sum(w.amount_piastres) filter (where w.status = 'paid' and w.processed_at >= v_since), 0
        ),
        'waiting_count', count(*) filter (where w.status = 'requested'),
        'waiting_piastres', coalesce(sum(w.amount_piastres) filter (where w.status = 'requested'), 0)
      )
        from public.wallet_withdrawals w
    ),
    'transactions', (
      select coalesce(jsonb_agg(x.item order by x.at desc), '[]')
        from (
          select * from (
            select o.updated_at as at,
                   jsonb_build_object(
                     'kind', case o.purpose when 'credit_pack' then 'pack_payment' else 'escrow_payment' end,
                     'amount_piastres', o.amount_piastres,
                     'person_name', p.full_name,
                     'role', o.role,
                     'method', o.payment_method,
                     'at', o.updated_at
                   ) as item
              from public.payment_orders o
              left join public.profiles p on p.id = o.user_id
             where o.status = 'succeeded' and o.updated_at >= v_since
            union all
            select w.created_at,
                   jsonb_build_object(
                     'kind', 'withdrawal_' || w.status::text,
                     'amount_piastres', w.amount_piastres,
                     'person_name', p.full_name,
                     'role', 'technician',
                     'method', w.method,
                     'at', w.created_at
                   )
              from public.wallet_withdrawals w
              left join public.profiles p on p.id = w.technician_id
             where w.created_at >= v_since
          ) u
          order by u.at desc
          limit 100
        ) x
    )
  );
end;
$$;

-- What technicians did in a period (today | week | month): for each one who
-- worked, the jobs with their customers and what they came to, busiest
-- first. A job counts when it was made, started or finished in the period.
create function public.admin_technician_activity(
  p_period text default 'today',
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz := private.calendar_since(p_period);
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  perform private.require_admin();
  if v_since is null then
    raise exception 'invalid_period' using errcode = '22023';
  end if;

  return (
    with worked as (
      select j.id, j.technician_id, j.customer_id, j.status, j.source, j.description,
             j.scheduled_at, j.started_at, j.finished_at, j.created_at,
             coalesce((
               select sum(i.unit_price_piastres * i.quantity)
                 from public.job_items i
                where i.job_id = j.id and i.technician_id = j.technician_id and i.deleted_at is null
             ), 0) as total_piastres,
             coalesce((
               select sum(pay.amount_piastres)
                 from public.payments pay
                where pay.job_id = j.id and pay.technician_id = j.technician_id and pay.deleted_at is null
             ), 0) as paid_piastres
        from public.jobs j
       where j.deleted_at is null
         and j.status <> 'cancelled'
         and (j.created_at >= v_since or j.started_at >= v_since or j.finished_at >= v_since)
    ),
    per_technician as (
      select w.technician_id,
             count(*) as jobs_count,
             count(*) filter (where w.status in ('finished', 'paid')) as finished_count,
             count(distinct w.customer_id) as customers_count,
             sum(w.total_piastres) filter (where w.status in ('finished', 'paid')) as billed_piastres,
             sum(w.paid_piastres) as paid_piastres
        from worked w
       group by w.technician_id
    ),
    top as (
      select * from per_technician
       order by finished_count desc, jobs_count desc, technician_id
       limit v_limit
    )
    select jsonb_build_object(
      'period', coalesce(p_period, 'today'),
      'since', v_since,
      'technicians_active', (select count(*) from per_technician),
      'jobs_count', (select coalesce(sum(jobs_count), 0) from per_technician),
      'finished_count', (select coalesce(sum(finished_count), 0) from per_technician),
      'billed_piastres', (select coalesce(sum(billed_piastres), 0) from per_technician),
      'technicians', coalesce(jsonb_agg(
        jsonb_build_object(
          'id', t.technician_id,
          'name', p.full_name,
          'phone', case when p.phone like '+20%' then '0' || substr(p.phone, 4) end,
          'jobs_count', t.jobs_count,
          'finished_count', t.finished_count,
          'customers_count', t.customers_count,
          'billed_piastres', coalesce(t.billed_piastres, 0),
          'paid_piastres', coalesce(t.paid_piastres, 0),
          'jobs', (
            select coalesce(jsonb_agg(
              jsonb_build_object(
                'id', w.id,
                'customer_name', c.name,
                'status', w.status,
                'source', w.source,
                'description', left(w.description, 120),
                'total_piastres', w.total_piastres,
                'paid_piastres', w.paid_piastres,
                'at', coalesce(w.finished_at, w.started_at, w.scheduled_at, w.created_at)
              ) order by coalesce(w.finished_at, w.started_at, w.scheduled_at, w.created_at) desc
            ), '[]')
              from (
                select * from worked ww
                 where ww.technician_id = t.technician_id
                 order by coalesce(ww.finished_at, ww.started_at, ww.scheduled_at, ww.created_at) desc
                 limit 30
              ) w
              left join public.customers c on c.id = w.customer_id and c.technician_id = w.technician_id
          )
        ) order by t.finished_count desc, t.jobs_count desc, t.technician_id
      ), '[]')
    )
      from top t
      left join public.profiles p on p.id = t.technician_id
  );
end;
$$;

revoke execute on function
  public.admin_money_summary(text),
  public.admin_technician_activity(text, integer)
from public, anon;
grant execute on function
  public.admin_money_summary(text),
  public.admin_technician_activity(text, integer)
to authenticated;
