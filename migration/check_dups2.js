const fs = require('fs');
function parseCSV(t) {
  const rows = []; let f = '', row = [], q = false;
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (q) { if (c === '"') { if (t[i+1] === '"') { f += '"'; i++; } else q = false; } else f += c; }
    else { if (c === '"') q = true; else if (c === ',') { row.push(f); f = ''; } else if (c === '\r') {} else if (c === '\n') { row.push(f); rows.push(row); row = []; f = ''; } else f += c; }
  }
  if (f.length || row.length) { row.push(f); rows.push(row); }
  return rows.filter(r => r.some(v => v && v.trim()));
}
const rows = parseCSV(fs.readFileSync('migration/csv/Database Ternak.csv', 'utf8'));
const h = rows[0].map(x => x.replace(/^\uFEFF/, '').trim());
const data = rows.slice(1).map(r => Object.fromEntries(h.map((x, i) => [x, (r[i] || '').trim()])));

console.log('Baris fisik CSV:', data.length);
const seen = {}, dups = [];
for (const r of data) { const e = (r.id_ternak || '').toUpperCase(); if (seen[e]) dups.push(e); else seen[e] = 1; }
console.log('Eartag unik:', Object.keys(seen).length);
console.log('Eartag duplikat:', dups.length ? dups : 'TIDAK ADA');

console.log('\n=== Pengecekan baris duplikat (eartag + rumpun + kolom lain) ===');
for (const e of dups) {
  const rs = data.filter(r => (r.id_ternak || '').toUpperCase() === e);
  console.log(`\n>>> Eartag: ${e}  (muncul ${rs.length}x)`);
  rs.forEach((r, i) => {
    console.log(`  [${i+1}] rumpun="${r.rumpun_ternak}" tgl="${r.tanggal_lahir}" kelamin="${r.jenis_kelamin}" bapak="${r.bapak}" induk="${r.induk}" status="${r.status_ternak}" lokasi="${r.lokasi_saat_ini}"`);
  });
  // cek apakah semua atribut SAMA (true duplicate) atau berbeda (kemungkinan typo)
  const sig = rs.map(r => JSON.stringify([r.rumpun_ternak, r.tanggal_lahir, r.jenis_kelamin, r.bapak, r.induk, r.status_ternak, r.lokasi_saat_ini]));
  const allSame = sig.every(s => s === sig[0]);
  console.log(`  => ${allSame ? 'SELURUH ATRIBUT SAMA => DUPLIKAT ASLI (aman dilewati)' : 'ADA PERBEDAAN => KEMUNGKINAN TYPO/EARTAG BERBEDA (perlu dicek manual)'}`);
}
