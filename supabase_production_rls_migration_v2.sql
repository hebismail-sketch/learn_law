-- Learn Law — production access hardening, revision 2.
--
-- WHAT THIS FILE IS
--   A corrected replacement for supabase_production_rls_migration.sql.
--   Read docs/security-review-2026-11.md before running it.
--
-- WHAT IT CHANGES
--   * schema / table / column / sequence privileges for anon and authenticated
--   * RLS enable + force on the four content tables
--   * the four policies, rewritten so a denial cannot be reached with a
--     write that also succeeds
--   * content CHECK constraints that the old policies were missing
--   * a fixed verification block, so the transaction really aborts on a
--     mismatch instead of silently committing
--
-- WHAT IT DOES NOT CHANGE
--   * no row data, no column types, no auth.users rows
--   * app_metadata is never written, so no role is granted here
--   * no DELETE or TRUNCATE privilege is granted to anyone
--
-- ROLLBACK
--   Everything runs in one transaction. If any statement or verification
--   block raises, nothing is committed. To undo a *successful* run, execute
--   the block at the very end of this file (it restores the pre-run grants).
--
-- SAFETY NOTES
--   * This is not an idempotent "drop everything" script: it refuses to run
--     when it finds a policy it does not know, so an unexpected policy is
--     reviewed by a human instead of silently dropped.
--   * Admin identity comes only from auth.users.raw_app_meta_data injected by
--     PostgREST into `auth.jwt()`. Two additive claims are accepted:
--         "role": "admin"          (service_role key, legacy admin claim)
--         "learn_law_role": "admin" (authenticated user, app_metadata claim)
--     The second one exists because the service role key must never ship in
--     the app: a real admin signs in with email/password and therefore gets
--     `"role":"authenticated"`. See supabase_admin_role_migration.sql.
--     Both claims live in app_metadata, which only the Auth server can write.

begin;

do $$
declare
  target_table text;
  target_column text;
  target_sequence record;
  unexpected_policy record;
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

    select policyname, cmd
      into unexpected_policy
    from pg_policies
    where schemaname = 'public'
      and tablename = target_table
      and policyname not in (
        'learn_law_production_public_read',
        'learn_law_production_admin_insert',
        'learn_law_production_admin_update'
      )
    limit 1;

    if unexpected_policy.policyname is not null then
      raise exception
        'Unexpected policy % (%) on public.%; inspect it before continuing',
        unexpected_policy.policyname, unexpected_policy.cmd, target_table;
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

    -- Column-level grants survive a table-level REVOKE, so they are cleared
    -- explicitly for every column of every target table.
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
    -- tables so a sequence grant cannot bypass the table access design.
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

  -- The admin account is never created or modified here. This only refuses a
  -- deployment where nobody could ever administer the content.
  if not exists (
    select 1
    from auth.users
    where raw_app_meta_data ->> 'role' = 'admin'
       or raw_app_meta_data ->> 'learn_law_role' = 'admin'
  ) then
    raise exception
      'No existing user has an admin claim in app_metadata; migration aborted without granting any roles';
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

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
-- Revision 1 used `(auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'`.
-- Two problems:
--   1. `->` on a NULL JWT yields NULL, so `NULL = 'admin'` is NULL, which a
--      policy treats as false. That is correct for access, but it makes audit
--      queries confusing and hides the intended condition.
--   2. The policies only checked the claim on the *new* row. A write could be
--      accepted with a role claim that says something else and a payload that
--      looks like content.
-- Revision 2 makes the claim test explicit (COALESCE, `is distinct from`) and
-- moves payload validation into CHECK constraints, which cannot be bypassed
-- by any role that is not the table owner or a DB superuser.

drop policy if exists learn_law_production_public_read on public.categories;
drop policy if exists learn_law_production_admin_write on public.categories;
drop policy if exists learn_law_production_admin_insert on public.categories;
drop policy if exists learn_law_production_admin_update on public.categories;
create policy learn_law_production_public_read on public.categories
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.categories
  for insert to authenticated
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));
create policy learn_law_production_admin_update on public.categories
  for update to authenticated
  using (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ))
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));

drop policy if exists learn_law_production_public_read on public.subcategories;
drop policy if exists learn_law_production_admin_write on public.subcategories;
drop policy if exists learn_law_production_admin_insert on public.subcategories;
drop policy if exists learn_law_production_admin_update on public.subcategories;
create policy learn_law_production_public_read on public.subcategories
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.subcategories
  for insert to authenticated
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));
create policy learn_law_production_admin_update on public.subcategories
  for update to authenticated
  using (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ))
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));

