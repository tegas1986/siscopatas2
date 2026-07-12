const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const env = {};
for (const l of fs.readFileSync('.env', 'utf8').split(/\r?\n/)) {
  const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const sb = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
(async () => {
  const { data, error } = await sb.from('ref_sni').select('*').limit(3);
  console.log('ERROR:', JSON.stringify(error));
  console.log('ROWS:', data ? data.length : 'null');
  if (data && data.length) {
    console.log('FIRST ROW KEYS:', Object.keys(data[0]).join(', '));
    console.log('FIRST ROW:', JSON.stringify(data[0]));
  }
})();
