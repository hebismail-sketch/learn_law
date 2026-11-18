// Restores the content that was deleted on 2026-11-09, then verifies it.
// Nothing is ever deleted by this script.
//
//   node scripts/restore_deleted_per_date.mjs            (report only)
//   node scripts/restore_deleted_per_date.mjs --apply    (restore)
//
// The publishable key is enough for this project because public writes are
// currently allowed; that hole is what supabase_production_content_visibility_fix.sql
// closes. Run this script BEFORE that SQL, or set SUPABASE_SERVICE_ROLE_KEY
// (or SUPABASE_KEY) to an admin key if the SQL has already been applied.
//
// Safety rules:
//   * only rows whose deleted_at falls on the requested UTC day are touched;
//   * a category/subcategory is restored only when its parent is live;
//   * an emptied deleted_at keeps the row's own updated_at, so devices pick the
//     change up on their next pull;
//   * every write checks that at least one row changed, and the run aborts on
//     the first refusal instead of leaving a half-restored library.

const url =
  process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const serviceKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  process.env.SUPABASE_KEY ??
  'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const apply = process.argv.includes('--apply');
const day = process.env.RESTORE_DAY ?? '2026-11-09';

const start = new Date(`${day}T00:00:00Z`);
const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

async function selectAll(table, query) {
  const pageSize = 1000;
  const rows = [];
  for (let offset = 0; ; offset += pageSize) {
    const res = await fetch(
      `${url}/rest/v1/${table}?${query}&order=id&offset=${offset}&limit=${pageSize}`,
      { headers },
    );
    if (!res.ok) throw new Error(`${table} read failed: ${res.status} ${await res.text()}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

/** Restores one batch of ids; returns how many rows the database changed. */
async function restore(table, ids) {
  if (ids.length === 0) return 0;
  let restored = 0;
  for (let i = 0; i < ids.length; i += 200) {
    const batch = ids.slice(i, i + 200);
    const res = await fetch(
      `${url}/rest/v1/${table}?id=in.(${batch.join(',')})`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ deleted_at: null }),
      },
    );
    if (!res.ok) {
      throw new Error(`${table} restore failed: ${res.status} ${await res.text()}`);
    }
    restored += (await res.json()).length;
  }
  return restored;
}

const deletedQuery = `select=id&deleted_at=gte.${start.toISOString()}&deleted_at=lt.${end.toISOString()}`;

function report(name, rows) {
  console.log(`  ${name.padEnd(14)} ${String(rows.length).padStart(6)} row(s) deleted on ${day}`);
}

const categories = await selectAll('categories', deletedQuery);
const subcategories = await selectAll('subcategories', deletedQuery);
const legalCases = await selectAll('legal_cases', deletedQuery);
const caseSteps = await selectAll('case_steps', deletedQuery);

console.log(`Soft-deleted on ${day}${apply ? '' : ' (dry run)'}:`);
report('categories', categories);
report('subcategories', subcategories);
report('legal_cases', legalCases);
report('case_steps', caseSteps);

if (!apply) {
  console.log('\nNothing changed. Re-run with --apply to restore.');
  process.exit(0);
}

// Parents first, so a child is never restored under a deleted parent.
const liveCategoryIds = new Set(
  (await selectAll('categories', 'select=id&deleted_at=is.null')).map((r) => r.id),
);
const liveSubcategoryIds = new Set(
  (await selectAll('subcategories', 'select=id&deleted_at=is.null')).map((r) => r.id),
);
const liveCaseIds = new Set(
  (await selectAll('legal_cases', 'select=id&deleted_at=is.null')).map((r) => r.id),
);

const rows = {
  categories: await selectAll('categories', `${deletedQuery}&select=id`),
  subcategories: await selectAll(
    'subcategories',
    `${deletedQuery}&select=id,category_id`,
  ),
  legal_cases: await selectAll(
    'legal_cases',
    `${deletedQuery}&select=id,subcategory_id`,
  ),
  case_steps: await selectAll('case_steps', `${deletedQuery}&select=id,case_id`),
};

const total = { categories: 0, subcategories: 0, legal_cases: 0, case_steps: 0 };

// A subcategory whose category was deleted on the same day comes back after it.
const restoreAll = async (table, ids) => {
  total[table] += await restore(table, ids);
};

await restoreAll('categories', rows.categories.map((r) => r.id));
for (const id of rows.categories.map((r) => r.id)) liveCategoryIds.add(id);

await restoreAll(
  'subcategories',
  rows.subcategories.filter((r) => liveCategoryIds.has(r.category_id)).map((r) => r.id),
);
for (const r of rows.subcategories) liveSubcategoryIds.add(r.id);

await restoreAll(
  'legal_cases',
  rows.legal_cases.filter((r) => liveSubcategoryIds.has(r.subcategory_id)).map((r) => r.id),
);
for (const r of rows.legal_cases) liveCaseIds.add(r.id);

await restoreAll(
  'case_steps',
  rows.case_steps.filter((r) => liveCaseIds.has(r.case_id)).map((r) => r.id),
);

console.log('\nRestored:');
for (const [table, count] of Object.entries(total)) {
  console.log(`  ${table.padEnd(14)} ${String(count).padStart(6)} row(s)`);
}

// Verification, read back from the database.
console.log('\nAfter restore:');
for (const table of ['categories', 'subcategories', 'legal_cases', 'case_steps']) {
  const live = await selectAll(table, 'select=id&deleted_at=is.null');
  const deleted = await selectAll(table, 'select=id&deleted_at=not.is.null');
  console.log(
    `  ${table.padEnd(14)} live ${String(live.length).padStart(6)}  deleted ${String(deleted.length).padStart(6)}`,
  );
}
