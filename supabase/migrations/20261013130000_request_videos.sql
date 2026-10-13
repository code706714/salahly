-- A short video of the fault, sent with the request: the sound a washing
-- machine makes or a leak under load says more than a photo.
--
-- Videos live in their own private bucket, small and of a few types, in the
-- consumer's own folder, and are seen by her and by the technicians who
-- see her photos. A request has at most one, attached right after it is sent
-- (attach_request_video) so the request call itself stays as it was.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('request-videos', 'request-videos', false, 15728640, array['video/mp4', 'video/quicktime']);

alter table public.service_requests
  add column video_path text check (video_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(mp4|mov)$');

create function guard.can_view_request_video(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(p_name, '/', 1) = (select auth.uid()::text)
      or exists (
        select 1
          from public.service_requests r
         where r.video_path = p_name
           and (
             exists (
               select 1 from public.request_recipients rr
                where rr.request_id = r.id and rr.technician_id = (select auth.uid())
             )
             or (
               r.status = 'open'
               and private.request_meant_for(r.id, (select auth.uid()))
             )
           )
      );
$$;

revoke execute on function guard.can_view_request_video(text) from public, anon;
grant execute on function guard.can_view_request_video(text) to authenticated;

create policy "Consumers upload request videos to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'request-videos'
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(mp4|mov)$'
    and split_part(name, '/', 1) = (select auth.uid()::text)
    and (select guard.has_profile())
    and (select guard.is_consumer())
    and guard.upload_quota_left(bucket_id)
  );

create policy "Request videos are seen by their consumer and the technicians asked"
  on storage.objects for select to authenticated
  using (bucket_id = 'request-videos' and guard.can_view_request_video(name));

-- Attaches an uploaded video to the consumer's open request. One per request.
create function public.attach_request_video(p_request_id uuid, p_video_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_request public.service_requests;
begin
  perform private.assert_active();
  select * into v_request from public.service_requests
   where id = p_request_id and consumer_id = v_user_id
   for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if v_request.status <> 'open' or v_request.video_path is not null then
    raise exception 'video_unavailable' using errcode = 'P0001';
  end if;
  if p_video_path is null
     or not private.owns_object(v_user_id, 'request-videos', p_video_path) then
    raise exception 'invalid_video' using errcode = '22023';
  end if;
  update public.service_requests set video_path = p_video_path where id = p_request_id;
end;
$$;

revoke execute on function public.attach_request_video(uuid, text) from public, anon;
grant execute on function public.attach_request_video(uuid, text) to authenticated;

-- The video follows the request into what both sides read.
create or replace function private.request_for_technician(p_request_id uuid, p_technician_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $function$
  select jsonb_build_object(
    'id', r.id,
    'category_id', r.category_id,
    'issue', r.issue,
    'description', r.description,
    'photo_paths', to_jsonb(r.photo_paths),
    'video_path', r.video_path,
    'area_id', r.area_id,
    'distance_km', coalesce(
      rr.distance_km,
      private.distance_km(t.base_lat, t.base_lng, a.center_lat, a.center_lng)
    ),
    'preferred_on', r.preferred_on,
    'time_window', r.time_window,
    'expires_at', r.expires_at,
    'created_at', r.created_at,
    'urgent', r.urgent,
    'urgent_fee_piastres', r.urgent_fee_piastres,
    'consumer_name', private.short_name(p.full_name),
    'consumer_honorific', cp.honorific,
    'status', private.request_state(r.status, r.expires_at),
    'sent_to', (select count(*) from public.request_recipients x where x.request_id = r.id),
    'offer_count', (
      select count(*) from public.request_offers o
       where o.request_id = r.id and o.status <> 'withdrawn'
    ),
    'dismissed', rr.dismissed_at is not null,
    'my_offer', (
      select jsonb_build_object(
        'id', o.id, 'service_id', o.service_id, 'price_piastres', o.price_piastres,
        'arrive_at', o.arrive_at, 'note', o.note, 'status', o.status,
        'counter_price_piastres', o.counter_price_piastres,
        'awaiting', o.awaiting,
        'revisions_left', 2 - o.revision_count
      )
      from public.request_offers o
      where o.request_id = r.id and o.technician_id = p_technician_id
    )
  )
  from public.service_requests r
  join public.technician_profiles t on t.id = p_technician_id
  join public.service_areas a on a.id = r.area_id
  left join public.request_recipients rr
    on rr.request_id = r.id and rr.technician_id = t.id
  join public.consumer_profiles cp on cp.id = r.consumer_id
  join public.profiles p on p.id = r.consumer_id
  where r.id = p_request_id;
$function$;

create or replace function public.request_details(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_details jsonb := private.request_details_impl(p_request_id);
begin
  if v_details is null then
    return null;
  end if;
  return v_details || jsonb_build_object(
    'urgent', (select urgent from public.service_requests where id = p_request_id),
    'urgent_fee_piastres', (
      select urgent_fee_piastres from public.service_requests where id = p_request_id
    ),
    'video_path', (select video_path from public.service_requests where id = p_request_id),
    'warranty_until', private.warranty_until(p_request_id, (select auth.uid())),
    'is_warranty', exists (
      select 1 from public.service_requests
       where id = p_request_id and warranty_of is not null
    ),
    'technician_arriving_at', (
      select max(n.created_at)
        from public.notifications n
       where n.request_id = p_request_id
         and n.user_id = (select auth.uid())
         and n.role = 'consumer'
         and n.kind = 'technician_arriving'
    ),
    'offers', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', o.id,
               'price_piastres', o.price_piastres,
               'arrive_at', o.arrive_at,
               'note', o.note,
               'status', o.status,
               'distance_km', rr.distance_km,
               'created_at', o.created_at,
               'counter_price_piastres', o.counter_price_piastres,
               'awaiting', o.awaiting,
               'counters_left', 3 - o.counter_count,
               'technician', private.technician_card(o.technician_id)
             ) order by o.created_at), '[]')
        from public.request_offers o
        left join public.request_recipients rr
          on rr.request_id = o.request_id and rr.technician_id = o.technician_id
       where o.request_id = p_request_id and o.status <> 'withdrawn'
    )
  );
end;
$function$;

-- A deleted account takes its videos with it, like its photos: they are
-- queued for the storage purge.
create function private.queue_video_purge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.storage_purge (bucket_id, name)
  select o.bucket_id, o.name
    from storage.objects o
   where o.bucket_id = 'request-videos'
     and (o.owner_id = old.id::text or split_part(o.name, '/', 1) = old.id::text)
  on conflict do nothing;
  return old;
end;
$$;

create trigger profiles_queue_video_purge before delete on public.profiles
  for each row execute function private.queue_video_purge();

revoke execute on all functions in schema private from public, anon, authenticated;
