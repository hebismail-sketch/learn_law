import fs from 'node:fs';
import path from 'node:path';

const url = process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const key = process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const headers = { apikey: key, Authorization: `Bearer ${key}` };

async function fetchAll(table) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${url}/rest/v1/${table}?select=*&order=id&offset=${offset}&limit=1000`, { headers });
    if (!res.ok) throw new Error(`Failed to fetch ${table}: ${res.status}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

async function run() {
  console.log('📦 Starting full library backup from Supabase...');

  const categories = await fetchAll('categories');
  const subcategories = await fetchAll('subcategories');
  const cases = await fetchAll('legal_cases');
  const steps = await fetchAll('case_steps');

  const liveCategories = categories.filter(c => !c.deleted_at);
  const liveSubcategories = subcategories.filter(s => !s.deleted_at);
  const liveCases = cases.filter(c => !c.deleted_at);
  const liveSteps = steps.filter(s => !s.deleted_at);

  const subMap = new Map(liveSubcategories.map(s => [s.id, s]));
  const catMap = new Map(liveCategories.map(c => [c.id, c]));

  const stepsByCaseId = new Map();
  for (const step of liveSteps) {
    if (!stepsByCaseId.has(step.case_id)) {
      stepsByCaseId.set(step.case_id, []);
    }
    stepsByCaseId.get(step.case_id).push(step);
  }

  const outputDir = path.join(process.cwd(), 'backup_cases');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const fullBackupData = {
    exported_at: new Date().toISOString(),
    total_categories: liveCategories.length,
    total_subcategories: liveSubcategories.length,
    total_cases: liveCases.length,
    total_steps: liveSteps.length,
    categories: liveCategories.map(c => ({ id: c.id, name: c.name, description: c.description })),
    subcategories: liveSubcategories.map(s => {
      const parentCat = catMap.get(s.category_id);
      return {
        id: s.id,
        category_id: s.category_id,
        category_name: parentCat ? parentCat.name : null,
        name: s.name
      };
    }),
    cases: liveCases.map((c, index) => {
      const sub = subMap.get(c.subcategory_id);
      const cat = sub ? catMap.get(sub.category_id) : null;
      const caseSteps = (stepsByCaseId.get(c.id) || [])
        .sort((a, b) => a.step_number - b.step_number);

      return {
        index: index + 1,
        id: c.id,
        title: c.title,
        description: c.description,
        category_id: cat ? cat.id : null,
        category_name: cat ? cat.name : null,
        subcategory_id: sub ? sub.id : null,
        subcategory_name: sub ? sub.name : null,
        steps_count: caseSteps.length,
        steps: caseSteps.map(s => ({
          id: s.id,
          step_number: s.step_number,
          title: s.title,
          short_description: s.short_description
        }))
      };
    })
  };

  // Write all_cases_backup.json
  const mainBackupPath = path.join(outputDir, 'all_cases_backup.json');
  fs.writeFileSync(mainBackupPath, JSON.stringify(fullBackupData, null, 2), 'utf8');

  // Write individual files for each case
  const individualFolder = path.join(outputDir, 'cases_individual');
  if (!fs.existsSync(individualFolder)) {
    fs.mkdirSync(individualFolder, { recursive: true });
  }

  fullBackupData.cases.forEach((c) => {
    const cleanTitle = c.title.replace(/[/\\?%*:|"<>\s]+/g, '_');
    const filename = `${String(c.index).padStart(3, '0')}_${cleanTitle}.json`;
    fs.writeFileSync(path.join(individualFolder, filename), JSON.stringify(c, null, 2), 'utf8');
  });

  console.log(`\n✅ Backup Completed Successfully!`);
  console.log(`📁 Backup Folder: ${outputDir}`);
  console.log(`📄 Main JSON File: ${mainBackupPath}`);
  console.log(`📁 Individual Cases Folder: ${individualFolder}`);
  console.log(`📊 Statistics:`);
  console.log(`   - Categories: ${liveCategories.length}`);
  console.log(`   - Subcategories (Branches): ${liveSubcategories.length}`);
  console.log(`   - Unique Legal Cases: ${liveCases.length}`);
  console.log(`   - Total Steps / Stages: ${liveSteps.length}`);
}

run().catch(console.error);
