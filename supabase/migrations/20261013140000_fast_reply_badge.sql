-- Fast-reply badge: a technician who usually answers a request within half
-- an hour gets a badge on their card, listing and page, so a consumer can
-- tell who to expect an offer from soon.
--
-- It looks at the offers of the last 60 days against when the request
-- reached them. Fewer than five offers say too little, so no badge yet.

create function private.is_fast_replier(p_technician_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select count(*) >= 5
         and percentile_cont(0.5) within group (
               order by extract(epoch from o.created_at - rr.sent_at)
             ) <= 30 * 60
        from public.request_offers o
        join public.request_recipients rr
          on rr.request_id = o.request_id and rr.technician_id = o.technician_id
       where o.technician_id = p_technician_id
         and o.created_at > now() - interval '60 days'
    ),
    false
  );
$$;

-- The card and the listing keep their definitions; the badge rides on top.
alter function private.technician_card(uuid) rename to technician_card_impl;

create function private.technician_card(p_technician_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.technician_card_impl(p_technician_id)
         || jsonb_build_object('fast_reply', private.is_fast_replier(p_technician_id));
$$;

alter function private.technician_listing(uuid, text) rename to technician_listing_impl;

create function private.technician_listing(p_technician_id uuid, p_category_id text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.technician_listing_impl(p_technician_id, p_category_id)
         || jsonb_build_object('fast_reply', private.is_fast_replier(p_technician_id));
$$;

revoke execute on all functions in schema private from public, anon, authenticated;
