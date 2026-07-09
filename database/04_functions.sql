-- ============================================================
-- SISCOPATAS - Supabase Database Schema
-- File 04: Functions (6 fungsi bisnis utama)
-- ============================================================
-- Fungsi-fungsi ini dipanggil dari frontend via:
--   supabase.rpc('nama_fungsi', { param1: value1, ... })
-- ============================================================

-- ============================================================
-- FUNCTION 1: hitung_adg
-- Menghitung Average Daily Gain
-- ADG = (BB_latest - estimated_birth_weight) / age_in_days
-- Estimasi BB Lahir:
--   Simmental/Limousin/Belgian Blue = 35 kg
--   Pesisir = 15 kg
--   Lainnya (Silangan/Lokal/FH/Brahman) = 25 kg
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_adg(eartag_param VARCHAR)
RETURNS NUMERIC(6,2) LANGUAGE plpgsql AS $$
DECLARE
    v_bb_latest NUMERIC;
    v_tanggal_ukur DATE;
    v_tanggal_lahir DATE;
    v_rumpun rumpun_ternak;
    v_bb_lahir_est NUMERIC;
    v_umur_hari INTEGER;
BEGIN
    -- Ambil pengukuran terakhir untuk eartag ini
    SELECT p.berat_badan, p.tanggal_ukur, t.tanggal_lahir, t.rumpun_ternak
    INTO v_bb_latest, v_tanggal_ukur, v_tanggal_lahir, v_rumpun
    FROM pengukuran p
    JOIN ternak t ON t.eartag = p.eartag
    WHERE p.eartag = eartag_param
    ORDER BY p.tanggal_ukur DESC
    LIMIT 1;

    IF v_bb_latest IS NULL THEN
        RETURN NULL;
    END IF;

    -- Estimasi BB lahir berdasarkan rumpun
    v_bb_lahir_est := CASE 
        WHEN v_rumpun IN ('Simmental', 'Limousin', 'Belgian Blue') THEN 35
        WHEN v_rumpun = 'Pesisir' THEN 15
        ELSE 25
    END;

    -- Umur dalam hari saat diukur
    v_umur_hari := (v_tanggal_ukur - v_tanggal_lahir);
    
    IF v_umur_hari <= 0 OR v_bb_latest < v_bb_lahir_est THEN
        RETURN NULL;
    END IF;

    RETURN ROUND(CAST((v_bb_latest - v_bb_lahir_est) AS NUMERIC) / v_umur_hari, 2);
END;
$$;

-- ============================================================
-- FUNCTION 2: hitung_adg_harian
-- SAMA PERSIS dengan logika hitungADGHarian_Server di Backend.txt
-- ADG = (BB_sekarang - BB_pertama) / selisih_hari
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_adg_harian(
    eartag_param VARCHAR,
    bb_sekarang NUMERIC,
    tanggal_ukur_param DATE,
    id_ukur_param UUID DEFAULT NULL
)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    v_ukur_pertama RECORD;
    v_selisih_hari INTEGER;
    v_hasil NUMERIC;
BEGIN
    -- Cari data pengukuran pertama untuk eartag ini (berdasarkan tanggal)
    SELECT id_ukur, berat_badan, tanggal_ukur INTO v_ukur_pertama
    FROM pengukuran
    WHERE eartag = eartag_param
    ORDER BY tanggal_ukur ASC
    LIMIT 1;

    -- Jika tidak ada data sebelumnya
    IF v_ukur_pertama.id_ukur IS NULL THEN
        RETURN '0,00 kg/hari';
    END IF;

    -- Jika baris saat ini adalah data paling awal
    IF id_ukur_param IS NOT NULL AND v_ukur_pertama.id_ukur = id_ukur_param THEN
        RETURN '0,00 kg/hari';
    END IF;

    -- Hitung ADG
    IF v_ukur_pertama.berat_badan IS NOT NULL THEN
        v_selisih_hari := (tanggal_ukur_param - v_ukur_pertama.tanggal_ukur);
        
        IF v_selisih_hari > 0 AND bb_sekarang >= v_ukur_pertama.berat_badan THEN
            v_hasil := (bb_sekarang - v_ukur_pertama.berat_badan) / v_selisih_hari;
            RETURN REPLACE(TO_CHAR(v_hasil, 'FM999990.00'), '.', ',') || ' kg/hari';
        END IF;
    END IF;

    RETURN '-';
