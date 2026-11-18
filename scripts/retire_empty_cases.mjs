// Retires cases that are live but have zero live steps, so the app never opens
// an empty roadmap. Nothing is erased: a retired case gets `deleted_at` set, and
// `--restore` clears it again on the same ids.
//
//   node scripts/retire_empty_cases.mjs            report only
//   node scripts/retire_empty_cases.mjs --apply    retire
//   node scripts/retire_empty_cases.mjs --restore  bring them back
//
// WHAT IT TOUCHES
//   Only `legal_cases.deleted_at` on cases with no live step. No rows are
//   deleted, no steps are created, no app code is involved. The app already
//   skips soft-deleted content, so these cases disappear from every phone on
//   the next pull and stop being downloaded by new installs.
//
// AFTER THE CONTENT TEAM FILLS A CASE
//   Run `--restore` once its steps exist: a case with steps is never retired by
//   this script, and restoring only affects the ids listed in the manifest.

import fs from 'node:fs';

const url =
  process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const key =
  process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const manifestPath = 'retired_empty_cases.json';
const apply = process.argv.includes('--apply');
const restoreMode = process.argv.includes('--restore');

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

async function selectAll(table, query) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(
      `${url}/rest/v1/${table}?${query}&order=id&offset=${offset}&limit=1000`,
      { headers },
    );
    if (!res.ok) throw new Error(`${table}: ${res.status} ${await res.text()}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

/** PATCHes deleted_at on [ids]; returns how many rows the server changed. */
async function setDeletedAt(ids, value) {
  let changed = 0;
  for (let i = 0; i < ids.length; i += 100) {
    const batch = ids.slice(i, i + 100);
    const res = await fetch(`${url}/rest/v1/legal_cases?id=in.(${batch.join(',')})`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ deleted_at: value }),
    });
    if (!res.ok) {
      throw new Error(`legal_cases update refused: ${res.status} ${await res.text()}`);
    }
    changed += (await res.json()).length;
  }
  return changed;
}

// ------------------------------------------------------------- restore mode
if (restoreMode) {
  if (!fs.existsSync(manifestPath)) {
    console.error(`No manifest at ${manifestPath}; nothing to restore.`);
    process.exit(1);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const ids = manifest.cases.map((c) => c.id);
  if (ids.length === 0) {
    console.log('The manifest lists no cases.');
    process.exit(0);
  }

  // Only bring back a case that has steps now: restoring an empty one would
  // put the empty roadmap back in front of the reader.
  const cases = await selectAll(
    'legal_cases',
    `select=id,title&id=in.(${ids.join(',')})`,
  );
  const ready = [];
  const stillEmpty = [];
  for (const legalCase of cases) {
    const steps = await selectAll(
      'case_steps',
      `select=id&case_id=eq.${legalCase.id}&deleted_at=is.null&limit=1`,
    );
    if (steps.length > 0) ready.push(legalCase);
    else stillEmpty.push(legalCase);
  }

  const changed = await setDeletedAt(ready.map((c) => c.id), null);
  console.log(`Restored ${changed} case(s) that now have steps.`);
  if (stillEmpty.length) {
    console.log(`Still empty, left retired: ${stillEmpty.length}`);
    for (const c of stillEmpty) console.log(`  - ${c.title}`);
  }
  process.exit(0);
}

// ------------------------------------------------------------- retire mode
const cases = await selectAll(
  'legal_cases',
  'select=id,title,subcategory_id&deleted_at=is.null',
);
const subcategories = await selectAll(
  'subcategories',
  'select=id,name,category_id&deleted_at=is.null',
);
const categories = await selectAll('categories', 'select=id,name&deleted_at=is.null');

// Count the live steps of every case, in chunks small enough to keep each
// response well under the server's 1000-row cap.
const withSteps = new Set();
const CHUNK = 100;
for (let i = 0; i < cases.length; i += CHUNK) {
  const ids = cases.slice(i, i + CHUNK).map((c) => c.id).join(',');
  const steps = await selectAll(
    'case_steps',
    `select=id,case_id&case_id=in.(${ids})&deleted_at=is.null`,
  );
  for (const step of steps) withSteps.add(step.case_id);
}

const empty = cases.filter((c) => !withSteps.has(c.id));
const categoryName = new Map(categories.map((c) => [c.id, c.name]));
const subcategoryById = new Map(subcategories.map((s) => [s.id, s]));

console.log(`live cases ${cases.length}, empty roadmaps ${empty.length}`);
if (empty.length === 0) {
  console.log('Nothing to retire.');
  process.exit(0);
}

for (const c of empty) {
  const sub = subcategoryById.get(c.subcategory_id);
  const parent = sub ? categoryName.get(sub.category_id) ?? '?' : '?';
  console.log(`  [${parent}] ${c.title}`);
}

if (!apply) {
  console.log('\nNothing changed. Re-run with --apply to retire these cases.');
  process.exit(0);
}

const now = new Date().toISOString();
const changed = await setDeletedAt(empty.map((c) => c.id), now);

fs.writeFileSync(
  manifestPath,
  JSON.stringify(
    {
      retiredAt: now,
      note:
        'Cases retired because they had no live steps. Restore with: ' +
        'node scripts/retire_empty_cases.mjs --restore',
      cases: empty.map((c) => ({
        id: c.id,
        title: c.title,
        subcategory: subcategoryById.get(c.subcategory_id)?.name ?? null,
      })),
    },
    null,
    2,
  ),
);

// Verify against the server: the app's own query must not see them.
const stillLive = [];
for (const c of empty) {
  const rows = await selectAll(
    'legal_cases',
    `select=id&id=eq.${c.id}&deleted_at=is.null`,
  );
  if (rows.length) stillLive.push(c);
}
const liveAfter = await selectAll('legal_cases', 'select=id&deleted_at=is.null');

console.log(`\nRetired ${changed} case(s). Live cases now: ${liveAfter.length}`);
console.log(`Manifest written to ${manifestPath} (restore with --restore).`);
if (stillLive.length) {
  console.error(`WARNING: ${stillLive.length} still live and need a retry.`);
  process.exit(1);
}
