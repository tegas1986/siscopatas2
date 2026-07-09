-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 02: Tables (18 tabel)
-- ============================================================
-- Cara pakai: Buka Supabase Dashboard → SQL Editor → Paste → Run
-- PASTIKAN 01_enums.sql sudah di-run SEBELUM file ini!
-- ============================================================

-- ============================================================
-- 1. Tabel: users
-- ============================================================
CREATE TABLE users (
    id_user UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    status VARCHAR(20) DEFAULT 'Aktif' CHECK (status IN ('Aktif', 'Tidak Aktif')),
    permissions JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. Tabel: petugas_reproduksi
-- ============================================================
CREATE TABLE petugas_reproduksi (
    id_petugas UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_petugas VARCHAR(200) NOT NULL,
    jabatan VARCHAR(100),
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 3. Tabel: petugas_keswan
-- ============================================================
CREATE TABLE petugas_keswan (
    id_petugas UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_petugas VARCHAR(200) NOT NULL,
    jabatan VARCHAR(100),
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 4. Tabel: bull
-- ============================================================
CREATE TABLE bull (
    id_bull UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_bull VARCHAR(200) NOT NULL,
    rumpun rumpun_ternak NOT NULL,
    asal VARCHAR(200),
    stok_awal INTEGER DEFAULT 0,
    stok_saat_ini INTEGER DEFAULT 0,
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 5. Tabel: ref_lokasi
-- ============================================================
CREATE TABLE ref_lokasi (
    id_lokasi UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_lokasi VARCHAR(200) NOT NULL,
    nama_blok VARCHAR(200),
    status VARCHAR(20) DEFAULT 'Aktif' CHECK (status IN ('Aktif', 'Tidak Aktif'))
);

-- ============================================================
-- 6. Tabel: ternak (CORE - Database Ternak)
-- ============================================================
CREATE TABLE ternak (
    id_ternak UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eartag VARCHAR(50) UNIQUE NOT NULL,
    rumpun_ternak rumpun_ternak NOT NULL,
    tanggal_lahir DATE NOT NULL,
    jenis_kelamin jenis_kelamin NOT NULL,
    bapak VARCHAR(200),
    induk VARCHAR(50),
    status_ternak status_ternak DEFAULT 'Hidup',
    registrasi status_registrasi DEFAULT 'Persediaan',  -- Aset / Persediaan
    tanggal_kejadian DATE,
    lokasi_saat_ini UUID REFERENCES ref_lokasi(id_lokasi),
    catatan TEXT,
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Self-referencing FK untuk induk (referensi ke eartag)
    FOREIGN KEY (induk) REFERENCES ternak(eartag)
);

-- ============================================================
-- 7. Tabel: log_mutasi (Riwayat Pindah Kandang)
-- ============================================================
CREATE TABLE log_mutasi (
    id_mutasi UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_mutasi DATE NOT NULL,
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    dari_lokasi VARCHAR(200),
    lokasi_saat_ini UUID NOT NULL REFERENCES ref_lokasi(id_lokasi),
    alasan VARCHAR(200),
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 8. Tabel: laporan_berahi
-- ============================================================
CREATE TABLE laporan_berahi (
    id_lapor UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_lapor DATE NOT NULL,
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    derajat_berahi derajat_berahi NOT NULL,
    rekomendasi VARCHAR(100),
    keterangan TEXT,
    status_ib status_ib DEFAULT 'Belum',
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. Tabel: ib (Inseminasi Buatan)
-- ============================================================
CREATE TABLE ib (
    id_ib UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_lapor UUID REFERENCES laporan_berahi(id_lapor),
    tanggal_ib DATE NOT NULL,
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    derajat_berahi derajat_berahi NOT NULL,
    nama_bull VARCHAR(200) NOT NULL,
    inseminator VARCHAR(200) NOT NULL,
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. Tabel: keswan (Kesehatan Hewan)
-- ============================================================
CREATE TABLE keswan (
    id_keswan UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal DATE NOT NULL,
    id_ternak UUID NOT NULL REFERENCES ternak(id_ternak),
    eartag VARCHAR(50),
    diagnosa TEXT NOT NULL,
    treatment TEXT,
    petugas VARCHAR(200),
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 11. Tabel: laporan_gangrep (Gangguan Reproduksi)
-- ============================================================
CREATE TABLE laporan_gangrep (
    id_gangrep UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_lapor DATE NOT NULL,
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    keterangan_pelapor TEXT,
    diagnosa_keswan TEXT,
    tindakan_keswan TEXT,
    petugas_keswan VARCHAR(200),
    status_akhir status_gangrep DEFAULT 'Open',
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. Tabel: kebuntingan (PKB)
-- ============================================================
CREATE TABLE kebuntingan (
    id_pkb UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    tanggal_ib DATE NOT NULL,
    tanggal_pemeriksaan DATE NOT NULL,
    hasil_pemeriksaan hasil_pemeriksaan NOT NULL,
    prediksi_bulan INTEGER,
    hpl DATE,
    petugas_pemeriksa VARCHAR(200),
    link_foto_pkb TEXT,  -- URL Google Drive untuk foto USG/dokumentasi PKB
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 13. Tabel: kelahiran
-- ============================================================
CREATE TABLE kelahiran (
    id_kelahiran UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_lahir DATE NOT NULL,
    eartag_induk VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun_induk rumpun_ternak NOT NULL,
    eartag_anak VARCHAR(50) UNIQUE NOT NULL,
    jenis_kelamin jenis_kelamin NOT NULL,
    rumpun_anak rumpun_ternak NOT NULL,
    bapak VARCHAR(200),
    link_foto TEXT,  -- URL Google Drive thumbnail
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 14. Tabel: pengukuran
-- ============================================================
CREATE TABLE pengukuran (
    id_ukur UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_ukur DATE NOT NULL,
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    sex jenis_kelamin NOT NULL,
    tanggal_lahir DATE NOT NULL,
    bapak VARCHAR(200),
    induk VARCHAR(50),
    periode_ukur periode_ukur NOT NULL,
    panjang_badan NUMERIC(5,1),
    lingkar_dada NUMERIC(5,1),
    tinggi_pundak NUMERIC(5,1),
    berat_badan NUMERIC(6,1),
    lingkar_scrotum NUMERIC(4,1),
    penilaian_kualitatif VARCHAR(50) CHECK (penilaian_kualitatif IN ('Sesuai SNI', 'Tidak Sesuai SNI')),
    keterangan TEXT,
    grade_sni grade_sni,
    rekomendasi_seleksi rekomendasi_seleksi,
    keterangan_audit_admin TEXT,
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. Tabel: penjualan
-- ============================================================
CREATE TABLE penjualan (
    id_penjualan UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eartag VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun rumpun_ternak NOT NULL,
    harga NUMERIC(12,2),
    tanggal_jual DATE NOT NULL,
    status_distribusi status_distribusi,
    no_billing VARCHAR(100),
    keterangan TEXT,
    input_by UUID REFERENCES users(id_user),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 16. Tabel: ref_sni (Standar Nasional Indonesia - Acuan)
-- ============================================================
CREATE TABLE ref_sni (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rumpun rumpun_ternak NOT NULL,
    jenis_kelamin jenis_kelamin NOT NULL,
    periode_bulan_min INTEGER NOT NULL,
    periode_bulan_max INTEGER NOT NULL,
    grade INTEGER NOT NULL CHECK (grade IN (1, 2, 3)),
    tp_min NUMERIC(5,1),
    tp_max NUMERIC(5,1),
    pb_min NUMERIC(5,1),
    pb_max NUMERIC(5,1),
    ld_min NUMERIC(5,1),
    ld_max NUMERIC(5,1),
    ls_min NUMERIC(4,1),
    ls_max NUMERIC(4,1),
    -- UNIQUE constraint: tidak boleh ada duplikat grade untuk rumpun+kelamin+periode yang sama
    UNIQUE (rumpun, jenis_kelamin, periode_bulan_min, periode_bulan_max, grade)
);

-- ============================================================
-- 17. Tabel: eartag_pasang (Pemasangan Eartag Definitif)
-- ============================================================
CREATE TABLE eartag_pasang (
    id_pasang UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eartag_lama VARCHAR(50) NOT NULL,
    eartag_baru VARCHAR(50) UNIQUE NOT NULL,
    tanggal_pasang DATE DEFAULT CURRENT_DATE,
    input_by UUID REFERENCES users(id_user)
);

-- ============================================================
-- 18. Tabel: log_audit_eartag (Log Penghapusan Eartag)
-- ============================================================
CREATE TABLE log_audit_eartag (
    id_log UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tanggal_hapus TIMESTAMPTZ DEFAULT NOW(),
    eartag_anak VARCHAR(50) NOT NULL REFERENCES ternak(eartag),
    rumpun_anak rumpun_ternak,
    eartag_induk VARCHAR(50),
    keterangan_status TEXT,
    dihapus_oleh VARCHAR(100)
);

-- ============================================================
-- VERIFIKASI:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' ORDER BY table_name;
-- Harus muncul 18 baris
-- ============================================================
