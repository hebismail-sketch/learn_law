-- Production access hardening for the four application content tables.
-- This transaction changes schema/table/sequence grants and RLS settings only;
-- it does not change table data, columns, constraints, or user roles.
--
-- Review before running in the production Supabase SQL Editor. It aborts if
-- any target table is missing, has an unexpected policy, or no existing
-- app_metadata.role=admin user is present. It never grants an admin role.

begin;

do $$
declare
  target_table text;
  target_column text;
  target_sequence record;
begin
  if to_regrole('anon') is null or to_regrole('authenticated') is null then
    raise exception
      'Expected Supabase roles anon and authenticated; migration aborted';
  end if;

  foreach target_table in array array[
    'categories',
    'subcategories',
    'legal_cases',
    'case_steps'
  ]
  loop
    if not exists (
      select 1
      from information_schema.tables
      where table_schema = 'public'
        and table_name = target_table
        and table_type = 'BASE TABLE'
    ) then
      raise exception 'Missing public.% base table; migration aborted',
        target_table;
    end if;

    if exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = target_table
        and policyname not in (
          'learn_law_production_public_read',
          'learn_law_production_admin_write',
          'learn_law_production_admin_insert',
          'learn_law_production_admin_update'
        )
    ) then
      raise exception
        'Unexpected RLS policy on public.%; inspect it before continuing',
        target_table;
    end if;

    if exists (
      select 1
      from pg_class t
      join pg_namespace n on n.oid = t.relnamespace
      join pg_roles owner_role on owner_role.oid = t.relowner
      where n.nspname = 'public'
        and t.relname = target_table
        and (
          pg_has_role('anon', owner_role.oid, 'MEMBER')
          or pg_has_role('authenticated', owner_role.oid, 'MEMBER')
        )
    ) then
      raise exception
        'anon or authenticated can assume ownership of public.%; migration aborted',
        target_table;
    end if;

    if exists (
      select 1
      from pg_roles bypass_role
      where (bypass_role.rolsuper or bypass_role.rolbypassrls)
        and (
          pg_has_role('anon', bypass_role.oid, 'MEMBER')
          or pg_has_role('authenticated', bypass_role.oid, 'MEMBER')
        )
    ) then
      raise exception
        'anon or authenticated can assume a superuser/BYPASSRLS role; migration aborted';
    end if;

    -- Remove any pre-existing column-level grants as well as table grants.
    for target_column in
      select column_name
      from information_schema.columns
      where table_schema = 'public'
        and table_name = target_table
    loop
      execute format(
        'revoke all privileges (%I) on table public.%I '
        'from public, anon, authenticated',
        target_column,
        target_table
      );
    end loop;

    -- The app sends client-generated UUIDs and never calls nextval(). Revoke
    -- sequence access for sequences owned by, or used by defaults on, these
    -- tables so sequence grants cannot bypass the table access design.
    for target_sequence in
      select distinct sequence_namespace.nspname, sequence_class.relname
      from pg_class sequence_class
      join pg_namespace sequence_namespace
        on sequence_namespace.oid = sequence_class.relnamespace
      where sequence_class.relkind = 'S'
        and (
          exists (
            select 1
            from pg_depend owned_dependency
            join pg_class target_class
              on target_class.oid = owned_dependency.refobjid
            join pg_namespace target_namespace
              on target_namespace.oid = target_class.relnamespace
            where owned_dependency.classid = 'pg_class'::regclass
              and owned_dependency.objid = sequence_class.oid
              and owned_dependency.refclassid = 'pg_class'::regclass
              and owned_dependency.deptype in ('a', 'i')
              and target_namespace.nspname = 'public'
              and target_class.relname = target_table
          )
          or exists (
            select 1
            from pg_attrdef column_default
            join pg_depend default_dependency
              on default_dependency.classid = 'pg_attrdef'::regclass
             and default_dependency.objid = column_default.oid
            where column_default.adrelid = (
              select target_class.oid
              from pg_class target_class
              join pg_namespace target_namespace
                on target_namespace.oid = target_class.relnamespace
              where target_namespace.nspname = 'public'
                and target_class.relname = target_table
            )
              and default_dependency.refclassid = 'pg_class'::regclass
              and default_dependency.refobjid = sequence_class.oid
          )
        )
    loop
      execute format(
        'revoke all privileges on sequence %I.%I '
        'from public, anon, authenticated',
        target_sequence.nspname,
        target_sequence.relname
      );
    end loop;
  end loop;

  if not exists (
    select 1
    from auth.users
    where raw_app_meta_data ->> 'role' = 'admin'
  ) then
    raise exception
      'No existing user has app_metadata.role=admin; migration aborted without granting any roles';
  end if;
