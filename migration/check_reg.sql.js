const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const { data, error } = await sb.from('ternak').select('registrasi').limit(99999);
  if (error) { console.log('ERR', error.message); return; }
  const cnt = {};
  data.forEach(r => { const k = r.registrasi || 'NULL'; cnt[k] = (cnt[k]||0)+1; });
  console.log('Jumlah ternak:', data.length);
  console.log('Distribusi registrasi:', JSON.stringify(cnt, null, 0));
})();
