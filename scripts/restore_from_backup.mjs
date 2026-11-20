// Restores all categories, subcategories, legal cases, and case steps from
// backup_cases/all_cases_backup.json back into Supabase.
//
// Usage:
//   node scripts/restore_from_backup.mjs            (dry run / report mode)
//   node scripts/restore_from_backup.mjs --apply    (apply restore to Supabase)

import fs from 'node:fs';
import path from 'node:path';

const url = process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const key = process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const adminEmail = process.env.ADMIN_EMAIL;
const adminPassword = process.env.ADMIN_PASSWORD;
const apply = process.argv.includes('--apply');

let authHeaders = { apikey: key, Authorization: `Bearer ${key}` };
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
  if (!res.ok) throw new Error(`admin sign-in failed: ${res.status}`);
  const { access_token: token } = await res.json();
  writeHeaders = {
    apikey: key,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
  };
}

async function run() {
  const backupPath = path.join(process.cwd(), 'backup_cases', 'all_cases_backup.json');
  if (!fs.existsSync(backupPath)) {
    console.error(`❌ Backup file not found at ${backupPath}`);
    process.exit(1);
  }

  const backupData = JSON.parse(fs.readFileSync(backupPath, 'utf8'));
  console.log(`📦 Found local backup created at: ${backupData.exported_at}`);
  console.log(`   - Categories: ${backupData.categories.length}`);
  console.log(`   - Subcategories: ${backupData.subcategories.length}`);
  console.log(`   - Legal Cases: ${backupData.cases.length}`);
  console.log(`   - Total Steps: ${backupData.total_steps}`);

  if (!apply) {
    console.log(`\n🔍 Dry run completed. Re-run with --apply to push restoration to Supabase.`);
    return;
  }

  await signInIfConfigured();

  console.log('\n🚀 Restoring content to Supabase...');

  // 1. Categories
  for (const cat of backupData.categories) {
    await fetch(`${url}/rest/v1/categories`, {
      method: 'POST',
      headers: { ...writeHeaders, Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({
        id: cat.id,
        name: cat.name,
        description: cat.description,
        deleted_at: null,
        updated_at: new Date().toISOString()
      }),
    });
  }
  console.log('✅ Categories restored.');

  // 2. Subcategories
  for (const sub of backupData.subcategories) {
    await fetch(`${url}/rest/v1/subcategories`, {
      method: 'POST',
      headers: { ...writeHeaders, Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({
        id: sub.id,
        category_id: sub.category_id,
        name: sub.name,
        deleted_at: null,
        updated_at: new Date().toISOString()
      }),
    });
  }
  console.log('✅ Subcategories restored.');

  // 3. Cases & Steps
  for (const c of backupData.cases) {
    await fetch(`${url}/rest/v1/legal_cases`, {
      method: 'POST',
      headers: { ...writeHeaders, Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({
        id: c.id,
        subcategory_id: c.subcategory_id,
        title: c.title,
        description: c.description,
        deleted_at: null,
        updated_at: new Date().toISOString()
      }),
    });

    for (const step of c.steps) {
      await fetch(`${url}/rest/v1/case_steps`, {
        method: 'POST',
        headers: { ...writeHeaders, Prefer: 'resolution=merge-duplicates' },
        body: JSON.stringify({
          id: step.id,
          case_id: c.id,
          step_number: step.step_number,
          title: step.title,
          short_description: step.short_description,
          deleted_at: null,
          updated_at: new Date().toISOString()
        }),
      });
    }
  }

  console.log('🎉 Full restoration to Supabase completed successfully!');
}

run().catch(console.error);
