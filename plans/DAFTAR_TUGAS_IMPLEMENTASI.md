# 📋 DAFTAR TUGAS IMPLEMENTASI SISCOPATAS — Supabase + Blogger

> **Peringatan**: Dokumen ini sangat panjang dan detail. Setiap langkah wajib diikuti urutannya.
> Jangan lewati satu langkah pun karena ada dependensi berantai.
> Setiap langkah yang selesai, centang [x] agar terlihat progresnya.

---

## 🔧 PERUBAHAN YANG DIMINTA KHUSUS

### ☐ Kolom `registrasi` di tabel `ternak`
Tabel `ternak` memiliki kolom baru:

| Kolom | Type | Default | Nilai |
|-------|------|---------|-------|
| registrasi | ENUM status_registrasi | 'Persediaan' | 'Aset' atau 'Persediaan' |

**Dampak ke aplikasi:**
1. **Modal Database Ternak** — tambah dropdown/select untuk memilih Aset/Persediaan
2. **Tabel Database Ternak** — tambah kolom di tabel tampilan
3. **Filter Database Ternak** — tambah filter Registrasi (Aset/Persediaan/Semua)
4. **Excel Export** — kolom Registrasi ikut di-export
5. **BAS (Berita Acara Seleksi)** — pertimbangkan apakah perlu filter berdasarkan status registrasi

---

## 🟢 TAHAP 0: PERSIAPAN AWAL

### ☐ 0.1 Buat Akun Supabase
1. Buka https://supabase.com
2. Daftar/Login (bisa pakai GitHub)
3. Buat project baru:
   - **Nama project**: `siscopatas`
   - **Database Password**: catat baik-baik (misal: `Siscopatas2024!`)
   - **Region**: Pilih yang paling dekat (Singapore atau Tokyo)
4. Tunggu ~2 menit sampai project selesai dibuat
5. Catat **Project URL** dan **anon public key** dari Settings → API
6. Simpan di notepad:
   ```
   SUPABASE_URL = https://xxxxxx.supabase.co
   SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIs...
   SUPABASE_SERVICE_KEY = eyJhbGciOiJIUzI1NiIs... (jangan pernah dibagikan!)
   ```

### ☐ 0.2 Siapkan Tools
1. Install **Visual Studio Code** (VS Code) — https://code.visualstudio.com
2. Install **Git** — https://git-scm.com
3. Buka VS Code, buka folder project: `siscopatas2`
4. Di VS Code, buka terminal: Terminal → New Terminal
5. Cek apakah Node.js sudah terinstall:
   ```
   node --version
   ```
   Kalau belum, download di https://nodejs.org (versi LTS)

### ☐ 0.3 Siapkan Folder Project
Buat struktur folder berikut di dalam `siscopatas2`:

```
siscopatas2/
├── database/           # Semua file SQL
│   ├── 01_enums.sql
│   ├── 02_tables.sql
│   ├── 03_indexes.sql
│   ├── 04_functions.sql
│   ├── 05_views.sql
│   ├── 06_rls.sql
│   └── 07_seed_data.sql
├── frontend/           # File frontend Vue.js
│   └── index.html      # File utama untuk Blogger
├── migration/          # Script migrasi data
│   └── export_data.gs  # Google Apps Script untuk export
└── docs/               # Dokumentasi
    └── user_guide.md
```

---

## 🟢 TAHAP 1: MEMBUAT DATABASE DI SUPABASE

> **Cara**: Buka Supabase Dashboard → SQL Editor → Copy-paste skrip SQL di bawah → Run

### ☐ 1.1 Buat SEMUA ENUM Type

Buka SQL Editor di Supabase, paste:
- [`database/01_enums.sql`]
- Isinya: 12 CREATE TYPE (rumpun_ternak, jenis_kelamin, status_ternak, kategori_ternak, grade_sni, rekomendasi_seleksi, periode_ukur, hasil_pemeriksaan, derajat_berahi, status_ib, status_gangrep, user_role, status_distribusi)

