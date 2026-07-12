-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 05: Views (6 view utama)
-- ============================================================
-- View adalah "tabel virtual" yang menggabungkan data dari 
-- beberapa tabel untuk kemudahan akses dari frontend.
-- ============================================================

-- ============================================================
-- VIEW 1: v_ternak
-- Tabel ternak dengan kolom computed (umur_bulan, kategori)
-- ============================================================
CREATE OR REPLACE VIEW v_ternak AS
SELECT 
    t.*,
    -- Hitung umur dalam bulan
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) AS umur_bulan,
    -- Kategori: Anak (<=6 bln), Muda (<=18 bln), Dewasa (>18 bln)
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
             EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) <= 6 THEN 'Anak'::kategori_ternak
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
             EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) <= 18 THEN 'Muda'::kategori_ternak
        ELSE 'Dewasa'::kategori_ternak
    END AS kategori,
    rl.nama_lokasi,
    rl.nama_blok
FROM ternak t
LEFT JOIN ref_lokasi rl ON rl.id_lokasi = t.lokasi_saat_ini;

-- ============================================================
-- VIEW 2: v_berita_acara_seleksi (BAS)
-- View paling kompleks - 19+ kolom
-- Menggabungkan ternak + latest pengukuran + penjualan
-- ============================================================
CREATE OR REPLACE VIEW v_berita_acara_seleksi AS
SELECT 
    t.eartag,
    t.rumpun_ternak,
    t.tanggal_lahir,
    t.jenis_kelamin,
    t.bapak,
    t.induk,
    t.status_ternak,
    t.registrasi,
    t.lokasi_saat_ini,
    t.catatan,
    -- Data pengukuran terakhir
    p.id_ukur,
    p.tanggal_ukur,
    p.periode_ukur,
    p.panjang_badan,
    p.lingkar_dada,
    p.tinggi_pundak,
    p.berat_badan,
    p.lingkar_scrotum,
    p.penilaian_kualitatif,
    p.grade_sni,
    p.rekomendasi_seleksi,
    p.keterangan_audit_admin,
    -- Data penjualan (jika ada)
    pj.id_penjualan IS NOT NULL AS sudah_terjual,
    pj.harga,
    pj.tanggal_jual,
    pj.status_distribusi,
    pj.no_billing,
    -- Umur & kategori (computed)
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) AS umur_bulan,
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
             EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) <= 6 THEN 'Anak'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, t.tanggal_lahir)) * 12 + 
             EXTRACT(MONTH FROM AGE(CURRENT_DATE, t.tanggal_lahir)) <= 18 THEN 'Muda'
        ELSE 'Dewasa'
    END AS kategori
FROM v_ternak t
LEFT JOIN LATERAL (
    SELECT * FROM pengukuran 
    WHERE eartag = t.eartag 
    ORDER BY tanggal_ukur DESC, created_at DESC 
    LIMIT 1
) p ON true
LEFT JOIN penjualan pj ON pj.eartag = t.eartag;

-- ============================================================
-- VIEW 3: v_antrean_pkb
-- Sapi yang perlu diperiksa kebuntingan (jalur IB/non-Pesisir):
-- mulai 30 hari setelah IB terakhir, dan belum ada PKB berhasil.
-- Batas atas 365 hari: IB yang lebih tua dari itu tanpa PKB dianggap
-- basi/terabaikan dan TIDAK ikut dihitung, supaya metrik dashboard tidak
-- membengkak oleh data historis lama (menghindari full scan tak terbatas).
-- Catatan: view ini DIPAKAI oleh v_dashboard_statistics (COUNT antrean_pkb),
-- jadi BUKAN orphan. UI harian memakai computed flatAlertPKB (client-side)
-- yang menangani rumpun Pesisir dengan aturan BERBEDA: 60 hari pasca
-- MELAHIRKAN (bukan pasca IB). Bila view ini kelak dipakai untuk jalur
-- Pesisir, tambahkan LEFT JOIN ke tabel kelahiran.
-- ============================================================
CREATE OR REPLACE VIEW v_antrean_pkb AS
SELECT 
    ib.id_ib,
    ib.eartag,
    ib.tanggal_ib,
    ib.rumpun,
    ib.nama_bull,
    ib.inseminator,
    t.tanggal_lahir,
    t.jenis_kelamin,
    t.lokasi_saat_ini,
    -- Hari sejak IB
    (CURRENT_DATE - ib.tanggal_ib) AS hari_sejak_ib,
    -- Status tenggat
    CASE
        WHEN (CURRENT_DATE - ib.tanggal_ib) BETWEEN 30 AND 60 THEN 'SEGERA'
        WHEN (CURRENT_DATE - ib.tanggal_ib) BETWEEN 61 AND 120 THEN 'TERLAMBAT'
        ELSE 'SANGAT_TERLAMBAT'
    END AS status_pkb
