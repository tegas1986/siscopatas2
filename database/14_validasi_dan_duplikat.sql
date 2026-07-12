-- ============================================================
-- SISCOPATAS - Migrasi 14: Sistem Validasi & Deteksi Duplikat
-- ============================================================
-- Jalankan di Supabase Dashboard -> SQL Editor -> paste -> Run
-- Urutan wajib diikuti (khususnya pembersihan duplikat SEBELUM
-- membuat UNIQUE constraint).
--
-- Cakupan:
--   1. Flag validasi (status_validasi) pada tabel ternak & pengukuran
--   2. Auto-flag "Perlu Validasi" lewat BEFORE INSERT trigger
--   3. Fungsi validasi_record() -> ubah jadi "Tervalidasi"
--   4. Deteksi duplikat (view) + UNIQUE constraint pengukuran
--   5. hapus_duplikat() -> hapus dari registrasi & pengukuran (+
--      tabel anak pembuat FK) secara atomic
--   6. Grandfather data sebelumnya -> "Tervalidasi"
-- ============================================================

-- 1. ENUM STATUS VALIDASI ------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'validation_status') THEN
    CREATE TYPE validation_status AS ENUM ('Perlu Validasi', 'Tervalidasi', 'Ditolak');
  END IF;
END $$;

-- 2. TAMBAH KOLOM (default 'Perlu Validasi' agar baris baru otomatis flag) --
ALTER TABLE ternak ADD COLUMN IF NOT EXISTS status_validasi validation_status DEFAULT 'Perlu Validasi';
ALTER TABLE ternak ADD COLUMN IF NOT EXISTS validasi_oleh   UUID REFERENCES users(id_user);
ALTER TABLE ternak ADD COLUMN IF NOT EXISTS validasi_at     TIMESTAMPTZ;

ALTER TABLE pengukuran ADD COLUMN IF NOT EXISTS status_validasi validation_status DEFAULT 'Perlu Validasi';
ALTER TABLE pengukuran ADD COLUMN IF NOT EXISTS validasi_oleh   UUID REFERENCES users(id_user);
ALTER TABLE pengukuran ADD COLUMN IF NOT EXISTS validasi_at     TIMESTAMPTZ;

-- 3. PEMBERSIHAN 5 DUPLIKAT pengukuran YANG SUDAH ADA --------------------
--    (sama eartag+periode_ukur). Pertahankan yang paling awal (created_at).
DELETE FROM pengukuran a
USING pengukuran b
WHERE a.eartag = b.eartag
  AND a.periode_ukur = b.periode_ukur
  AND a.id_ukur < b.id_ukur;   -- keep satu per kombinasi

-- 4. UNIQUE CONSTRAINT (cegah duplikat di level tulis) -------------------
ALTER TABLE pengukuran
  ADD CONSTRAINT IF NOT EXISTS uq_pengukuran_eartag_periode
  UNIQUE (eartag, periode_ukur);

-- 5. TRIGGER AUTO-FLAG "Perlu Validasi" ----------------------------------
CREATE OR REPLACE FUNCTION set_perlu_validasi()
RETURNS trigger AS $$
BEGIN
  NEW.status_validasi := 'Perlu Validasi';
  NEW.validasi_oleh    := NULL;
  NEW.validasi_at      := NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ternak_perlu_validasi ON ternak;
CREATE TRIGGER trg_ternak_perlu_validasi
  BEFORE INSERT ON ternak FOR EACH ROW EXECUTE FUNCTION set_perlu_validasi();

DROP TRIGGER IF EXISTS trg_pengukuran_perlu_validasi ON pengukuran;
CREATE TRIGGER trg_pengukuran_perlu_validasi
  BEFORE INSERT ON pengukuran FOR EACH ROW EXECUTE FUNCTION set_perlu_validasi();

-- 6. FUNGSI VALIDASI (ubah jadi Tervalidasi) -----------------------------
CREATE OR REPLACE FUNCTION validasi_record(p_tabel text, p_id uuid, p_user uuid)
RETURNS void AS $$
BEGIN
  IF p_tabel = 'ternak' THEN
    UPDATE ternak
       SET status_validasi = 'Tervalidasi', validasi_oleh = p_user, validasi_at = now()
     WHERE id_ternak = p_id;
  ELSIF p_tabel = 'pengukuran' THEN
    UPDATE pengukuran
       SET status_validasi = 'Tervalidasi', validasi_oleh = p_user, validasi_at = now()
     WHERE id_ukur = p_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 7. VIEW DETEKSI DUPLIKAT ----------------------------------------------