**Cek hasil**: `SELECT * FROM pg_type WHERE typcategory = 'E';` → muncul 12 baris

### ☐ 1.2 Buat SEMUA Tabel (18 tabel)

Buka SQL Editor, paste:
- [`database/02_tables.sql`]
- Isinya: CREATE TABLE untuk:
  1. `users`
  2. `petugas_reproduksi`
  3. `petugas_keswan`
  4. `bull`
  5. `ref_lokasi`
  6. `ternak`
  7. `log_mutasi`
  8. `laporan_berahi`
  9. `ib`
  10. `keswan`
  11. `laporan_gangrep`
  12. `kebuntingan` (dengan kolom `link_foto_pkb`)
  13. `kelahiran` (link_foto tetap pakai Google Drive)
  14. `pengukuran`
  15. `penjualan`
  16. `ref_sni`
  17. `eartag_pasang`
  18. `log_audit_eartag`

**Cek hasil**: `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';` → muncul 18 baris

### ☐ 1.3 Buat Indexes

Buka SQL Editor, paste:
- [`database/03_indexes.sql`]
- Index yang diperlukan:
  - `ternak(eartag)` — UNIQUE
  - `ternak(status_ternak)` — untuk filter hidup/mati
  - `ternak(rumpun_ternak)` — untuk filter breed
  - `pengukuran(eartag, tanggal_ukur)` — untuk latest measurement query
  - `pengukuran(periode_ukur)` — untuk filter periode
  - `laporan_berahi(eartag)` — untuk join
  - `laporan_berahi(status_ib)` — untuk filter
  - `ib(eartag, tanggal_ib)` — untuk riwayat IB
  - `kebuntingan(eartag)` — untuk join
  - `kebuntingan(hasil_pemeriksaan)` — untuk filter positif/negatif
  - `kelahiran(eartag_induk)` — untuk riwayat induk
  - `log_mutasi(eartag, tanggal_mutasi)` — untuk latest location
  - `penjualan(eartag)` — untuk join
  - `laporan_gangrep(eartag)` — untuk gangrep check
  - `ref_sni(rumpun, jenis_kelamin, grade)` — untuk SNI lookup
  - FULLTEXT search index untuk pencarian eartag

### ☐ 1.4 Buat Functions (5 fungsi utama)

Buka SQL Editor, paste:
- [`database/04_functions.sql`]
- Fungsi yang dibuat:
  1. **hitung_adg(eartag)** — menghitung Average Daily Gain
  2. **hitung_grade_sni(eartag, periode)** — mesin SNI grading
  3. **hitung_hpl(tanggal_ib)** — menghitung HPL = IB + 270 hari
  4. **hitung_rekomendasi_seleksi(grade, rumpun, kelamin)** — Replacement/Distribusi/Hold
  5. **check_gangrep_status(eartag)** — cek apakah sapi layak IB
  6. **generate_eartag_ns()** — generate kode eartag NS-YYMMDD-NNN

**Cek hasil**: `SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace;` → muncul 6 fungsi

### ☐ 1.5 Buat Views (5 view)

Buka SQL Editor, paste:
- [`database/05_views.sql`]
- View yang dibuat:
  1. **v_ternak** — ternak + umur_bulan + kategori (kolom computed)
  2. **v_berita_acara_seleksi** — BAS 19 kolom (ternak + latest pengukuran + penjualan)
  3. **v_antrean_pkb** — sapi 30-120 hari post-IB tanpa PKB
  4. **v_antrean_kelahiran** — sapi bunting dengan HPL dekat
  5. **v_antrean_ukur** — sapi yang perlu diukur (8 periode FSM)
  6. **v_dashboard_statistics** — statistik dashboard

**Cek hasil**: `SELECT table_name FROM information_schema.views WHERE table_schema = 'public';` → muncul 6 view