FROM ib
JOIN ternak t ON t.eartag = ib.eartag
WHERE t.status_ternak = 'Hidup'
  AND t.jenis_kelamin = 'Betina'
  AND (CURRENT_DATE - ib.tanggal_ib) BETWEEN 30 AND 365
  AND NOT EXISTS (
      SELECT 1 FROM kebuntingan k 
      WHERE k.eartag = ib.eartag 
        AND k.tanggal_ib = ib.tanggal_ib
        AND k.hasil_pemeriksaan IN ('Positif','Negatif')
  )
ORDER BY (CURRENT_DATE - ib.tanggal_ib) DESC;

-- ============================================================
-- VIEW 4: v_antrean_kelahiran
-- Sapi bunting dengan HPL yang sudah dekat
-- ============================================================
CREATE OR REPLACE VIEW v_antrean_kelahiran AS
SELECT 
    k.id_pkb,
    k.eartag,
    k.rumpun,
    k.tanggal_ib,
    k.tanggal_pemeriksaan,
    k.hpl,
    k.petugas_pemeriksa,
    t.tanggal_lahir AS tanggal_lahir_induk,
    t.lokasi_saat_ini,
    t.bapak AS bapak_dari_ib,
    -- Hitung mundur ke HPL
    (k.hpl - CURRENT_DATE) AS hari_menuju_hpl,
    -- Status kelahiran
    CASE
        WHEN k.hpl IS NULL THEN 'TANPA_HPL'
        WHEN (k.hpl - CURRENT_DATE) < 0 THEN 'TERLEWAT'
        WHEN (k.hpl - CURRENT_DATE) <= 30 THEN 'SIAGA'
        WHEN (k.hpl - CURRENT_DATE) <= 60 THEN 'DEKAT'
        WHEN (k.hpl - CURRENT_DATE) <= 90 THEN 'NORMAL'
        ELSE 'JAUH'
    END AS status_kelahiran,
    -- Cek apakah sudah punya kelahiran untuk PKB ini
    EXISTS (
        SELECT 1 FROM kelahiran kl 
        WHERE kl.eartag_induk = k.eartag 
          AND kl.tanggal_lahir >= k.tanggal_ib
    ) AS sudah_melahirkan
FROM kebuntingan k
JOIN ternak t ON t.eartag = k.eartag
WHERE k.hasil_pemeriksaan = 'Positif'
  AND t.status_ternak = 'Hidup'
  AND (k.hpl - CURRENT_DATE) >= -30  -- Toleransi 30 hari setelah HPL
ORDER BY k.hpl ASC;