end;
$$;

revoke create on schema public from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

revoke all privileges
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  from public, anon, authenticated;

grant select
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  to anon, authenticated;

-- The app's delete operation is a soft delete implemented as UPDATE of
-- deleted_at. Do not grant hard DELETE or TRUNCATE, even to administrators.
grant insert, update
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  to authenticated;

alter table public.categories enable row level security;
alter table public.subcategories enable row level security;
alter table public.legal_cases enable row level security;
alter table public.case_steps enable row level security;
alter table public.categories force row level security;
alter table public.subcategories force row level security;
alter table public.legal_cases force row level security;
alter table public.case_steps force row level security;

drop policy if exists learn_law_production_public_read on public.categories;
drop policy if exists learn_law_production_admin_write on public.categories;
drop policy if exists learn_law_production_admin_insert on public.categories;
drop policy if exists learn_law_production_admin_update on public.categories;
create policy learn_law_production_public_read on public.categories
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.categories
  for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy learn_law_production_admin_update on public.categories
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_production_public_read on public.subcategories;
drop policy if exists learn_law_production_admin_write on public.subcategories;
drop policy if exists learn_law_production_admin_insert on public.subcategories;
drop policy if exists learn_law_production_admin_update on public.subcategories;
create policy learn_law_production_public_read on public.subcategories
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.subcategories
  for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy learn_law_production_admin_update on public.subcategories
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_production_public_read on public.legal_cases;
drop policy if exists learn_law_production_admin_write on public.legal_cases;
drop policy if exists learn_law_production_admin_insert on public.legal_cases;
drop policy if exists learn_law_production_admin_update on public.legal_cases;
create policy learn_law_production_public_read on public.legal_cases
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.legal_cases
  for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy learn_law_production_admin_update on public.legal_cases
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_production_public_read on public.case_steps;
drop policy if exists learn_law_production_admin_write on public.case_steps;
drop policy if exists learn_law_production_admin_insert on public.case_steps;
drop policy if exists learn_law_production_admin_update on public.case_steps;
create policy learn_law_production_public_read on public.case_steps
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.case_steps
  for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy learn_law_production_admin_update on public.case_steps
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

do $$
declare
  target_table text;
  target_relation regclass;
