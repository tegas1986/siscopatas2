-- ============================================================
-- SISCOPATAS - Perbaikan Bug Login (RLS)
-- File 08: Fix current_user_role() + policy baca data sendiri
-- ============================================================
-- Jalankan file ini di Supabase SQL Editor SETELAH file 06_rls.sql.
--
-- Memperbaiki 2 bug yang membuat login gagal:
--   BUG #1: current_user_role() membaca (auth.jwt() ->> 'role')
--           padahal claim itu selalu bernilai 'authenticated'
--           (role Postgres), BUKAN role aplikasi (Super Admin, dll).
--           Casting 'authenticated'::user_role -> ERROR.
--   BUG #2: Tidak ada policy yang mengizinkan user membaca barisnya
--           sendiri di tabel users, sehingga saat login muncul
--           "User tidak ditemukan di database".
-- ============================================================


-- ============================================================
-- FIX #1: current_user_role()
-- Baca role dari tabel public.users berdasarkan auth.uid().
-- SECURITY DEFINER = fungsi bypass RLS saat baca tabel users,
-- sehingga TIDAK terjadi rekursi tak terbatas dengan policy
-- yang memanggil fungsi ini.
-- ============================================================
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(
        (SELECT role FROM public.users WHERE id_user = auth.uid()),
        'Viewer'::user_role
    );
$$;


-- ============================================================
-- FIX #2: has_menu_permission()
-- Samakan pola: SECURITY DEFINER + cocokkan berdasarkan
-- id_user (auth.uid()) yang lebih andal daripada email.
-- ============================================================
CREATE OR REPLACE FUNCTION has_menu_permission(menu_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id_user = auth.uid()
          AND (permissions @> ('["' || menu_id || '"]')::jsonb
               OR role = 'Super Admin')
    );
$$;


-- ============================================================
-- FIX #3: Policy agar setiap user bisa membaca barisnya sendiri
-- di tabel users. Ini yang dibutuhkan frontend saat login:
--   supabaseClient.from('users').select('*').eq('username', ...)
-- ============================================================
DROP POLICY IF EXISTS "users_select_own" ON users;
CREATE POLICY "users_select_own" ON users
    FOR SELECT
    USING (id_user = auth.uid());


-- ============================================================
-- (Opsional) Izinkan user meng-update barisnya sendiri, mis.
-- untuk menyimpan preferensi. Aktifkan bila diperlukan.
-- ============================================================
-- DROP POLICY IF EXISTS "users_update_own" ON users;
-- CREATE POLICY "users_update_own" ON users
--     FOR UPDATE
--     USING (id_user = auth.uid())
--     WITH CHECK (id_user = auth.uid());


-- ============================================================
-- VERIFIKASI
-- ============================================================
-- 1. Cek fungsi sudah SECURITY DEFINER:
--    SELECT proname, prosecdef FROM pg_proc
--    WHERE proname IN ('current_user_role','has_menu_permission');
--    (prosecdef harus 't')
--
-- 2. Cek policy users:
--    SELECT policyname, cmd FROM pg_policies
--    WHERE schemaname='public' AND tablename='users';
--    (harus ada: super_admin_all, users_insert_own, users_select_own)
--
-- 3. Setelah login sebagai user, cek role terbaca benar:
--    SELECT current_user_role();
-- ============================================================