-- ============================================================
-- VIEW 5: v_antrean_ukur
-- Sapi yang perlu diukur berdasarkan FSM (Finite State Machine)
-- 8 periode: Lahir, Sapih, 9B, 12B, 15B, 18B, 21B, 24B
-- 
-- Aturan FSM:
-- - Tolerance: ±30 hari (bisa diubah via parameter)
-- - Grade 1-2 hanya diukur di 12B & 18B (kecuali Lahir & Sapih)
-- - Non SNI & Grade 3 diukur di semua periode
-- - "pernahCacat" (penilaian_kualitatif = Tidak Sesuai SNI) 
--   menghapus dari antrean selamanya
-- ============================================================
CREATE OR REPLACE VIEW v_antrean_ukur AS
WITH target_periode AS (
    -- Definisikan 8 periode dengan rentang umur (dalam hari)
    SELECT * FROM (VALUES
        ('Lahir'::periode_ukur, 0, 7, 0),
        ('Sapih'::periode_ukur, 180, 30, 180),
        ('9 Bulan'::periode_ukur, 270, 30, 270),
        ('12 Bulan'::periode_ukur, 365, 30, 365),
        ('15 Bulan'::periode_ukur, 455, 30, 455),
        ('18 Bulan'::periode_ukur, 545, 30, 545),
        ('21 Bulan'::periode_ukur, 640, 30, 640),
        ('24 Bulan'::periode_ukur, 730, 30, 730)
    ) AS tp(nama, umur_target_hari, toleransi_hari, urutan)
),
sapi_hidup AS (
    -- Semua sapi hidup dengan status aktif
    SELECT 
        t.eartag,
        t.rumpun_ternak,
        t.tanggal_lahir,
        t.jenis_kelamin,
        t.bapak,
        t.induk,
        t.lokasi_saat_ini,
        (CURRENT_DATE - t.tanggal_lahir) AS umur_hari,
        -- Cek apakah pernah punya catatan "Tidak Sesuai SNI"
        EXISTS (
            SELECT 1 FROM pengukuran p 
            WHERE p.eartag = t.eartag 
              AND p.penilaian_kualitatif = 'Tidak Sesuai SNI'
        ) AS pernah_cacat,
        -- Ambil grade SNI terakhir
        (SELECT grade_sni FROM pengukuran 
         WHERE eartag = t.eartag 
         ORDER BY tanggal_ukur DESC LIMIT 1) AS grade_terakhir
    FROM v_ternak t
    WHERE t.status_ternak = 'Hidup'
      AND t.jenis_kelamin = 'Betina'  -- Pengukuran khusus betina (sesuai bisnis)
),
periode_sapi AS (
    -- Generate semua kombinasi sapi x periode yang memungkinkan
    SELECT 
        s.eartag,
        s.rumpun_ternak,
        s.tanggal_lahir,
        s.jenis_kelamin,
        s.bapak,
        s.induk,
        s.umur_hari,
        s.pernah_cacat,
        s.grade_terakhir,
        tp.nama AS periode_ukur,
        tp.umur_target_hari,
        tp.toleransi_hari,
        tp.urutan,
        -- Apakah sapi sudah mencapai umur untuk periode ini?
        (s.umur_hari >= (tp.umur_target_hari - tp.toleransi_hari)) AS sudah_sampai_umur,
        -- Apakah sapi masih dalam rentang toleransi?
        (s.umur_hari BETWEEN (tp.umur_target_hari - tp.toleransi_hari) 
                        AND (tp.umur_target_hari + tp.toleransi_hari)) AS dalam_toleransi
    FROM sapi_hidup s
    CROSS JOIN target_periode tp
)
SELECT 
    ps.eartag,
    ps.rumpun_ternak,
    ps.tanggal_lahir,
    ps.jenis_kelamin,
    ps.bapak,
    ps.induk,
    ps.umur_hari,
    ps.periode_ukur,
    ps.umur_target_hari,
    ps.urutan,
    ps.dalam_toleransi,
    ps.grade_terakhir,
    -- Sudah diukur atau belum?
    NOT EXISTS (
        SELECT 1 FROM pengukuran p 
        WHERE p.eartag = ps.eartag 
          AND p.periode_ukur = ps.periode_ukur
    ) AS belum_diukur,
    -- Label prioritas
    CASE
        WHEN ps.dalam_toleransi AND NOT EXISTS (
            SELECT 1 FROM pengukuran p 
            WHERE p.eartag = ps.eartag 
              AND p.periode_ukur = ps.periode_ukur
        ) AND NOT ps.pernah_cacat THEN 'SEGERA_UKUR'
        WHEN ps.sudah_sampai_umur AND NOT EXISTS (
            SELECT 1 FROM pengukuran p 
            WHERE p.eartag = ps.eartag 
              AND p.periode_ukur = ps.periode_ukur
        ) AND NOT ps.pernah_cacat THEN 'MENUNGGU'
        ELSE 'SELESAI'
    END AS status_antrean
FROM periode_sapi ps
WHERE NOT ps.pernah_cacat  -- Sapi cacat tidak perlu diukur lagi
  AND ps.sudah_sampai_umur  -- Belum mencapai umur target
  -- Filter Grade: Grade 1-2 hanya diukur di 12B dan 18B (selain Lahir/Sapih)
  AND (
      ps.grade_terakhir IS NULL
      OR ps.grade_terakhir IN ('Non SNI', 'Grade 3', 'Belum Ada SNI')
      OR ps.periode_ukur IN ('Lahir', 'Sapih', '12 Bulan', '18 Bulan')
  )
