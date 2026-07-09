# 🚀 Panduan Setup Komputer Baru — Sirepatas Gas App

## 📋 Prasyarat di Komputer Baru

Yang perlu diinstall/dipersiapkan:

| No | Software | Kegunaan |
|----|----------|----------|
| 1 | **Google Drive for Desktop** | Sinkronisasi file project |
| 2 | **VS Code** | Editor kode |
| 3 | **Git** | Version control |
| 4 | **Node.js** (jika pakai backend Node) | Runtime JavaScript |

---

## 🔄 Langkah 1: Install Google Drive

1. Download: https://www.google.com/drive/download/
2. Install dan login dengan email: **tegas.saja1986@gmail.com**
3. Setelah sinkron, folder `J:\My Drive\SIREPATAS GAS APP\...` akan muncul
4. Path lengkap project:
   ```
   J:\My Drive\SIREPATAS GAS APP\FRONTEND & BACKEND V2\siscopatas2
   ```

---

## 🖥️ Langkah 2: Install VS Code

1. Download: https://code.visualstudio.com/download
2. Install (centang "Add to PATH" saat instalasi)

### Aktifkan Settings Sync (bungkus ekstensi & pengaturan)

Setelah VS Code terinstall:

1. Tekan **`Ctrl+Shift+P`** → ketik **"Turn on Settings Sync..."**
2. Pilih **"Sign in with GitHub"**
3. Login dengan akun GitHub **tegas1986**
4. Centang semua: Settings, Keybindings, Extensions (Roo otomatis terinstall!), Snippets, UI State
5. Klik **"Turn On"**
6. Tunggu proses sinkronisasi selesai (ekstensi akan terinstall otomatis)

---

## 🐙 Langkah 3: Install Git

1. Download: https://git-scm.com/download/win
2. Install (default settings sudah cukup)
3. Buka **Command Prompt** atau **VS Code Terminal**
4. Set identity Git (global):
   ```bash
   git config --global user.name "tegas1986"
   git config --global user.email "tegas.saja1986@gmail.com"
   ```

---

## 📦 Langkah 4: Clone Repository dari GitHub

Buka terminal (Command Prompt atau VS Code Terminal) dan jalankan:

```bash
cd /d "J:\My Drive\SIREPATAS GAS APP\FRONTEND & BACKEND V2"
git clone https://github.com/tegas1986/siscopatas2.git
```

Atau jika sudah punya folder dari Google Drive, cukup:

```bash
cd /d "J:\My Drive\SIREPATAS GAS APP\FRONTEND & BACKEND V2\siscopatas2"
git pull origin master
```

---

## 📂 Langkah 5: Buka Project di VS Code

1. Buka VS Code
2. **File → Open Folder...**
3. Pilih: `J:\My Drive\SIREPATAS GAS APP\FRONTEND & BACKEND V2\siscopatas2`
4. Roo extension sudah terinstall otomatis dari Settings Sync ✅

---

## ✅ Cheat Sheet Perintah Git Penting

```bash
# Cek status perubahan
git status

# Lihat riwayat commit
git log --oneline

# Tarik update terbaru dari GitHub
git pull origin master

# Kirim perubahan ke GitHub
git add .
git commit -m "pesan perubahan"
git push origin master
```

---

## 📎 Links Penting

| Link | URL |
|------|-----|
| GitHub Repository | https://github.com/tegas1986/siscopatas2 |
| Google Drive | https://drive.google.com |
| VS Code | https://code.visualstudio.com |
| Git Download | https://git-scm.com/download/win |
