begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

create function pg_temp.sign_in_as(p_user_id uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text,
    true
  );
$$;

-- Inserts the object row the storage API writes for an upload.
create function pg_temp.upload(p_bucket text, p_name text, p_owner text)
returns void
language sql
as $$
  insert into storage.objects (bucket_id, name, owner_id)
  values (p_bucket, p_name, p_owner);
$$;

grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.sign_in_as('00000000-0000-4000-8000-00000000c001');
set local role authenticated;

select lives_ok(
  $$select pg_temp.upload(
      'avatars',
      '00000000-0000-4000-8000-00000000c001/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-00000000c001'
    )$$,
  'a user can upload into their own folder'
);

select throws_ok(
  $$select pg_temp.upload(
      'avatars',
      '00000000-0000-4000-8000-00000000c002/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-00000000c001'
    )$$,
  '42501',
  null,
  'a user cannot upload into someone else''s folder'
);

select throws_ok(
  $$select pg_temp.upload(
      'avatars',
      '00000000-0000-4000-8000-00000000c001/photo.jpg',
      '00000000-0000-4000-8000-00000000c001'
    )$$,
  '42501',
  null,
  'file names must be random uuids'
);

select throws_ok(
  $$select pg_temp.upload(
      'avatars',
      '00000000-0000-4000-8000-00000000c001/' || gen_random_uuid() || '.svg',
      '00000000-0000-4000-8000-00000000c001'
    )$$,
  '42501',
  null,
  'only image extensions are accepted'
);

select lives_ok(
  $$select pg_temp.upload(
      'verification-docs',
      '00000000-0000-4000-8000-00000000c001/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-00000000c001'
    )
    from generate_series(1, 10)$$,
  'a user can upload ten documents in a day'
);

select throws_ok(
  $$select pg_temp.upload(
      'verification-docs',
      '00000000-0000-4000-8000-00000000c001/' || gen_random_uuid() || '.jpg',
      '00000000-0000-4000-8000-00000000c001'
    )$$,
  '42501',
  null,
  'the eleventh upload in a day is refused'
);

select is_empty(
  $$select name from storage.objects$$,
  'users cannot list uploaded files, their own included'
);

select * from finish();
rollback;
