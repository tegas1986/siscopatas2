-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 07: Seed Data (data awal)
-- ============================================================
-- Data awal yang diperlukan sebelum aplikasi bisa dipakai.
-- JANGAN di-run jika Anda sudah migrasi data dari Google Sheets!
-- ============================================================

-- ============================================================
-- 1. Data User Awal (Super Admin)
-- NOTE: Password harus di-hash dengan bcrypt.
-- Untuk keperluan development, kita buat dulu di Supabase Auth,
-- lalu trigger on_auth_user_created akan mengisi tabel users.
-- ============================================================

-- INSERT DEFAULT LOCATIONS
INSERT INTO ref_lokasi (nama_lokasi, nama_blok, status) VALUES
('Kandang Utama', 'Blok A', 'Aktif'),
('Kandang Utama', 'Blok B', 'Aktif'),
('Kandang Utama', 'Blok C', 'Aktif'),
('Kandang Pedet', 'Blok A', 'Aktif'),
('Kandang Pedet', 'Blok B', 'Aktif'),
('Kandang Karantina', NULL, 'Aktif'),
('Kandang Isolasi', NULL, 'Aktif'),
('Padang Penggembalaan', 'Sektor 1', 'Aktif'),
('Padang Penggembalaan', 'Sektor 2', 'Aktif'),
('Padang Penggembalaan', 'Sektor 3', 'Aktif');

-- ============================================================
-- 2. Contoh Data SNI (hanya untuk testing)
-- NOTE: Data SNI asli harus dimasukkan sesuai standar BPTUHPT
-- ============================================================
-- Contoh untuk Simmental Betina periode 6-12 bulan
INSERT INTO ref_sni (rumpun, jenis_kelamin, periode_bulan_min, periode_bulan_max, grade, pb_min, pb_max, tp_min, tp_max, ld_min, ld_max, ls_min, ls_max) VALUES
('Simmental', 'Betina', 6, 12, 1, 110, 999, 120, 999, 150, 999, NULL, NULL),
('Simmental', 'Betina', 6, 12, 2, 100, 109.9, 110, 119.9, 135, 149.9, NULL, NULL),
('Simmental', 'Betina', 6, 12, 3, 90, 99.9, 100, 109.9, 120, 134.9, NULL, NULL),
('Simmental', 'Betina', 12, 18, 1, 130, 999, 135, 999, 170, 999, NULL, NULL),
('Simmental', 'Betina', 12, 18, 2, 120, 129.9, 125, 134.9, 155, 169.9, NULL, NULL),
('Simmental', 'Betina', 12, 18, 3, 110, 119.9, 115, 124.9, 140, 154.9, NULL, NULL),
('Simmental', 'Betina', 18, 24, 1, 145, 999, 148, 999, 190, 999, NULL, NULL),
('Simmental', 'Betina', 18, 24, 2, 135, 144.9, 138, 147.9, 175, 189.9, NULL, NULL),
('Simmental', 'Betina', 18, 24, 3, 125, 134.9, 128, 137.9, 160, 174.9, NULL, NULL),

('Limousin', 'Betina', 6, 12, 1, 108, 999, 118, 999, 148, 999, NULL, NULL),
('Limousin', 'Betina', 6, 12, 2, 98, 107.9, 108, 117.9, 133, 147.9, NULL, NULL),
('Limousin', 'Betina', 6, 12, 3, 88, 97.9, 98, 107.9, 118, 132.9, NULL, NULL),
('Limousin', 'Betina', 12, 18, 1, 128, 999, 133, 999, 168, 999, NULL, NULL),
('Limousin', 'Betina', 12, 18, 2, 118, 127.9, 123, 132.9, 153, 167.9, NULL, NULL),
('Limousin', 'Betina', 12, 18, 3, 108, 117.9, 113, 122.9, 138, 152.9, NULL, NULL),
('Limousin', 'Betina', 18, 24, 1, 143, 999, 146, 999, 188, 999, NULL, NULL),
('Limousin', 'Betina', 18, 24, 2, 133, 142.9, 136, 145.9, 173, 187.9, NULL, NULL),
('Limousin', 'Betina', 18, 24, 3, 123, 132.9, 126, 135.9, 158, 172.9, NULL, NULL),