### ☐ 1.6 Aktifkan RLS + Buat Policy

Buka SQL Editor, paste:
- [`database/06_rls.sql`]
- Langkah:
  1. Enable RLS di semua 18 tabel
  2. Buat policy untuk setiap role:
     - Super Admin → ALL (full access)
     - Admin Wasbit → CRUD performance + reproduction tables
     - User Wasbit → INSERT + SELECT on same tables
     - Admin Keswan → CRUD keswan + gangrep
     - User Keswan → INSERT + SELECT on keswan + gangrep
     - Admin IJP → CRUD penjualan
     - User IJP → SELECT + INSERT penjualan
     - Viewer → SELECT only

### ☐ 1.7 Buat Trigger Auth → Users Sync

Buka SQL Editor, paste:
```sql
-- Trigger: ketika user login via Supabase Auth, otomatis terdaftar di public.users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.encrypted_password,
        COALESCE(NEW.raw_user_meta_data ->> 'role', 'Viewer')::user_role,
        'Aktif',
        COALESCE(NEW.raw_user_meta_data -> 'permissions', '[]'::jsonb)
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
```

---

## 🟢 TAHAP 2: MIGRASI DATA DARI GOOGLE SHEETS KE SUPABASE

> **PENTING**: Urutan import TIDAK BOLEH SALES karena ada foreign key.

### ☐ 2.1 Export Data dari Google Sheets

1. Buka Google Sheets SISCOPATAS
2. Export setiap sheet sebagai CSV:
   - File → Download → Comma Separated Values (.csv)
3. Sheet yang di-export (urutan bebas karena belum ada relasi):
   - Users → `users.csv`
   - Database Bull → `bull.csv`
   - Ref_Lokasi → `ref_lokasi.csv`
   - Petugas Reproduksi → `petugas_reproduksi.csv`
   - Petugas Keswan → `petugas_keswan.csv`
   - Database Ternak → `ternak.csv`
   - Laporan Berahi → `laporan_berahi.csv`
   - Database IB → `ib.csv`
   - Keswan → `keswan.csv`
   - Laporan Gangrep → `laporan_gangrep.csv`
   - Database Kebuntingan → `kebuntingan.csv`
   - Database Kelahiran → `kelahiran.csv`
   - Database Pengukuran → `pengukuran.csv`
   - Log_Mutasi → `log_mutasi.csv`
   - Laporan Penjualan → `penjualan.csv`
   - Log_Audit_Eartag → `log_audit_eartag.csv`
   - Aturan SNI → `ref_sni.csv`
   - (Jika ada sheet Pemasangan Eartag) → `eartag_pasang.csv`

### ☐ 2.2 Siapkan Script Transformasi Data

Buat script Node.js di `migration/transform.js` untuk:
1. Baca setiap CSV
2. Konversi tipe data (string → number, string → date, dll)
3. Generate UUID untuk setiap baris
4. Mapping foreign key (eartag → id_ternak)
5. Output JSON array per tabel

### ☐ 2.3 Import Data ke Supabase (URUTKAN!)

**Urutan import WAJIB:**

| Urut | Tabel | Karena |
|------|-------|--------|
| 1 | `ref_lokasi` | Tidak punya FK |
| 2 | `users` | Tidak punya FK |
| 3 | `petugas_reproduksi` | FK ke users |
| 4 | `petugas_keswan` | FK ke users |
| 5 | `bull` | FK ke users |
| 6 | `ref_sni` | Tidak punya FK |
| 7 | **`ternak`** | FK ke ref_lokasi + users |
| 8 | `log_audit_eartag` | FK ke ternak |
| 9 | `laporan_berahi` | FK ke ternak + users |
| 10 | `log_mutasi` | FK ke ternak + ref_lokasi + users |
| 11 | `ib` | FK ke laporan_berahi + ternak + users |
| 12 | `keswan` | FK ke ternak + users |
| 13 | `laporan_gangrep` | FK ke ternak + users |
| 14 | `kebuntingan` | FK ke ternak + users |
| 15 | `kelahiran` | FK ke ternak + users |
| 16 | `pengukuran` | FK ke ternak + users |
| 17 | `penjualan` | FK ke ternak + users |
| 18 | `eartag_pasang` | FK ke ternak + users |