END;
$$;

-- ============================================================
-- FUNCTION 3: hitung_adg_fase
-- SAMA PERSIS dengan logika hitungADGFase_Server di Backend.txt
-- ADG = (BB_sekarang - BB_sebelumnya) / selisih_hari
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_adg_fase(
    eartag_param VARCHAR,
    bb_sekarang NUMERIC,
    tanggal_ukur_param DATE,
    id_ukur_param UUID
)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    v_data_sebelum RECORD;
    v_selisih_hari INTEGER;
    v_hasil NUMERIC;
BEGIN
    -- Cari data pengukuran tepat satu langkah sebelumnya (kronologis)
    SELECT id_ukur, berat_badan, tanggal_ukur INTO v_data_sebelum
    FROM pengukuran
    WHERE eartag = eartag_param
      AND tanggal_ukur < tanggal_ukur_param
      AND berat_badan IS NOT NULL
    ORDER BY tanggal_ukur DESC
    LIMIT 1;

    -- Jika tidak ada data sebelumnya
    IF v_data_sebelum IS NULL THEN
        RETURN '0,00 kg/hr';
    END IF;

    -- Hitung ADG fase
    v_selisih_hari := (tanggal_ukur_param - v_data_sebelum.tanggal_ukur);
    
    IF v_selisih_hari > 0 AND bb_sekarang >= v_data_sebelum.berat_badan THEN
        v_hasil := (bb_sekarang - v_data_sebelum.berat_badan) / v_selisih_hari;
        RETURN REPLACE(TO_CHAR(v_hasil, 'FM999990.00'), '.', ',') || ' kg/hr';
    END IF;

    RETURN '-';
END;
$$;

-- ============================================================
-- FUNCTION 4: hitung_grade_sni
-- Menghitung Grade SNI berdasarkan data pengukuran
-- SAMA PERSIS dengan logika hitungGradeSNI_Server di Backend.txt
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_grade_sni(
    rumpun_param VARCHAR,
    sex_param VARCHAR,
    periode_ukur_param VARCHAR,
    panjang_badan_param NUMERIC,
    tinggi_pundak_param NUMERIC,
    lingkar_dada_param NUMERIC,
    lingkar_scrotum_param NUMERIC DEFAULT NULL,
    penilaian_kualitatif_param VARCHAR DEFAULT NULL
)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    v_rumpun TEXT;
    v_sex TEXT;
    v_periode TEXT;
    v_pkey TEXT;          -- Periode key: '6-12 bulan', '12-18 bulan', '18-24 bulan'
    v_pb NUMERIC;
    v_tp NUMERIC;
    v_ld NUMERIC;
    v_ls NUMERIC;
    v_is_jantan BOOLEAN;
    v_is_wajib_scrotum BOOLEAN;
    v_grade INTEGER;
    v_rule RECORD;
    v_hasil_grade VARCHAR := 'Non SNI';
