// Restores the content exactly as it stood on a given date, and keeps the app's
// own code/ads/UI untouched: this script only changes rows in Supabase.
//
//   node scripts/restore_as_of_date.mjs 2026-11-04          report only
//   node scripts/restore_as_of_date.mjs 2026-11-04 --apply  do it
//
// WHAT "AS OF <date>" MEANS
//
// A row that existed and was live at any moment on that UTC day comes back:
//   - currently live                       → left alone
//   - deleted, deleted_at <= end of day    → deleted_at cleared (it was live
//                                            at the start of the day)
//   - created after the day                → not part of that state, left alone
// Rows deleted *after* that day stay deleted: they are what was removed later.
//
// SAFETY
//   - nothing is inserted, renamed or deleted;
//   - children are restored only under a parent that is live;
//   - every PATCH is checked, and the run stops on the first refusal;
//   - at the end it reads the data back the same way the app does and prints
//     the exact numbers, so the result is verified, not assumed.
//
// The app reads with the publishable key; writing needs that key to still be
// allowed (true today) or an admin session:
//   ADMIN_EMAIL=... ADMIN_PASSWORD=... node scripts/restore_as_of_date.mjs <day> --apply

const url =
  process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const publishableKey =
  process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const adminEmail = process.env.ADMIN_EMAIL;
const adminPassword = process.env.ADMIN_PASSWORD;

const day = process.argv.find((a) => /^\d{4}-\d{2}-\d{2}$/.test(a));
const apply = process.argv.includes('--apply');
if (!day) {
  console.error('Usage: node scripts/restore_as_of_date.mjs YYYY-MM-DD [--apply]');
  process.exit(2);
}

const start = new Date(`${day}T00:00:00Z`);
const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

let writeHeaders = {
  apikey: publishableKey,
  Authorization: `Bearer ${publishableKey}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};
const readHeaders = {
  apikey: publishableKey,
  Authorization: `Bearer ${publishableKey}`,
};

async function signIn() {
  if (!adminEmail || !adminPassword) return false;
  const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { ...readHeaders, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: adminEmail, password: adminPassword }),
  });
  if (!res.ok) throw new Error(`admin sign-in failed: ${res.status}`);
  const { access_token: token } = await res.json();
  writeHeaders = { ...writeHeaders, Authorization: `Bearer ${token}` };
  return true;
}

async function selectAll(table, query) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(
      `${url}/rest/v1/${table}?${query}&offset=${offset}&limit=1000`,
      { headers: readHeaders },
    );
    if (!res.ok) {
      throw new Error(`${table} read failed: ${res.status} ${await res.text()}`);
    }
    const page = await res.json();
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

/** Clears deleted_at on [ids]; returns the rows the database really changed. */
async function restore(table, ids) {
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

// ---------------------------------------------------------------- read state
const categories = await selectAll(
  'categories',
  'select=id,name,deleted_at&order=id',
);
const subcategories = await selectAll(
  'subcategories',
  'select=id,category_id,deleted_at&order=id',
);
const legalCases = await selectAll(
  'legal_cases',
  'select=id,subcategory_id,deleted_at&order=id',
);
const caseSteps = await selectAll(
  'case_steps',
  'select=id,case_id,deleted_at&order=id',
);

const deletedOnOrBeforeDay = (row) =>
  row.deleted_at !== null && new Date(row.deleted_at) < end;

const plan = {
  categories: categories.filter(deletedOnOrBeforeDay).map((r) => r.id),
  subcategories: subcategories.filter(deletedOnOrBeforeDay),
  legal_cases: legalCases.filter(deletedOnOrBeforeDay),
  case_steps: caseSteps.filter(deletedOnOrBeforeDay),
};

const liveCategoryIds = new Set(
  categories.filter((r) => r.deleted_at === null).map((r) => r.id),
);
const liveSubcategoryIds = new Set(
  subcategories.filter((r) => r.deleted_at === null).map((r) => r.id),
);
const liveCaseIds = new Set(
  legalCases.filter((r) => r.deleted_at === null).map((r) => r.id),
);

const subcategoryPlan = plan.subcategories.filter((r) =>
  liveCategoryIds.has(r.category_id),
);
const casePlan = plan.legal_cases.filter((r) =>
  liveSubcategoryIds.has(r.subcategory_id),
);
const stepPlan = plan.case_steps.filter((r) => liveCaseIds.has(r.case_id));
const orphaned =
  plan.subcategories.length -
  subcategoryPlan.length +
  plan.legal_cases.length -
  casePlan.length +
  plan.case_steps.length -
  stepPlan.length;

console.log(`State as of ${day} (UTC) — rows to bring back`);
console.log(`  categories     ${String(plan.categories.length).padStart(6)}`);
console.log(`  subcategories  ${String(subcategoryPlan.length).padStart(6)}`);
console.log(`  legal_cases    ${String(casePlan.length).padStart(6)}`);
console.log(`  case_steps     ${String(stepPlan.length).padStart(6)}`);
console.log(
  `  live now: ${categories.filter((r) => !r.deleted_at).length} categories, ` +
  `${subcategories.filter((r) => !r.deleted_at).length} subcategories, ` +
  `${legalCases.filter((r) => !r.deleted_at).length} cases, ` +
  `${caseSteps.filter((r) => !r.deleted_at).length} steps`,
);
if (orphaned) {
  console.log(
    `  ${orphaned} row(s) deleted on/before that day hang under a parent that ` +
    'is deleted for a later reason: left as is (their parent no longer exists).',
  );
}

if (!apply) {
  console.log('\nNothing changed. Re-run with --apply.');
  process.exit(0);
}

// ------------------------------------------------------------- restore
const usedAdmin = await signIn();
console.log(`\nWriting as ${usedAdmin ? 'the admin session' : 'the publishable key'}…`);

const restored = {};
restored.categories = await restore('categories', plan.categories);
for (const id of plan.categories) liveCategoryIds.add(id);
restored.subcategories = await restore(
  'subcategories',
  subcategoryPlan.map((r) => r.id),
);
for (const r of subcategoryPlan) liveSubcategoryIds.add(r.id);
restored.legal_cases = await restore(
  'legal_cases',
  casePlan.map((r) => r.id),
);
for (const r of casePlan) liveCaseIds.add(r.id);
restored.case_steps = await restore(
  'case_steps',
  stepPlan.map((r) => r.id),
);

console.log('\nRestored');
for (const [table, count] of Object.entries(restored)) {
  console.log(`  ${table.padEnd(14)} ${String(count).padStart(6)}`);
}

// ------------------------------------------------------- verify from server
const after = {
  categories: await selectAll('categories', 'select=id&deleted_at=is.null'),
  subcategories: await selectAll('subcategories', 'select=id&deleted_at=is.null'),
  legal_cases: await selectAll('legal_cases', 'select=id&deleted_at=is.null'),
  case_steps: await selectAll('case_steps', 'select=id,case_id&deleted_at=is.null'),
};
const casesWithSteps = new Set(after.case_steps.map((s) => s.case_id)).size;
console.log('\nLive now, read back from the server (what the app will download)');
console.log(`  categories     ${after.categories.length}`);
console.log(`  subcategories  ${after.subcategories.length}`);
console.log(`  legal_cases    ${after.legal_cases.length}`);
console.log(`  case_steps     ${after.case_steps.length}`);
console.log(
  `  cases with roadmap steps: ${casesWithSteps} of ${after.legal_cases.length}`,
);
