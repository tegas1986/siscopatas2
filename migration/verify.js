const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv() {
  const e = {}; const p = path.join(ROOT, '.env');
  if (fs.existsSync(p)) for (const l of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, '');
  } return e;
}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const TABLES = ['ref_lokasi','users','petugas_reproduksi','petugas_keswan','bull','ternak',
  'laporan_berahi','ib','kebuntingan','kelahiran','pengukuran','penjualan','log_mutasi'];

async function getAll(table, col) {
  let all = [], from = 0, size = 1000;
  for (;;) {
    const { data, error } = await sb.from(table).select(col).range(from, from + size - 1);
    if (error) throw error;
    if (!data || !data.length) break;
    all = all.concat(data); if (data.length < size) break; from += size;
  }
  return all;
}

(async () => {
  console.log('TABEL'.padEnd(20), 'JUMLAH');
  let total = 0;
  for (const t of TABLES) {
    const { count, error } = await sb.from(t).select('*', { count: 'exact', head: true });
    if (error) { console.log(t.padEnd(20), 'ERR', error.message); continue; }
    console.log(t.padEnd(20), count); total += count;
  }
  console.log('TOTAL DATA'.padEnd(20), total);

  const tn = await getAll('ternak', 'eartag');
  const set = new Set(tn.map(r => r.eartag));
  console.log('ternak dimuat ke Set:', set.size);
  for (const t of ['ib','pengukuran','laporan_berahi','kebuntingan','penjualan','log_mutasi']) {
    const rows = await getAll(t, 'eartag');
    const bad = rows.filter(r => !set.has(r.eartag)).length;
    console.log(`FK cek ${t}: ${bad} eartag orphan (seharusnya 0)`);
  }
  const k = await getAll('kelahiran', 'eartag_induk');
  const badK = k.filter(r => !set.has(r.eartag_induk)).length;
  console.log(`FK cek kelahiran.eartag_induk: ${badK} orphan (seharusnya 0)`);
})();
