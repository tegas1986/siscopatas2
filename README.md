# 🐄 SISCOPATAS — Supabase + Blogger Migration

**SISCOPATAS** (Smart Integrated System for Cattle Performance Analytics)  
**BPTUHPT Padang Mengatas**

---

## 📋 Daftar Isi

1. [Gambaran Umum](#-gambaran-umum)
2. [Prasyarat](#-prasyarat)
3. [Cara Menjalankan SQL di Supabase](#-cara-menjalankan-sql-di-supabase)
4. [Tahap 1: Setup Database](#-tahap-1-setup-database)
5. [Tahap 2: Migrasi Data](#-tahap-2-migrasi-data)
6. [Tahap 3: Setup Frontend](#-tahap-3-setup-frontend)
7. [Tahap 4: Testing](#-tahap-4-testing)
8. [Tahap 5: Go-Live](#-tahap-5-go-live)
9. [Struktur File](#-struktur-file)
10. [Troubleshooting](#-troubleshooting)

---

## 🎯 Gambaran Umum

Aplikasi ini adalah **sistem manajemen peternakan sapi** yang mencakup:

| Modul | Deskripsi |
|-------|-----------|
| 📊 **Dashboard** | Populasi, grafik reproduksi, performans, antrean |
| 🐄 **Database Ternak** | Data induk sapi (eartag, rumpun, umur, lokasi) |
| 🔥 **Laporan Berahi** | Deteksi birahi, rekomendasi IB |
| 💉 **IB** | Inseminasi Buatan, riwayat kawin |
| 🤰 **PKB** | Pemeriksaan Kebuntingan, HPL (Hari Perkiraan Lahir) |
| 👶 **Kelahiran** | Pencatatan lahir, upload foto ke Google Drive |
| 📏 **Pengukuran** | 8 periode ukur, SNI grading otomatis |
| 🏆 **SNI** | Standar Nasional Indonesia (Grade 1/2/3/Non SNI) |
| 📋 **BAS** | Berita Acara Seleksi (19 kolom) |
| 💰 **Penjualan** | Manajemen penjualan/distribusi |
| 🩺 **Keswan** | Kesehatan hewan |
| ⚠️ **Gangrep** | Gangguan reproduksi, 14 hari treatment |
| 📍 **Lokasi & Mutasi** | Riwayat pindah kandang |
| 👥 **Users** | 8 role dengan RBAC |
| 📤 **Upload Massal** | 3 modul (Berahi, IB, Kelahiran) + fuzzy matching |

### Arsitektur

```
Blogger (Frontend Vue.js 2)
    ↕ HTTPS
Supabase (PostgreSQL + REST API + Auth)
    ↕ RLS
PostgreSQL (18 tabel + 6 view + 8 fungsi)
    ↕ Google Drive (Foto Kelahiran & PKB via link)
```

---

## ✅ Prasyarat

| Tool | Kegunaan | Link Download |
|------|----------|---------------|
| **Supabase Account** | Database + API | https://supabase.com |
| **Google Account** | Blogger + Google Drive | https://blogger.com |
| **VS Code** | Editor teks | https://code.visualstudio.com |
| **Node.js** | Untuk script migrasi | https://nodejs.org (LTS) |

---

## 🛠 Cara Menjalankan SQL di Supabase

### Langkah-langkah:

1. **Login** ke https://supabase.com
2. **Pilih project** `siscopatas` (atau buat project baru)
3. Klik menu **SQL Editor** di sidebar kiri
4. Klik tombol **New Query** (+)
5. **Copy-paste** isi file SQL
6. Klik **Run** (▶) atau tekan `Ctrl+Enter`

### Urutan Eksekusi:

| Urutan | File | Estimasi Waktu |
|--------|------|----------------|
| 1 | `database/01_enums.sql` | 5 detik |
| 2 | `database/02_tables.sql` | 10 detik |
| 3 | `database/03_indexes.sql` | 10 detik |
| 4 | `database/04_functions.sql` | 15 detik |
| 5 | `database/05_views.sql` | 10 detik |
| 6 | `database/06_rls.sql` | 15 detik |
| 7 | `database/07_seed_data.sql` (hanya bagian trigger & fungsi) | 5 detik |

---

## 📦 Tahap 1: Setup Database

### 1.1 Buat Project Supabase Baru

1. Buka https://supabase.com
2. Klik **New project**
3. Isi:
   - **Name**: `siscopatas`
   - **Database Password**: `Siscopatas2024!` (atau password sendiri — **catat baik-baik**)
   - **Region**: `Singapore` (paling dekat dengan Indonesia)
   - **Pricing Plan**: Free tier cukup untuk development
4. Tunggu ~2 menit sampai selesai
5. **Catat** (dari Settings → API):
   - `Project URL` (contoh: `https://iutzeofskougncvpevlv.supabase.co`)
   - `anon public key` (panjang, mulai dengan `eyJhbGciOi...`)
   - `service_role key` (RAHASIA — jangan pernah dibagikan ke frontend!)

### 1.2 Eksekusi File SQL

Buka SQL Editor dan jalankan file-file berikut **berurutan**:

```bash
# Buka file-file ini di VS Code, copy-paste ke Supabase SQL Editor:

1. database/01_enums.sql    → 14 ENUM types
2. database/02_tables.sql    → 18 tables with FK
3. database/03_indexes.sql   → Indexes untuk performa
4. database/04_functions.sql → 8 fungsi bisnis
5. database/05_views.sql     → 6 views
6. database/06_rls.sql       → RLS policies
7. database/07_seed_data.sql → HANYA bagian trigger + fungsi sync
   (JANGAN jalankan data SNI contoh jika sudah punya data asli!)
```

### 1.3 Verifikasi

Jalankan query berikut di Supabase SQL Editor:

```sql
-- Cek ENUM (harus 14 baris)
SELECT typname FROM pg_type WHERE typcategory = 'E' ORDER BY typname;

-- Cek tabel (harus 18 baris)
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' ORDER BY table_name;

-- Cek fungsi (harus 8+ baris)
SELECT proname FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace ORDER BY proname;

-- Cek view (harus 6+ baris)
SELECT table_name FROM information_schema.views 
WHERE table_schema = 'public' ORDER BY table_name;

-- Cek RLS (harus banyak baris)
SELECT tablename, count(*) FROM pg_policies 
WHERE schemaname = 'public' GROUP BY tablename;
```

### 1.4 Buat User Admin

**PENTING:** Jika trigger `on_auth_user_created` masih aktif, matikan dulu sebelum membuat user:
```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
```

**Cara 1 — Via Supabase Dashboard (MUDAH):**
1. Buka menu **Authentication** → **Users**
2. Klik **Add user**
3. Email: `admin@siscopatas.com`
4. Password: `Admin123!`
5. Klik **Create user**
6. Setelah user berhasil, buka SQL Editor, jalankan:
   ```sql
   -- Insert manual ke tabel users
   INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
   SELECT
       au.id, au.email, au.encrypted_password,
       'Super Admin'::user_role, 'Aktif', '[]'::jsonb
   FROM auth.users au
   WHERE au.email = 'admin@siscopatas.com'
   ON CONFLICT (username) DO NOTHING;
   ```

**Cara 2 — Jika ingin trigger tetap aktif:**
Jika Anda ingin trigger `on_auth_user_created` berfungsi untuk user-user berikutnya, aktifkan kembali setelah Step 6:
```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
    VALUES (
        NEW.id, NEW.email, NEW.encrypted_password,
        COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'Viewer'),
        'Aktif',
        COALESCE(NEW.raw_user_meta_data -> 'permissions', '[]'::jsonb)
    )
    ON CONFLICT (username) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
```

---

## 📤 Tahap 2: Migrasi Data dari Google Sheets

### 2.1 Export dari Google Sheets

1. Buka Google Sheets SISCOPATAS
2. **File** → **Download** → **Comma Separated Values (.csv)**
3. Export sheet berikut:

| Sheet Google Sheets | Nama File CSV | Tabel Tujuan | Wajib? |
|--------------------|---------------|--------------|--------|
| Users | `users.csv` | users | ✅ |
| Database Bull | `bull.csv` | bull | ✅ |
| Ref_Lokasi | `ref_lokasi.csv` | ref_lokasi | ✅ |
| Database Ternak | `ternak.csv` | ternak | ✅ |
| Laporan Berahi | `laporan_berahi.csv` | laporan_berahi | ✅ |
| Database IB | `ib.csv` | ib | ✅ |
| Database Kebuntingan | `kebuntingan.csv` | kebuntingan | ✅ |
| Database Kelahiran | `kelahiran.csv` | kelahiran | ✅ |
| Database Pengukuran | `pengukuran.csv` | pengukuran | ✅ |
| Keswan | `keswan.csv` | keswan | opsional |
| Laporan Gangrep | `laporan_gangrep.csv` | laporan_gangrep | opsional |
| Log_Mutasi | `log_mutasi.csv` | log_mutasi | opsional |
| Laporan Penjualan | `penjualan.csv` | penjualan | opsional |
| Log_Audit_Eartag | `log_audit_eartag.csv` | log_audit_eartag | opsional |
| Aturan SNI | `ref_sni.csv` | ref_sni | ✅ |

### 2.2 Import CSV ke Supabase

**Cara termudah — Via Table Editor:**
1. Buka menu **Table Editor** di Supabase
2. Pilih tabel tujuan
3. Klik **Insert** → **Import from CSV**
4. Pilih file CSV
5. Mapping kolom (pastikan nama kolom cocok)
6. Klik **Import**

**PENTING:** Import dalam **urutan ini** karena ada foreign key:

```
1. ref_lokasi      (tidak punya FK)
2. users           (tidak punya FK)
3. petugas_reproduksi (FK ke users)
4. petugas_keswan  (FK ke users)
5. bull            (FK ke users)
6. ref_sni         (tidak punya FK)
7. ternak          (FK ke ref_lokasi + users) ⚠️
8. log_audit_eartag (FK ke ternak)
9. laporan_berahi  (FK ke ternak + users)
10. log_mutasi     (FK ke ternak + ref_lokasi + users)
11. ib             (FK ke berahi + ternak + users)
12. keswan         (FK ke ternak + users)
13. laporan_gangrep (FK ke ternak + users)
14. kebuntingan    (FK ke ternak + users)
15. kelahiran      (FK ke ternak + users)
16. pengukuran     (FK ke ternak + users)
17. penjualan      (FK ke ternak + users)
18. eartag_pasang  (FK ke ternak + users)
```

### 2.3 Verifikasi Data

```sql
SELECT 'ternak' as tabel, COUNT(*) FROM ternak
UNION ALL
SELECT 'pengukuran', COUNT(*) FROM pengukuran
UNION ALL
SELECT 'ib', COUNT(*) FROM ib
UNION ALL
SELECT 'kebuntingan', COUNT(*) FROM kebuntingan
UNION ALL
SELECT 'kelahiran', COUNT(*) FROM kelahiran
UNION ALL
SELECT 'bull', COUNT(*) FROM bull;
```

Bandingkan jumlah baris dengan data asli di Google Sheets!

---

## 🌐 Tahap 3: Setup Frontend — Install sebagai THEME Blogger

### 3.1 Persiapan — Ganti SUPABASE_URL & SUPABASE_ANON_KEY

**WAJIB** ganti URL dan Key Supabase di [`frontend/index.html`](frontend/index.html):

1. Buka file [`frontend/index.html`](frontend/index.html)
2. Cari 2 baris ini (sekitar baris 5865–5866):
   ```javascript
   const SUPABASE_URL = "https://xxxxxxxxxxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ....";
   ```
3. Ganti dengan milikmu dari **Supabase Dashboard → Settings → API**:
   - `SUPABASE_URL` = Project URL (https://xxx.supabase.co)
   - `SUPABASE_ANON_KEY` = anon/public key

### 3.2 Install sebagai THEME (BUKAN Postingan)

> **⚠️ KRUSIAL:** File [`frontend/index.html`](frontend/index.html) SUDAH berformat **Blogger Theme XML** — ada `b:skin`, `b:section`, `b:widget`, namespace Blogger, dll. **JANGAN copy-paste ke postingan!** Install sebagai **Theme**.

**Langkah-langkah:**

1. **Login** ke [Blogger Dashboard](https://www.blogger.com)
2. Pilih blog SISCOPATAS (atau buat blog baru)
3. Di menu kiri, klik **Theme** (atau **Tema**)
4. Klik tombol **⬇️ Back up / Restore** (atau **Cadangkan / Pulihkan**) — pojok kanan atas
5. Klik **⬆️ Upload** (atau **Unggah**)
6. Pilih file **`frontend/index.html`** dari komputermu
7. Klik **Upload**
8. **SELESAI!** — Buka blog kamu, aplikasi SISCOPATAS langsung muncul full-screen

### 3.3 Konfigurasi Blogger (Settings)

Setelah Theme terinstall, atur ini di **Blogger Dashboard → Settings**:

| Pengaturan | Nilai |
|-----------|-------|
| **Language → Language** | Indonesia |
| **Language → Time Zone** | `(UTC+07:00) Asia/Jakarta` |
| **Language → Date format** | DD/MM/YYYY |
| **Privacy → Add blog to listings?** | No |
| **Privacy → Let search engines find?** | No |
| **Posts → Post feed** | None |

### 3.4 Konfigurasi CORS di Supabase

1. Buka **Supabase Dashboard → Settings → API**
2. Di bagian **CORS**, tambahkan domain blog kamu:
   ```
   https://namablog.blogspot.com
   ```
3. Klik **Save**

### 3.5 Verifikasi

Buka blog kamu. Jika berhasil:
- ✅ Layar login SISCOPATAS muncul (bukan postingan blog)
- ✅ Sidebar dengan menu lengkap di kiri
- ✅ Bisa login (setelah user dibuat)
- ✅ Responsive di HP

> **Jika masih muncul postingan:** Bersihkan cache (Ctrl+F5) atau buka tab incognito.

---

## 🧪 Tahap 4: Testing

### 4.1 Test Login
1. Buka blog SISCOPATAS
2. Login dengan `admin@siscopatas.com` / `Admin123!`
3. **Harus**: muncul dashboard dengan data

### 4.2 Test Dashboard
- [ ] Kartu populasi (total, anak, muda, dewasa)
- [ ] Grafik donat (populasi per kategori)
- [ ] Grafik donat (rumpun)
- [ ] Alert priority (gangrep, PKB, HPL, ukur)
- [ ] Kartu reproduksi (IB, S/C, kelahiran)

### 4.3 Test CRUD per Tab
Test setiap tab: tambah, edit, hapus, filter, search

### 4.4 Test Fitur Khusus
- [ ] **SNI Grading** — otomatis pas input pengukuran
- [ ] **ADG** — otomatis pas input pengukuran
- [ ] **HPL** — otomatis pas PKB positif (IB + 270 hari)
- [ ] **Gangrep** — 14 hari countdown treatment
- [ ] **Upload foto** — ke Google Drive (kelahiran & PKB)
- [ ] **BAS view** — 19 kolom muncul dengan benar
- [ ] **PDF cetak** — BAS landscape A4
- [ ] **Excel download** — BAS, IB, Penjualan, PKB, Kelahiran, Pengukuran
- [ ] **Upload massal** — 3 modul (Berahi, IB, Kelahiran)
- [ ] **Fuzzy matching** — Levenshtein distance

### 4.5 Test RBAC (8 Role)
- [ ] **Super Admin** — full akses
- [ ] **Admin Wasbit** — reproduksi + performans
- [ ] **User Wasbit** — input saja
- [ ] **Admin Keswan** — kesehatan + gangrep
- [ ] **User Keswan** — input kesehatan
- [ ] **Admin IJP** — penjualan
- [ ] **User IJP** — penjualan (terbatas)
- [ ] **Viewer** — lihat saja

### 4.6 Test Session Timeout
- [ ] 5 menit idle → muncul warning
- [ ] 10 menit idle → logout otomatis

---

## 🚀 Tahap 5: Go-Live

### Checklist Final

- [ ] Semua 14 ENUM type terbuat
- [ ] Semua 18 tabel terisi data
- [ ] Semua 8 fungsi bisa dipanggil
- [ ] Semua 6 view return data
- [ ] RLS aktif dan tidak blocking akses yang sah
- [ ] Login/logout berfungsi
- [ ] Semua tab bisa diakses sesuai role
- [ ] SNI grading benar
- [ ] ADG terhitung otomatis
- [ ] HPL otomatis
- [ ] Foto Google Drive muncul (kelahiran + PKB)
- [ ] BAS PDF bisa dicetak
- [ ] Excel bisa di-download
- [ ] Upload massal berfungsi
- [ ] Responsive di HP
- [ ] Tidak ada error di browser console (F12)

### Backup

1. Export semua data dari Supabase:
   - Table Editor → pilih tabel → Export as CSV
2. Simpan semua file SQL yang sudah dijalankan
3. Backup template Blogger

### Matikan Aplikasi Lama

1. Buka Google Sheets SISCOPATAS
2. Extensions → Apps Script
3. Hapus trigger atau nonaktifkan project
4. Informasikan ke user untuk beralih ke blog baru

---

## 📂 Struktur File

```
siscopatas2/
│
├── README.md                           ← Panduan ini
│
├── database/                           ← Semua file SQL
│   ├── 01_enums.sql                    ← 14 ENUM types
│   ├── 02_tables.sql                   ← 18 tabel
│   ├── 03_indexes.sql                  ← Indexes
│   ├── 04_functions.sql                ← 8 fungsi bisnis
│   ├── 05_views.sql                    ← 6 views
│   ├── 06_rls.sql                      ← RLS policies
│   └── 07_seed_data.sql               ← Seed + trigger Auth sync
│
├── frontend/
│   ├── index.html                      ← Seluruh aplikasi Vue.js 2
│   └── supabase.js                     ← Config Supabase client
│
├── migration/
│   └── (script transformasi data akan menyusul)
│
├── plans/
│   ├── supabase_migration_plan.md      ← Dokumen rencana teknis
│   └── DAFTAR_TUGAS_IMPLEMENTASI.md    ← Todo list Bahasa Indonesia
│
├── Backend.txt                         ← Original GAS backend
└── Frontend.txt                        ← Original Vue.js frontend
```

---

## 🔧 Troubleshooting

### Masalah: Login gagal
**Penyebab**: User belum di-sync dari Auth ke public.users
**Solusi**: 
```sql
SELECT sync_auth_users_to_public();
UPDATE public.users SET role = 'Super Admin' WHERE username = 'admin@siscopatas.com';
```

### Masalah: Data tidak muncul di tabel
**Penyebab**: RLS memblokir akses
**Solusi**: Cek role user:
```sql
SELECT current_user_role();
```
Pastikan user punya role yang sesuai dengan policy.

### Masalah: CORS error di browser
**Penyebab**: Domain Blogger belum terdaftar di Supabase CORS
**Solusi**: Tambahkan domain blog di Settings → API → CORS

### Masalah: Foto tidak muncul
**Penyebab**: Google Drive link kadang terblokir
**Solusi**: 
1. Pastikan file di Google Drive di-share ke publik
2. Cek format URL: `https://drive.google.com/thumbnail?id=FILE_ID&sz=w1000`
3. Untuk production, ganti `thumbnail` dengan `uc?export=view&id=`

### Masalah: Query lambat
**Penyebab**: Belum ada indexes
**Solusi**: Jalankan `database/03_indexes.sql`

### Masalah: SNI grade salah
**Penyebab**: Data ref_sni belum sesuai standar
**Solusi**: Cek data di tabel ref_sni, pastikan periode dan threshold benar

---

## 📞 Kontak & Dukungan

Untuk pertanyaan lebih lanjut, hubungi:
- **BPTUHPT Padang Mengatas**
- Email: (email instansi)
- Aplikasi ini dikembangkan oleh Tim Teknis BPTUHPT Padang Mengatas

---

## 📝 Catatan Rilis

| Versi | Tanggal | Perubahan |
|-------|---------|-----------|
| 1.0 | - | Migrasi dari Google Sheets + GAS ke Supabase + Blogger |
| 2.0 | - | Tambahan kolom: registrasi (Aset/Persediaan) di tabel ternak |
| 2.0 | - | Tambahan kolom: link_foto_pkb di tabel kebuntingan |
| 2.0 | - | Foto tetap via Google Drive (bukan Supabase Storage) |

---

**© 2024 BPTUHPT Padang Mengatas — SISCOPATAS v2.0**
