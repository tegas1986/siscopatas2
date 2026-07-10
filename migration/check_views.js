const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const r1 = await sb.from('v_ternak').select('eartag,status_ternak,kategori').limit(3);
  console.log('v_ternak sample:', r1.error ? ('ERR ' + r1.error.message) : JSON.stringify(r1.data));
  const c1 = await sb.from('v_ternak').select('*', { count: 'exact', head: true });
  console.log('v_ternak count:', c1.error ? ('ERR ' + c1.error.message) : c1.count);
  const c2 = await sb.from('ternak').select('*', { count: 'exact', head: true });
  console.log('ternak count:', c2.error ? ('ERR ' + c2.error.message) : c2.count);
  // coba dari app anon key (frontend pakai anon) - simulasi RLS baca
})();
