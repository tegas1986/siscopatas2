-- ============================================================
-- SISCOPATAS - Migrasi 15: Bersihkan Spasi pada Seluruh Kolom Eartag
-- ============================================================
-- Jalankan di Supabase Dashboard -> SQL Editor -> paste -> Run
-- (Gunakan service_role / owner agar bisa DROP & CREATE CONSTRAINT FK.)
--
-- Tujuan:
--   1. Hapus SEMUA spasi (dan whitespace) dari setiap kolom eartag di
--      seluruh tabel, secara KONSISTEN agar relasi FK tetap valid.
--   2. Tambah CHECK constraint agar ke depan eartag TIDAK BOLEH mengandung
--      spasi sama sekali.
--
-- Catatan penting:
--   * eartag tetap BUKAN Primary Key. PK tetap id_ternak (UUID) yg stabil,
--     sehingga fitur rename eartag (tabel eartag_pasang) tetap aman.
--   * eartag sudah UNIQUE NOT NULL -> cukup jadi business key + CHECK.
--   * Karena eartag dipakai sbg target FK, update dilakukan dgn me-lepas
--     sementara FK constraint yg men-reference ternak(eartag) (dalam 1
--     transaksi) lalu memasangnya kembali, agar tak ada pelanggaran saat
--     parent & child di-update ke nilai yg sama.
--     (CATATAN: di Supabase tidak boleh DISABLE TRIGGER pada RI/system
--      trigger -> pakai DROP/CREATE CONSTRAINT yg cukup level owner.)
-- ============================================================

-- ------------------------------------------------------------
-- LANGKAH 0 (WAJIB): CEK TABRAKAN SEBELUM MENGUBAH
--    Bila query berikut mengembalikan baris, BERHENTI. Dua eartag
--    berbeda akan "tabrakan" jadi satu nilai setelah spasi dihapus.
--    Selesaikan manual dulu (mis. "S 123" vs "S123") sebelum lanjut.
-- ------------------------------------------------------------
-- 0a. Tabrakan di tabel induk (ternak.eartag)
SELECT regexp_replace(eartag, '\s+', '', 'g') AS stripped, count(*) AS jml
FROM ternak
GROUP BY stripped
HAVING count(*) > 1;

-- 0b. Tabrakan di pengukuran (eartag + periode_ukur harus tetap unik)
SELECT regexp_replace(eartag, '\s+', '', 'g') AS e, periode_ukur, count(*) AS jml
FROM pengukuran
GROUP BY e, periode_ukur
HAVING count(*) > 1;

-- 0c. Tabrakan eartag_anak (UNIQUE) & eartag_baru (UNIQUE)
SELECT regexp_replace(eartag_anak, '\s+', '', 'g') AS e, count(*) AS jml
FROM kelahiran GROUP BY e HAVING count(*) > 1;
SELECT regexp_replace(eartag_baru, '\s+', '', 'g') AS e, count(*) AS jml
FROM eartag_pasang GROUP BY e HAVING count(*) > 1;

-- ------------------------------------------------------------
-- LANGKAH 1: LIHAT BERAPA BANYAK BARIS YANG AKAN DIUBAH (dry-run)
-- ------------------------------------------------------------
SELECT
  (SELECT count(*) FROM ternak          WHERE eartag ~ '\s' OR induk ~ '\s') AS ternak,
  (SELECT count(*) FROM log_mutasi      WHERE eartag ~ '\s') AS log_mutasi,
  (SELECT count(*) FROM laporan_berahi  WHERE eartag ~ '\s') AS laporan_berahi,
  (SELECT count(*) FROM ib              WHERE eartag ~ '\s') AS ib,
  (SELECT count(*) FROM laporan_gangrep WHERE eartag ~ '\s') AS laporan_gangrep,
  (SELECT count(*) FROM kebuntingan     WHERE eartag ~ '\s') AS kebuntingan,
  (SELECT count(*) FROM kelahiran       WHERE eartag_induk ~ '\s' OR eartag_anak ~ '\s') AS kelahiran,
  (SELECT count(*) FROM pengukuran      WHERE eartag ~ '\s' OR induk ~ '\s') AS pengukuran,
  (SELECT count(*) FROM penjualan       WHERE eartag ~ '\s') AS penjualan,
  (SELECT count(*) FROM keswan          WHERE eartag ~ '\s') AS keswan,
  (SELECT count(*) FROM eartag_pasang   WHERE eartag_lama ~ '\s' OR eartag_baru ~ '\s') AS eartag_pasang,
  (SELECT count(*) FROM log_audit_eartag WHERE eartag_anak ~ '\s' OR eartag_induk ~ '\s') AS log_audit_eartag;

