# 🪜 PANDUAN LOGIN — 4 Langkah Mudah

---

## 📌 LANGKAH 1 — Hapus Trigger Bermasalah

**Buka Supabase Dashboard → SQL Editor** (https://supabase.com/dashboard/project/xeafoechdhogteqcvdsm/sql/new)

Copy-paste SQL ini:

```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
```

Klik **Run** (▶️)

---

## 📌 LANGKAH 2 — Buat User Admin

1. Di Supabase Dashboard, klik **Authentication** → **Users** (sidebar kiri)
2. Klik tombol **Add User** (atau **Invite user**)
3. Isi:
   - **Email**: `admin@siscopatas.com`
   - **Password**: `Admin123!`
4. Klik **Create user**
5. Tunggu sampai muncul pesan **"User created successfully"**

---

## 📌 LANGKAH 3 — Nonaktifkan RLS, Insert User, Aktifkan RLS Kembali

**Masih di SQL Editor**, buka tab baru (klik **+ New Query**), lalu jalankan:

```sql
-- Nonaktifkan RLS
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Insert user admin
INSERT INTO public.users (id_user, username, password_hash, role, status, permissions)
SELECT 
    au.id, au.email, au.encrypted_password,
    'Super Admin'::user_role, 'Aktif', '[]'::jsonb
FROM auth.users au
WHERE au.email = 'admin@siscopatas.com'
ON CONFLICT (username) DO NOTHING;

-- Aktifkan RLS kembali
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Cek hasil
SELECT id_user, username, role, status FROM public.users;
```

Klik **Run** (▶️)

**Hasil yang diharapkan:** muncul 1 baris dengan `admin@siscopatas.com` dan role `Super Admin`

---

## 📌 LANGKAH 4 — Upload Ulang & Login

1. Buka [Blogger Dashboard](https://www.blogger.com)
2. Klik **Theme** (Tema)
3. Klik tombol ⬇️ **Back up / Restore** (pojok kanan atas)
4. Klik ⬆️ **Upload**
5. Pilih file **`frontend/index.html`** dari komputer
6. Klik **Upload**
7. Buka blog Anda

**Login:**

| Field | Isi |
|-------|-----|
| Username | `admin@siscopatas.com` |
| Password | `Admin123!` |

Klik **"Masuk ke Dasbor"**

---

### ✅ Selesai! Anda sudah login sebagai Super Admin.

Jika masih ada error, beri tahu saya pesan error yang muncul.