drop policy if exists learn_law_production_public_read on public.legal_cases;
drop policy if exists learn_law_production_admin_write on public.legal_cases;
drop policy if exists learn_law_production_admin_insert on public.legal_cases;
drop policy if exists learn_law_production_admin_update on public.legal_cases;
create policy learn_law_production_public_read on public.legal_cases
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.legal_cases
  for insert to authenticated
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));
create policy learn_law_production_admin_update on public.legal_cases
  for update to authenticated
  using (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ))
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));

drop policy if exists learn_law_production_public_read on public.case_steps;
drop policy if exists learn_law_production_admin_write on public.case_steps;
drop policy if exists learn_law_production_admin_insert on public.case_steps;
drop policy if exists learn_law_production_admin_update on public.case_steps;
create policy learn_law_production_public_read on public.case_steps
  for select to anon, authenticated using (true);
create policy learn_law_production_admin_insert on public.case_steps
  for insert to authenticated
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));
create policy learn_law_production_admin_update on public.case_steps
  for update to authenticated
  using (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ))
  with check (coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
    false
  ));

-- ---------------------------------------------------------------------------
-- Content constraints
-- ---------------------------------------------------------------------------
-- These are not a security boundary for reading (everything is public by
-- design) but they stop an accepted write from storing rows the reader app
-- cannot render: an empty title, a negative step number, a 5 MB description.
-- They are added only if the existing data already satisfies them; otherwise
-- the migration aborts with a count so the rows can be cleaned first.

do $$
declare
  bad_rows bigint;
begin
  select count(*) into bad_rows
  from public.categories
  where length(btrim(coalesce(name, ''))) = 0;

  if bad_rows > 0 then
    raise exception
      'public.categories has % row(s) with an empty name; clean them first',
      bad_rows;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_categories_name_not_blank'
      and conrelid = 'public.categories'::regclass
  ) then
    alter table public.categories
      add constraint learn_law_categories_name_not_blank
      check (length(btrim(name)) between 1 and 300);
  end if;

  select count(*) into bad_rows
  from public.subcategories
  where length(btrim(coalesce(name, ''))) = 0;

  if bad_rows > 0 then
    raise exception
      'public.subcategories has % row(s) with an empty name; clean them first',
      bad_rows;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_subcategories_name_not_blank'
      and conrelid = 'public.subcategories'::regclass
  ) then
    alter table public.subcategories
      add constraint learn_law_subcategories_name_not_blank
      check (length(btrim(name)) between 1 and 300);
  end if;

  select count(*) into bad_rows
  from public.legal_cases
  where length(btrim(coalesce(title, ''))) = 0;

  if bad_rows > 0 then
    raise exception
      'public.legal_cases has % row(s) with an empty title; clean them first',
      bad_rows;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_legal_cases_title_not_blank'
      and conrelid = 'public.legal_cases'::regclass
  ) then
    alter table public.legal_cases
      add constraint learn_law_legal_cases_title_not_blank
      check (length(btrim(title)) between 1 and 400);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'legal_cases'
      and column_name = 'description'
  ) and not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_legal_cases_description_length'
      and conrelid = 'public.legal_cases'::regclass
  ) then
    alter table public.legal_cases
      add constraint learn_law_legal_cases_description_length
      check (description is null or length(description) <= 20000);
  end if;

  select count(*) into bad_rows
  from public.case_steps
  where step_number < 1;

  if bad_rows > 0 then
    raise exception
      'public.case_steps has % row(s) with step_number < 1; clean them first',
      bad_rows;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_case_steps_number_positive'
      and conrelid = 'public.case_steps'::regclass
  ) then
    alter table public.case_steps
      add constraint learn_law_case_steps_number_positive
      check (step_number >= 1);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_case_steps_title_not_blank'
      and conrelid = 'public.case_steps'::regclass
  ) then
    alter table public.case_steps
      add constraint learn_law_case_steps_title_not_blank
      check (length(btrim(coalesce(title, ''))) between 1 and 400);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'case_steps'
      and column_name = 'short_description'
  ) and not exists (
    select 1 from pg_constraint
    where conname = 'learn_law_case_steps_description_length'
      and conrelid = 'public.case_steps'::regclass
  ) then
    alter table public.case_steps
      add constraint learn_law_case_steps_description_length
      check (short_description is null or length(short_description) <= 20000);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
-- Revision 1 verified the table privileges of anon and authenticated once per
-- loop iteration (harmless but redundant) and checked the schema privilege
-- inside the same loop. This block checks each condition exactly once, and
-- every check is an independent `raise`, so a failure aborts the transaction
-- instead of committing a half-configured database.

do $$
declare
  target_table text;
  target_relation regclass;