('Pesisir', 'Betina', 6, 12, 1, 90, 999, 95, 999, 120, 999, NULL, NULL),
('Pesisir', 'Betina', 6, 12, 2, 80, 89.9, 85, 94.9, 105, 119.9, NULL, NULL),
('Pesisir', 'Betina', 6, 12, 3, 70, 79.9, 75, 84.9, 90, 104.9, NULL, NULL),
('Pesisir', 'Betina', 12, 18, 1, 110, 999, 110, 999, 140, 999, NULL, NULL),
('Pesisir', 'Betina', 12, 18, 2, 100, 109.9, 100, 109.9, 125, 139.9, NULL, NULL),
('Pesisir', 'Betina', 12, 18, 3, 90, 99.9, 90, 99.9, 110, 124.9, NULL, NULL),
('Pesisir', 'Betina', 18, 24, 1, 125, 999, 120, 999, 155, 999, NULL, NULL),
('Pesisir', 'Betina', 18, 24, 2, 115, 124.9, 110, 119.9, 140, 154.9, NULL, NULL),
('Pesisir', 'Betina', 18, 24, 3, 105, 114.9, 100, 109.9, 125, 139.9, NULL, NULL);

-- ============================================================
-- 3. Trigger: Sinkronisasi Supabase Auth → public.users
-- ============================================================
-- Fungsi ini dipanggil OTOMATIS ketika user daftar/login
-- melalui Supabase Auth untuk pertama kali
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.encrypted_password,
        COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'Viewer'),
        'Aktif',
        COALESCE(NEW.raw_user_meta_data -> 'permissions', '[]'::jsonb)
    )
    ON CONFLICT (username) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Hapus trigger lama jika sudah ada
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Buat trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 4. Fungsi untuk sync data user dari Auth ke public.users
-- (dipanggil manual jika ada user yang sudah terdaftar)
-- ============================================================
CREATE OR REPLACE FUNCTION sync_auth_users_to_public()
RETURNS TABLE(username TEXT, role TEXT, status_sync TEXT)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user RECORD;
BEGIN
    FOR v_user IN 
        SELECT id, email, encrypted_password, 
               raw_user_meta_data ->> 'role' as user_role,
               raw_user_meta_data -> 'permissions' as user_permissions
        FROM auth.users
        WHERE NOT EXISTS (
            SELECT 1 FROM public.users WHERE id_user = auth.users.id
        )
    LOOP
        INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
        VALUES (
            v_user.id,
            v_user.email,
            v_user.encrypted_password,
            COALESCE(v_user.user_role::user_role, 'Viewer'),
            'Aktif',
            COALESCE(v_user.user_permissions, '[]'::jsonb)
        );
        
        username := v_user.email;
        role := v_user.user_role;
        status_sync := 'SYNCED';
        RETURN NEXT;
    END LOOP;
    
    IF NOT FOUND THEN
        username := '-';
        role := '-';
        status_sync := 'NO_NEW_USERS';
        RETURN NEXT;
    END IF;
END;
$$;

-- ============================================================
-- EKSEKUSI: Cara membuat user Super Admin pertama
-- ============================================================
-- JALANKAN INI DI SUPABASE SQL EDITOR UNTUK MEMBUAT ADMIN:
-- 
-- -- Buat user di Supabase Auth
-- SELECT supabase.auth.sign_up(
--     '{
--       "email": "admin@siscopatas.com",
--       "password": "Admin123!",
--       "options": {
--         "data": {
--           "role": "Super Admin",
--           "permissions": ["dashboard","users","database_ternak","pengukuran","laporan_berahi","ib","pkb","kelahiran","antrean_kelahiran","antrean_ukur","antrean_pkb","bas","penjualan","cetak_profil","bull","petugas_repro","petugas_keswan","keswan","gangrep","lokasi","mutasi","eartag","sni","upload_massal"]
--         }
--       }
--     }'
-- );
-- 
-- -- Atau via Dashboard Supabase:
-- 1. Buka Authentication → Users → Invite user
-- 2. Email: admin@siscopatas.com
-- 3. Password: (buat sendiri)
-- 4. Setelah user terdaftar, jalankan:
--    SELECT sync_auth_users_to_public();
-- 5. Update role jadi Super Admin:
--    UPDATE public.users SET role = 'Super Admin'::user_role 
--    WHERE username = 'admin@siscopatas.com';
-- ============================================================