**Cara import**: Buka Supabase Dashboard → Table Editor → Insert → Import from CSV

Atau via SQL:
```sql
-- Import dari JSON
INSERT INTO ternak (id_ternak, eartag, rumpun_ternak, tanggal_lahir, ...)
SELECT * FROM json_populate_recordset(NULL::ternak, '[{"id_ternak": "...", ...}]'::json);
```

### ☐ 2.4 Verifikasi Data

Jalankan query verifikasi:
```sql
-- Cek jumlah baris per tabel
SELECT 'ternak' as tabel, COUNT(*) FROM ternak
UNION ALL
SELECT 'pengukuran', COUNT(*) FROM pengukuran
UNION ALL
SELECT 'ib', COUNT(*) FROM ib
-- ... dan seterusnya
```

Bandingkan jumlah baris dengan Google Sheets asli.

---

## 🟢 TAHAP 3: MEMBUAT FRONTEND BARU

### ☐ 3.1 Setup Project Vue.js + Supabase Client

Di terminal VS Code:
```bash
cd siscopatas2/frontend
npm init -y
npm install vue@2 @supabase/supabase-js
```

### ☐ 3.2 Buat File `supabase.js` — Konfigurasi Client

Buat file [`frontend/supabase.js`]:
```javascript
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://xxxxxx.supabase.co'  // GANTI dengan URL project mu
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIs...'  // GANTI dengan anon key mu

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
```

### ☐ 3.3 Adaptasi `apiCall()` → Supabase Client

Di Frontend.txt (baris 9910), function `apiCall()` saat ini:
```javascript
apiCall(action, payload) {
    return fetch(GAS_URL, {
        method: 'POST',
        body: JSON.stringify({ action, username: this.currentUser?.username, payload })
    }).then(res => res.json())
}
```

**Ganti dengan**:
```javascript
// Panggil langsung Supabase
async apiCall(action, payload) {
    // Supabase REST API langsung
    const { data, error } = await supabase.from(action).select('*');
    return data;
}
```

TAPI karena action di GAS ada ~40+ jenis, kita perlu mapping:

| Action GAS | Supabase Method |
|------------|----------------|
| `getDataTab` | `supabase.from(tabel).select('*')` |
| `add...` (addib, addpkb, dll) | `supabase.from(tabel).insert(payload)` |
| `update...` (updateib, updatepkb, dll) | `supabase.from(tabel).update(payload).eq('id', id)` |
| `delete...` (deleteib, deletepkb, dll) | `supabase.from(tabel).delete().eq('id', id)` |
| `login` | `supabase.auth.signInWithPassword({email, password})` |
| `hitungGradeSNI_Server` | `supabase.rpc('hitung_grade_sni', { eartag, periode })` |

### ☐ 3.4 Adaptasi Login System

**Saat ini** (Frontend.txt baris 9962-9970):
```javascript
handleLogin() {
    fetch(GAS_URL, {
        method: 'POST',
        body: JSON.stringify({ action: 'login', username, password })
    }).then(r => r.json()).then(data => {
        localStorage.setItem('sirepatas_user', JSON.stringify(data));
        this.currentUser = data;
    })
}
```

**Ganti dengan Supabase Auth**:
```javascript
async handleLogin() {
    const { data, error } = await supabase.auth.signInWithPassword({
        email: this.username + '@siscopatas.com',  // atau pakai username langsung
        password: this.password
    });
    if (error) { alert('Login gagal: ' + error.message); return; }
    
    // Ambil data user dari tabel users
    const { data: userData } = await supabase
        .from('users')
        .select('*')
        .eq('username', this.username)
        .single();
    
    localStorage.setItem('sirepatas_user', JSON.stringify(userData));
    this.currentUser = userData;
}
```

