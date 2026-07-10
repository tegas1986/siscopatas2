const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const tables = ['v_ternak','ternak','ib','pengukuran','laporan_berahi','bull','ref_lokasi','penjualan','log_mutasi','kebuntingan','kelahiran','petugas_reproduksi','petugas_keswan','users'];
(async () => {
  for (const t of tables) {
    const { data, error } = await sb.from(t).select('*').order('created_at', { ascending: false }).limit(1);
    if (error) console.log(`${t}: ERROR -> ${error.message}`);
    else console.log(`${t}: OK rows=${data.length} created_at_field=${data.length? (data[0].created_at!==undefined?'ada':'TIDAK ADA'):'n/a'}`);
  }
})();
