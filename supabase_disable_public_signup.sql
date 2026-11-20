-- ===========================================================================
-- PRODUCTION: NOBODY CAN CREATE AN ACCOUNT
-- ===========================================================================
-- Goal: only the admin accounts that already exist can sign in. A stranger who
-- installs the app cannot create an account, so nobody can reach the admin area
-- with an account they made themselves.
--
-- HOW TO RUN (important)
--   Supabase Dashboard -> SQL Editor -> New query.
--   Paste the file, then run each block that ends with ";" on its own, in
--   order (select a block, or place the cursor in it and press Run). The editor
--   executes one statement per run and refuses multi-statement scripts.
--
-- Every block is idempotent: running it twice changes nothing.
--
-- WHAT THIS FILE DOES NOT DO
--   * it does not create, delete or promote any account
--   * it does not change any password or e-mail
--   * it does not touch the content tables or their RLS policies
--
-- NOTE ON `disable_signup`
--   There is no such column in auth.users. The flag lives in the Auth server
--   configuration, which is exactly the dashboard toggle in step 3 below.
-- ===========================================================================


-- ===========================================================================
-- STEP 1 - the database refuses any new auth user
-- ===========================================================================
-- A brand-new row in auth.users means a brand-new account. This trigger raises
-- for every insert except the trusted contexts: the SQL editor, the service
-- role and the Admin API. It fires on INSERT only, so the existing admin
-- accounts are never touched. It also blocks Dashboard "Add user" and "Invite",
-- so a new admin account can only be created by an operation that runs as the
-- service role.
create or replace function public.learn_law_block_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role')
     or coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
     or coalesce((nullif(current_setting('request.jwt.claims', true), '')::jsonb) ->> 'role', '') = 'service_role'
  then
    return new;
  end if;

  raise exception
    'Signups are disabled for this project.'
    using errcode = '42501';
end;
$fn$;


-- ===========================================================================
-- STEP 2 - attach the trigger (and remove an older copy of it)
-- ===========================================================================
drop trigger if exists learn_law_block_signup on auth.users;


create trigger learn_law_block_signup
  before insert on auth.users
  for each row
  execute function public.learn_law_block_signup();


-- ===========================================================================
-- STEP 3 - verify (read-only, safe to run any time)
-- ===========================================================================
-- 3a) The accounts that exist, and the role each one carries.
select u.email,
       u.email_confirmed_at is not null       as email_confirmed,
       u.raw_app_meta_data ->> 'role'          as app_role,
       u.raw_app_meta_data ->> 'learn_law_role' as app_learn_law_role,
       u.last_sign_in_at
from auth.users u
order by u.created_at;


-- 3b) The trigger must be listed here (tgenabled = 'O' means enabled).
select t.tgname                     as trigger_name,
       t.tgenabled                  as enabled,
       p.proname                    as function_name
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'auth.users'::regclass
  and not t.tgisinternal;


-- 3c) Prove the trigger bites: this insert must FAIL with
--     "Signups are disabled for this project." (it is rolled back either way).
do $test$
begin
  begin
    insert into auth.users (id, instance_id, aud, role)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
            'authenticated', 'authenticated');
    raise exception 'CHECK FAILED: the guard did not block the insert';
  exception
    when insufficient_privilege then
      raise notice 'OK: new auth users are blocked.';
  end;
end
$test$;


-- ===========================================================================
-- STEP 4 - the dashboard toggle (manual, one minute)
-- ===========================================================================
-- 1. Authentication -> Sign In / Providers -> Email
-- 2. Turn OFF "Allow new users to sign up" -> Save
--    (The Auth server, not the database, answers the signup request first, so
--     this toggle is what stops it before it ever reaches step 1.)
-- 3. Authentication -> Providers -> Anonymous sign-ins: keep it OFF.
--
-- Test it from PowerShell (Settings -> API gives the project URL and the
-- publishable key):
--
--   Invoke-WebRequest -Method Post -Uri "https://<PROJECT>.supabase.co/auth/v1/signup" -Headers @{ apikey = "<PUBLISHABLE_KEY>"; "Content-Type" = "application/json" } -Body '{"email":"probe@example.com","password":"probe-123456"}'
--
-- Expected: HTTP 422 with "Signups not allowed for this instance".
--
-- Then open the app, tap the title ten times and sign in with an existing
-- admin account: it must still reach the editor.
--
-- If you ever need a new admin account, create it from the SQL editor (service
-- role, so the trigger allows it) and then run scripts/fix_admin_account.sql
-- with the new address. Public signup stays closed.
