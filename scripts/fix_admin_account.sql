-- Learn Law - make hebaesmail.dev@gmail.com a working admin account.
--
-- Run this in the Supabase SQL Editor of the project the app talks to
-- (production: https://ptsfjeersiesgjtvcjkh.supabase.co). Run
-- scripts/admin_check.sql FIRST and read its output:
--
--   * no row at all            -> the account lives on another project; create
--                                 it here (Authentication > Users > Add user,
--                                 with a password) and run this file after.
--   * has_password = false     -> part 1 below sets one.
--   * app_will_accept_admin=f  -> part 2 below writes the claim.
--
-- This file does nothing else: it does not touch other accounts, does not
-- change e-mail addresses, and never creates a user.
--
-- IMPORTANT, before running part 1:
--   Replace EVERY-CHANGE-ME below with a real password (at least 8 chars,
--   letters + digits) and keep it somewhere safe. Do not reuse the one that
--   produced "بيانات الدخول غير صحيحة".
--
-- Part 1 is the same operation as Dashboard > Authentication > Users > the
-- account > "Reset password" / "Set password", done in one statement so it also
-- works when the dashboard form leaves the account without a password.

begin;

-- 1) Password --------------------------------------------------------------
-- GoTrue requires a bcrypt hash in encrypted_password; crypt()/gen_salt() come
-- from pgcrypto, which Supabase projects already have enabled.
update auth.users
   set encrypted_password = crypt('EVERY-CHANGE-ME', gen_salt('bf')),
       email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at         = now()
 where lower(email) = lower('hebaesmail.dev@gmail.com');

-- 2) Admin claim -----------------------------------------------------------
-- Both spellings are written: this project's build trusts `role`, and the
-- review/production migrations document `learn_law_role`. The existing keys
-- (provider, providers, ...) are kept as they are.
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                           || jsonb_build_object('role', 'admin',
                                                 'learn_law_role', 'admin'),
       updated_at        = now()
 where lower(email) = lower('hebaesmail.dev@gmail.com');

-- 3) Verify (same shape as scripts/admin_check.sql) -------------------------
select u.email,
       u.encrypted_password is not null
         and u.encrypted_password <> '' as has_password,
       u.email_confirmed_at is not null as email_confirmed,
       u.raw_app_meta_data ->> 'role'            as app_role,
       u.raw_app_meta_data ->> 'learn_law_role'  as app_learn_law_role,
       u.raw_user_meta_data ->> 'role'           as user_meta_role
from auth.users u
where lower(u.email) = lower('hebaesmail.dev@gmail.com');

commit;

-- Expected afterwards: has_password = t, email_confirmed = t,
-- app_role = admin (or app_learn_law_role = admin).
--
-- Then in the app: sign out (if any session is open) and sign in again through
-- the admin screen, so the brand-new JWT carries the claim. A token issued
-- before this update keeps the old claims until it is refreshed (~1 hour).