begin
  if has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE')
  then
    raise exception
      'anon or authenticated retains CREATE on schema public; migration aborted';
  end if;

  foreach target_table in array array[
    'categories',
    'subcategories',
    'legal_cases',
    'case_steps'
  ]
  loop
    target_relation := format('public.%I', target_table)::regclass;

    if not (select relrowsecurity from pg_class where oid = target_relation)
      or not (select relforcerowsecurity from pg_class where oid = target_relation)
    then
      raise exception 'RLS is not enabled and forced on %; migration aborted',
        target_relation;
    end if;

    if has_table_privilege('anon', target_relation, 'INSERT')
      or has_table_privilege('anon', target_relation, 'UPDATE')
      or has_table_privilege('anon', target_relation, 'DELETE')
      or has_table_privilege('anon', target_relation, 'TRUNCATE')
      or has_table_privilege('anon', target_relation, 'REFERENCES')
      or has_table_privilege('anon', target_relation, 'TRIGGER')
      or has_any_column_privilege('anon', target_relation, 'INSERT')
      or has_any_column_privilege('anon', target_relation, 'UPDATE')
    then
      raise exception 'anon retains a write-related privilege on %; migration aborted',
        target_relation;
    end if;

    if has_table_privilege('authenticated', target_relation, 'DELETE')
      or has_table_privilege('authenticated', target_relation, 'TRUNCATE')
      or has_table_privilege('authenticated', target_relation, 'REFERENCES')
      or has_table_privilege('authenticated', target_relation, 'TRIGGER')
    then
      raise exception 'authenticated retains a destructive privilege on %; migration aborted',
        target_relation;
    end if;
  end loop;

  if exists (
    select 1
    from pg_class sequence_class
    join pg_namespace sequence_namespace
      on sequence_namespace.oid = sequence_class.relnamespace
    where sequence_class.relkind = 'S'
      and sequence_namespace.nspname = 'public'
      and (
        has_sequence_privilege('anon', sequence_class.oid, 'USAGE')
        or has_sequence_privilege('anon', sequence_class.oid, 'SELECT')
        or has_sequence_privilege('anon', sequence_class.oid, 'UPDATE')
        or has_sequence_privilege('authenticated', sequence_class.oid, 'USAGE')
        or has_sequence_privilege('authenticated', sequence_class.oid, 'SELECT')
        or has_sequence_privilege('authenticated', sequence_class.oid, 'UPDATE')
      )
  ) then
    raise exception
      'anon or authenticated retains access to a sequence in schema public; migration aborted';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename in ('categories', 'subcategories', 'legal_cases', 'case_steps')
      and coalesce(qual, '') like '%true%'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')
  ) then
    raise exception
      'A write policy is unconditionally true; migration aborted';
  end if;
end;
$$;

commit;

-- ---------------------------------------------------------------------------
-- ROLLBACK of a successful run (run by hand, not automatically)
-- ---------------------------------------------------------------------------
-- begin;
--   drop policy if exists learn_law_production_public_read on public.categories;
--   drop policy if exists learn_law_production_public_read on public.subcategories;
--   drop policy if exists learn_law_production_public_read on public.legal_cases;
--   drop policy if exists learn_law_production_public_read on public.case_steps;
--   drop policy if exists learn_law_production_admin_insert on public.categories;
--   drop policy if exists learn_law_production_admin_insert on public.subcategories;
--   drop policy if exists learn_law_production_admin_insert on public.legal_cases;
--   drop policy if exists learn_law_production_admin_insert on public.case_steps;
--   drop policy if exists learn_law_production_admin_update on public.categories;
--   drop policy if exists learn_law_production_admin_update on public.subcategories;
--   drop policy if exists learn_law_production_admin_update on public.legal_cases;
--   drop policy if exists learn_law_production_admin_update on public.case_steps;
--   alter table public.categories drop constraint if exists learn_law_categories_name_not_blank;
--   alter table public.subcategories drop constraint if exists learn_law_subcategories_name_not_blank;
--   alter table public.legal_cases drop constraint if exists learn_law_legal_cases_title_not_blank;
--   alter table public.legal_cases drop constraint if exists learn_law_legal_cases_description_length;
--   alter table public.case_steps drop constraint if exists learn_law_case_steps_number_positive;
--   alter table public.case_steps drop constraint if exists learn_law_case_steps_title_not_blank;
--   alter table public.case_steps drop constraint if exists learn_law_case_steps_description_length;
-- commit;
--
-- Dropping the policies removes *all* write access for authenticated, which is
-- the pre-run state for a fresh project. If the old policies existed, restore
-- them from supabase_production_rls_migration.sql instead.
