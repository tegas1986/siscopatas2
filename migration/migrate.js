/**
 * SISCOPATAS - Migrasi Google Sheets (CSV) -> Supabase
 * ===================================================
 * Jalankan dari root project:
 *   $env:NODE_PATH="C:\Users\LENOVO\AppData\Local\Temp\kilo\mig-deps\node_modules"
 *   node migration/migrate.js            (jalankan semua)
 *   node migration/migrate.js ref_lokasi (jalankan 1 langkah saja)
 *
 * Prasyarat:
 *   - database/09_migration_enums.sql sudah dijalankan di Supabase
 *   - .env terisi SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY
 *   - CSV ada di migration/csv/
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

const ROOT = path.join(__dirname, '..');
const CSV_DIR = path.join(__dirname, 'csv');
const OUT_DIR = path.join(__dirname, 'json');
if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

// ---------- ENV ----------
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
const SUPABASE_URL = ENV.SUPABASE_URL;
const SERVICE_KEY = ENV.SUPABASE_SERVICE_ROLE_KEY;
const DOMAIN = ENV.DEFAULT_EMAIL_DOMAIN || 'siscopatas.com';
const DEFAULT_PW = ENV.DEFAULT_USER_PASSWORD || 'Siscopatas2024!';

if (!SUPABASE_URL || !SERVICE_KEY || SERVICE_KEY.includes('PASTE_')) {
  console.error('\n❌ .env belum lengkap. Isi SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY di file .env.\n');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false }
});

// ---------- CSV ----------
function parseCSV(text) {
  const rows = []; let f = '', row = [], q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"') { if (text[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += c; }
    else {
      if (c === '"') q = true;
      else if (c === ',') { row.push(f); f = ''; }
      else if (c === '\r') { }
      else if (c === '\n') { row.push(f); rows.push(row); row = []; f = ''; }
      else f += c;
    }
  }
  if (f.length || row.length) { row.push(f); rows.push(row); }
  return rows.filter(r => r.some(v => v && v.trim()));
}
function load(name) {
  const p = path.join(CSV_DIR, name);
  if (!fs.existsSync(p)) { console.warn('  (file tidak ada: ' + name + ')'); return []; }
  const rows = parseCSV(fs.readFileSync(p, 'utf8'));
  if (!rows.length) return [];
  const h = rows[0].map(x => x.replace(/^\uFEFF/, '').trim());
  return rows.slice(1).map(r => Object.fromEntries(h.map((x, i) => [x, (r[i] || '').trim()])));
}

// ---------- HELPERS ----------
const empty = v => v === undefined || v === null || v === '' || v === '-';
function parseDate(v) {
  if (empty(v)) return null;
  v = v.trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(v)) return v.slice(0, 10);
  const p = v.split(/[-/.]/).map(s => s.trim());
  if (p.length !== 3) return null;
  let dd, mm, yy;
  if (p[0].length === 4) { yy = p[0]; mm = p[1]; dd = p[2]; }
  else { dd = p[0]; mm = p[1]; yy = p[2]; }
  if (yy.length === 2) yy = '20' + yy;
  dd = dd.padStart(2, '0'); mm = mm.padStart(2, '0');
  const D = +dd, M = +mm, Y = +yy;
  if (!(D >= 1 && D <= 31 && M >= 1 && M <= 12 && Y >= 2000 && Y <= 2100)) return null;
  return `${yy}-${mm}-${dd}`;
}
function normSex(v) {
  if (empty(v)) return null;
  const c = v.trim().toLowerCase()[0];
  if (c === 'j') return 'Jantan';
  if (c === 'b') return 'Betina';
  return null;
}
const RUMPUN_MAP = {
  'simmental': 'Simmental', 'limousin': 'Limousin', 'pesisir': 'Pesisir', 'brahman': 'Brahman',
  'belgian blue': 'Belgian Blue', 'bb': 'Belgian Blue',
  'fh': 'Frisian Holstein', 'frisian holstein': 'Frisian Holstein',
  'bbx sim': 'BBx Sim', 'bbx lim': 'BBx Lim',
  'simx lim': 'Simx Lim', 'sim x lim': 'Simx Lim',
  'silangan': 'Silangan', 'lokal': 'Lokal'
};
function mapRumpun(v) {
  if (empty(v)) return 'Silangan';
  const k = v.trim().toLowerCase().replace(/\s+/g, ' ');
  return RUMPUN_MAP[k] || 'Silangan';
}
function mapStatusTernak(v) {
  if (empty(v)) return 'Hidup';
  const set = ['Hidup', 'Mati', 'Jual', 'Hibah', 'Pindah'];
  const hit = set.find(s => s.toLowerCase() === v.trim().toLowerCase());
  return hit || 'Hidup';
}
function mapRegistrasi(v) {
  return (!empty(v) && v.trim().toLowerCase() === 'aset') ? 'Aset' : 'Persediaan';
}
function mapGrade(v) {
  if (empty(v)) return null;
  const t = v.trim().toLowerCase();
  const set = { 'grade 1': 'Grade 1', 'grade 2': 'Grade 2', 'grade 3': 'Grade 3', 'non sni': 'Non SNI', 'belum ada sni': 'Belum Ada SNI' };
  return set[t] || 'Belum Ada SNI';
}
function mapRekom(v) {
  if (empty(v)) return null;
  const t = v.trim().toLowerCase();
  return { replacement: 'Replacement', distribusi: 'Distribusi', hold: 'Hold' }[t] || null;
}
function mapPenilaian(v) {
  if (empty(v)) return null;
  const t = v.trim().toLowerCase();
  if (t === 'sesuai sni') return 'Sesuai SNI';
  if (t === 'tidak sesuai sni') return 'Tidak Sesuai SNI';
  return null;
}
function mapHasil(v) {
  if (empty(v)) return null;
  const t = v.trim().toLowerCase();
  return { positif: 'Positif', negatif: 'Negatif', dubius: 'Dubius' }[t] || null;
}
function mapDist(v) {
  if (empty(v)) return null;
  const set = ['Lokal', 'Keluar Daerah', 'Teregistrasi', 'Jual SNI'];
  return set.find(s => s.toLowerCase() === v.trim().toLowerCase()) || null;
}
function mapDerajat(v) {
  const d = String(v || '').trim();
  return ['1', '2', '3', '4'].includes(d) ? d : null;
}
function mapPeriode(v) {
  if (empty(v)) return null;
  const set = ['Lahir', 'Sapih', '9 Bulan', '12 Bulan', '15 Bulan', '18 Bulan', '21 Bulan', '24 Bulan'];
  return set.find(s => s.toLowerCase() === v.trim().toLowerCase()) || null;
}
function num(v) {
  if (empty(v)) return null;
  const n = parseFloat(String(v).replace(/,/g, '.').replace(/[^0-9.\-]/g, ''));
  return isNaN(n) ? null : n;
}
function harga(v) {
  if (empty(v)) return null;
  const n = parseInt(String(v).replace(/[^0-9]/g, ''), 10);
  return isNaN(n) ? null : n;
}
function bulan(v) {
  if (empty(v)) return null;
  const m = String(v).match(/\d+/);
  return m ? parseInt(m[0], 10) : null;
}
function clean(v) { return empty(v) ? null : v.trim(); }
function parsePerms(v) {
  if (empty(v)) return [];
  try { const a = JSON.parse(v); return Array.isArray(a) ? a : []; } catch { return []; }
}

// ---------- INSERT ----------
async function insertRows(table, rows, opts = {}) {
  const { chunk = 500, upsert = false, onConflict } = opts;
  let ok = 0; const errors = [];
  for (let i = 0; i < rows.length; i += chunk) {
    const slice = rows.slice(i, i + chunk);
    const res = upsert
      ? await supabase.from(table).upsert(slice, { onConflict }).select()
      : await supabase.from(table).insert(slice).select();
    if (res.error) {
      // isolasi per baris untuk baris yang bermasalah
      for (const r of slice) {
        const rr = upsert
          ? await supabase.from(table).upsert(r, { onConflict }).select()
          : await supabase.from(table).insert(r).select();
        if (rr.error) { if (errors.length < 15) errors.push(rr.error.message + ' :: ' + JSON.stringify(r).slice(0, 160)); }
        else ok++;
      }
    } else ok += slice.length;
  }
  return { ok, errors };
}
function report(name, total, ok, skipped, errors) {
  console.log(`  ${name}: ${ok}/${total} masuk` + (skipped ? `, ${skipped} dilewati` : '') + (errors.length ? `, ${errors.length} error` : ''));
  errors.slice(0, 5).forEach(e => console.log('     ! ' + e));
}

// ---------- STATE (dibangun antar-langkah) ----------
const state = {
  lokasiByName: {},   // nama_lokasi(lower) -> id_lokasi(uuid)
  usernameMap: {},    // old username(lower) -> id_user(uuid)
  ternakEartags: new Set(),
  laporMap: {},       // old id_lapor -> new uuid
  usedEmails: new Set(),
};
function resolveUser(v) {
  if (empty(v)) return null;
  return state.usernameMap[v.trim().toLowerCase()] || null;
}
function lokasiId(name) {
  if (empty(name)) return null;
  return state.lokasiByName[name.trim().toLowerCase()] || null;
}

// ============================================================
// LANGKAH-LANGKAH
// ============================================================
const steps = {};

steps.ref_lokasi = async () => {
  const { data: existing } = await supabase.from('ref_lokasi').select('id_lokasi,nama_lokasi');
  if (existing && existing.length) {
    existing.forEach(l => { state.lokasiByName[l.nama_lokasi.trim().toLowerCase()] = l.id_lokasi; });
    console.log(`  ref_lokasi: sudah ada ${existing.length} (lewati insert, rebuild map)`);
    return;
  }
  const rows = load('Ref_Lokasi.csv');
  const payload = rows.map(r => ({
    nama_lokasi: r.nama_lokasi, nama_blok: clean(r.nama_blok),
    status: (r.status && r.status.toLowerCase().includes('tidak')) ? 'Tidak Aktif' : 'Aktif'
  }));
  const res = await supabase.from('ref_lokasi').insert(payload).select();
  if (res.error) { console.log('  ref_lokasi ERROR: ' + res.error.message); return; }
  res.data.forEach(l => { state.lokasiByName[l.nama_lokasi.trim().toLowerCase()] = l.id_lokasi; });
  console.log(`  ref_lokasi: ${res.data.length}/${rows.length} masuk`);
};

async function findUserByEmail(email) {
  let page = 1;
  for (;;) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 200 });
    if (error || !data || !data.users.length) return null;
    const hit = data.users.find(u => (u.email || '').toLowerCase() === email.toLowerCase());
    if (hit) return hit.id;
    if (data.users.length < 200) return null;
    page++;
  }
}
function makeEmail(u) {
  if (/@/.test(u)) { const e = u.toLowerCase(); state.usedEmails.add(e); return e; }
  let base = u.toLowerCase().normalize('NFKD').replace(/[^a-z0-9._-]/g, '');
  if (!base) base = 'user';
  let email = `${base}@${DOMAIN}`, n = 2;
  while (state.usedEmails.has(email)) { email = `${base}-${n}@${DOMAIN}`; n++; }
  state.usedEmails.add(email);
  return email;
}
steps.users = async () => {
  const rows = load('user.csv');
  const creds = [['old_username', 'old_password', 'email_baru', 'password_baru', 'role']];
  let ok = 0; const errors = [];
  for (const r of rows) {
    const email = makeEmail(r.username);
    const pw = (r.password && r.password.trim().length >= 6) ? r.password.trim() : DEFAULT_PW;
    let userId = null;
    const c = await supabase.auth.admin.createUser({ email, password: pw, email_confirm: true });
    if (c.error) {
      if (/registered|already|exists/i.test(c.error.message)) userId = await findUserByEmail(email);
      if (!userId) { if (errors.length < 15) errors.push(`auth ${email}: ${c.error.message}`); continue; }
    } else userId = c.data.user.id;
    const up = await supabase.from('users').upsert({
      id_user: userId, username: email, password_hash: r.password || 'migrated',
      role: r.role, status: r.status && r.status.toLowerCase().includes('tidak') ? 'Tidak Aktif' : 'Aktif',
      permissions: parsePerms(r.permissions)
    }, { onConflict: 'username' }).select();
    if (up.error) { if (errors.length < 15) errors.push(`users ${email}: ${up.error.message}`); continue; }
    state.usernameMap[r.username.trim().toLowerCase()] = userId;
    creds.push([r.username, r.password, email, pw, r.role]);
    ok++;
  }
  // simpan kredensial baru
  const csv = creds.map(row => row.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
  fs.writeFileSync(path.join(OUT_DIR, 'users_login_baru.csv'), csv, 'utf8');
  report('users', rows.length, ok, 0, errors);
  console.log('     -> kredensial baru disimpan di migration/json/users_login_baru.csv');
};

steps.petugas = async () => {
  const rows = load('Petugas Reproduksi Keswan.csv');
  const repro = rows.filter(r => (r.id_petugas || '').toUpperCase().startsWith('PR'))
    .map(r => ({ nama_petugas: r.nama_petugas, jabatan: clean(r.jabatan), input_by: resolveUser(r.input_by) }));
  const keswan = rows.filter(r => (r.id_petugas || '').toUpperCase().startsWith('PK'))
    .map(r => ({ nama_petugas: r.nama_petugas, jabatan: clean(r.jabatan), input_by: resolveUser(r.input_by) }));
  let res = await insertRows('petugas_reproduksi', repro);
  report('petugas_reproduksi', repro.length, res.ok, 0, res.errors);
  res = await insertRows('petugas_keswan', keswan);
  report('petugas_keswan', keswan.length, res.ok, 0, res.errors);
};

steps.bull = async () => {
  const rows = load('Database Bull.csv');
  const payload = rows.map(r => ({
    nama_bull: r.nama_bull, rumpun: mapRumpun(r.rumpun), asal: clean(r.asal),
    stok_awal: parseInt(r.stok_awal || '0', 10) || 0,
    stok_saat_ini: parseInt(r.stok_saat_ini || '0', 10) || 0,
    input_by: resolveUser(r.input_by)
  }));
  const res = await insertRows('bull', payload);
  report('bull', rows.length, res.ok, 0, res.errors);
};

steps.ternak = async () => {
  const rows = load('Database Ternak.csv');
  const seen = new Set(); const objs = []; let skipped = 0; let coerced = 0;
  const SENTINEL_TGL = '1900-01-01'; // penanda tanggal lahir kosong
  for (const r of rows) {
    const eartag = (r.id_ternak || '').trim().toUpperCase();
    if (!eartag || seen.has(eartag)) { skipped++; continue; }
    let tgl = parseDate(r.tanggal_lahir);
    let sex = normSex(r.jenis_kelamin);
    let coercedRow = false;
    if (!tgl) { tgl = SENTINEL_TGL; coercedRow = true; }   // isi pengganti supaya tetap valid
    if (!sex) { sex = 'Betina'; coercedRow = true; }        // default kalau kosong
    if (coercedRow) coerced++;
    seen.add(eartag);
    objs.push({
      _induk: (clean(r.induk) || '').toUpperCase() || null,
      row: {
        eartag, rumpun_ternak: mapRumpun(r.rumpun_ternak), tanggal_lahir: tgl, jenis_kelamin: sex,
        bapak: clean(r.bapak), induk: null, status_ternak: mapStatusTernak(r.status_ternak),
        registrasi: mapRegistrasi(r.registrasi), tanggal_kejadian: parseDate(r.tanggal_kejadian),
        lokasi_saat_ini: lokasiId(r.lokasi_saat_ini), catatan: clean(r.catatan), input_by: resolveUser(r.input_by)
      }
    });
  }
  const res = await insertRows('ternak', objs.map(o => o.row), { upsert: true, onConflict: 'eartag' });
  objs.forEach(o => state.ternakEartags.add(o.row.eartag));
  report('ternak (fase 1)', rows.length, res.ok, skipped + coerced, res.errors);
  if (coerced) console.log(`     (${coerced} baris ber-tanggal/kelamin kosong diisi pengganti: tgl 1900-01-01 / kelamin Betina)`);
  // fase 2: set induk yang valid (baris tetap masuk walaupun induk tak ditemukan)
  const ph2 = objs.filter(o => o._induk && state.ternakEartags.has(o._induk))
    .map(o => ({ ...o.row, induk: o._induk }));
  if (ph2.length) {
    const r2 = await insertRows('ternak', ph2, { upsert: true, onConflict: 'eartag' });
    console.log(`  ternak (fase 2 induk): ${r2.ok}/${ph2.length} baris di-update`);
  }
};

// filter baris berdasar eartag yang ada di ternak
function filterByEartag(rows, key) {
  const kept = [], skipped = [];
  for (const r of rows) {
    const e = (r[key] || '').trim().toUpperCase();
    (e && state.ternakEartags.has(e) ? kept : skipped).push(r);
  }
  return { kept, skippedCount: skipped.length };
}

steps.laporan_berahi = async () => {
  const rows = load('Laporan Berahi.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  const payload = kept.map(r => {
    const id = crypto.randomUUID();
    state.laporMap[r.id_lapor] = id;
    return {
      id_lapor: id, tanggal_lapor: parseDate(r.tanggal_lapor), eartag: r.eartag.trim().toUpperCase(),
      rumpun: mapRumpun(r.rumpun), derajat_berahi: mapDerajat(r.derajat_berahi),
      rekomendasi: clean(r.rekomendasi), keterangan: clean(r.keterangan),
      status_ib: (r.status_ib || '').toLowerCase() === 'sudah' ? 'Sudah' : 'Belum',
      input_by: resolveUser(r.input_by)
    };
  });
  const res = await insertRows('laporan_berahi', payload);
  report('laporan_berahi', rows.length, res.ok, skippedCount, res.errors);
};

steps.ib = async () => {
  const rows = load('Database IB.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  const payload = kept.map(r => ({
    id_lapor: state.laporMap[r.id_lapor] || null, tanggal_ib: parseDate(r.tanggal_ib), eartag: r.eartag.trim().toUpperCase(),
    rumpun: mapRumpun(r.rumpun), derajat_berahi: mapDerajat(r.derajat_berahi),
    nama_bull: r.nama_bull || '-', inseminator: r.inseminator || '-', input_by: resolveUser(r.input_by)
  }));
  const res = await insertRows('ib', payload);
  report('ib', rows.length, res.ok, skippedCount, res.errors);
};

steps.kebuntingan = async () => {
  const rows = load('Database Kebuntingan.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  const payload = kept.map(r => ({
    eartag: r.eartag.trim().toUpperCase(), rumpun: mapRumpun(r.rumpun), tanggal_ib: parseDate(r.tanggal_ib),
    tanggal_pemeriksaan: parseDate(r.tanggal_pemeriksaan), hasil_pemeriksaan: mapHasil(r.hasil_pemeriksaan),
    prediksi_bulan: bulan(r.prediksi_bulan), hpl: parseDate(r.hpl), petugas_pemeriksa: clean(r.petugas_pemeriksa),
    link_foto_pkb: null, input_by: resolveUser(r.input_by)
  }));
  const res = await insertRows('kebuntingan', payload);
  report('kebuntingan', rows.length, res.ok, skippedCount, res.errors);
};

steps.kelahiran = async () => {
  const rows = load('Database Kelahiran.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag_induk');
  const seen = new Set(); let dup = 0;
  const payload = [];
  for (const r of kept) {
    const anak = (r.eartag_anak || '').trim().toUpperCase();
    if (!anak || seen.has(anak)) { dup++; continue; }
    seen.add(anak);
    payload.push({
      tanggal_lahir: parseDate(r.tanggal_lahir), eartag_induk: r.eartag_induk.trim().toUpperCase(),
      rumpun_induk: mapRumpun(r.rumpun_induk), eartag_anak: anak, jenis_kelamin: normSex(r.jenis_kelamin),
      rumpun_anak: mapRumpun(r.rumpun_anak), bapak: clean(r.bapak), link_foto: clean(r.link_foto),
      input_by: resolveUser(r.input_by)
    });
  }
  const res = await insertRows('kelahiran', payload);
  report('kelahiran', rows.length, res.ok, skippedCount + dup, res.errors);
};

steps.pengukuran = async () => {
  const rows = load('Database Pengukuran.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  const payload = kept.map(r => ({
        tanggal_ukur: parseDate(r.tanggal_ukur), eartag: r.eartag.trim().toUpperCase(), rumpun: mapRumpun(r.rumpun),
    sex: normSex(r.sex), tanggal_lahir: parseDate(r.tanggal_lahir), bapak: clean(r.bapak), induk: clean(r.induk),
    periode_ukur: mapPeriode(r.periode_ukur), panjang_badan: num(r.panjang_badan), lingkar_dada: num(r.lingkar_dada),
    tinggi_pundak: num(r.tinggi_pundak), berat_badan: num(r.berat_badan), lingkar_scrotum: num(r.lingkar_scrotum),
    penilaian_kualitatif: mapPenilaian(r.penilaian_kualitatif), keterangan: clean(r.keterangan),
    grade_sni: mapGrade(r.grade_sni), rekomendasi_seleksi: mapRekom(r.rekomendasi_seleksi),
    keterangan_audit_admin: clean(r.keterangan_audit_admin), input_by: resolveUser(r.input_by)
  }));
  const res = await insertRows('pengukuran', payload);
  report('pengukuran', rows.length, res.ok, skippedCount, res.errors);
};

steps.penjualan = async () => {
  const rows = load('Laporan Penjualan.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  const payload = kept.map(r => ({
    eartag: r.eartag.trim().toUpperCase(), rumpun: mapRumpun(r.rumpun), harga: harga(r.harga), tanggal_jual: parseDate(r.tanggal_jual),
    status_distribusi: mapDist(r.status_distribusi), no_billing: clean(r.no_billing), keterangan: clean(r.keterangan),
    input_by: resolveUser(r.input_by)
  }));
  const res = await insertRows('penjualan', payload);
  report('penjualan', rows.length, res.ok, skippedCount, res.errors);
};

steps.log_mutasi = async () => {
  const rows = load('Log_Mutasi.csv');
  const { kept, skippedCount } = filterByEartag(rows, 'eartag');
  let noLoc = 0; const payload = [];
  for (const r of kept) {
    const lok = lokasiId(r.lokasi_saat_ini);
    if (!lok) { noLoc++; continue; } // lokasi_saat_ini NOT NULL
    payload.push({
      tanggal_mutasi: parseDate(r.tanggal_mutasi), eartag: r.eartag.trim().toUpperCase(), dari_lokasi: clean(r.dari_lokasi),
      lokasi_saat_ini: lok, alasan: clean(r.alasan), input_by: resolveUser(r.input_by)
    });
  }
  const res = await insertRows('log_mutasi', payload);
  report('log_mutasi', rows.length, res.ok, skippedCount + noLoc, res.errors);
};

steps.ref_sni = async () => {
  const p = path.join(CSV_DIR, 'ref_sni.csv');
  if (!fs.existsSync(p)) { console.warn('  (file tidak ada: ref_sni.csv)'); return; }
  const raw = fs.readFileSync(p, 'utf8').split(/\r?\n/).filter(l => l.trim());
  if (raw.length < 2) { console.log('  ref_sni: kosong'); return; }
  const h = raw[0].split(';').map(x => x.replace(/^\uFEFF/, '').trim());
  const idx = name => h.findIndex(c => c.toLowerCase().includes(name.toLowerCase()));
  const iRumpun = idx('rumpun'), iSex = idx('sex'), iPer = idx('periode'),
        iTP = idx('tinggi pundak'), iPB = idx('panjang badan'),
        iLD = idx('lingkar dada'), iLS = idx('lingkar scrotum'), iGrade = idx('grade');
  const rows = [];
  for (let i = 1; i < raw.length; i++) {
    const c = raw[i].split(';').map(x => x.trim());
    const rumpun = mapRumpun(c[iRumpun]);
    const sex = normSex(c[iSex]);
    if (!sex) continue;
    const per = (c[iPer] || '').match(/(\d+)\s*-\s*(\d+)/);
    if (!per) continue;
    const grade = parseInt(c[iGrade], 10);
    if (![1, 2, 3].includes(grade)) continue;
    rows.push({
      rumpun, jenis_kelamin: sex,
      periode_bulan_min: parseInt(per[1], 10),
      periode_bulan_max: parseInt(per[2], 10),
      grade,
      tp_min: num(c[iTP]), pb_min: num(c[iPB]), ld_min: num(c[iLD]), ls_min: num(c[iLS])
    });
  }
  if (!rows.length) { console.log('  ref_sni: tidak ada baris valid'); return; }
  const res = await insertRows('ref_sni', rows, {
    upsert: true,
    onConflict: 'rumpun,jenis_kelamin,periode_bulan_min,periode_bulan_max,grade'
  });
  report('ref_sni', rows.length, res.ok, 0, res.errors);
};

// ---------- MAIN ----------
const ORDER = ['ref_sni', 'ref_lokasi', 'users', 'petugas', 'bull', 'ternak',
  'laporan_berahi', 'ib', 'kebuntingan', 'kelahiran', 'pengukuran', 'penjualan', 'log_mutasi'];

async function main() {
  const only = process.argv[2];
  console.log('\n🔄 MIGRASI SISCOPATAS -> Supabase');
  console.log('   URL:', SUPABASE_URL);
  const list = only ? [only] : ORDER;
  // pre-load state jika menjalankan sebagian (butuh lokasi/user/ternak)
  if (only && only !== 'ref_lokasi') await preloadState();
  for (const s of list) {
    if (!steps[s]) { console.log('  (langkah tidak dikenal: ' + s + ')'); continue; }
    console.log('\n== ' + s + ' ==');
    await steps[s]();
  }
  console.log('\n✅ Selesai.\n');
}

// bila menjalankan langkah tertentu, isi ulang map dari DB
async function preloadState() {
  const { data: loks } = await supabase.from('ref_lokasi').select('id_lokasi,nama_lokasi');
  (loks || []).forEach(l => state.lokasiByName[l.nama_lokasi.trim().toLowerCase()] = l.id_lokasi);
  const { data: us } = await supabase.from('users').select('id_user,username');
  (us || []).forEach(u => state.usernameMap[u.username.trim().toLowerCase()] = u.id_user);
  const { data: tn } = await supabase.from('ternak').select('eartag');
  (tn || []).forEach(t => state.ternakEartags.add(t.eartag));
  const { data: lb } = await supabase.from('laporan_berahi').select('id_lapor');
  // laporMap tidak bisa direkonstruksi (id lama hilang) -> id_lapor pada ib akan null bila jalan terpisah
}

main().catch(e => { console.error('FATAL:', e); process.exit(1); });