begin
  foreach target_table in array array[
    'categories',
    'subcategories',
    'legal_cases',
    'case_steps'
  ]
  loop
    target_relation := format('public.%I', target_table)::regclass;

    if has_table_privilege('anon', target_relation, 'INSERT')
      or has_table_privilege('anon', target_relation, 'UPDATE')
      or has_table_privilege('anon', target_relation, 'DELETE')
      or has_table_privilege('anon', target_relation, 'TRUNCATE')
      or has_table_privilege('anon', target_relation, 'REFERENCES')
      or has_table_privilege('anon', target_relation, 'TRIGGER')
      or has_any_column_privilege('anon', target_relation, 'INSERT')
      or has_any_column_privilege('anon', target_relation, 'UPDATE')
    then
      raise exception
        'anon retains a write-related privilege on %; migration aborted',
        target_relation;
    end if;

    if not has_table_privilege('anon', target_relation, 'SELECT')
      or not has_table_privilege('authenticated', target_relation, 'SELECT')
      or not has_table_privilege('authenticated', target_relation, 'INSERT')
      or not has_table_privilege('authenticated', target_relation, 'UPDATE')
      or has_table_privilege('authenticated', target_relation, 'DELETE')
      or has_table_privilege('authenticated', target_relation, 'TRUNCATE')
      or has_table_privilege('authenticated', target_relation, 'REFERENCES')
      or has_table_privilege('authenticated', target_relation, 'TRIGGER')
    then
      raise exception
        'Unexpected effective table privileges on %; migration aborted',
        target_relation;
    end if;

    if has_schema_privilege('anon', 'public', 'CREATE')
      or has_schema_privilege('authenticated', 'public', 'CREATE')
    then
      raise exception
        'anon or authenticated retains CREATE on schema public; migration aborted';
    end if;
  end loop;

  if exists (
    select 1
    from pg_class sequence_class
    join pg_namespace sequence_namespace
      on sequence_namespace.oid = sequence_class.relnamespace
    where sequence_class.relkind = 'S'
      and (
        has_sequence_privilege(
          'anon',
          sequence_class.oid,
          'USAGE'
        )
        or has_sequence_privilege(
          'anon',
          sequence_class.oid,
          'SELECT'
        )
        or has_sequence_privilege(
          'anon',
          sequence_class.oid,
          'UPDATE'
        )
        or has_sequence_privilege(
          'authenticated',
          sequence_class.oid,
          'USAGE'
        )
        or has_sequence_privilege(
          'authenticated',
          sequence_class.oid,
          'SELECT'
        )
        or has_sequence_privilege(
          'authenticated',
          sequence_class.oid,
          'UPDATE'
        )
      )
      and exists (
        select 1
        from pg_depend dependency
        join pg_class target_class
          on target_class.oid = dependency.refobjid
        join pg_namespace target_namespace
          on target_namespace.oid = target_class.relnamespace
        where dependency.classid = 'pg_class'::regclass
          and dependency.objid = sequence_class.oid
          and dependency.refclassid = 'pg_class'::regclass
          and target_namespace.nspname = 'public'
          and target_class.relname in (
            'categories',
            'subcategories',
            'legal_cases',
            'case_steps'
          )
      )
      or (
        sequence_class.relkind = 'S'
        and (
          has_sequence_privilege(
            'anon',
            sequence_class.oid,
            'USAGE'
          )
          or has_sequence_privilege(
            'anon',
            sequence_class.oid,
            'SELECT'
          )
          or has_sequence_privilege(
            'anon',
            sequence_class.oid,
            'UPDATE'
          )
          or has_sequence_privilege(
            'authenticated',
            sequence_class.oid,
            'USAGE'
          )
          or has_sequence_privilege(
            'authenticated',
            sequence_class.oid,
            'SELECT'
          )
          or has_sequence_privilege(
            'authenticated',
            sequence_class.oid,
            'UPDATE'
          )
        )
        and exists (
          select 1
          from pg_attrdef column_default
          join pg_depend default_dependency
            on default_dependency.classid = 'pg_attrdef'::regclass
           and default_dependency.objid = column_default.oid
          where default_dependency.refclassid = 'pg_class'::regclass
            and default_dependency.refobjid = sequence_class.oid
            and exists (
              select 1
              from pg_class target_class
              join pg_namespace target_namespace
                on target_namespace.oid = target_class.relnamespace
              where target_class.oid = column_default.adrelid
                and target_namespace.nspname = 'public'
                and target_class.relname in (
                  'categories',
                  'subcategories',
                  'legal_cases',
                  'case_steps'
                )
            )
        )
      )
  ) then
    raise exception
      'anon or authenticated retains access to a sequence associated with a target table';
  end if;
end;
$$;

commit;