ORDER BY 
    ps.dalam_toleransi DESC,
    ps.umur_hari ASC;

-- ============================================================
-- VIEW 6: v_dashboard_statistics
-- Statistik dashboard: populasi, reproduksi, performans
-- ============================================================
CREATE OR REPLACE VIEW v_dashboard_statistics AS
WITH populasi AS (
    SELECT
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup') AS total_hidup,
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup' AND jenis_kelamin = 'Jantan') AS jantan_hidup,
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup' AND jenis_kelamin = 'Betina') AS betina_hidup,
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup' AND 
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, tanggal_lahir)) * 12 + 
            EXTRACT(MONTH FROM AGE(CURRENT_DATE, tanggal_lahir)) <= 6) AS anak,
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup' AND 
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, tanggal_lahir)) * 12 + 
            EXTRACT(MONTH FROM AGE(CURRENT_DATE, tanggal_lahir)) > 6 AND
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, tanggal_lahir)) * 12 + 
            EXTRACT(MONTH FROM AGE(CURRENT_DATE, tanggal_lahir)) <= 18) AS muda,
        COUNT(*) FILTER (WHERE status_ternak = 'Hidup' AND 
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, tanggal_lahir)) * 12 + 
            EXTRACT(MONTH FROM AGE(CURRENT_DATE, tanggal_lahir)) > 18) AS dewasa
    FROM ternak
),
reproduksi AS (
    SELECT
        -- Total IB bulan ini
        COUNT(*) FILTER (WHERE tanggal_ib >= DATE_TRUNC('month', CURRENT_DATE)) AS ib_bulan_ini,
        -- Total IB bulan lalu
        COUNT(*) FILTER (WHERE tanggal_ib >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
                        AND tanggal_ib < DATE_TRUNC('month', CURRENT_DATE)) AS ib_bulan_lalu,
        -- Service per Conception (S/C) = total IB / total kebuntingan positif
        (SELECT COUNT(*) FROM ib 
         WHERE tanggal_ib >= DATE_TRUNC('year', CURRENT_DATE))::float /
        NULLIF((SELECT COUNT(*) FROM kebuntingan 
                WHERE hasil_pemeriksaan = 'Positif'
                AND tanggal_pemeriksaan >= DATE_TRUNC('year', CURRENT_DATE)), 0) AS sc_ratio
    FROM ib
),
kelahiran_baru AS (
    SELECT COUNT(*) AS jumlah
    FROM kelahiran
    WHERE tanggal_lahir >= DATE_TRUNC('month', CURRENT_DATE)
),
penjualan_bulan AS (
    SELECT COUNT(*) AS jumlah
    FROM penjualan
    WHERE tanggal_jual >= DATE_TRUNC('month', CURRENT_DATE)
)
SELECT
    -- Populasi
    p.total_hidup,
    p.jantan_hidup,
    p.betina_hidup,
    p.anak,
    p.muda,
    p.dewasa,
    -- Reproduksi
    r.ib_bulan_ini,
    r.ib_bulan_lalu,
    ROUND(CAST(r.sc_ratio AS NUMERIC), 2) AS sc_ratio,
    -- Kelahiran
    k.jumlah AS kelahiran_bulan_ini,
    -- Penjualan
    pj.jumlah AS penjualan_bulan_ini,
    -- Antrean
    (SELECT COUNT(*) FROM v_antrean_pkb) AS antrean_pkb,
    (SELECT COUNT(*) FROM v_antrean_kelahiran WHERE status_kelahiran IN ('SIAGA', 'DEKAT')) AS antrean_kelahiran,
    (SELECT COUNT(*) FROM v_antrean_ukur WHERE status_antrean = 'SEGERA_UKUR') AS antrean_ukur
FROM populasi p, reproduksi r, kelahiran_baru k, penjualan_bulan pj;

-- ============================================================
-- VERIFIKASI:
-- SELECT table_name FROM information_schema.views 
-- WHERE table_schema = 'public' ORDER BY table_name;
-- ============================================================