BEGIN
    -- Validasi input wajib
    IF rumpun_param IS NULL OR sex_param IS NULL OR periode_ukur_param IS NULL 
       OR panjang_badan_param IS NULL OR lingkar_dada_param IS NULL OR tinggi_pundak_param IS NULL THEN
        RETURN '-';
    END IF;

    v_rumpun := LOWER(TRIM(rumpun_param));
    v_sex := LOWER(TRIM(sex_param));
    v_periode := LOWER(TRIM(periode_ukur_param));

    -- Periode 'Lahir' tidak bisa di-SNI
    IF v_periode = 'lahir' THEN
        RETURN 'Belum Ada SNI';
    END IF;

    -- Mapping periode ke key
    IF v_periode IN ('sapih', '9 bulan') THEN
        v_pkey := '6-12 bulan';
    ELSIF v_periode IN ('12 bulan', '15 bulan') THEN
        v_pkey := '12-18 bulan';
    ELSIF v_periode IN ('18 bulan', '21 bulan', '24 bulan') THEN
        v_pkey := '18-24 bulan';
    ELSE
        RETURN 'Non SNI';
    END IF;

    v_pb := COALESCE(panjang_badan_param, 0);
    v_tp := COALESCE(tinggi_pundak_param, 0);
    v_ld := COALESCE(lingkar_dada_param, 0);
    v_ls := COALESCE(lingkar_scrotum_param, 0);
    v_is_jantan := (v_sex = 'jantan');
    v_is_wajib_scrotum := (v_is_jantan AND v_pkey != '6-12 bulan');

    -- Cari aturan SNI yang cocok, urut dari Grade 1 (tertinggi) ke 3
    FOR v_rule IN
        SELECT grade,
               COALESCE(pb_min, 0) as pb_min,
               COALESCE(tp_min, 0) as tp_min,
               COALESCE(ld_min, 0) as ld_min,
               COALESCE(ls_min, 0) as ls_min
        FROM ref_sni
        WHERE LOWER(rumpun::text) = v_rumpun
          AND LOWER(jenis_kelamin::text) = v_sex
          AND LOWER(TRIM(periode_bulan_min::text || '-' || periode_bulan_max::text || ' bulan')) LIKE '%' || 
              CASE 
                  WHEN v_pkey = '6-12 bulan' THEN '6'
                  WHEN v_pkey = '12-18 bulan' THEN '12'
                  WHEN v_pkey = '18-24 bulan' THEN '18'
              END || '%'
        ORDER BY grade ASC  -- Grade 1 dulu (paling ketat)
    LOOP
        -- Cek PB, TP, LD
        IF v_pb >= v_rule.pb_min AND v_tp >= v_rule.tp_min AND v_ld >= v_rule.ld_min THEN
            -- Jika Jantan dan bukan periode 6-12 bulan, cek LS
            IF v_is_wajib_scrotum AND v_ls < v_rule.ls_min THEN
                CONTINUE;  -- Tidak lolos grade ini, lanjut ke grade berikutnya
            END IF;
            
            v_hasil_grade := 'Grade ' || v_rule.grade;
            EXIT;  -- Grade tertinggi yang lolos
        END IF;
    END LOOP;

    -- Override jika penilaian kualitatif 'Tidak Sesuai SNI'
    IF penilaian_kualitatif_param IS NOT NULL 
       AND LOWER(TRIM(penilaian_kualitatif_param)) = 'tidak sesuai sni' THEN
        v_hasil_grade := 'Non SNI';
    END IF;

    RETURN v_hasil_grade;
END;
$$;

-- ============================================================
-- FUNCTION 5: hitung_rekomendasi_seleksi
-- SAMA PERSIS dengan logika hitungRekomendasiSeleksi di Backend.txt
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_rekomendasi_seleksi(
    rumpun_param VARCHAR,
    sex_param VARCHAR,
    grade_sni_param VARCHAR,
    penilaian_kualitatif_param VARCHAR DEFAULT NULL
)
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    v_rumpun TEXT;
    v_sex TEXT;
    v_grade TEXT;
    v_kualitatif TEXT;
BEGIN
    v_rumpun := LOWER(TRIM(rumpun_param));
    v_sex := LOWER(TRIM(sex_param));
    v_grade := LOWER(TRIM(grade_sni_param));
    v_kualitatif := LOWER(TRIM(COALESCE(penilaian_kualitatif_param, '')));

    -- 1. Jika Jantan -> Distribusi
    IF v_sex != 'betina' THEN
        RETURN 'Distribusi';
    END IF;

    -- 2. Jika rumpun bukan Simmental, Limousin, atau Pesisir -> Distribusi
    IF v_rumpun NOT IN ('simmental', 'limousin', 'pesisir') THEN
        RETURN 'Distribusi';
    END IF;

    -- 3. Jika Betina, Rumpun OK, Grade 1 atau 2, Kualitatif Sesuai SNI -> Replacement
    IF (v_grade LIKE 'grade 1%' OR v_grade LIKE 'grade 2%') 
       AND v_kualitatif = 'sesuai sni' THEN
        RETURN 'Replacement';
    END IF;

    -- 4. Default: Distribusi
    RETURN 'Distribusi';
