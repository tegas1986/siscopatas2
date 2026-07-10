const fs = require('fs'), path = require('path');
const { createClient } = require('@supabase/supabase-js');
const ROOT = path.join(__dirname, '..');
function loadEnv(){const e={};const p=path.join(ROOT,'.env');if(fs.existsSync(p))for(const l of fs.readFileSync(p,'utf8').split(/\r?\n/)){const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,'');}return e;}
const E = loadEnv();
const html = fs.readFileSync(path.join(ROOT,'frontend','index.html'),'utf8');
const m = html.match(/SUPABASE_ANON_KEY\s*=\s*'([^']+)'/);
const ANON = m ? m[1] : E.SUPABASE_ANON_KEY;
const sb = createClient(E.SUPABASE_URL, E.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const { data: auth, error } = await sb.auth.signInWithPassword({ email: 'wahyuni@siscopatas.com', password: '123456' });
  if (error) { console.log('login gagal:', error.message); return; }
  const token = auth.session.access_token;
  console.log('Login OK sebagai admin. User role (dari tabel users):');
  const { data: me } = await sb.from('users').select('username,role').eq('id_user', auth.user.id).single();
  console.log('  ', JSON.stringify(me));
  const userSb = createClient(E.SUPABASE_URL, ANON, { auth: { persistSession: false } });
  userSb.auth.session = { access_token: token, token_type: 'bearer', user: auth.user };
  // cara simpel: set header via .auth(token)
  const { data, error: e2, count } = await userSb.from('v_ternak').select('eartag', { count: 'exact' }).limit(5);
  console.log('Baca v_ternak sebagai user login:');
  console.log('  count:', count);
  console.log('  error:', e2 ? e2.message : 'NONE');
  console.log('  sample:', JSON.stringify(data));
})();
