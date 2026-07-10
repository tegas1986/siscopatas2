const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const { data: lm } = await sb.from('log_mutasi').select('eartag,lokasi_saat_ini').limit(3);
  console.log('log_mutasi sample:', JSON.stringify(lm));
  const { data: loks } = await sb.from('ref_lokasi').select('id_lokasi,nama_lokasi').limit(2);
  console.log('ref_lokasi sample:', JSON.stringify(loks));
})();
