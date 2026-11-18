-- ===========================================================================
-- PRODUCTION CONTENT VISIBILITY FIX
-- ===========================================================================
-- WHY THIS FILE EXISTS
--
-- The app reads content with the publishable (anon) key and writes only with an
-- authenticated admin session. A live probe of the production project on
-- 2026-11-17 showed the public key is allowed to WRITE:
--
--     anon insert into categories -> 201 Created
--
-- That is both a security hole and a source of junk content in the library
-- every reader downloads. The app has since been changed so it never downloads
-- a row whose deleted_at is set, so anything deleted stays off the phones.
--
-- WHAT THIS FILE DOES
--
--   1. Recreates the four read policies as SELECT-only, and revokes every write
--      privilege on the four content tables from anon. Afterwards the public
--      key can read and nothing else; writes need an admin session, which is
--      what the sync engine already assumes.
--   2. Reports (and, where it is certainly junk, removes) content that was
--      written by the public key. Nothing is ever un-deleted: a row with
--      deleted_at set is left exactly as it is.
--   3. Rolls back instead of committing a half-applied fix.
--
-- SAFE TO RUN MORE THAN ONCE.
--
-- HOW TO RUN
--
--   Supabase dashboard -> SQL Editor -> paste this file -> Run.
--   Then paste it again and run it a second time: section 5's checks only pass
--   when the fix is really in place.
--
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Read policies: explicit FOR SELECT, for readers only.
-- ---------------------------------------------------------------------------
do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'categories', 'subcategories', 'legal_cases', 'case_steps'
  ]::text[]
  loop
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

-- ---------------------------------------------------------------------------
-- 2. Table privileges: the public key may read content, never change it.
-- ---------------------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger
  on public.categories, public.subcategories,
     public.legal_cases, public.case_steps
  from anon;

grant select
  on public.categories, public.subcategories,
     public.legal_cases, public.case_steps
  to anon;

-- ---------------------------------------------------------------------------
-- 3. Junk written by the public key.
--
--    A category created by anon has no children and no description; every real
--    category has both. Only those are removed, and only if nothing points at
--    them, so a legitimate category can never be caught by this.
--    Soft-deleted rows are deliberately NOT touched.
-- ---------------------------------------------------------------------------
do $$
declare
  removed integer;
begin
  with junk as (
    select c.id
    from public.categories c
    where coalesce(btrim(c.description), '') = ''
      and not exists (
        select 1 from public.subcategories s where s.category_id = c.id
      )
  )
  delete from public.categories c
  using junk
  where c.id = junk.id;

  get diagnostics removed = row_count;
  raise notice 'Removed % empty category row(s) with no subcategories.', removed;
end
$$;

-- ---------------------------------------------------------------------------
-- 4. Verification inside the transaction: refuse to commit a half fix.
-- ---------------------------------------------------------------------------
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
    then
      raise exception
        'anon still holds a write privilege on public.%s; rolled back',
        target_table;
    end if;

    if not has_table_privilege('anon', target_table, 'SELECT') then
      raise exception
        'anon lost SELECT on public.%s; rolled back', target_table;
    end if;
  end loop;
end
$$;

commit;

-- ---------------------------------------------------------------------------
-- 5. Post-run checks (read-only).
-- ---------------------------------------------------------------------------

-- Policies: one SELECT policy per table, nothing that grants writes.
select schemaname, tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('categories', 'subcategories', 'legal_cases', 'case_steps')
order by tablename, policyname;

-- Content as the app will read it: live rows only.
select 'categories'    as table_name, count(*) filter (where deleted_at is null) as live_rows,
       count(*) filter (where deleted_at is not null) as deleted_rows from public.categories
union all
select 'subcategories', count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null) from public.subcategories
union all
select 'legal_cases',   count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null) from public.legal_cases
union all
select 'case_steps',    count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null) from public.case_steps;

-- Cases whose every step is soft-deleted: these open with an empty roadmap.
-- This is a content decision for the team (write the steps again); this fix
-- does not invent content.
select c.id, c.title, count(s.id) as live_steps
from public.legal_cases c
left join public.case_steps s
  on s.case_id = c.id and s.deleted_at is null
where c.deleted_at is null
group by c.id, c.title
having count(s.id) = 0
order by c.title;

-- The probe that proves the hole is closed: run it on its own, outside a
-- transaction, after this file. It must fail.
--
--    insert into public.categories (name) values ('probe');
--    -- expect: ERROR 42501  permission denied for table categories