### ☐ 3.5 Adaptasi Load Data — Ganti `fetch` dengan Supabase

**Saat ini** (Frontend.txt baris 9912):
```javascript
loadInitialData() {
    fetch(GAS_URL, { method: 'POST', body: JSON.stringify({ action: 'getInitialData', username }) })
        .then(r => r.json()).then(data => { ... })
}
```

**Ganti dengan**:
```javascript
async loadInitialData() {
    const { data: ternak, error: err1 } = await supabase.from('ternak').select('*');
    const { data: pengukuran, error: err2 } = await supabase.from('pengukuran').select('*');
    const { data: ib, error: err3 } = await supabase.from('ib').select('*');
    // ... semua tabel yang diperlukan
    
    if (err1 || err2 || err3) { console.error('Load data gagal', err1, err2, err3); return; }
    
    this.dataDatabase = ternak;
    this.dataPengukuran = pengukuran;
    this.dataIB = ib;
    // ... set semua data
}
```

### ☐ 3.6 Copy-paste Konten Blogger

**Cara deploy ke Blogger:**
1. Buka https://www.blogger.com
2. Masuk ke dashboard blog SISCOPATAS
3. Theme → Edit HTML
4. Hapus SEMUA kode yang ada
5. Paste seluruh isi `frontend/index.html` (yang sudah dimodifikasi)
6. Save

**Yang perlu diubah di template Blogger:**
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html>
<html b:css='false' b:defaultwidgetversion='2' b:layoutsVersion='3' b:responsive='true' 
      b:templateVersion='1.0.0' expr:dir='data:blog.languageDirection' 
      xmlns='http://www.w3.org/1999/xhtml' 
      xmlns:b='http://www.google.com/2005/gml/b' 
      xmlns:data='http://www.google.com/2005/gml/data' 
      xmlns:expr='http://www.google.com/2005/gml/expr'>
<head>
    <meta charset='UTF-8'/>
    <meta content='width=device-width, initial-scale=1.0' name='viewport'/>
    <title>SISCOPATAS BPTUHPT Padang Mengatas</title>
    <!-- Google Fonts -->
    <link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap' rel='stylesheet'/>
    <!-- CSS Bootstrap -->
    <link href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css' rel='stylesheet'/>
    <!-- Font Awesome -->
    <link href='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css' rel='stylesheet'/>
    <!-- Flatpickr -->
    <link href='https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css' rel='stylesheet'/>
    <!-- Vue.js -->
    <script src='https://cdn.jsdelivr.net/npm/vue@2/dist/vue.js'/>
    <style>
        /* ====== CSS SISCOPATAS ====== */
        ...paste semua CSS dari Frontend.txt baris 1-373...
    </style>
</head>
<body>
    <div id='app-container'>
        ...paste semua HTML template dari Frontend.txt baris 374-5831...
    </div>
    
    <!-- Libraries -->
    <script src='https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js'/>
    <script src='https://cdn.jsdelivr.net/npm/flatpickr'/>
    <script src='https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'/>
    <script src='https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js'/>
    <script src='https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js'/>
    
    <!-- Supabase JS -->
    <script src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js'/>
    
    <script>
        // Inisialisasi Supabase client
        const supabaseUrl = 'https://xxxxxx.supabase.co';  // GANTI!
        const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIs...';  // GANTI!
        const supabaseClient = supabase.createClient(supabaseUrl, supabaseAnonKey);
        
        // ====== SEMUA KODE VUE.JS ======
        (function() {
            // ...paste semua script Vue.js dari Frontend.txt baris 5837-10433
            // TAPI ganti semua GAS_URL dengan panggilan supabaseClient
        })();
    </script>