--    Pengukuran: duplikat eksak (eartag+periode). UNIQUE di atas mencegah
--    duplikat baru; view ini untuk menyapu sisa (jika ada).
CREATE OR REPLACE VIEW v_duplikat_pengukuran AS
SELECT eartag, periode_ukur, count(*) AS jml,
       array_agg(id_ukur ORDER BY created_at) AS ids
FROM pengukuran
GROUP BY eartag, periode_ukur
HAVING count(*) > 1;

--    Ternak: eartag sudah UNIQUE, jadi cari duplikat LOGIS (hewan sama
--    eartag beda/typo) berdasar silsilah + tanggal lahir + rumpun.
CREATE OR REPLACE VIEW v_duplikat_ternak AS
SELECT t1.id_ternak, t1.eartag,
       t2.id_ternak AS duplikat_id, t2.eartag AS eartag_duplikat
FROM ternak t1
JOIN ternak t2
  ON t1.id_ternak <> t2.id_ternak
 AND t1.tanggal_lahir = t2.tanggal_lahir
 AND COALESCE(t1.bapak, '') = COALESCE(t2.bapak, '')
 AND COALESCE(t1.induk, '') = COALESCE(t2.induk, '')
 AND t1.rumpun_ternak = t2.rumpun_ternak
WHERE t1.status_validasi = 'Perlu Validasi';

-- 8. FUNGSI HAPUS DUPLIKAT (dua sumber + FK anak, atomic) ---------------
--    Karena pengukuran.eartag adalah FK ke KOLOM eartag (bukan cascade),
--    child harus dihapus DULU. Tabel lain yg mereferensi ternak(eartag)
--    ikut dibersihkan agar tidak ada orphan / FK violation.
CREATE OR REPLACE FUNCTION hapus_duplikat(p_eartag text, p_user text)
RETURNS void AS $$
BEGIN
  -- Arsip dulu (reuse pola log_audit_eartag)
  INSERT INTO log_audit_eartag (eartag_anak, rumpun_anak, eartag_induk, keterangan_status, dihapus_oleh)
  SELECT eartag, rumpun_ternak, induk, 'Auto-hapus duplikat (seluruh footprint eartag)', p_user
  FROM ternak WHERE eartag = p_eartag;

  -- Hapus child dulu (urut agar tak langgar FK)
  DELETE FROM pengukuran      WHERE eartag = p_eartag;
  DELETE FROM laporan_berahi  WHERE eartag = p_eartag;
  DELETE FROM ib              WHERE eartag = p_eartag;
  DELETE FROM kebuntingan     WHERE eartag = p_eartag;
  DELETE FROM laporan_gangrep WHERE eartag = p_eartag;
  DELETE FROM penjualan       WHERE eartag = p_eartag;
  DELETE FROM log_mutasi      WHERE eartag = p_eartag;
  DELETE FROM kelahiran       WHERE eartag_induk = p_eartag;

  -- Lalu hapus induk (registrasi)
  DELETE FROM ternak WHERE eartag = p_eartag;
END;
$$ LANGUAGE plpgsql;

-- 9. INDEX (filter "Perlu Validasi" cepat) ------------------------------
CREATE INDEX IF NOT EXISTS idx_ternak_status_validasi     ON ternak(status_validasi);
CREATE INDEX IF NOT EXISTS idx_pengukuran_status_validasi ON pengukuran(status_validasi);

-- 10. GRANDFATHER DATA SEBELUMNYA -> "Tervalidasi" ----------------------
--     Data yg sudah diimpor/terdaftar dianggap sudah tervalidasi.
--     (Jika ingin data lama ikut di-review ulang, ganti 'Tervalidasi'
--      di bawah menjadi 'Perlu Validasi'.)
UPDATE ternak     SET status_validasi = 'Tervalidasi', validasi_at = now() WHERE status_validasi = 'Perlu Validasi';
UPDATE pengukuran SET status_validasi = 'Tervalidasi', validasi_at = now() WHERE status_validasi = 'Perlu Validasi';

-- ============================================================
-- VERIFIKASI:
-- SELECT status_validasi, count(*) FROM pengukuran GROUP BY 1;
-- SELECT status_validasi, count(*) FROM ternak GROUP BY 1;
-- SELECT * FROM v_duplikat_pengukuran;   -- harus kosong
-- ============================================================
