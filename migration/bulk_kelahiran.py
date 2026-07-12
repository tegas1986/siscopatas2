"""
SISCOPATAS - Bulk Upload Data Kelahiran (CSV -> Supabase)
=========================================================
Cara pakai:
  1. pip install supabase python-dotenv
  2. Pastikan file .env (di root project) berisi:
       SUPABASE_URL=https://xxxx.supabase.co
       SUPABASE_SERVICE_ROLE_KEY=eyJ...service_role...
  3. Siapkan CSV (UTF-8, header baris pertama). Contoh header:
       eartag_induk,rumpun_induk,tanggal_lahir,eartag_anak,jenis_kelamin,rumpun_anak,bapak,link_foto
     (Header bahasa Indonesia "Eartag Induk", "Rumpun Induk", "Tanggal Lahir",
      "Eartag Anak", "Jenis Kelamin", "Rumpun Anak", "Bapak", "Link Foto" juga diterima.)
  4. Jalankan:
       python migration/bulk_kelahiran.py kelahiran.csv            # upload sungguhan
       python migration/bulk_kelahiran.py kelahiran.csv --dry-run  # hanya validasi, tidak insert

Catatan integritas (lihat database/02_tables.sql):
  - eartag_induk  : FK -> ternak(eartag), harus sudah ada di tabel ternak (case-sensitive, uppercase)
  - eartag_anak   : UNIQUE, tidak boleh duplikat / kosong
  - rumpun_induk/rumpun_anak : enum rumpun_ternak (lihat ENUM_RUMPUN)
  - jenis_kelamin : enum 'Jantan' | 'Betina'
  - tanggal_lahir : DATE, format YYYY-MM-DD (DD/MM/YYYY otomatis dinormalisasi)
  - input_by      : dihilangkan -> otomatis NULL (hindari string kosong agar tidak gagal tipe UUID)
"""

import csv
import os
import sys

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

try:
    from supabase import create_client
except Exception as e:
    sys.exit("Module 'supabase' belum terinstall. Jalankan: pip install supabase python-dotenv")

# ---------------- KONFIGURASI ----------------
ENUM_RUMPUN = {
    'Simmental', 'Limousin', 'Pesisir', 'Brahman',
    'Belgian Blue', 'FH', 'Silangan', 'Lokal',
}
ENUM_JK = {'Jantan', 'Betina'}
BATCH = 500
TABLE = 'kelahiran'


def load_env():
    env = {}
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            m = line.strip().match(r'^([A-Z0-9_]+)\s*=\s*(.*?)\s*$')
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    env.update({k: v for k, v in os.environ.items() if k.startswith('SUPABASE')})
    return env


def norm_date(s):
    s = (s or '').strip()
    if not s or s in ('-', 'NULL', 'null'):
        return None
    if '/' in s:                       # DD/MM/YYYY atau MM/DD/YYYY
        parts = s.split('/')
        if len(parts) == 3:
            d, m, y = parts
            if int(m) > 12:             # MM/DD -> salah, anggap DD/MM
                d, m = m, d
            return f"{y}-{int(m):02d}-{int(d):02d}"
    if '-' in s:                       # YYYY-MM-DD atau DD-MM-YYYY
        parts = s.split('-')
        if len(parts) == 3 and len(parts[2]) == 4:
            y, m, d = parts
            if int(m) > 12:             # DD-MM-YYYY
                y, m, d = parts[2], parts[1], parts[0]
            return f"{y}-{int(m):02d}-{int(d):02d}"
    return s[:10] if s else None


def build_row(r):
    ei = (r.get('eartag_induk') or r.get('Eartag Induk') or '').strip().upper()
    ea = (r.get('eartag_anak') or r.get('Eartag Anak') or '').strip().upper()
    ri = (r.get('rumpun_induk') or r.get('Rumpun Induk') or '').strip()
    ra = (r.get('rumpun_anak') or r.get('Rumpun Anak') or '').strip()
    jk = (r.get('jenis_kelamin') or r.get('Jenis Kelamin') or '').strip()
    tl = norm_date(r.get('tanggal_lahir') or r.get('Tanggal Lahir'))

    errors = []
    if not ei:
        errors.append('eartag_induk kosong')
    if not ea:
        errors.append('eartag_anak kosong')
    if ri not in ENUM_RUMPUN:
        errors.append(f"rumpun_induk invalid: '{ri}'")
    if ra not in ENUM_RUMPUN:
        errors.append(f"rumpun_anak invalid: '{ra}'")
    if jk not in ENUM_JK:
        errors.append(f"jenis_kelamin invalid: '{jk}'")
    if tl is None:
        errors.append('tanggal_lahir invalid/kosong')

    row = {
        'eartag_induk': ei,
        'rumpun_induk': ri,
        'tanggal_lahir': tl,
        'eartag_anak': ea,
        'jenis_kelamin': jk,
        'rumpun_anak': ra,
        'bapak': (r.get('bapak') or r.get('Bapak') or '').strip() or None,
        'link_foto': (r.get('link_foto') or r.get('Link Foto') or '').strip() or None,
        # input_by sengaja dihilangkan -> NULL
    }
    return row, errors


def main():
    if len(sys.argv) < 2:
        sys.exit("Pakai: python migration/bulk_kelahiran.py <file.csv> [--dry-run]")
    csv_path = sys.argv[1]
    dry_run = '--dry-run' in sys.argv

    env = load_env()
    url = env.get('SUPABASE_URL')
    key = env.get('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key or 'PASTE_' in (key or ''):
        sys.exit("Isi SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY di .env (atau environment variable).")

    supabase = create_client(url, key, {'auth': {'persistSession': False}})

    if not os.path.exists(csv_path):
        sys.exit(f"File tidak ditemukan: {csv_path}")

    rows, skipped = [], []
    with open(csv_path, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for i, r in enumerate(reader, start=2):  # baris 1 = header
            row, errs = build_row(r)
            if errs:
                skipped.append((i, row.get('eartag_anak') or '-', '; '.join(errs)))
                continue
            rows.append(row)

    print(f"Valid: {len(rows)} baris | Dilewati: {len(skipped)} baris")
    for ln, ea, msg in skipped:
        print(f"  [baris {ln}] {ea}: {msg}")

    if dry_run:
        print("\n[DRY-RUN] Tidak ada data yang di-insert. Perbaiki baris di atas lalu jalankan tanpa --dry-run.")
        return

    if not rows:
        print("Tidak ada baris valid untuk di-upload.")
        return

    # Cek duplikat eartag_anak di dalam file
    seen = {}
    for row in rows:
        seen.setdefault(row['eartag_anak'], 0)
        seen[row['eartag_anak']] += 1
    dups = [k for k, v in seen.items() if v > 1]
    if dups:
        print(f"PERINGATAN: ada eartag_anak duplikat dalam file: {dups}")

    ok_total = 0
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        res = supabase.table(TABLE).insert(chunk).execute()
        if getattr(res, 'error', None):
            print(f"ERROR batch {i}-{i+len(chunk)}: {res.error}")
        else:
            ok_total += len(chunk)
            print(f"OK {i}-{i+len(chunk)} ({ok_total} total)")

    print(f"\nSELESAI. Berhasil di-upload: {ok_total} | Dilewati: {len(skipped)}")


if __name__ == '__main__':
    main()
