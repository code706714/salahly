begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

select is_empty(
  $$select tablename from pg_tables where schemaname in ('public', 'private') and not rowsecurity$$,
  'every table in public and private has row level security'
);

select is_empty(
  $$select table_name, privilege_type
      from information_schema.role_table_grants
     where grantee = 'anon' and table_schema in ('public', 'private')$$,
  'anon has no table privileges'
);

select is_empty(
  $$select table_name, privilege_type
      from information_schema.role_table_grants
     where grantee = 'authenticated'
       and table_schema = 'public'
       and privilege_type <> 'SELECT'$$,
  'authenticated can only read public tables, never write them directly'
);

select ok(
  not has_schema_privilege('authenticated', 'private', 'usage')
  and not has_schema_privilege('anon', 'private', 'usage'),
  'the private schema is not reachable from the API roles'
);

select is_empty(
  $$select p.oid::regprocedure::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public', 'private', 'guard')
       and (p.proconfig is null
            or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))$$,
  'every function pins its search_path'
);

select is_empty(
  $$select p.oid::regprocedure::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and has_function_privilege('anon', p.oid, 'execute')$$,
  'anon cannot execute any public function'
);

select ok(
  has_function_privilege('authenticated', 'public.complete_consumer_onboarding(text, public.honorific, text)', 'execute')
  and has_function_privilege(
    'authenticated',
    'public.complete_technician_onboarding(text, text, smallint, text, text, double precision, double precision, smallint, smallint[], text[], jsonb, text, text, text)',
    'execute'
  ),
  'signed-in users can call the onboarding functions'
);

select ok(
  not has_schema_privilege('anon', 'guard', 'usage')
  and not exists (select 1 from pg_tables where schemaname = 'guard'),
  'the guard schema holds no tables and anon cannot reach it'
);

select is_empty(
  $$select p.oid::regprocedure::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'guard'
       and (has_function_privilege('anon', p.oid, 'execute')
            or p.prorettype <> 'boolean'::regtype)$$,
  'guard functions only answer yes or no, and only to signed-in users'
);

select ok(
  not has_function_privilege('authenticated', 'public.set_updated_at()', 'execute'),
  'the updated_at trigger function is not callable from the API'
);

select * from finish();
rollback;
