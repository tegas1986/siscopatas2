const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
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
(async () => {
  const rows = parseCSV(fs.readFileSync('migration/csv/Database Ternak.csv', 'utf8'));
  const h = rows[0].map(x => x.replace(/^\uFEFF/, '').trim());
  const data = rows.slice(1).map(r => Object.fromEntries(h.map((x, i) => [x, (r[i] || '').trim()])));
  console.log('Baris fisik CSV:', data.length);
  const seen = {}, dups = [];
  for (const r of data) { const e = (r.id_ternak || '').toUpperCase(); if (seen[e]) dups.push(e); else seen[e] = 1; }
  console.log('Eartag unik:', Object.keys(seen).length);
  console.log('Eartag duplikat:', dups.length ? dups : 'TIDAK ADA');
  const { count } = await sb.from('ternak').select('*', { count: 'exact', head: true });
  console.log('Ternak di DB:', count);
})();