</body>
</html>
```

### ☐ 3.7 Integrasi Google Drive untuk Foto

**Saat upload foto kelahiran** (Frontend.txt baris 9882):
```javascript
handleImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) { alert("Ukuran foto maksimal 5MB"); return; }
    
    const reader = new FileReader();
    reader.onload = (e) => {
        const fullResult = e.target.result;
        const base64Data = fullResult.split(',')[1];
        this.formKelahiran.foto_base64 = base64Data;
        this.formKelahiran.foto_mime = file.type;
        this.formKelahiran.foto_name = file.name;
    };
    reader.readAsDataURL(file);
}
```

**Ini TIDAK BERUBAH** karena foto tetap dikirim ke Google Drive via backend.
Bedanya, backend sekarang bukan GAS tapi **Supabase Edge Function**.

Buat Edge Function `upload-foto` di Supabase:
```javascript
// supabase/functions/upload-foto/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

serve(async (req) => {
    const { base64, mime, name } = await req.json()
    
    // Upload ke Google Drive via API
    const accessToken = await getGoogleDriveToken()
    const response = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'multipart/related'
        },
        body: buildMultipart(base64, mime, name)
    })
    
    const file = await response.json()
    const thumbnailUrl = `https://drive.google.com/thumbnail?id=${file.id}&sz=w1000`
    
    return new Response(JSON.stringify({ url: thumbnailUrl }), {
        headers: { 'Content-Type': 'application/json' }
    })
})
```

**Saat view foto**: TIDAK BERUBAH — link Google Drive langsung ditampilkan:
```html
<img :src="k.link_foto" />
```

### ☐ 3.8 Integrasi Google Drive untuk Foto PKB

Tambah upload foto di modal PKB (Frontend.txt baris 5430):
```html
<div v-if='modalType === "pkb"'>
    <!-- ... form yang sudah ada ... -->
    
    <!-- BARU: Upload Foto PKB -->
    <div class='mb-3'>
        <label class='small fw-bold'>Foto Pemeriksaan (USG/Dokumentasi)</label>
        <div class='mb-2' v-if='isEdit && formPKB.link_foto_pkb'>
            <img class='img-thumbnail' style='max-width: 150px;' :src='formPKB.link_foto_pkb'/>
            <small class='text-muted'>Foto saat ini</small>
        </div>
        <input accept='image/*' class='form-control' type='file' @change='handleImageUploadPKB'/>
        <div class='form-text text-muted small'>
            <i class='fas fa-upload'/> Foto akan tersimpan di Google Drive.
        </div>
    </div>