-- ------------------------------------------------------------
-- LANGKAH 2: EKSEKUSI PEMBERSIHAN (dalam 1 transaksi)
--    Lepas FK -> update semua kolom -> pasang kembali FK.
-- ------------------------------------------------------------
BEGIN;

-- 2a. Lepas sementara SELURUH FK yg men-reference ternak(eartag).
--     Supabase tidak mengizinkan DISABLE TRIGGER pada RI/system trigger,
--     sehingga kita DROP constraint-nya lalu pasang kembali di 2d.
--     Definisi disimpan di temp table agar bisa di-recreate persis sama.
CREATE TEMP TABLE IF NOT EXISTS fk_eartag_backup (tab text, conname text, def text);

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.conname,
           c.conrelid::regclass::text AS tab,
           pg_get_constraintdef(c.oid) AS def
    FROM pg_constraint c
    JOIN pg_class t2 ON t2.oid = c.confrelid
    WHERE c.contype = 'f'
      AND t2.relname = 'ternak'
      AND c.confkey @> (
        SELECT array_agg(attnum) FROM pg_attribute
        WHERE attrelid = t2.oid AND attname = 'eartag'
      )
  LOOP
    INSERT INTO fk_eartag_backup VALUES (r.tab, r.conname, r.def);
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', r.tab, r.conname);
  END LOOP;
END $$;

-- 2b. Tabel induk (sumber kebenaran eartag) + self-ref induk.
UPDATE ternak
SET eartag = regexp_replace(eartag, '\s+', '', 'g'),
    induk  = regexp_replace(induk,  '\s+', '', 'g')
WHERE eartag ~ '\s' OR induk ~ '\s';

-- 2c. Tabel anak (FK ke ternak.eartag) + kolom eartag copy.
UPDATE log_mutasi      SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE laporan_berahi  SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE ib              SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE laporan_gangrep SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE kebuntingan     SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE kelahiran
SET eartag_induk = regexp_replace(eartag_induk, '\s+', '', 'g'),
    eartag_anak  = regexp_replace(eartag_anak,  '\s+', '', 'g')
WHERE eartag_induk ~ '\s' OR eartag_anak ~ '\s';
UPDATE pengukuran
SET eartag = regexp_replace(eartag, '\s+', '', 'g'),
    induk  = regexp_replace(induk,  '\s+', '', 'g')
WHERE eartag ~ '\s' OR induk ~ '\s';
UPDATE penjualan       SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
-- kolom eartag yg BUKAN FK (hanya salinan) -> ikut dibersihkan utk konsistensi
UPDATE keswan          SET eartag = regexp_replace(eartag, '\s+', '', 'g') WHERE eartag ~ '\s';
UPDATE eartag_pasang
SET eartag_lama = regexp_replace(eartag_lama, '\s+', '', 'g'),
    eartag_baru = regexp_replace(eartag_baru, '\s+', '', 'g')
WHERE eartag_lama ~ '\s' OR eartag_baru ~ '\s';
UPDATE log_audit_eartag
SET eartag_anak  = regexp_replace(eartag_anak,  '\s+', '', 'g'),
    eartag_induk = regexp_replace(eartag_induk, '\s+', '', 'g')
WHERE eartag_anak ~ '\s' OR eartag_induk ~ '\s';

-- 2d. Pasang kembali FK yg tadi di-lepas (otomatis divalidasi saat ADD).
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT * FROM fk_eartag_backup LOOP
    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I %s', r.tab, r.conname, r.def);
  END LOOP;
END $$;

COMMIT;

