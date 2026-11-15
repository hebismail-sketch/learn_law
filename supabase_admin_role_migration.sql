-- Learn Law — admin role claim alignment. RUN THIS BEFORE
-- supabase_production_rls_migration_v2.sql.
--
-- WHY THIS EXISTS
--   The production hardening policies grant writes to a JWT whose
--   app_metadata carries `role = 'admin'`.
--
--   That claim is only produced by the *service role* key: PostgREST injects
--   `"role": "service_role"` for it. A human administrator signs in with
--   email + password, and Supabase Auth then issues a JWT with
--   `"role": "authenticated"` and the account's own app_metadata copied into
--   `app_metadata`. So, for a signed-in person, `app_metadata.role` can hold
--   'admin' only if somebody wrote that claim into the account — which the
--   Auth server allows, and which the policies accept.
--
--   The service role key can never be used for this: it bypasses RLS
--   entirely, so it must not exist inside the app. `/rest/v1/rpc` with the
--   service key would be an unauthenticated admin backdoor.
--
--   Therefore this file introduces a dedicated, additive claim that only the
--   Auth server can write:
--       app_metadata.learn_law_role = 'admin'
--   Migration v2 accepts either claim. Nothing is granted here: this file
--   only *documents* and *verifies*, because granting an admin role is a
--   decision for the project owner, not for a migration.
--
-- WHAT THIS FILE DOES NOT DO
--   * it does not create a user
--   * it does not change any password or email
--   * it does not promote any account
--   * it does not touch app_metadata at all
--
-- HOW TO GRANT THE CLAIM (owner action, from the Supabase dashboard or a
-- server-side script holding the service role key — never from the app):
--
--   1. Supabase Dashboard → Authentication → Users → (the single admin
--      account) → "Edit" → Raw App MetaData → add
--          { "learn_law_role": "admin" }
--      Keep the existing keys (provider, providers) untouched.
--
--   2. The user must sign out and back in (or wait for the access token to be
--      refreshed, at most one hour) so the new claim reaches the JWT. Until
--      then the app's admin screens stay closed and every push is refused
--      client-side and server-side.
--
-- HOW TO REVOKE IT: remove the key in the same screen. No migration is
-- needed; the RLS policies read the JWT, so the revocation applies at the
-- next token refresh.

begin;

do $$
declare
  admin_accounts integer;
begin
  select count(*)
    into admin_accounts
  from auth.users
  where raw_app_meta_data ->> 'role' = 'admin'
     or raw_app_meta_data ->> 'learn_law_role' = 'admin';

  if admin_accounts = 0 then
    raise notice
      'No account currently carries an admin claim. The editor will be unusable until one is granted manually (see the header of this file). Nothing was changed.';
  elsif admin_accounts > 1 then
    raise notice
      'WARNING: % accounts carry an admin claim. The intended design is exactly one. Review them in Authentication → Users; this migration will not change any of them.', admin_accounts;
  else
    raise notice
      'Exactly one admin account found. No change made (this file never edits auth.users).';
  end if;
end;
$$;

commit;

-- Post-deployment checks (read-only, safe to run in the SQL editor):

-- 1. The claim as the server sees it, for the account in question:
--    select id, email,
--           raw_app_meta_data ->> 'role'            as legacy_role,
--           raw_app_meta_data ->> 'learn_law_role'  as learn_law_role
--    from auth.users
--    where raw_app_meta_data ->> 'role' = 'admin'
--       or raw_app_meta_data ->> 'learn_law_role' = 'admin';

-- 2. What the policies will evaluate for a signed-in admin. Run while signed
--    in with the admin account (the SQL editor uses the service role, so use
--    the app's RPC path or the API instead):
--    select
--      coalesce(
--        (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
--        or (auth.jwt() -> 'app_metadata' ->> 'learn_law_role') = 'admin',
--        false
--      ) as is_admin;

-- 3. Negative checks, run from a normal authenticated context (never with the
--    service key). Each must fail with an RLS or privilege error:
--      insert into public.categories (id, name, updated_at)
--        values (gen_random_uuid(), 'probe', now());
--      delete from public.legal_cases where false;   -- must be denied: no DELETE grant
--      select * from public.categories for update;    -- must not lock rows for anon
