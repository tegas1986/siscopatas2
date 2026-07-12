-- ============================================================
-- SISCOPATAS - Migrasi 16: Validasi Eartag Pengukuran vs Database Acuan
-- ============================================================
-- Jalankan di Supabase Dashboard -> SQL Editor -> paste -> Run
--
-- Tujuan:
--   Deteksi pengukuran yg eartag-NYA TIDAK ditemukan di tabel referensi
--   (Database Ternak / tabel `ternak`). Baris seperti ini disebut "orphan"
--   (yatim) dan harus ditandai merah di UI serta bisa dihapus.
--
-- Pendekatan:
--   * Tidak pakai CONSTRAINT, karena eartag pengukuran BOLEH belum terdaftar
--     di ternak (pengukuran bisa diinput lebih dulu). Jadi kita pakai VIEW
--     sebagai "indikator validasi", bukan pembatas tulis.
--   * UI (frontend/index.html) sudah membandingkan via mapSapiDaftar
--     (set eartag ternak di-memoori) -> logika ini SETARA dgn view ini.
-- ============================================================

-- 1. VIEW: semua baris pengukuran yg eartag-nya TIDAK ada di ternak.
CREATE OR REPLACE VIEW v_pengukuran_tanpa_referensi AS
SELECT p.*
FROM pengukuran p
LEFT JOIN ternak t ON t.eartag = p.eartag
WHERE t.eartag IS NULL;

-- 2. FUNGSI helper: cek apakah sebuah eartag terdaftar di ternak.
--    Bisa dipakai di trigger/SQL lain bila diperlukan.
CREATE OR REPLACE FUNCTION eartag_terdaftar(p_eartag text)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM ternak WHERE eartag = p_eartag);
$$;

-- 3. VIEW ringkas khusus kolom yg dipakai UI/audit (hindari SELECT *).
--    Catatan: kolom status_validasi TIDAK disertakan karena keberadaannya
--    bergantung migrasi 14; view ini cukup pakai kolom inti agar tidak
--    gagal bila migrasi tersebut belum dijalankan.
CREATE OR REPLACE VIEW v_pengukuran_orphan_ringkas AS
SELECT
  p.id_ukur,
  p.eartag,
  p.periode_ukur,
  p.tanggal_ukur
FROM pengukuran p
LEFT JOIN ternak t ON t.eartag = p.eartag
WHERE t.eartag IS NULL;

-- ============================================================
-- VERIFIKASI / DIGUNAKAN UI:
--   -- daftar eartag pengukuran yg tidak terdaftar (untuk sinkron/audit)
--   SELECT * FROM v_pengukuran_tanpa_referensi ORDER BY tanggal_ukur DESC;
--
--   -- jumlah orphan (indikator badge peringatan di dashboard)
--   SELECT count(*) AS jml_invalid FROM v_pengukuran_tanpa_referensi;
-- ============================================================
