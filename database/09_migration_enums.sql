-- ============================================================
-- SISCOPATAS - Penyesuaian ENUM untuk Migrasi Data Lama
-- File 09: Tambah/rename nilai enum sesuai data Google Sheets
-- ============================================================
-- Jalankan di Supabase SQL Editor SEBELUM menjalankan migrate.js
-- ============================================================

-- 1) Rumpun: rename 'FH' -> 'Frisian Holstein'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
               WHERE t.typname = 'rumpun_ternak' AND e.enumlabel = 'FH') THEN
        ALTER TYPE rumpun_ternak RENAME VALUE 'FH' TO 'Frisian Holstein';
    END IF;
END$$;

-- 2) Rumpun: tambah nilai silangan
ALTER TYPE rumpun_ternak ADD VALUE IF NOT EXISTS 'BBx Sim';
ALTER TYPE rumpun_ternak ADD VALUE IF NOT EXISTS 'BBx Lim';
ALTER TYPE rumpun_ternak ADD VALUE IF NOT EXISTS 'Simx Lim';

-- 3) Status distribusi: tambah 'Jual SNI'
ALTER TYPE status_distribusi ADD VALUE IF NOT EXISTS 'Jual SNI';

-- ============================================================
-- VERIFIKASI:
-- SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid
-- WHERE t.typname='rumpun_ternak' ORDER BY e.enumsortorder;
-- ============================================================
