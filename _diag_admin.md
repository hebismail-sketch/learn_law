# Admin login — why the editor refuses `hebaesmail.dev@gmail.com`

Account in question: **hebaesmail.dev@gmail.com**, production project
`https://ptsfjeersiesgjtvcjkh.supabase.co` (the URL hard-coded in
`lib/main.dart`).

## The SQL that was run

```sql
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb
WHERE email = 'hebaesmail.dev@gmail.com';
```

This is the right statement **for the claim**, and the app accepts `role`
(`lib/core/sync/admin_guard.dart` reads `app_metadata.role` or
`app_metadata.learn_law_role`). Two things it cannot do:

1. **It cannot fix a missing password.** If the row changed but the app still
   says *«بيانات الدخول غير صحيحة»*, the account has no password at all — that
   is what the dashboard produces when "Add user" is used without typing one
   (or with "Auto Confirm User" off). Then every password typed in the app is
   refused before the role is ever looked at, so the admin claim changes
   nothing. Check `has_password` first.
2. **It cannot fix a stale token.** The claim reaches the phone inside the
   access token. A session opened before the UPDATE keeps the old claims for up
   to one hour. Sign out and sign in again.

There is also no "change your password" screen inside the app: the only auth
path it has is `signInWithPassword` (`lib/core/app_backend.dart` →
`signInAsAdmin`). So the password must be set on the Supabase side.

## Which message do you actually see?

| Message in the app | Meaning | Fix |
| --- | --- | --- |
| «بيانات الدخول غير صحيحة.» / «تعذّر إتمام العملية…» | sign-in itself failed: wrong/stale password, or the account has no password | steps 1 and 2 below |
| «هذا الحساب غير مخوّل بدور مسؤول في هذه البيئة» | sign-in worked, the token has no admin claim | steps 3 and 4 below |
| «سجّل الدخول صحيحًا، لكن حساب … لا يحمل دور المسؤول…» (home screen snackbar) | the app found no claim; it also tells you whether your role sits in *User Metadata* (wrong field) or nowhere | steps 3 and 4 |
| «دور المسؤول موجود في الحساب، لكن الجلسة الحالية أُنشئت قبله…» | claim is correct, the token is older | step 5 |
| «تسجيل الدخول غير متاح في هذه النسخة.» | a review-only build is installed, but no review project is configured for it | install the production build |

## Steps

### 1. Run the check

Run [`scripts/admin_check.sql`](scripts/admin_check.sql) in the SQL Editor.
**If it returns no row**, the account does not exist on this project (it is on
the review project, or was deleted) — that alone explains everything; create
it here first.

### 2. Set the password (only if `has_password = false`)

Use [`scripts/fix_admin_account.sql`](scripts/fix_admin_account.sql): edit the
`EVERY-CHANGE-ME` placeholder, run it. That statement also sets the claim in
step 3, so one run is enough. The equivalent dashboard path is
Authentication → Users → the account → **Reset password**.

Use at least 8 characters with letters **and** digits, and a password you have
not used for this account before. If Dashboard → Authentication → Providers →
Email shows stricter minimum length / character requirements, satisfy those
too, and keep «Leaked password protection» in mind: a password found in a leak
database is rejected at sign-in ([Password-based Auth](https://supabase.com/docs/guides/auth/passwords)).

### 3. Make sure the claim is in `raw_app_meta_data`

`raw_user_meta_data` (a.k.a. *User Metadata*) is writable by the account owner,
so the app and the RLS policies deliberately ignore a role there. Only
`raw_app_meta_data` counts. The `UPDATE` above does exactly this; verify with:

```sql
select email,
       raw_app_meta_data  ->> 'role' as app_role,
       raw_user_meta_data ->> 'role' as user_meta_role
from auth.users
where lower(email) = lower('hebaesmail.dev@gmail.com');
```

Or, without the SQL editor, from this folder (needs the **service_role** key,
never shipped in the app):

```powershell
$env:SUPABASE_URL = 'https://ptsfjeersiesgjtvcjkh.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = '<Project Settings > API > service_role key>'
.\scripts\make_admin.ps1 -Email 'hebaesmail.dev@gmail.com'
```

### 4. Are the write policies deployed?

The editor also needs rows the admin is allowed to write:

```sql
select policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
```

Production should list the `learn_law_production_admin_*` policies from
[`supabase_production_rls_migration_v2.sql`](supabase_production_rls_migration_v2.sql).
If they are missing, run that migration (only after
[`supabase_admin_role_migration.sql`](supabase_admin_role_migration.sql)).

### 5. Sign in again

Home screen → tap «دليل المحاماة» ten times → enter the e-mail and the new
password. If a session was already stored, sign out from the admin screen first
(the gate now tells you when the token is simply older than the claim).

## Other checks kept from before

* **The publishable key in `lib/main.dart`** (`sb_publishable_XkB0rrhh…`) was
  accepted by `/auth/v1/settings` (200) but rejected as
  `401 {"message":"Invalid API key"}` by `/rest/v1/` and `/auth/v1/admin/users`
  from this machine, while `/auth/v1/settings` answered 200 for the same key.
  If sign-in fails with a generic error rather than the two specific messages
  above, replace `SUPABASE_ANON_KEY`'s default with the project's publishable
  key from Dashboard → Project Settings → API keys and rebuild.
* **Network / rate limit**: «تعذّر الاتصال بالخادم…» and «محاولات كثيرة…» are
  transport messages, not role problems.
