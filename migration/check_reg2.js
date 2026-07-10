const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const { count } = await sb.from('ternak').select('*', { count: 'exact', head: true });
  console.log('TOTAL ternak:', count);
  let from = 0, aset = 0, pers = 0, nullc = 0; const other = {};
  for (;;) {
    const { data } = await sb.from('ternak').select('registrasi').range(from, from + 999);
    if (!data || !data.length) break;
    data.forEach(r => { const v = (r.registrasi || '').trim();
      if (v === 'Aset') aset++; else if (v === 'Persediaan') pers++; else if (!v) nullc++; else other[v] = (other[v]||0)+1; });
    if (data.length < 1000) break; from += 1000;
  }
  console.log('Aset:', aset, '| Persediaan:', pers, '| Kosong:', nullc, '| Lain:', JSON.stringify(other));
})();
