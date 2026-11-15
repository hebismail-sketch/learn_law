# Learn Law — Security & Release Review (2026-11-15)

Scope: the Flutter app, its Drift cache, the Supabase schema/policies, the sync
engine, the Android release configuration and the Play submission package.

Nothing in this document was executed against the production database. Every
SQL change is delivered as a file for you to run, and every conclusion about
the production project is marked as *verified in code* or *must be verified in
the dashboard* — never guessed.

---

## 1. Security status by area

| Area | Result | Evidence |
|---|---|---|
| Flutter / Dart | Clean | `flutter analyze`: no issues; `flutter test`: 67/67 pass |
| Android manifest | Hardened | backup/exfil flags added, no exported components beyond the launcher, 2 normal permissions (verified in merged manifest) |
| Supabase Auth | Acceptable, one manual step | password login + `getUser()` re-check; admin claim must be granted in the dashboard (see §3) |
| PostgreSQL | Hardened (pending run) | `supabase_production_rls_migration_v2.sql`: grants, RLS, content constraints, verification |
| RLS policies | **Critical defect found and fixed** | see S-1/S-2 in §2 |
| Sync engine | **High defects fixed** | see S-3 … S-7 in §2 |
| Drift / local storage | Acceptable, documented | session not in Keystore — see C2 in the checklist; DB holds public content only |
| API surface | Hardened | publishable key only in the client; no service-role key anywhere (verified by grep) |
| Authentication flows | Hardened | server-side admin check, re-auth before the editor, no raw error text |
| Admin account | untouched | no migration writes to `auth.users`, no role grant, no password change |
| Secrets | No leak found in the working tree | no keystore/key.properties/*.env tracked; full history scan is listed as a manual step (needs your approval) |
| AdMob | Policy-compliant for closed testing | sample IDs only; real IDs required before production |

---

## 2. Findings

Severity: **Critical** = authorization bypass in production, **High** = data
loss / cross-account leakage / blocked release, **Medium** = hygiene or
defence-in-depth, **Low** = hardening.

### S-1 — An authenticated non-admin could hold INSERT/UPDATE and be denied only by the policy (Critical, fixed)

**File:** `supabase_production_rls_migration.sql` (replaced by `_v2`)
**Attack:** the migration granted `insert, update` on all four content tables to
`authenticated` and relied on `with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')`.
Any signed-in user held the table privilege; the only barrier was one policy
expression. A single mistake in that expression (or in a future `FOR ALL`
policy) turns the app into a public content editor. Separately, the policies did
not validate the *content* of a write at all: an admin claim could insert an
empty title, a negative step number or a 5 MB description.
**Action:** v2 keeps the minimal grant (authenticated can insert/update, nothing
else), rewrites the claim test as an explicit boolean and moves payload
validation into CHECK constraints, which no policy can bypass.
**Test:** negative checks in `supabase_admin_role_migration.sql` (C3 block);
run them with a normal authenticated account and confirm each is rejected.

### S-2 — The production policies only accepted the service-role claim (Critical, fixed)

**File:** `supabase_production_rls_migration.sql`
**Attack/impact:** `app_metadata.role = 'admin'` is what *PostgREST* puts in the
JWT for the **service role key**. A human admin signs in with email/password and
receives `role: authenticated`. In practice the policies either locked the real
admin out of every write or forced the app to ship the service-role key — which
bypasses RLS completely and would be a full database takeover.
**Action:** v2 accepts `app_metadata.role='admin'` **or** the additive claim
`app_metadata.learn_law_role='admin'`, which only the Auth server can write (see
`supabase_admin_role_migration.sql`, including the dashboard steps). The app
still needs no privileged key.
**Test:** sign in with the admin after granting the claim → create a category;
sign in with a normal account → the same insert must fail with RLS.

### S-3 — The sync queue pushed to Supabase without any admin check (Critical, fixed)

**File:** `lib/core/sync/sync_manager.dart`
**Attack:** `_pushQueue()` sent every queued row through whichever session the
client held. On a signed-out device, or with a non-admin session restored from
disk, the app attempted writes with a token that is admin — and any
future policy weakening would have made it succeed. The UI's admin check was
never consulted by the writer.
**Action:** the push path now requires a signed-in session *and*
`AdminGuard.verify()` (fresh `getUser()` from the Auth server, reading
`appMetadata` only). Reads stay anonymous through a dedicated publishable-key
client, so offline-first still works with no login.
**Test:** `test/sync_security_test.dart` — "a private local edit is never sent".

### S-4 — A failed push blocked the whole queue and could never recover (High, fixed)

**File:** `lib/core/sync/sync_manager.dart`
**Failure mode:** one rejected row (parent deleted on the dashboard, a row from
another project) returned from `_pushQueue`, so every later edit stayed behind
it forever, and the pull was skipped in the same run. Offline users could lose
work silently because the queue never drained.
**Action:** per-entry results are now distinguished: the server's *refusal*
(`PostgrestException`) marks the entry and continues with the rest; a
*transport* failure stops the batch and is retried later; the pull always runs.
The admin hub retries stuck entries once per visit, and a session that is valid
but no longer admin discards its dead queue instead of retrying forever.

### S-5 — Another account could inherit the previous account's outbox (High, fixed)

**File:** `lib/core/sync/` (`SyncQueue.actorId`, `LocalDataSource`, `AppBackendRegistry`)
**Attack:** admin A edits content offline, signs out; admin B signs in on the
same phone; the queued rows were pushed under B's session.
**Action:** every queued operation records the account that wrote it. Sign-in
stamps the queue, sign-out flushes it while the session is still valid and then
clears the stamp, and the push path refuses to send entries owned by a different
account. Schema version 2 adds the nullable column with an in-place migration.
**Test:** `sync_security_test.dart` — owner stamping, re-stamping, discard.

### S-6 — The local database accepted writes the server would reject (Medium, fixed)

**File:** `lib/core/sync/local_data_source.dart`
**Failure mode:** creating a case under a deleted subcategory, or editing a row
that had been removed by another device, wrote locally, queued an operation and
then failed on the server on every sync — a permanent ghost in the outbox.

**Action:** `_requireParent` / `_requireAffected` reject those writes before
they are queued. No table schema change (the local DB intentionally has no
foreign keys because pulls arrive out of order).

### S-7 — `upsert` on insert let a payload overwrite an existing row (Medium, fixed)

**File:** `lib/core/sync/sync_manager.dart`
**Action:** `insert` operations now use `.insert()`. An upsert keyed on `id`
would have merged a client payload into a row that predates it, hiding
duplicates from the audit trail. Unknown table names in the queue are also
rejected before any request is built.

### S-8 — Raw exception text shown to users (Medium, fixed)

**Files:** admin screens, sync error strings
**Action:** `lib/core/auth_error_text.dart` maps Auth failures to safe Arabic
messages (network, rate limit, wrong credentials, unconfirmed email); generic
failures no longer interpolate `$e`. Sync diagnostics go through
`lib/core/app_log.dart`, which is silent in release for everything except a
short category.
**Test:** manual — force a wrong password and a network error.

### S-9 — Admin area opened for any admin session, without re-authentication (Medium, fixed)

**Files:** `categories_screen.dart`, `admin_hub_screen.dart`, `admin_login_screen.dart`
**Action:** opening the editor requires the account password again (verified by
Supabase, not cached). The editor re-reads the role from the server on entry; the
"10 taps" entry point rebuilds the reader stack afterwards. Sign-out now always
returns to a freshly built home screen instead of an empty stack.

### S-10 — Backup / data-extraction configuration (Medium, fixed)

**File:** `android/app/src/main/AndroidManifest.xml`, new `res/xml/data_extraction_rules.xml`
**Note:** `allowBackup="false"` was already present. `dataExtractionRules` is
mandatory for API 31+ and was **missing**; the manifest merge would have emitted
a build warning and the app declared no device-transfer policy. Both are now
explicit, with the session directory and the cache excluded.

### S-11 — Verification block in the migration could silently pass (Low, fixed)

**File:** `supabase_production_rls_migration.sql`
**Detail:** the per-table privilege checks ran inside the loop that also checked
schema privilege, and the sequence check used a wide `OR` precedence mix. v2
verifies each condition once, checks RLS is both *enabled* and *forced*, and
re-raises with the exact object name.
**Test:** run v2 against a Supabase branch database before production.

### Accepted risks / not changed on purpose

- **R8 shrinking stays off.** Turning it on needs a full device test of Drift,
  Supabase and AdMob; doing that here without a device would risk shipping a
  broken release. The keep rules were improved in preparation.
- **No session encryption at rest.** Adding `flutter_secure_storage` changes the
  auth storage path and needs device testing (see C2 in the Play checklist).
- **No rate limiting in the app.** Sign-in throttling is Supabase Auth's job
  (enable "Rate limits" in the dashboard); the app only maps the error.
- **Content tables are public by design.** Reading them is the product.

---

## 3. What you must do before/while submitting

1. **Run, in this order, in the SQL editor of a *branch* database first:**
   1. `supabase_admin_role_migration.sql` (notice-only; it changes nothing)
   2. `supabase_production_rls_migration_v2.sql`
   3. The negative tests at the bottom of the role file.
   Then repeat on production during a quiet window. Keep the rollback block at
   the end of v2 handy.
2. **Grant the admin claim once** (Dashboard → Authentication → Users → the
   single admin → Raw App MetaData → add `"learn_law_role": "admin"`). Sign in
   again. Do not create a second admin, do not change the password or email.
3. **Scan the git history for secrets** (not run: it needs your go-ahead because
   a hit means history rewriting). Suggested:
   `git log -p --all -S 'eyJ' --pretty=format:%h | Select-String 'service_role|anon'`
   and check `git log --all -- android/key.properties`.
4. **Create the encrypted keystore backup** to two separate locations:
   `scripts\backup_upload_keystore.ps1 -OutDir <folder>`
5. **Play Console forms** per `docs/play-console-checklist.md`.
6. **Device test** per part 4 of the final report.

---

## 4. Sync design after the fix

```
read  : anonymous client (publishable key)  -> RLS: SELECT true
write : user client (admin session)         -> RLS: app_metadata admin claim
gate  : AdminGuard.verify()  (getUser, server)  + queue ownership match
```

- Pulls are watermark-based per table, follow the same order as the parents,
  and apply soft deletes (`deleted_at`) — repositories filter them, so no hard
  DELETE is ever sent.
- A local row with queued work is never overwritten by a pull.
- The queue collapses repeated edits of the same row into one entry.
- Interrupted runs are idempotent: inserts carry client-generated ids, updates
  are keyed on the id, deletes are UPDATEs.
