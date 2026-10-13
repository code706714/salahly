-- Price guide: before asking for a technician the consumer sees what a job
-- like hers usually costs, so an offer far above it stands out.
--
-- It comes from the offers consumers actually accepted for the same trade
-- (and problem) in the last six months, as the range most of them fall in
-- (the 10th to the 90th percentile, rounded out to whole 10 pounds). Fewer
-- than five accepted offers say too little and could point at one person's
-- price, so then the guide is the technicians' own suggested prices for the
-- trade from the catalog. Only the range leaves the database, never a row.

create function public.price_guide(
  p_category_id text,
  p_issue public.request_issue default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with seen as (
    select o.price_piastres
      from public.request_offers o
      join public.service_requests r on r.id = o.request_id
     where r.category_id = p_category_id
       and (p_issue is null or r.issue = p_issue)
       and r.warranty_of is null
       and o.status = 'accepted'
       and o.price_piastres >= 100
       and o.created_at > now() - interval '180 days'
  ),
  agreed as (
    select count(*) as samples,
           percentile_cont(0.1) within group (order by price_piastres) as low,
           percentile_cont(0.9) within group (order by price_piastres) as high
      from seen
  ),
  catalog as (
    select min(s.suggested_price_piastres) as low,
           max(s.suggested_price_piastres) as high
      from public.services s
     where s.category_id = p_category_id and s.is_active
  )
  select case
           when (select auth.uid()) is null then null
           when (select samples from agreed) >= 5 then jsonb_build_object(
             'low_piastres', (floor((select low from agreed) / 1000) * 1000)::bigint,
             'high_piastres', (ceil((select high from agreed) / 1000) * 1000)::bigint,
             'source', 'offers'
           )
           when (select low from catalog) is not null then jsonb_build_object(
             'low_piastres', (select low from catalog),
             'high_piastres', (select high from catalog),
             'source', 'catalog'
           )
         end;
$$;

revoke execute on function public.price_guide(text, public.request_issue) from public, anon;
grant execute on function public.price_guide(text, public.request_issue) to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