-- ------------------------------------------------------------
-- LANGKAH 3: CHECK CONSTRAINT -> cegah spasi ke depan (enforced)
--    ^\S+$ = tidak ada whitespace sama sekali.
--    PostgreSQL TIDAK mendukung "ADD CONSTRAINT IF NOT EXISTS",
--    jadi dipakai DO block yg cek pg_constraint dulu (idempoten /
--    aman dijalankan berulang kali).
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ternak_eartag_no_space') THEN
    ALTER TABLE ternak ADD CONSTRAINT chk_ternak_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ternak_induk_no_space') THEN
    ALTER TABLE ternak ADD CONSTRAINT chk_ternak_induk_no_space CHECK (induk IS NULL OR induk ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_log_mutasi_eartag_no_space') THEN
    ALTER TABLE log_mutasi ADD CONSTRAINT chk_log_mutasi_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_berahi_eartag_no_space') THEN
    ALTER TABLE laporan_berahi ADD CONSTRAINT chk_berahi_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ib_eartag_no_space') THEN
    ALTER TABLE ib ADD CONSTRAINT chk_ib_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_gangrep_eartag_no_space') THEN
    ALTER TABLE laporan_gangrep ADD CONSTRAINT chk_gangrep_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kebuntingan_eartag_no_space') THEN
    ALTER TABLE kebuntingan ADD CONSTRAINT chk_kebuntingan_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kelahiran_induk_no_space') THEN
    ALTER TABLE kelahiran ADD CONSTRAINT chk_kelahiran_induk_no_space CHECK (eartag_induk ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kelahiran_anak_no_space') THEN
    ALTER TABLE kelahiran ADD CONSTRAINT chk_kelahiran_anak_no_space CHECK (eartag_anak ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pengukuran_eartag_no_space') THEN
    ALTER TABLE pengukuran ADD CONSTRAINT chk_pengukuran_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pengukuran_induk_no_space') THEN
    ALTER TABLE pengukuran ADD CONSTRAINT chk_pengukuran_induk_no_space CHECK (induk IS NULL OR induk ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_penjualan_eartag_no_space') THEN
    ALTER TABLE penjualan ADD CONSTRAINT chk_penjualan_eartag_no_space CHECK (eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_keswan_eartag_no_space') THEN
    ALTER TABLE keswan ADD CONSTRAINT chk_keswan_eartag_no_space CHECK (eartag IS NULL OR eartag ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pasang_lama_no_space') THEN
    ALTER TABLE eartag_pasang ADD CONSTRAINT chk_pasang_lama_no_space CHECK (eartag_lama ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pasang_baru_no_space') THEN
    ALTER TABLE eartag_pasang ADD CONSTRAINT chk_pasang_baru_no_space CHECK (eartag_baru ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_audit_anak_no_space') THEN
    ALTER TABLE log_audit_eartag ADD CONSTRAINT chk_audit_anak_no_space CHECK (eartag_anak ~ '^\S+$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_audit_induk_no_space') THEN
    ALTER TABLE log_audit_eartag ADD CONSTRAINT chk_audit_induk_no_space CHECK (eartag_induk IS NULL OR eartag_induk ~ '^\S+$');
  END IF;
END $$;

-- ============================================================
-- VERIFIKASI AKHIR (harus mengembalikan 0 baris / 0)
-- ============================================================
-- Sisa eartag yg masih mengandung spasi di seluruh tabel:
SELECT 'ternak' AS tabel, count(*) AS sisa FROM ternak WHERE eartag ~ '\s' OR induk ~ '\s'
UNION ALL SELECT 'log_mutasi',      count(*) FROM log_mutasi      WHERE eartag ~ '\s'
UNION ALL SELECT 'laporan_berahi',  count(*) FROM laporan_berahi  WHERE eartag ~ '\s'
UNION ALL SELECT 'ib',              count(*) FROM ib              WHERE eartag ~ '\s'
UNION ALL SELECT 'laporan_gangrep', count(*) FROM laporan_gangrep WHERE eartag ~ '\s'
UNION ALL SELECT 'kebuntingan',     count(*) FROM kebuntingan     WHERE eartag ~ '\s'
UNION ALL SELECT 'kelahiran',       count(*) FROM kelahiran WHERE eartag_induk ~ '\s' OR eartag_anak ~ '\s'
UNION ALL SELECT 'pengukuran',      count(*) FROM pengukuran WHERE eartag ~ '\s' OR induk ~ '\s'
UNION ALL SELECT 'penjualan',       count(*) FROM penjualan       WHERE eartag ~ '\s'
UNION ALL SELECT 'keswan',          count(*) FROM keswan          WHERE eartag ~ '\s'
UNION ALL SELECT 'eartag_pasang',   count(*) FROM eartag_pasang WHERE eartag_lama ~ '\s' OR eartag_baru ~ '\s'
UNION ALL SELECT 'log_audit_eartag',count(*) FROM log_audit_eartag WHERE eartag_anak ~ '\s' OR eartag_induk ~ '\s';
-- Semua kolom harus menunjukkan 0.
-- ============================================================
