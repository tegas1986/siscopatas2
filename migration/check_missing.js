const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const all = ['users','petugas_reproduksi','petugas_keswan','bull','ref_lokasi','ternak','log_mutasi',
  'laporan_berahi','ib','keswan','laporan_gangrep','kebuntingan','kelahiran','pengukuran','penjualan',
  'ref_sni','eartag_pasang','log_audit_eartag'];
(async () => {
  const missing = [];
  for (const t of all) {
    const { error } = await sb.from(t).select('*').order('created_at', { ascending: false }).limit(1);
    if (error && /created_at does not exist/.test(error.message)) missing.push(t);
  }
  console.log('Tabel yg MASIH kurang created_at:', missing.length ? missing.join(', ') : 'TIDAK ADA (semua OK)');
})();
