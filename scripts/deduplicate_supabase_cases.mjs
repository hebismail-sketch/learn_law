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

async function selectAll(table, query) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${url}/rest/v1/${table}?${query}&order=id&offset=${offset}&limit=1000`, { headers: authHeaders });
    if (!res.ok) throw new Error(`${table} select error: ${res.status} ${await res.text()}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

function normalizeTitle(title) {
  if (!title) return '';
  return title
    .replace(/[\u064B-\u065F\u0670]/g, '') // remove Arabic diacritics
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

async function main() {
  console.log(`Starting Supabase Case Deduplication (${apply ? 'APPLY MODE' : 'DRY RUN'})...\n`);

  const categories = await selectAll('categories', 'select=id,name,deleted_at');
  const subcategories = await selectAll('subcategories', 'select=id,category_id,name,deleted_at');
  const cases = await selectAll('legal_cases', 'select=id,subcategory_id,title,description,updated_at,deleted_at');
  const steps = await selectAll('case_steps', 'select=id,case_id,step_number,title,short_description,deleted_at');

  const liveCategories = categories.filter(c => !c.deleted_at);
  const liveSubcategories = subcategories.filter(s => !s.deleted_at);
  const liveCases = cases.filter(c => !c.deleted_at);
  const liveSteps = steps.filter(s => !s.deleted_at);

  const subcategoryMap = new Map(liveSubcategories.map(s => [s.id, s]));
  const categoryMap = new Map(liveCategories.map(c => [c.id, c]));

  // Map live steps per case
  const stepsByCaseId = new Map();
  for (const step of liveSteps) {
    if (!stepsByCaseId.has(step.case_id)) {
      stepsByCaseId.set(step.case_id, []);
    }
    stepsByCaseId.get(step.case_id).push(step);
  }

  // Group live cases by normalized title
  const caseGroupsByTitle = new Map();
  for (const c of liveCases) {
    const norm = normalizeTitle(c.title);
    if (!norm) continue;
    if (!caseGroupsByTitle.has(norm)) {
      caseGroupsByTitle.set(norm, []);
    }
    caseGroupsByTitle.get(norm).push(c);
  }

  let totalDuplicateGroups = 0;
  let totalCasesToSoftDelete = 0;
  let totalStepsToReassign = 0;

  const casesToSoftDelete = [];
  const stepReassignments = []; // { stepId, newCaseId }

  for (const [normTitle, group] of caseGroupsByTitle.entries()) {
    if (group.length <= 1) continue;

    totalDuplicateGroups++;

    // Sort group:
    // 1. Max number of live steps first
    // 2. Longer description length second
    // 3. Newest updated_at third
    group.sort((a, b) => {
      const stepsA = (stepsByCaseId.get(a.id) || []).length;
      const stepsB = (stepsByCaseId.get(b.id) || []).length;
      if (stepsA !== stepsB) return stepsB - stepsA; // max steps first

      const descLenA = (a.description || '').length;
      const descLenB = (b.description || '').length;
      if (descLenA !== descLenB) return descLenB - descLenA;

      return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime();
    });

    const primaryCase = group[0];
    const primarySteps = stepsByCaseId.get(primaryCase.id) || [];
    const primaryStepKeys = new Set(
      primarySteps.map(s => `${s.step_number}\u0000${normalizeTitle(s.title)}`)
    );

    const primarySub = subcategoryMap.get(primaryCase.subcategory_id);
    console.log(`\nDuplicate Group #${totalDuplicateGroups}: "${primaryCase.title}" (${group.length} copies)`);
    console.log(`  -> KEEP Primary Case ID: ${primaryCase.id} | Steps: ${primarySteps.length} | Subcategory: ${primarySub ? primarySub.name : primaryCase.subcategory_id}`);

    for (let i = 1; i < group.length; i++) {
      const dupCase = group[i];
      const dupSteps = stepsByCaseId.get(dupCase.id) || [];
      const dupSub = subcategoryMap.get(dupCase.subcategory_id);

      console.log(`  -> SOFT-DELETE Duplicate Case ID: ${dupCase.id} | Steps: ${dupSteps.length} | Subcategory: ${dupSub ? dupSub.name : dupCase.subcategory_id}`);
      casesToSoftDelete.push(dupCase.id);
      totalCasesToSoftDelete++;

      // Check for any missing steps in duplicate case that are not in primary case
      for (const step of dupSteps) {
        const stepKey = `${step.step_number}\u0000${normalizeTitle(step.title)}`;
        if (!primaryStepKeys.has(stepKey)) {
          stepReassignments.push({ stepId: step.id, newCaseId: primaryCase.id });
          primaryStepKeys.add(stepKey);
          totalStepsToReassign++;
          console.log(`     + Move unique step "${step.title}" (Step #${step.step_number}) to Primary Case`);
        }
      }
    }
  }

  console.log(`\n========================================`);
  console.log(`SUMMARY:`);
  console.log(`Total duplicate title groups found: ${totalDuplicateGroups}`);
  console.log(`Total duplicate cases to soft-delete: ${totalCasesToSoftDelete}`);
  console.log(`Total steps to reassign to primary cases: ${totalStepsToReassign}`);
  console.log(`Remaining unique live cases: ${liveCases.length - totalCasesToSoftDelete}`);
  console.log(`========================================\n`);

  if (!apply) {
    console.log('Dry run complete. No changes made to Supabase. Re-run with --apply to apply changes.');
    return;
  }

  await signInIfConfigured();

  const nowIso = new Date().toISOString();

  // 1. Reassign steps
  if (stepReassignments.length > 0) {
    console.log(`Reassigning ${stepReassignments.length} step(s) to primary cases...`);
    for (const item of stepReassignments) {
      const res = await fetch(`${url}/rest/v1/case_steps?id=eq.${item.stepId}`, {
        method: 'PATCH',
        headers: writeHeaders,
        body: JSON.stringify({ case_id: item.newCaseId, updated_at: nowIso }),
      });
      if (!res.ok) {
        console.error(`Failed to reassign step ${item.stepId}: ${res.status} ${await res.text()}`);
      }
    }
    console.log('Step reassignment done.');
  }

  // 2. Soft-delete duplicate cases
  if (casesToSoftDelete.length > 0) {
    console.log(`Soft-deleting ${casesToSoftDelete.length} duplicate case(s)...`);
    for (let i = 0; i < casesToSoftDelete.length; i += 100) {
      const batch = casesToSoftDelete.slice(i, i + 100);
      const res = await fetch(`${url}/rest/v1/legal_cases?id=in.(${batch.join(',')})`, {
        method: 'PATCH',
        headers: writeHeaders,
        body: JSON.stringify({ deleted_at: nowIso, updated_at: nowIso }),
      });
      if (!res.ok) {
        console.error(`Failed to soft-delete batch: ${res.status} ${await res.text()}`);
      }
    }
    console.log('Duplicate cases soft-deleted.');
  }

  // 3. Cleanup blank category if exists
  const blankCategories = categories.filter(c => !c.name || c.name.trim() === '');
  for (const bCat of blankCategories) {
    if (!bCat.deleted_at) {
      console.log(`Soft-deleting blank category ID: ${bCat.id}`);
      await fetch(`${url}/rest/v1/categories?id=eq.${bCat.id}`, {
        method: 'PATCH',
        headers: writeHeaders,
        body: JSON.stringify({ deleted_at: nowIso, updated_at: nowIso }),
      });
    }
  }

  console.log('\nSupabase deduplication completed successfully!');
}

main().catch(console.error);