</div>
```

Tambah method `handleImageUploadPKB`:
```javascript
handleImageUploadPKB(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) { alert("Ukuran foto maksimal 5MB"); return; }
    
    const reader = new FileReader();
    reader.onload = async (e) => {
        const base64Data = e.target.result.split(',')[1];
        // Upload ke Google Drive via Supabase Edge Function
        const { data, error } = await supabaseClient.functions.invoke('upload-foto', {
            body: { base64: base64Data, mime: file.type, name: file.name }
        });
        if (error) { alert('Gagal upload foto: ' + error.message); return; }
        this.formPKB.link_foto_pkb = data.url;
    };
    reader.readAsDataURL(file);
}
```

---

## 🟢 TAHAP 4: TESTING & VALIDASI

### ☐ 4.1 Test Login
1. Buka blog SISCOPATAS
2. Halaman login muncul dengan branding BPTUHPT
3. Login dengan username: `admin` password: `admin123`
4. Berhasil masuk ke dashboard

### ☐ 4.2 Test Dashboard
1. Semua kartu statistik muncul (populasi, anak, muda, dewasa)
2. Grafik donat populasi dan rumpun muncul
3. Alert priority (gangrep, antrean PKB, HPL, ukur) muncul
4. Tabel rekap rumpun muncul

### ☐ 4.3 Test Semua Tab (26 tab)
Test satu per satu:

| # | Tab | Test |
|---|-----|------|
| 1 | Database Ternak | Filter, search, pagination, edit, delete |
| 2 | Database Bull | CRUD, stok otomatis |
| 3 | Laporan Berahi | Tambah, edit, status IB berubah |
| 4 | Database IB | Tambah dari berahi, auto-fill |
| 5 | Database PKB | HPL otomatis, bypass mode, **upload foto PKB** |
| 6 | Database Kelahiran | Upload foto ke Google Drive, eartag NS otomatis |
| 7 | Database Pengukuran | SNI grade otomatis, ADG otomatis |
| 8 | Keswan | Tambah treatment |
| 9 | Gangrep | Status countdown 14 hari |
| 10 | Antrean Kelahiran | HPL countdown |
| 11 | Antrean Ukur | Queue berdasarkan FSM |
| 12 | Antrean PKB | Queue 30-120 hari |
| 13 | BAS | 19 kolom, override, cetak PDF, download Excel |
| 14 | Penjualan | Filter, confirm penjualan, pagination |
| 15 | Cetak Profil | PDF generasi profil individu |
| 16 | Upload Massal | 3 modul (Berahi, IB, Kelahiran), fuzzy matching |
| 17 | Users | CRUD user, role management |
| 18 | Petugas | Reproduksi & Keswan |
| 19 | Lokasi | CRUD lokasi |
| 20 | Mutasi | Riwayat pindah kandang |
| 21 | Eartag | Pasang eartag definitif |
| 22 | SNI | Riwayat SNI per sapi |
| 23-26 | Dashboard, dll | Semua fitur |

### ☐ 4.4 Test RBAC (8 Role)
Buat 8 akun test dan verifikasi akses setiap role:

| Role | Bisa Akses |
|------|-----------|
| Super Admin | Semua menu, bisa CRUD semua |
| Admin Wasbit | Data reproduksi + performans |
| User Wasbit | Input data reproduksi (tidak bisa edit data lama) |
| Admin Keswan | Data kesehatan + gangrep |
| User Keswan | Input kesehatan (terbatas) |
| Admin IJP | Penjualan + BAS read |
| User IJP | Penjualan read limited |
| Viewer | Lihat data saja, no edit |

### ☐ 4.5 Test Session Timeout
1. Login
2. Diam 5 menit → muncul warning timer
3. Diam 10 menit → logout otomatis

### ☐ 4.6 Test Bulk Upload
1. Download template Excel (Berahi, IB, Kelahiran)
2. Isi data sample
3. Upload → validasi → fuzzy matching → preview
4. Execute → data masuk

### ☐ 4.7 Test SNI Grading Engine
1. Input pengukuran baru
2. Grade SNI muncul otomatis
3. Cek perhitungan: Grade 1/2/3/Non SNI
4. Test override (Super Admin)

### ☐ 4.8 Test Download & Cetak
1. Download Excel BAS → berhasil
2. Download Excel IB → berhasil
3. Download Excel Penjualan → berhasil
4. Cetak PDF BAS → berhasil landscape A4
5. Cetak Profil Sapi (PDF) → berhasil

### ☐ 4.9 Test Google Drive Foto
1. Tambah kelahiran baru dengan upload foto
2. Foto muncul di Google Drive folder "Galeri Pedet"
3. Di aplikasi, foto muncul (via thumbnail URL)
4. Tambah PKB baru dengan upload foto
5. Foto PKB muncul di form PKB → bisa dilihat

---

## 🟢 TAHAP 5: DEPLOYMENT

### ☐ 5.1 Konfigurasi Supabase
1. Settings → API → CORS: tambahkan domain Blogger
2. Settings → Auth → Session: sesuaikan timeout
3. Settings → Auth → Email: matikan confirm email (karena user internal)
4. Storage: (tidak dipakai, tetap Google Drive)

### ☐ 5.2 Update Blogger Template
1. Buka Blogger dashboard
2. Theme → Edit HTML
3. Paste final `index.html`
4. **PENTING**: Ganti `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dengan milikmu
5. Save

