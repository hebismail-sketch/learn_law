// Diagnostic: how much content does the production Supabase project expose,
// split by the `deleted_at` soft-delete flag, and how are the timestamps set?
//
// Run from the repo root:  node scripts/check_remote_counts.mjs
// SUPABASE_URL / SUPABASE_KEY env vars can override the defaults below.

const url =
  process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const key =
  process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  Prefer: 'count=exact',
  Range: '0-0',
};

async function count(path) {
  const res = await fetch(`${url}/rest/v1/${path}`, {
    method: 'HEAD',
    headers,
  });
  return `${res.status} ${res.headers.get('content-range') ?? '-'}`;
}

const probes = {
  categories: ['categories', 'categories?deleted_at=is.null'],
  subcategories: ['subcategories', 'subcategories?deleted_at=is.null'],
  legal_cases: ['legal_cases', 'legal_cases?deleted_at=is.null'],
  case_steps: ['case_steps', 'case_steps?deleted_at=is.null'],
};

for (const [name, [all, alive]] of Object.entries(probes)) {
  console.log(
    `\n${name}\n  all rows      ${await count(all)}\n  live rows     ${await count(alive)}`,
  );
}

// Does `updated_at` actually exist and move? A watermark pull is only correct
// when the column is maintained.
const sample = await fetch(
  `${url}/rest/v1/case_steps?select=id,updated_at,deleted_at&limit=3&order=updated_at.desc`,
  { headers: { apikey: key, Authorization: `Bearer ${key}` } },
);
console.log('\nnewest step rows:', JSON.stringify(await sample.json(), null, 1));

// Anonymous write check: this must be refused (401/403) for the app's design.
const write = await fetch(`${url}/rest/v1/categories`, {
  method: 'POST',
  headers: {
    apikey: key,
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
    Prefer: 'return=minimal',
  },
  body: JSON.stringify({}),
});
console.log('\nanon insert into categories ->', write.status, write.statusText);
