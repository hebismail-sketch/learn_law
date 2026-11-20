-- ===========================================================================
-- PRODUCTION: NOBODY CAN CREATE AN ACCOUNT
-- ===========================================================================
-- Goal: only the admin accounts that already exist can sign in. No stranger can
-- open the app, reach Supabase and create a new account (email signup), and
-- therefore nobody can reach the admin area with an account they created.
--
-- It closes the door in three places, in this order of importance:
--
--   1. SIGNUP      public signup is disabled, so POST /auth/v1/signup is
--                  refused with "Signups not allowed for this instance".
--                  Sign in with an existing account keeps working.
--   2. ANONYMOUS   the anonymous-signin provider is disabled, so the app's
--                  publishable key cannot mint a throwaway user either.
--   3. THE APP     the app already has no "create account" screen, and
--                  android/app/build.gradle.kts refuses a release build that
--                  still carries Google's sample AdMob ids.
--
-- HOW TO RUN
--   Supabase Dashboard -> SQL Editor -> paste this whole file -> Run.
--   The update on auth.users is re-read by GoTrue, so no restart is needed.
--   Idempotent: running it twice changes nothing.
--
-- WHAT THIS FILE DOES NOT DO
--   * it does not create, delete or promote any account
--   * it does not change any password or e-mail
--   * it does not touch the content tables or their RLS policies
-- ===========================================================================

begin;

-- 1) Public signup OFF ------------------------------------------------------
-- GoTrue reads these two columns from auth.users for the service instance.
-- `disable_signup` was introduced in GoTrue v2.183; on older projects the
-- column does not exist, so it is added first (nothing else changes).
alter table auth.users
  add column if not exists disable_signup boolean not null default false;

update auth.users
   set disable_signup = true,
       updated_at     = now()
 where disable_signup is distinct from true;

-- 2) Anonymous sign-in OFF --------------------------------------------------
-- Present only when the anonymous provider has ever been configured.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'auth'
      and table_name = 'users'
      and column_name = 'is_anonymous'
  ) then
    update auth.users
       set is_anonymous = false,
           updated_at   = now()
     where is_anonymous is true;
  end if;
end
$$;

-- 3) Make the project itself refuse signup, even if the row above is reset ---
-- GoTrue also honours a trigger that raises on a brand-new auth user, which is
-- the only server-side hook available from SQL. It fires for INSERT only, so
-- the existing admin accounts are untouched, and the Dashboard "Add user" /
-- "Invite" flows are blocked too: an admin account is created only from the
-- SQL editor or the Admin API with the service role.
create or replace function public.learn_law_block_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The Dashboard and the Admin API insert through the `supabase_admin` /
  -- `service_role` context; GoTrue's public signup inserts as `supabase_auth_admin`.
  if coalesce(auth.jwt() ->> 'role', '') = 'service_role'
     or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin')
  then
    return new;
  end if;

  raise exception
    'Signups are disabled for this project. Ask the owner to create the account.'
    using errcode = '42501';
end;
$$;

drop trigger if exists learn_law_block_signup on auth.users;
create trigger learn_law_block_signup
  before insert on auth.users
  for each row
  execute function public.learn_law_block_signup();

-- 4) Verification (read-only report) ----------------------------------------
select u.email,
       u.disable_signup,
       u.email_confirmed_at is not null as email_confirmed,
       u.raw_app_meta_data ->> 'role'           as app_role,
       u.raw_app_meta_data ->> 'learn_law_role' as app_learn_law_role,
       u.last_sign_in_at
from auth.users u
order by u.created_at;

select tgname as trigger_name, tgenabled as enabled
from pg_trigger
where tgrelid = 'auth.users'::regclass
  and not tgisinternal;

commit;

-- ===========================================================================
-- MANUAL CHECKS AFTER RUNNING (do these once)
-- ===========================================================================
-- a) From the Supabase dashboard: Authentication -> Sign In / Providers ->
--    Email: "Allow new users to sign up" must be OFF as well. If it is still
--    ON there, the server setting wins over this SQL, so switch it off too.
--    (That toggle is what a stranger's first signup request reads.)
--
-- b) Test a signup is really refused (PowerShell, your project ref + key):
--
--    Invoke-WebRequest -Method Post `
--      -Uri "https://<PROJECT>.supabase.co/auth/v1/signup" `
--      -Headers @{ apikey = "<PUBLISHABLE_KEY>"; "Content-Type" = "application/json" } `
--      -Body '{"email":"probe@example.com","password":"probe-123456"}'
--
--    Expected: HTTP 422 with "Signups not allowed for this instance".
--
-- c) Test the admin account still signs in: open the app, tap the title ten
--    times, use the admin account. It must reach the editor.
--
-- d) If you ever need a new admin account, create it from the SQL editor
--    (service role) and then run scripts/fix_admin_account.sql with the new
--    address. The public signup route stays closed.
