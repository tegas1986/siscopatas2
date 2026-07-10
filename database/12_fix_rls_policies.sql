-- ============================================================
-- SISCOPATAS - RLS: semua user login boleh BACA, batas menu di permissions
-- File 12 (revisi): ubah model akses baca -> semua user terautentikasi
-- ============================================================
-- JALANKAN DI Supabase Dashboard -> SQL Editor -> Run.
-- Aman dijalankan berulang kali (DROP POLICY IF EXISTS + CREATE).
--
-- PRINSIP BARU:
--   * BACA (SELECT): BOLEH untuk SEMUA user yang sudah login
--     (auth.uid() IS NOT NULL). Pembatasan tampilan menu (& pencarian)
--     dilakukan lewat kolom permissions di tabel users (manajemen user),
--     BUKAN lewat RLS.
--   * TULIS (INSERT/UPDATE/DELETE): tetap mengikuti role (kebijakan
--     per-role di bawah), sesuai desain semula.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Function current_user_role() & has_menu_permission()
--    (tetap dipakai untuk kebijakan TULIS dan pengecekan menu)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- 2. ENABLE RLS di semua tabel (idempoten)
-- ------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE petugas_reproduksi ENABLE ROW LEVEL SECURITY;
ALTER TABLE petugas_keswan ENABLE ROW LEVEL SECURITY;
ALTER TABLE bull ENABLE ROW LEVEL SECURITY;
ALTER TABLE ref_lokasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE ternak ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_mutasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE laporan_berahi ENABLE ROW LEVEL SECURITY;
ALTER TABLE ib ENABLE ROW LEVEL SECURITY;
ALTER TABLE keswan ENABLE ROW LEVEL SECURITY;
ALTER TABLE laporan_gangrep ENABLE ROW LEVEL SECURITY;
ALTER TABLE kebuntingan ENABLE ROW LEVEL SECURITY;
ALTER TABLE kelahiran ENABLE ROW LEVEL SECURITY;
ALTER TABLE pengukuran ENABLE ROW LEVEL SECURITY;
ALTER TABLE penjualan ENABLE ROW LEVEL SECURITY;
ALTER TABLE ref_sni ENABLE ROW LEVEL SECURITY;
ALTER TABLE eartag_pasang ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_audit_eartag ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 3. Hapus semua policy lama lalu buat ulang
-- ------------------------------------------------------------
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;',
      r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- ============================================================
-- 4. BACA: semua user login boleh SELECT ( satu policy per tabel )
-- ============================================================
CREATE POLICY "read_authenticated" ON users FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON petugas_reproduksi FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON petugas_keswan FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON bull FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON ref_lokasi FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON ternak FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON log_mutasi FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON laporan_berahi FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON ib FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON keswan FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON laporan_gangrep FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON kebuntingan FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON kelahiran FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON pengukuran FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON penjualan FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON ref_sni FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON eartag_pasang FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "read_authenticated" ON log_audit_eartag FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================
-- 5. TULIS: kebijakan per-role (INSERT/UPDATE/DELETE)
-- ============================================================

-- USERS
CREATE POLICY "super_admin_all" ON users FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "users_insert_own" ON users FOR INSERT WITH CHECK (id_user = auth.uid());

-- SUPER ADMIN: akses penuh semua tabel data
CREATE POLICY "super_admin_all" ON petugas_reproduksi FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON petugas_keswan FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON bull FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON ref_lokasi FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON ternak FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON log_mutasi FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON laporan_berahi FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON ib FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON keswan FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON laporan_gangrep FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON kebuntingan FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON kelahiran FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON pengukuran FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON penjualan FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON ref_sni FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON eartag_pasang FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "super_admin_all" ON log_audit_eartag FOR ALL USING (current_user_role() = 'Super Admin');

-- ADMIN WASBIT: CRUD penuh data reproduksi & terkait
CREATE POLICY "admin_wasbit_insert" ON ternak FOR INSERT WITH CHECK (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_update" ON ternak FOR UPDATE USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_delete" ON ternak FOR DELETE USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_insert" ON pengukuran FOR INSERT WITH CHECK (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_update" ON pengukuran FOR UPDATE USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_delete" ON pengukuran FOR DELETE USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON laporan_berahi FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON ib FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON kebuntingan FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON kelahiran FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON bull FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON petugas_reproduksi FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON ref_lokasi FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON log_mutasi FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON eartag_pasang FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON ref_sni FOR ALL USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit" ON log_audit_eartag FOR ALL USING (current_user_role() = 'Admin Wasbit');

-- USER WASBIT: bisa INSERT + SELECT, tidak bisa ubah/hapus data lama
CREATE POLICY "user_wasbit_insert" ON ternak FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert" ON pengukuran FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_berahi" ON laporan_berahi FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_ib" ON ib FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_pkb" ON kebuntingan FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_kelahiran" ON kelahiran FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');

-- ADMIN KESWAN
CREATE POLICY "admin_keswan" ON keswan FOR ALL USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan" ON laporan_gangrep FOR ALL USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan_update" ON ternak FOR UPDATE USING (current_user_role() = 'Admin Keswan');

-- USER KESWAN
CREATE POLICY "user_keswan_insert" ON keswan FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_insert" ON laporan_gangrep FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');

-- ADMIN IJP
CREATE POLICY "admin_ijp" ON penjualan FOR ALL USING (current_user_role() = 'Admin IJP');
CREATE POLICY "admin_ijp_update" ON pengukuran FOR UPDATE USING (current_user_role() = 'Admin IJP');

-- USER IJP
CREATE POLICY "user_ijp_insert" ON penjualan FOR INSERT WITH CHECK (current_user_role() = 'User IJP');

-- OVERRIDE BAS (pengukuran) oleh Super Admin / Admin Wasbit
CREATE POLICY "admin_wasbit_update_pengukuran_audit" ON pengukuran
    FOR UPDATE USING (current_user_role() IN ('Super Admin', 'Admin Wasbit'))
    WITH CHECK (current_user_role() IN ('Super Admin', 'Admin Wasbit'));

-- ============================================================
-- VERIFIKASI (query terpisah di SQL Editor):
-- SELECT tablename, policyname, cmd, qual
-- FROM pg_policies WHERE schemaname='public'
-- ORDER BY tablename, policyname;
-- Setiap tabel punya policy "read_authenticated" (cmd=SELECT, qual: auth.uid() IS NOT NULL).
-- ============================================================
