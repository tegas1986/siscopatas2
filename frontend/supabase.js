/**
 * ============================================================
 * SISCOPATAS - Supabase Client Configuration
 * ============================================================
 * 
 * Cara pakai:
 * 1. Ganti SUPABASE_URL dan SUPABASE_ANON_KEY dengan milikmu
 *    (dapat dari Settings → API di Supabase Dashboard)
 * 2. Import file ini di index.html sebelum script Vue.js
 * 3. Gunakan 'supabaseClient' global di seluruh aplikasi
 * ============================================================
 * 
 * NOTE: Karena aplikasi ini berjalan di Blogger (tanpa build tool),
 * Supabase JS Client di-load via CDN:
 *   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"/>
 * 
 * Variabel global 'supabase' tersedia setelah CDN di-load.
 * ============================================================
 */

// ============================================================
// 🔴 GANTI DENGAN MILIKMU!
// ============================================================
const SUPABASE_URL = 'https://xeafoechdhogteqcvdsm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYWZvZWNoZGhvZ3RlcWN2ZHNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MDc4NjcsImV4cCI6MjA5OTE4Mzg2N30.PGSKmclW5Uj89BKJJ6GsjxBGEe-svLN8kW3Rr3-4cW8';

// ============================================================
// Inisialisasi Supabase Client
// ============================================================
const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false  // Blogger tidak pakai URL redirect
    },
    realtime: {
        params: {
            eventsPerSecond: 10
        }
    }
});

// ============================================================
// EXPORT (via global variable - karena tidak ada module system)
// ============================================================
// Di frontend/index.html, akses via: window.supabaseClient
// Atau langsung: supabaseClient
