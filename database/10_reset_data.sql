-- ============================================================
-- SISCOPATAS - Reset Data (untuk mengulang migrasi)
-- File 10: Kosongkan semua tabel DATA (struktur tetap)
-- ============================================================
-- GUNAKAN HANYA saat ingin mengulang migrasi dari nol.
-- TIDAK menghapus: struktur tabel, enum, fungsi, policy.
-- TIDAK menghapus user Auth (Authentication) -- itu terpisah.
-- ============================================================

TRUNCATE TABLE
    log_audit_eartag,
    eartag_pasang,
    penjualan,
    pengukuran,
    kelahiran,
    kebuntingan,
    laporan_gangrep,
    keswan,
    ib,
    laporan_berahi,
    log_mutasi,
    ternak,
    bull,
    petugas_keswan,
    petugas_reproduksi,
    ref_lokasi
RESTART IDENTITY CASCADE;

-- Catatan: tabel users TIDAK di-truncate di sini supaya user admin
-- yang sudah kamu buat tetap ada. Jika ingin reset users juga
-- (kecuali admin), jalankan manual:
--   DELETE FROM public.users WHERE username <> 'admin@siscopatas.com';