END;
$$;

-- ============================================================
-- FUNCTION 6: hitung_hpl
-- Menghitung Hari Perkiraan Lahir = Tanggal IB + 270 hari
-- ============================================================
CREATE OR REPLACE FUNCTION hitung_hpl(tanggal_ib DATE)
RETURNS DATE LANGUAGE plpgsql AS $$
BEGIN
    IF tanggal_ib IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN tanggal_ib + INTERVAL '270 days';
END;
$$;

-- ============================================================
-- FUNCTION 7: check_gangrep_status
-- Memeriksa apakah sapi dengan eartag tertentu layak IB
-- Berdasarkan status gangrep dan aturan 14 hari
-- ============================================================
CREATE OR REPLACE FUNCTION check_gangrep_status(eartag_param VARCHAR)
RETURNS TABLE (
    status VARCHAR,
    pesan TEXT,
    tanggal_lapor DATE,
    hari_terakhir INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_gangrep RECORD;
    v_hari INTEGER;
BEGIN
    -- Cari gangrep terbaru untuk eartag ini
    SELECT * INTO v_gangrep
    FROM laporan_gangrep
    WHERE eartag = eartag_param
    ORDER BY created_at DESC
    LIMIT 1;

    -- Tidak ada gangrep → Layak IB
    IF v_gangrep.id_gangrep IS NULL THEN
        status := 'LAYAK';
        pesan := 'Sapi layak IB (tidak ada gangrep)';
        tanggal_lapor := NULL;
        hari_terakhir := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    v_hari := CURRENT_DATE - v_gangrep.tanggal_lapor;

    -- Cek status gangrep
    CASE v_gangrep.status_akhir
        WHEN 'Open' THEN
            IF v_hari > 14 THEN
                status := 'MENUNGGU_TREATMENT';
                pesan := 'Menunggu treatment (' || v_hari || ' hari sejak laporan)';
            ELSE
                status := 'DALAM_MASA_TENGGANG';
                pesan := 'Dalam masa tenggang (' || (14 - v_hari) || ' hari tersisa)';
            END IF;
        
        WHEN 'Dalam Penanganan' THEN
            status := 'TIDAK_LAYAK';
            pesan := 'Tidak layak IB (dalam penanganan keswan)';
        
        WHEN 'Selesai' THEN
            status := 'LAYAK';
            pesan := 'Sapi layak IB (gangrep selesai)';
        
        WHEN 'Kronis' THEN
            status := 'TIDAK_LAYAK';
            pesan := 'Tidak layak IB (gangrep kronis)';
        
        WHEN 'Tidak Layak IB' THEN
            status := 'TIDAK_LAYAK';
            pesan := 'Tidak layak IB';
        
        ELSE
            status := 'LAYAK';
            pesan := 'Status tidak dikenal, dianggap layak';
    END CASE;

    tanggal_lapor := v_gangrep.tanggal_lapor;
    hari_terakhir := v_hari;
    RETURN NEXT;
END;
$$;

-- ============================================================
-- FUNCTION 8: generate_eartag_ns
-- Menghasilkan kode eartag sementara NS-YYMMDD-NNN
-- ============================================================
CREATE OR REPLACE FUNCTION generate_eartag_ns()
RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    v_kode_tanggal VARCHAR(6);
    v_nomor INTEGER;
    v_eartag VARCHAR(50);
BEGIN
    v_kode_tanggal := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Cari nomor urut terakhir untuk tanggal ini
    SELECT COALESCE(MAX(CAST(SPLIT_PART(eartag_anak, '-', 3) AS INTEGER)), 0) + 1
    INTO v_nomor
    FROM kelahiran
    WHERE eartag_anak LIKE 'NS-' || v_kode_tanggal || '-%';

    v_eartag := 'NS-' || v_kode_tanggal || '-' || LPAD(v_nomor::text, 3, '0');
    RETURN v_eartag;
END;
$$;

-- ============================================================
-- VERIFIKASI:
-- SELECT proname, pronargs FROM pg_proc 
-- WHERE pronamespace = 'public'::regnamespace 
-- ORDER BY proname;
-- ============================================================
