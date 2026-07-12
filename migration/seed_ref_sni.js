/**
 * Seed ref_sni langsung ke Supabase via REST API (tanpa dependency npm).
 * Membaca migration/csv/ref_sni.csv (delimiter ';') dan upsert ke tabel ref_sni.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const CSV = path.join(__dirname, 'csv', 'ref_sni.csv');

function loadEnv() {
  const env = {};
  const p = path.join(ROOT, '.env');
  if (fs.existsSync(p)) {
    for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
  return env;
}
const ENV = loadEnv();
const URL = ENV.SUPABASE_URL;
const KEY = ENV.SUPABASE_SERVICE_ROLE_KEY;
if (!URL || !KEY || KEY.includes('PASTE_')) {
  console.error('❌ .env belum lengkap (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)');
  process.exit(1);
}

const RUMPUN = {
  simmental: 'Simmental', limousin: 'Limousin', pesisir: 'Pesisir', brahman: 'Brahman',
  'belgian blue': 'Belgian Blue', bb: 'Belgian Blue',
  fh: 'Frisian Holstein', 'frisian holstein': 'Frisian Holstein',
  'bbx sim': 'BBx Sim', 'bbx lim': 'BBx Lim', 'simx lim': 'Simx Lim', 'sim x lim': 'Simx Lim',
  silangan: 'Silangan', lokal: 'Lokal'
};
function mapRumpun(v) {
  if (!v) return 'Silangan';
  return RUMPUN[v.trim().toLowerCase().replace(/\s+/g, ' ')] || 'Silangan';
}
function normSex(v) {
  const c = (v || '').trim().toLowerCase()[0];
  if (c === 'j') return 'Jantan';
  if (c === 'b') return 'Betina';
  return null;
}
function num(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = parseFloat(String(v).replace(/,/g, '.').replace(/[^0-9.\-]/g, ''));
  return isNaN(n) ? null : n;
}

const raw = fs.readFileSync(CSV, 'utf8').split(/\r?\n/).filter(l => l.trim());
if (raw.length < 2) { console.error('CSV kosong'); process.exit(1); }
const h = raw[0].split(';').map(x => x.replace(/^\uFEFF/, '').trim());
const idx = name => h.findIndex(c => c.toLowerCase().includes(name.toLowerCase()));
const iRumpun = idx('rumpun'), iSex = idx('sex'), iPer = idx('periode'),
  iTP = idx('tinggi pundak'), iPB = idx('panjang badan'),
  iLD = idx('lingkar dada'), iLS = idx('lingkar scrotum'), iGrade = idx('grade');

const rows = [];
for (let i = 1; i < raw.length; i++) {
  const c = raw[i].split(';').map(x => x.trim());
  const sex = normSex(c[iSex]);
  if (!sex) continue;
  const per = (c[iPer] || '').match(/(\d+)\s*-\s*(\d+)/);
  if (!per) continue;
  const grade = parseInt(c[iGrade], 10);
  if (![1, 2, 3].includes(grade)) continue;
  rows.push({
    rumpun: mapRumpun(c[iRumpun]),
    jenis_kelamin: sex,
    periode_bulan_min: parseInt(per[1], 10),
    periode_bulan_max: parseInt(per[2], 10),
    grade,
    tp_min: num(c[iTP]), pb_min: num(c[iPB]), ld_min: num(c[iLD]), ls_min: num(c[iLS])
  });
}
console.log(`📄 ${rows.length} baris valid dari CSV`);

const endpoint = `${URL.replace(/\/$/, '')}/rest/v1/ref_sni`;
const headers = {
  'apikey': KEY,
  'Authorization': `Bearer ${KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'resolution=merge-duplicates,return=minimal',
  'On-Conflict': 'rumpun,jenis_kelamin,periode_bulan_min,periode_bulan_max,grade'
};

(async () => {
  // Bersihkan data lama (seed/duplikat) agar CSV menjadi otoritatif & idempoten
  const del = await fetch(`${endpoint}?rumpun=not.is.null`, {
    method: 'DELETE',
    headers: { 'apikey': KEY, 'Authorization': `Bearer ${KEY}` }
  });
  if (!del.ok) {
    const txt = await del.text();
    console.error(`⚠️  Gagal hapus data lama (${del.status}): ${txt.slice(0, 200)}`);
  } else {
    console.log('🧹 Data lama di ref_sni dibersihkan');
  }

  let ok = 0;
  const CHUNK = 100;
  for (let i = 0; i < rows.length; i += CHUNK) {
    const slice = rows.slice(i, i + CHUNK);
    const res = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(slice)
    });
    if (!res.ok) {
      const txt = await res.text();
      console.error(`❌ Gagal insert (${res.status}): ${txt.slice(0, 300)}`);
      process.exit(1);
    }
    ok += slice.length;
    console.log(`  ✓ ${ok}/${rows.length} baris diupsert`);
  }

  // Verifikasi jumlah
  const check = await fetch(`${endpoint}?select=id&rumpun=eq.Pesisir`, {
    headers: { 'apikey': KEY, 'Authorization': `Bearer ${KEY}`, 'Accept': 'application/json' }
  });
  const after = await fetch(`${endpoint}?select=id`, {
    headers: { 'apikey': KEY, 'Authorization': `Bearer ${KEY}`, 'Accept': 'application/json' }
  });
  const all = await after.json();
  console.log(`✅ Selesai. Total baris di ref_sni sekarang: ${Array.isArray(all) ? all.length : '?'} (Pesisir: ${(await check.json()).length})`);
})();
