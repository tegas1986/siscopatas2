-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 01: ENUM Types
-- ============================================================
-- Cara pakai: Buka Supabase Dashboard → SQL Editor → Paste → Run
-- ============================================================

-- 1. Rumpun Ternak (Breed)
CREATE TYPE rumpun_ternak AS ENUM (
    'Simmental',
    'Limousin',
    'Pesisir',
    'Brahman',
    'Belgian Blue',
    'FH',
    'Silangan',
    'Lokal'
);

-- 2. Jenis Kelamin
CREATE TYPE jenis_kelamin AS ENUM (
    'Jantan',
    'Betina'
);

-- 3. Status Ternak
CREATE TYPE status_ternak AS ENUM (
    'Hidup',
    'Mati',
    'Jual',
    'Hibah',
    'Pindah'
);

-- 4. Status Registrasi (BARU - untuk Aset/Persediaan)
CREATE TYPE status_registrasi AS ENUM (
    'Aset',
    'Persediaan'
);

-- 5. Kategori Ternak (Anak/Muda/Dewasa)
CREATE TYPE kategori_ternak AS ENUM (
    'Anak',
    'Muda',
    'Dewasa'
);

-- 6. Grade SNI (Standar Nasional Indonesia)
CREATE TYPE grade_sni AS ENUM (
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Non SNI',
    'Belum Ada SNI'
);

-- 7. Rekomendasi Seleksi (untuk BAS)
CREATE TYPE rekomendasi_seleksi AS ENUM (
    'Replacement',
    'Distribusi',
    'Hold'
);

-- 8. Periode Ukur (8 periode FSM)
CREATE TYPE periode_ukur AS ENUM (
    'Lahir',
    'Sapih',
    '9 Bulan',
    '12 Bulan',
    '15 Bulan',
    '18 Bulan',
    '21 Bulan',
    '24 Bulan'
);

-- 9. Hasil Pemeriksaan Kebuntingan (PKB)
CREATE TYPE hasil_pemeriksaan AS ENUM (
    'Positif',
    'Negatif',
    'Dubius'
);

-- 10. Derajat Berahi (1-4)
CREATE TYPE derajat_berahi AS ENUM (
    '1',
    '2',
    '3',
    '4'
);

-- 11. Status IB
CREATE TYPE status_ib AS ENUM (
    'Belum',
    'Sudah'
);

-- 12. Status Gangrep (Gangguan Reproduksi)
CREATE TYPE status_gangrep AS ENUM (
    'Open',
    'Dalam Penanganan',
    'Selesai',
    'Kronis',
    'Tidak Layak IB'
);

-- 13. User Role (8 role)
CREATE TYPE user_role AS ENUM (
    'Super Admin',
    'Admin Wasbit',
    'User Wasbit',
    'Admin Keswan',
    'User Keswan',
    'Admin IJP',
    'User IJP',
    'Viewer'
);

-- 14. Status Distribusi (Penjualan)
CREATE TYPE status_distribusi AS ENUM (
    'Lokal',
    'Keluar Daerah',
    'Teregistrasi'
);

-- ============================================================
-- VERIFIKASI: jalankan query ini untuk cek hasil
-- SELECT * FROM pg_type WHERE typcategory = 'E' ORDER BY typname;
-- Harus muncul 14 baris
-- ============================================================
