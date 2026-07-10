-- ============================================================
-- SISCOPATAS - Re-create ALL RLS policies (idempotent)
-- File 12: FIX data tidak muncul di frontend
-- ============================================================
-- JALANKAN DI Supabase Dashboard -> SQL Editor -> Run.
-- Aman dijalankan berulang kali (DROP POLICY IF EXISTS + CREATE).
--
-- Gejala: lewat API (anon key + session login), SELECT ke semua
-- tabel mengembalikan 0 baris TANPA error -> RLS aktif tapi policy
-- baca tidak ada. Data sebenarnya ada (service_role bisa baca).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Function current_user_role() (baca dari public.users)
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
-- 3. Hapus semua policy lama (biar bersih) lalu buat ulang
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

-- ===================== USERS =====================
CREATE POLICY "super_admin_all" ON users FOR ALL USING (current_user_role() = 'Super Admin');
CREATE POLICY "users_insert_own" ON users FOR INSERT WITH CHECK (id_user = auth.uid());
CREATE POLICY "users_select_own" ON users FOR SELECT USING (id_user = auth.uid());

-- ===================== REPRODUKSI / DATA INTI =====================
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

-- ===================== ADMIN WASBIT =====================
CREATE POLICY "admin_wasbit_select" ON ternak FOR SELECT USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_insert" ON ternak FOR INSERT WITH CHECK (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_update" ON ternak FOR UPDATE USING (current_user_role() = 'Admin Wasbit');
CREATE POLICY "admin_wasbit_delete" ON ternak FOR DELETE USING (current_user_role() = 'Admin Wasbit');

CREATE POLICY "admin_wasbit_select" ON pengukuran FOR SELECT USING (current_user_role() = 'Admin Wasbit');
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

-- ===================== USER WASBIT =====================
CREATE POLICY "user_wasbit_select" ON ternak FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert" ON ternak FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON pengukuran FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert" ON pengukuran FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit" ON laporan_berahi FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_berahi" ON laporan_berahi FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit" ON ib FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_ib" ON ib FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit" ON kebuntingan FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_pkb" ON kebuntingan FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit" ON kelahiran FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_insert_kelahiran" ON kelahiran FOR INSERT WITH CHECK (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON bull FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON petugas_reproduksi FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON ref_lokasi FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON log_mutasi FOR SELECT USING (current_user_role() = 'User Wasbit');
CREATE POLICY "user_wasbit_select" ON ref_sni FOR SELECT USING (current_user_role() = 'User Wasbit');

-- ===================== ADMIN KESWAN =====================
CREATE POLICY "admin_keswan" ON keswan FOR ALL USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan" ON laporan_gangrep FOR ALL USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan_select" ON ternak FOR SELECT USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan_select" ON petugas_keswan FOR SELECT USING (current_user_role() = 'Admin Keswan');

-- ===================== USER KESWAN =====================
CREATE POLICY "user_keswan_select" ON keswan FOR SELECT USING (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_insert" ON keswan FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_select" ON laporan_gangrep FOR SELECT USING (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_insert" ON laporan_gangrep FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_select" ON ternak FOR SELECT USING (current_user_role() = 'User Keswan');

-- ===================== ADMIN IJP =====================
CREATE POLICY "admin_ijp" ON penjualan FOR ALL USING (current_user_role() = 'Admin IJP');
CREATE POLICY "admin_ijp_select" ON ternak FOR SELECT USING (current_user_role() = 'Admin IJP');
CREATE POLICY "admin_ijp_select" ON pengukuran FOR SELECT USING (current_user_role() = 'Admin IJP');

-- ===================== USER IJP =====================
CREATE POLICY "user_ijp_select" ON penjualan FOR SELECT USING (current_user_role() = 'User IJP');
CREATE POLICY "user_ijp_insert" ON penjualan FOR INSERT WITH CHECK (current_user_role() = 'User IJP');
CREATE POLICY "user_ijp_select" ON ternak FOR SELECT USING (current_user_role() = 'User IJP');

-- ===================== VIEWER =====================
CREATE POLICY "viewer_select_ternak" ON ternak FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_pengukuran" ON pengukuran FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_laporan_berahi" ON laporan_berahi FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_ib" ON ib FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_kebuntingan" ON kebuntingan FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_kelahiran" ON kelahiran FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_bull" ON bull FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_ref_lokasi" ON ref_lokasi FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_penjualan" ON penjualan FOR SELECT USING (current_user_role() = 'Viewer');

-- ===================== OVERRIDE BAS =====================
CREATE POLICY "admin_wasbit_update_pengukuran_audit" ON pengukuran
    FOR UPDATE USING (current_user_role() IN ('Super Admin', 'Admin Wasbit'))
    WITH CHECK (current_user_role() IN ('Super Admin', 'Admin Wasbit'));

-- ============================================================
-- VERIFIKASI (jalankan di SQL Editor terpisah):
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE schemaname='public' ORDER BY tablename, policyname;
-- Laporan Berahi minimal punya: super_admin_all, admin_wasbit,
-- user_wasbit, viewer_select_laporan_berahi.
-- ============================================================
