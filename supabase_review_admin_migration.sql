-- Run only in the dedicated review Supabase project after
-- supabase_review_schema.sql and supabase_sync_migration.sql.
-- This does not alter or delete table data.

do $$
declare
  target_table text;
begin
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
    ) then
      raise exception 'Missing public.% table; run the review schema setup first',
        target_table;
    end if;

    if exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = target_table
        and policyname not in (
          'learn_law_review_public_read',
          'learn_law_review_admin_write'
        )
    ) then
      raise exception
        'Unexpected RLS policies exist on public.%; inspect them before continuing',
        target_table;
    end if;
  end loop;
end;
$$;

grant usage on schema public to anon, authenticated;

revoke insert, update, delete
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  from public, anon;

grant select
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  to anon, authenticated;

grant insert, update, delete
  on table public.categories, public.subcategories,
            public.legal_cases, public.case_steps
  to authenticated;

alter table public.categories enable row level security;
alter table public.subcategories enable row level security;
alter table public.legal_cases enable row level security;
alter table public.case_steps enable row level security;

drop policy if exists learn_law_review_public_read on public.categories;
drop policy if exists learn_law_review_admin_write on public.categories;
create policy learn_law_review_public_read on public.categories
  for select to anon, authenticated using (true);
create policy learn_law_review_admin_write on public.categories
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_review_public_read on public.subcategories;
drop policy if exists learn_law_review_admin_write on public.subcategories;
create policy learn_law_review_public_read on public.subcategories
  for select to anon, authenticated using (true);
create policy learn_law_review_admin_write on public.subcategories
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_review_public_read on public.legal_cases;
drop policy if exists learn_law_review_admin_write on public.legal_cases;
create policy learn_law_review_public_read on public.legal_cases
  for select to anon, authenticated using (true);
create policy learn_law_review_admin_write on public.legal_cases
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists learn_law_review_public_read on public.case_steps;
drop policy if exists learn_law_review_admin_write on public.case_steps;
create policy learn_law_review_public_read on public.case_steps
  for select to anon, authenticated using (true);
create policy learn_law_review_admin_write on public.case_steps
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
