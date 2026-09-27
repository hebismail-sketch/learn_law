-- =============================================================================
-- Offline-first sync: server-side schema changes for Supabase
-- =============================================================================
-- Run this once in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query).
-- It is idempotent, so running it twice is safe.
--
-- Why this is needed:
--   The app tracks changes with `updated_at` (what changed since the last
--   pull) and `deleted_at` (soft delete, so other devices learn a row is gone
--   instead of it simply disappearing for them). Those columns do not exist
--   yet, so every push and pull would fail.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. The tracking columns
-- -----------------------------------------------------------------------------
-- `updated_at` is maintained by the trigger in section 2, so the app never has
-- to remember to set it. `deleted_at` stays NULL until a delete is synced.
-- Backfilling from `created_at` where available keeps the first pull correct for
-- rows that already exist.

alter table public.categories
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at  timestamptz;

alter table public.subcategories
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at  timestamptz;

alter table public.legal_cases
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at  timestamptz;

alter table public.case_steps
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at  timestamptz;

-- Give the new columns a value for every existing row. `now()` is used rather
-- than created_at because these tables have no created_at column, which was
-- confirmed against information_schema before writing this migration.
update public.categories    set updated_at = now() where updated_at is null;
update public.subcategories set updated_at = now() where updated_at is null;
update public.legal_cases   set updated_at = now() where updated_at is null;
update public.case_steps    set updated_at = now() where updated_at is null;

-- Backfilling first, then marking not null, is the order the migration was
-- actually applied in.
alter table public.categories    alter column updated_at set not null;
alter table public.subcategories alter column updated_at set not null;
alter table public.legal_cases   alter column updated_at set not null;
alter table public.case_steps    alter column updated_at set not null;

-- A default keeps direct SQL inserts (from the dashboard or another service)
-- working without having to remember the column.
alter table public.categories    alter column updated_at set default now();
alter table public.subcategories alter column updated_at set default now();
alter table public.legal_cases   alter column updated_at set default now();
alter table public.case_steps    alter column updated_at set default now();


-- -----------------------------------------------------------------------------
-- 2. Keep `updated_at` correct automatically
-- -----------------------------------------------------------------------------
-- Last write wins by timestamp, and the timestamp must be trustworthy on every
-- path into the table. A trigger is the only way to guarantee that: it fires
-- for the app, for the dashboard and for any other client.

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_categories_updated_at   on public.categories;
drop trigger if exists trg_subcategories_updated_at on public.subcategories;
drop trigger if exists trg_legal_cases_updated_at  on public.legal_cases;
drop trigger if exists trg_case_steps_updated_at    on public.case_steps;

create trigger trg_categories_updated_at
  before update on public.categories
  for each row execute function public.touch_updated_at();

create trigger trg_subcategories_updated_at
  before update on public.subcategories
  for each row execute function public.touch_updated_at();

create trigger trg_legal_cases_updated_at
  before update on public.legal_cases
  for each row execute function public.touch_updated_at();

create trigger trg_case_steps_updated_at
  before update on public.case_steps
  for each row execute function public.touch_updated_at();


-- -----------------------------------------------------------------------------
-- 3. Index `updated_at`
-- -----------------------------------------------------------------------------
-- Every pull runs `where updated_at > <watermark>` on every table. Without an
-- index that is a sequential scan of the whole table on each sync, which gets
-- slow as the data grows.

create index if not exists idx_categories_updated_at
  on public.categories (updated_at);
create index if not exists idx_subcategories_updated_at
  on public.subcategories (updated_at);
create index if not exists idx_legal_cases_updated_at
  on public.legal_cases (updated_at);
create index if not exists idx_case_steps_updated_at
  on public.case_steps (updated_at);


-- =============================================================================
-- NOT included on purpose: a `deleted_at is null` read policy
-- =============================================================================
-- It looks like the right guard, but it breaks the sync in two ways:
--
--   1. The pull runs `where updated_at > <watermark>` to discover that a row
--      was deleted on another device. If the policy hides deleted rows, that
--      row never comes back, so the deleting device is the only one that
--      knows it is gone and the others keep showing it forever.
--   2. Enabling RLS also requires write policies. Turning it on without
--      matching insert/update policies for the admin client would silently
--      break every write in the app.
--
-- Filtering on the client is where `deleted_at is null` belongs: the reads in
-- LegalRepositoryImpl already do it, and the pull deliberately does not.
-- If you later want the server to hide deleted rows from the anon role, add a
-- policy for that role only and keep a separate policy that lets the sync role
-- see everything.
-- =============================================================================

