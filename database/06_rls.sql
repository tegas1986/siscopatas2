-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 06: Row Level Security (RLS)
-- ============================================================
-- RLS mengamankan data di level baris.
-- Setiap user hanya bisa mengakses data sesuai role-nya.
--
-- Cara kerja:
-- 1. Supabase Auth → JWT token → auth.jwt() ->> 'role'
-- 2. Role dibaca dari JWT claim "role"
-- 3. Policy membandingkan role dengan operasi yang diijinkan
--
-- PENTING: JWT role claim harus di-set saat signup.
-- Lihat trigger di file 07_seed_data.sql
-- ============================================================

-- ============================================================
-- Helper function: Mendapatkan role user saat ini dari JWT
-- ============================================================
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        (auth.jwt() ->> 'role')::user_role,
        'Viewer'::user_role
    );
$$;

-- ============================================================
-- Helper function: Cek permission menu
-- ============================================================
CREATE OR REPLACE FUNCTION has_menu_permission(menu_id TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1 FROM users
        WHERE username = auth.jwt() ->> 'email'
          AND (permissions @> ('["' || menu_id || '"]')::jsonb
               OR role = 'Super Admin')
    );
$$;

-- ============================================================
-- ENABLE RLS di SEMUA tabel
-- ============================================================
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

-- ============================================================
-- POLICY: Super Admin → FULL ACCESS ke semua tabel
-- ============================================================
CREATE POLICY "super_admin_all" ON users FOR ALL USING (current_user_role() = 'Super Admin');

-- POLICY: User bisa insert dirinya sendiri (untuk auto-create saat login pertama)
CREATE POLICY "users_insert_own" ON users FOR INSERT WITH CHECK (id_user = auth.uid());
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

-- ============================================================
-- POLICY: Admin Wasbit
-- CRUD penuh pada tabel reproduksi, performans, bull, lokasi, petugas
-- ============================================================
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

-- ============================================================
-- POLICY: User Wasbit
-- Bisa INSERT + SELECT, tapi tidak bisa UPDATE/DELETE data lama
-- ============================================================
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

-- ============================================================
-- POLICY: Admin Keswan
-- CRUD pada tabel keswan + gangrep
-- ============================================================
CREATE POLICY "admin_keswan" ON keswan FOR ALL USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan" ON laporan_gangrep FOR ALL USING (current_user_role() = 'Admin Keswan');

CREATE POLICY "admin_keswan_select" ON ternak FOR SELECT USING (current_user_role() = 'Admin Keswan');
CREATE POLICY "admin_keswan_select" ON petugas_keswan FOR SELECT USING (current_user_role() = 'Admin Keswan');

-- ============================================================
-- POLICY: User Keswan
-- INSERT + SELECT pada keswan + gangrep (tidak bisa edit data lama)
-- ============================================================
CREATE POLICY "user_keswan_select" ON keswan FOR SELECT USING (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_insert" ON keswan FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');

CREATE POLICY "user_keswan_select" ON laporan_gangrep FOR SELECT USING (current_user_role() = 'User Keswan');
CREATE POLICY "user_keswan_insert" ON laporan_gangrep FOR INSERT WITH CHECK (current_user_role() = 'User Keswan');

CREATE POLICY "user_keswan_select" ON ternak FOR SELECT USING (current_user_role() = 'User Keswan');

-- ============================================================
-- POLICY: Admin IJP
-- CRUD pada tabel penjualan + SELECT pada BAS
-- ============================================================
CREATE POLICY "admin_ijp" ON penjualan FOR ALL USING (current_user_role() = 'Admin IJP');
CREATE POLICY "admin_ijp_select" ON ternak FOR SELECT USING (current_user_role() = 'Admin IJP');
CREATE POLICY "admin_ijp_select" ON pengukuran FOR SELECT USING (current_user_role() = 'Admin IJP');

-- ============================================================
-- POLICY: User IJP
-- INSERT + SELECT pada penjualan
-- ============================================================
CREATE POLICY "user_ijp_select" ON penjualan FOR SELECT USING (current_user_role() = 'User IJP');
CREATE POLICY "user_ijp_insert" ON penjualan FOR INSERT WITH CHECK (current_user_role() = 'User IJP');
CREATE POLICY "user_ijp_select" ON ternak FOR SELECT USING (current_user_role() = 'User IJP');

-- ============================================================
-- POLICY: Viewer
-- Hanya SELECT pada tabel yang diizinkan
-- ============================================================
CREATE POLICY "viewer_select_ternak" ON ternak FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_pengukuran" ON pengukuran FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_laporan_berahi" ON laporan_berahi FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_ib" ON ib FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_kebuntingan" ON kebuntingan FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_kelahiran" ON kelahiran FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_bull" ON bull FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_ref_lokasi" ON ref_lokasi FOR SELECT USING (current_user_role() = 'Viewer');
CREATE POLICY "viewer_select_penjualan" ON penjualan FOR SELECT USING (current_user_role() = 'Viewer');

-- ============================================================
-- POLICY khusus: Admin Wasbit bisa override BAS (Super Admin juga)
-- ============================================================
CREATE POLICY "admin_wasbit_update_pengukuran_audit" ON pengukuran 
    FOR UPDATE USING (current_user_role() IN ('Super Admin', 'Admin Wasbit'))
    WITH CHECK (current_user_role() IN ('Super Admin', 'Admin Wasbit'));

-- ============================================================
-- VERIFIKASI:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd 
-- FROM pg_policies WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
-- ============================================================
