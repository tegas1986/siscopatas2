-- ============================================================
-- SISCOPATAS - Fix kolom created_at yang hilang
-- File 11: Tambah created_at ke tabel yg tidak memilikinya
-- ============================================================
-- Frontend melakukan .order('created_at') pada SETIAP query select.
-- Tabel berikut tidak punya kolom tersebut -> query error -> data
-- tidak tampil di dashboard. Jalankan di Supabase SQL Editor (Run).
-- ============================================================

ALTER TABLE bull              ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE ref_lokasi        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE log_mutasi        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE kebuntingan       ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE petugas_reproduksi ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE petugas_keswan    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE keswan            ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE laporan_gangrep   ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE eartag_pasang     ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE log_audit_eartag  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE ref_sni           ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- VERIFIKASI:
-- SELECT table_name, column_name FROM information_schema.columns
-- WHERE column_name = 'created_at' AND table_schema = 'public'
-- ORDER BY table_name;
-- (semua tabel data harus punya created_at)
-- ============================================================
