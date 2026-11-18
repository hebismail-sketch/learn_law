// Brings the whole library back to how it was 13 days ago (2026-11-04).
//
//   node scripts/restore_library.mjs            report only, changes nothing
//   node scripts/restore_library.mjs --apply    do it
//
// "Library" here means every case that exists on the server, with every step
// that still exists for it. Nothing is created and nothing is erased: rows that
// are marked deleted get their marker cleared, which is the same edit the team
// makes from the admin screen when it un-deletes something.
//
// Reads use the publishable key. Writes need an admin session: after
// supabase_production_content_visibility_fix.sql only an admin can write.
//   ADMIN_EMAIL=... ADMIN_PASSWORD=... node scripts/restore_library.mjs --apply
// (without them, the script writes with the publishable key, which only works
//  while that key still has write access).

const url =
  process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const publishableKey =
  process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const adminEmail = process.env.ADMIN_EMAIL;
const adminPassword = process.env.ADMIN_PASSWORD;
const apply = process.argv.includes('--apply');
const today = new Date();

const authHeaders = { apikey: publishableKey, Authorization: `Bearer ${publishableKey}` };

// A write always has to announce its body type; without it PostgREST answers
// 400 "Content-Type not acceptable" instead of the permission check.
let writeHeaders = {
  ...authHeaders,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

async function signInIfConfigured() {
  if (!adminEmail || !adminPassword) return;
  const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { ...authHeaders, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: adminEmail, password: adminPassword }),
  });
  if (!res.ok) throw new Error(`admin sign-in failed: ${res.status} ${await res.text()}`);
  const { access_token: token } = await res.json();
  writeHeaders = {
    apikey: publishableKey,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
  };
}

async function selectAll(table, query) {
  const rows = [];
  const pageSize = 1000;
  for (let offset = 0; ; offset += pageSize) {
    const res = await fetch(
      `${url}/rest/v1/${table}?${query}&order=id&offset=${offset}&limit=${pageSize}`,
      { headers: authHeaders },
    );
    if (!res.ok) throw new Error(`${table} read failed: ${res.status} ${await res.text()}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

/** Clears deleted_at on [ids]; returns the rows the database really changed. */
async function restore(table, ids) {
  if (ids.length === 0) return 0;
  let changed = 0;
  for (let i = 0; i < ids.length; i += 150) {
    const batch = ids.slice(i, i + 150);
    const res = await fetch(`${url}/rest/v1/${table}?id=in.(${batch.join(',')})`, {
      method: 'PATCH',
      headers: writeHeaders,
      body: JSON.stringify({ deleted_at: null }),
    });
    if (!res.ok) {
      throw new Error(`${table} restore refused: ${res.status} ${await res.text()}`);
    }
    changed += (await res.json()).length;
  }
  return changed;
}

const categories = await selectAll('categories', 'select=id,deleted_at');
const subcategories = await selectAll('subcategories', 'select=id,category_id,deleted_at');
const legalCases = await selectAll('legal_cases', 'select=id,subcategory_id,deleted_at');
const caseSteps = await selectAll('case_steps', 'select=id,case_id,deleted_at');

const snapshot = (rows) => ({
  all: rows.length,
  deleted: rows.filter((r) => r.deleted_at).length,
});

console.log('Server now:');
for (const [name, rows] of Object.entries({ categories, subcategories, legal_cases: legalCases, case_steps: caseSteps })) {
  const { all, deleted } = snapshot(rows);
  console.log(`  ${name.padEnd(14)} ${String(all).padStart(6)} row(s), ${String(deleted).padStart(6)} marked deleted`);
}

// Parents come back before children, so a restored case always has its folder.
const categoryIds = new Set(categories.map((r) => r.id));
const subcategoryIds = new Set(
  subcategories.filter((r) => categoryIds.has(r.category_id)).map((r) => r.id),
);
const caseIds = new Set(
  legalCases.filter((r) => subcategoryIds.has(r.subcategory_id)).map((r) => r.id),
);

const plan = {
  categories: categories.filter((r) => r.deleted_at && categoryIds.has(r.id)).map((r) => r.id),
  subcategories: subcategories
    .filter((r) => r.deleted_at && subcategoryIds.has(r.id))
    .map((r) => r.id),
  legal_cases: legalCases
    .filter((r) => r.deleted_at && caseIds.has(r.id))
    .map((r) => r.id),
  case_steps: caseSteps.filter((r) => r.deleted_at && caseIds.has(r.case_id)).map((r) => r.id),
};

const emptyRoadmaps = legalCases.filter(
  (c) =>
    !c.deleted_at &&
    !caseSteps.some((s) => s.case_id === c.id && !s.deleted_at),
);

console.log('\nWill be restored (nothing is created or removed):');
for (const [table, ids] of Object.entries(plan)) {
  console.log(`  ${table.padEnd(14)} ${String(ids.length).padStart(6)} row(s)`);
}
console.log(
  `\nRetired content (kept as is, stays off every phone): ` +
  `${snapshot(legalCases).deleted - plan.legal_cases.length} case(s), ` +
  `${snapshot(caseSteps).deleted - plan.case_steps.length} step(s).`,
);
if (emptyRoadmaps.length) {
  console.log(
    `Cases with no live step at all: ${emptyRoadmaps.length}. ` +
    'These need their roadmap written; restoring cannot invent steps.',
  );
}

if (!apply) {
  console.log('\nNothing changed. Re-run with --apply to restore.');
  process.exit(0);
}

await signInIfConfigured();

const restored = {};
restored.categories = await restore('categories', plan.categories);
restored.subcategories = await restore('subcategories', plan.subcategories);
restored.legal_cases = await restore('legal_cases', plan.legal_cases);
restored.case_steps = await restore('case_steps', plan.case_steps);

console.log('\nRestored:');
for (const [table, count] of Object.entries(restored)) {
  console.log(`  ${table.padEnd(14)} ${String(count).padStart(6)} row(s)`);
}

// Read back from the server, exactly like the app will.
const after = {
  categories: await selectAll('categories', 'select=id&deleted_at=is.null'),
  subcategories: await selectAll('subcategories', 'select=id&deleted_at=is.null'),
  legal_cases: await selectAll('legal_cases', 'select=id,deleted_at'),
  case_steps: await selectAll('case_steps', 'select=id,case_id&deleted_at=is.null'),
};
const liveCases = after.legal_cases.filter((c) => !c.deleted_at).length;
const casesWithSteps = new Set(after.case_steps.map((s) => s.case_id)).size;

console.log('\nAfter restore (as the app reads it):');
console.log(`  categories      ${after.categories.length}`);
console.log(`  subcategories   ${after.subcategories.length}`);
console.log(`  legal_cases     ${liveCases}`);
console.log(`  case_steps      ${after.case_steps.length}`);
console.log(`  cases with roadmap steps: ${casesWithSteps} of ${liveCases}`);
console.log(`\nFinished ${today.toISOString()}. Open the app once with internet: it syncs everything.`);
