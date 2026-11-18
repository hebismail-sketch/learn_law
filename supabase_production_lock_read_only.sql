-- ===========================================================================
-- PRODUCTION: MAKE THE PUBLIC KEY READ-ONLY
-- ===========================================================================
-- Verified problem (scripts/probe_anon_writes.mjs, 2026-11-17):
--
--   categories     read=200 insert=201 update=200 delete=200 upsert=200
--   subcategories  read=200 insert=201 update=200 delete=200 upsert=200
--   legal_cases    read=200 insert=201 update=200 delete=200 upsert=200
--   case_steps     read=200 insert=201 update=200 delete=200 upsert=400
--
-- The publishable key every app install ships with could write content. That
-- is how junk categories ("test", "New Vategory", a blank name) got into the
-- library the app downloads, and why a fresh install could refuse to fill.
--
-- After this file the same probe must report 401/403 for every write verb and
-- 200 for read. Applies to anon AND authenticated, so content can only change
-- through the service role or the SQL editor: public signup is disabled on this
-- project and readers have no account at all.
--
-- Idempotent. Aborts and rolls back if anything is still writable.
-- ===========================================================================

begin;

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'categories', 'subcategories', 'legal_cases', 'case_steps'
  ]::text[]
  loop
    -- Table-level grants: reads only.
    execute format(
      'revoke all on public.%I from anon, authenticated', target_table
    );
    execute format(
      'grant select on public.%I to anon, authenticated', target_table
    );

    -- Row-level policies: exactly one SELECT policy, nothing permissive for
    -- writes. A leftover `for all` policy would otherwise re-open the hole even
    -- with the grant revoked, because RLS is checked after privileges.
    execute format(
      'drop policy if exists learn_law_production_public_read on public.%I',
      target_table
    );
    execute format(
      'create policy learn_law_production_public_read on public.%I '
      'for select to anon, authenticated using (true)',
      target_table
    );
  end loop;
end
$$;

-- Report any other permissive policy on these tables. It is reported, not
-- treated as fatal: a policy named differently from ours may legitimately be
-- an admin-write policy, and rolling the fix back would leave the hole open.
-- Read the list below and drop anything that is not deliberate.
do $$
declare
  leftover record;
begin
  for leftover in
    select policyname, tablename, cmd
    from pg_policies
    where schemaname = 'public'
      and tablename in ('categories', 'subcategories', 'legal_cases', 'case_steps')
      and cmd <> 'SELECT'
  loop
    raise warning
      'policy % on % allows % - confirm this is intentional',
      leftover.policyname, leftover.tablename, leftover.cmd;
  end loop;
end
$$;

-- Verification inside the transaction: refuse to commit a half fix.
do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'categories', 'subcategories', 'legal_cases', 'case_steps'
  ]::text[]
  loop
    if has_table_privilege('anon', target_table, 'INSERT')
      or has_table_privilege('anon', target_table, 'UPDATE')
      or has_table_privilege('anon', target_table, 'DELETE')
      or has_table_privilege('anon', target_table, 'TRUNCATE')
    then
      raise exception 'anon still holds a write privilege on public.%s', target_table;
    end if;

    if not has_table_privilege('anon', target_table, 'SELECT') then
      raise exception 'anon lost SELECT on public.%s', target_table;
    end if;
  end loop;
end
$$;

commit;

-- State after the fix (read-only report).
select schemaname, tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('categories', 'subcategories', 'legal_cases', 'case_steps')
order by tablename, policyname;

select c.relname                                                  as table_name,
       has_table_privilege('anon', c.oid, 'SELECT')               as anon_read,
       has_table_privilege('anon', c.oid, 'INSERT')               as anon_write
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('categories', 'subcategories', 'legal_cases', 'case_steps')
order by c.relname;