### ☐ 5.3 Test Final End-to-End
1. Buka blog di browser incognito
2. Login sebagai Super Admin
3. Coba semua fitur utama
4. Login sebagai Viewer → verifikasi restricted
5. Test di HP (responsive design)

### ☐ 5.4 User Acceptance Testing (UAT)
1. Minta user BPTUHPT untuk test
2. Catat bug/feedback
3. Fix sesuai prioritas

---

## 🟢 TAHAP 6: CUTOVER & GO-LIVE

### ☐ 6.1 Backup Final
1. Export semua data dari Supabase (Table Editor → Export as CSV)
2. Simpan backup di folder terpisah
3. Catat semua konfigurasi

### ☐ 6.2 Matikan Aplikasi Lama (Google Apps Script)
1. Hapus atau nonaktifkan trigger di GAS
2. Arahkan user ke blog baru

### ☐ 6.3 Go-Live Checklist
- [ ] Semua 18 tabel terisi data
- [ ] RLS aktif dan bekerja
- [ ] Login/logout berfungsi
- [ ] Semua 26 tab dapat diakses sesuai role
- [ ] SNI grading bekerja
- [ ] ADG terhitung otomatis
- [ ] HPL otomatis
- [ ] Antrean muncul dengan benar
- [ ] BAS bisa dicetak PDF
- [ ] Upload massal berfungsi
- [ ] Foto Google Drive muncul
- [ ] **Foto PKB juga tersimpan di Google Drive**
- [ ] Dashboard menampilkan grafik
- [ ] Responsive di HP
- [ ] Session timeout bekerja
- [ ] Tidak ada error di console browser

---

## 📊 RINGKASAN FILE YANG HARUS DIBUAT

| File | Tujuan |
|------|--------|
| `database/01_enums.sql` | 12 ENUM types |
| `database/02_tables.sql` | 18 tabel |
| `database/03_indexes.sql` | ~20 indexes |
| `database/04_functions.sql` | 6 fungsi bisnis |
| `database/05_views.sql` | 6 views |
| `database/06_rls.sql` | RLS policies untuk 8 role |
| `database/07_seed_data.sql` | Data awal (admin user, lokasi default) |
| `frontend/index.html` | Seluruh aplikasi Vue.js 2 (10438 baris) + Supabase integration |
| `frontend/supabase.js` | Konfigurasi Supabase client |
| `migration/transform.js` | Script transformasi CSV → JSON |
| `migration/export_data.gs` | Google Apps Script untuk export data |

---

## ⚠️ HAL PENTING YANG TIDAK BOLEH TERLEWATKAN

1. **Fuzzy Matching** (Levenshtein) di Upload Massal — harus tetap ada
2. **SNI Grading** — algoritma Grade 1→2→3 harus SAMA PERSIS
3. **Eartag NS** — format NS-YYMMDD-NNN auto-generate
4. **Dua Jalur Kelahiran** — Pesisir bypass vs non-Pesisir via PKB
5. **14 Hari Gangrep** — countdown treatment
6. **Kategori** — Anak (≤6 bln), Muda (≤18 bln), Dewasa (>18 bln)
7. **ADG** — BB lahir estimasi sesuai rumpun
8. **HPL** — IB + 270 hari
9. **Bulk Upload 3 Modul** — Berahi, IB, Kelahiran
10. **Override BAS** — hanya Super Admin
11. **Session Timeout** — 5 menit warning, 10 menit logout
12. **Styling** — glassmorphism header, sidebar dark, sticky table headers, mobile card layout — HARUS SAMA PERSIS
13. **Foto PKB** — kolom baru `link_foto_pkb` di tabel kebuntingan + form upload
14. **Google Drive tetap** — untuk foto kelahiran DAN foto PKB
