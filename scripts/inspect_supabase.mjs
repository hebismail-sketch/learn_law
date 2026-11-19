const url = process.env.SUPABASE_URL ?? 'https://ptsfjeersiesgjtvcjkh.supabase.co';
const key = process.env.SUPABASE_KEY ?? 'sb_publishable_XkB0rrhhqcw9A3xcJzc9Dg_5ZtCfy6O';
const headers = { apikey: key, Authorization: `Bearer ${key}` };

async function selectAll(table, query) {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${url}/rest/v1/${table}?${query}&order=id&offset=${offset}&limit=1000`, { headers });
    if (!res.ok) throw new Error(`${table} error: ${res.status}`);
    const page = await res.json();
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

async function run() {
  const categories = await selectAll('categories', 'select=*');
  const subcategories = await selectAll('subcategories', 'select=*');
  const cases = await selectAll('legal_cases', 'select=*');
  const steps = await selectAll('case_steps', 'select=*');

  console.log('Categories:');
  for (const cat of categories) {
    const subs = subcategories.filter(s => s.category_id === cat.id && !s.deleted_at);
    console.log(`  - ${cat.name} (ID: ${cat.id}, deleted: ${cat.deleted_at}) -> ${subs.length} live subcategories`);
  }

  // Check subcategories per category
  console.log('\nSubcategory counts per category:');
  const subGroup = {};
  for (const sub of subcategories.filter(s => !s.deleted_at)) {
    subGroup[sub.category_id] = (subGroup[sub.category_id] || 0) + 1;
  }
  console.log(subGroup);

  // Check duplicate subcategory names
  const subNameMap = {};
  for (const s of subcategories.filter(s => !s.deleted_at)) {
    const norm = s.name.trim().toLowerCase();
    subNameMap[norm] = subNameMap[norm] || [];
    subNameMap[norm].push(s);
  }

  let dupSubCount = 0;
  for (const [name, list] of Object.entries(subNameMap)) {
    if (list.length > 1) {
      dupSubCount++;
      console.log(`\nDuplicate Subcategory "${list[0].name}" (${list.length} copies):`);
      for (const s of list) {
        const cat = categories.find(c => c.id === s.category_id);
        const caseCount = cases.filter(c => c.subcategory_id === s.id && !c.deleted_at).length;
        console.log(`  - ID: ${s.id} | Category: ${cat ? cat.name : s.category_id} | Live Cases: ${caseCount}`);
      }
    }
  }
  console.log(`\nTotal duplicate subcategories: ${dupSubCount}`);
}

run().catch(console.error);
