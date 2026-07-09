-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 03: Indexes
-- ============================================================
-- Indexes ini MEMPERCEPAT query yang sering dipakai.
-- Wajib dibuat setelah tabel terisi data (atau sebelum migrasi data).
-- ============================================================

-- ============================================================
-- TERNAK - indexes
-- ============================================================
CREATE INDEX idx_ternak_eartag ON ternak(eartag);
CREATE INDEX idx_ternak_status ON ternak(status_ternak);
CREATE INDEX idx_ternak_rumpun ON ternak(rumpun_ternak);
CREATE INDEX idx_ternak_jk ON ternak(jenis_kelamin);
CREATE INDEX idx_ternak_registrasi ON ternak(registrasi);
CREATE INDEX idx_ternak_lokasi ON ternak(lokasi_saat_ini);

-- ============================================================
-- PENGUKURAN - indexes (paling sering di-query)
-- ============================================================
CREATE INDEX idx_pengukuran_eartag ON pengukuran(eartag);
CREATE INDEX idx_pengukuran_tanggal ON pengukuran(tanggal_ukur);
CREATE INDEX idx_pengukuran_eartag_tanggal ON pengukuran(eartag, tanggal_ukur DESC);
CREATE INDEX idx_pengukuran_periode ON pengukuran(periode_ukur);
CREATE INDEX idx_pengukuran_grade ON pengukuran(grade_sni);
CREATE INDEX idx_pengukuran_rekomendasi ON pengukuran(rekomendasi_seleksi);

-- ============================================================
-- LAPORAN BERAHI - indexes
-- ============================================================
CREATE INDEX idx_berahi_eartag ON laporan_berahi(eartag);
CREATE INDEX idx_berahi_tanggal ON laporan_berahi(tanggal_lapor);
CREATE INDEX idx_berahi_status ON laporan_berahi(status_ib);

-- ============================================================
-- IB - indexes
-- ============================================================
CREATE INDEX idx_ib_eartag ON ib(eartag);
CREATE INDEX idx_ib_tanggal ON ib(tanggal_ib);
CREATE INDEX idx_ib_eartag_tanggal ON ib(eartag, tanggal_ib DESC);

-- ============================================================
-- KEBUNTINGAN (PKB) - indexes
-- ============================================================
CREATE INDEX idx_pkb_eartag ON kebuntingan(eartag);
CREATE INDEX idx_pkb_hasil ON kebuntingan(hasil_pemeriksaan);
CREATE INDEX idx_pkb_hpl ON kebuntingan(hpl);

-- ============================================================
-- KELAHIRAN - indexes
-- ============================================================
CREATE INDEX idx_kelahiran_induk ON kelahiran(eartag_induk);
CREATE INDEX idx_kelahiran_tanggal ON kelahiran(tanggal_lahir);

-- ============================================================
-- MUTASI - indexes
-- ============================================================
CREATE INDEX idx_mutasi_eartag ON log_mutasi(eartag);
CREATE INDEX idx_mutasi_eartag_tanggal ON log_mutasi(eartag, tanggal_mutasi DESC);

-- ============================================================
-- GANGREP - indexes
-- ============================================================
CREATE INDEX idx_gangrep_eartag ON laporan_gangrep(eartag);
CREATE INDEX idx_gangrep_status ON laporan_gangrep(status_akhir);

-- ============================================================
-- KESWAN - indexes
-- ============================================================
CREATE INDEX idx_keswan_ternak ON keswan(id_ternak);
CREATE INDEX idx_keswan_tanggal ON keswan(tanggal);

-- ============================================================
-- PENJUALAN - indexes
-- ============================================================
CREATE INDEX idx_penjualan_eartag ON penjualan(eartag);
CREATE INDEX idx_penjualan_tanggal ON penjualan(tanggal_jual);

-- ============================================================
-- REF_SNI - indexes
-- ============================================================
CREATE INDEX idx_sni_rumpun_kelamin ON ref_sni(rumpun, jenis_kelamin);
CREATE INDEX idx_sni_periode ON ref_sni(periode_bulan_min, periode_bulan_max);

-- ============================================================
-- EARTAG_PASANG - indexes
-- ============================================================
CREATE INDEX idx_eartag_lama ON eartag_pasang(eartag_lama);
CREATE INDEX idx_eartag_baru ON eartag_pasang(eartag_baru);

-- ============================================================
-- FULLTEXT SEARCH untuk pencarian eartag
-- Berguna saat user mengetik eartag di form (auto-fill)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- untuk trigram similarity search
CREATE INDEX idx_ternak_eartag_trgm ON ternak USING gin (eartag gin_trgm_ops);

-- ============================================================
-- VERIFIKASI:
-- SELECT indexname, indexdef FROM pg_indexes 
-- WHERE schemaname = 'public' ORDER BY indexname;
-- ============================================================
