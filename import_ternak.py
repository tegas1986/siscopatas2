"""
SISCOPATAS - Import Ulang Database Ternak (dari CSV, bebas spasi)
=================================================================
Sumber : E:\\csv\\Database_Ternak.csv
Target : tabel `ternak` (Supabase)

Alur:
  1. (Manual/SQL) Kosongkan SELURUH tabel data dulu -> jalankan
     database/10_reset_data.sql di Supabase SQL Editor. Skrip ini TIDAK
     men-drop tabel, hanya mengosongkan data agar struktur + migrasi 1-16
     tetap utuh.
  2. Baca CSV:
       - header kolom dinormalkan (spasi dibuang) agar pemetaan ke kolom
         `ternak` robust (mis. "No. Eartag Sapi" -> "No.EartagSapi").
       - NILAI: HANYA kolom `eartag` (dan `induk`, karena induk merujuk
         eartag) yang dibuang spasinya. Kolom LAIN ("rumpun", "catatan",
         "bapak", dst) dibiarkan APA ADANYA ("lain bebas", boleh spasi).
       - `tanggal_lahir` hanya diformat ke YYYY-MM-DD (bukan penghapusan spasi).
   3. Petakan header ke kolom `ternak` (lihat COL_MAP / fallback nama kolom).
  4. Insert ke `ternak`. Karena ada self-FK (induk -> eartag), insert
     dilakukan 2 tahap: tahap-1 tanpa induk, tahap-2 update induk
     (semua eartag sudah ada -> FK valid).
  5. Baris gagal (enum salah, eartag duplikat, dll) dikumpulkan & diekspor.

KEAMANAN: DRY_RUN = True secara default -> HANYA mencetak header,
pemetaan, dan contoh baris hasil bersih. Tidak ada data yang ditulis.
Setel DRY_RUN = False SETELAH memverifikasi pemetaan.
-------------------------------------------------------------------
"""

import os
import re
import sys

try:
    import pandas as pd
except Exception:
    sys.exit("Module 'pandas' belum terinstall. Jalankan: pip install pandas supabase")

try:
    from supabase import create_client, Client
except Exception:
    sys.exit("Module 'supabase' belum terinstall. Jalankan: pip install pandas supabase")

# ------------------------------- KONFIGURASI -----------------------------
DRY_RUN = True  # True -> tidak menulis apa-apa, hanya laporan

USE_ENV = True
SUPABASE_URL = "https://your-project.supabase.co"
SUPABASE_KEY = "your-service-role-key"

CSV_SOURCE_PATH = r"E:\csv\Database_Ternak.csv"
CSV_REJECT_PATH = r"E:\csv\Database_Ternak_reject.csv"

TABLE = "ternak"
BATCH_SIZE = 200

# Kolom valid di tabel ternak (whitelist -> kolom lain di-skip).
TERNAK_COLUMNS = {
    "eartag", "rumpun_ternak", "tanggal_lahir", "jenis_kelamin",
    "bapak", "induk", "status_ternak", "registrasi",
    "tanggal_kejadian", "lokasi_saat_ini", "catatan",
}

# Pemetaan header CSV (SUDAH dinormalkan: spasi dibuang, lower) -> kolom DB.
# Tambahkan/ubah di sini bila nama di CSV berbeda.
COL_MAP = {
    "no": None,
    "noeartagsapi": "eartag",
    "no.eartagsapi": "eartag",
    "eartag": "eartag",
    "eartagsapi": "eartag",
    "tag": "eartag",
    "rumpun": "rumpun_ternak",
    "rumpunternak": "rumpun_ternak",
    "tanggallahir": "tanggal_lahir",
    "jeniskelamin": "jenis_kelamin",
    "sex": "jenis_kelamin",
    "bapak": "bapak",
    "induk": "induk",
    "no.eartaginduk": "induk",
    "eartaginduk": "induk",
    "statusternak": "status_ternak",
    "registrasi": "registrasi",
    "tanggalkejadian": "tanggal_kejadian",
    "lokasi": None,            # lokasi_saat_ini butuh UUID -> di-skip (lihat catatan)
    "lokasisaatini": None,
    "catatan": "catatan",
    "keterangan": "catatan",
}
# -------------------------------------------------------------------------

ENUM_JK = {"Jantan", "Betina"}
ENUM_STATUS = {"Hidup", "Mati", "Jual", "Hibah", "Pindah"}
ENUM_REGISTRASI = {"Aset", "Persediaan"}

# rumpun_ternak: hanya divalidasi (harus nilai enum), TIDAK diubah/spasi
# tidak dihapus -> "lain bebas". Daftar nilai enum (01 + migrasi 09).
ENUM_RUMPUN = {
    "Simmental", "Limousin", "Pesisir", "Brahman", "Belgian Blue",
    "Frisian Holstein", "Silangan", "Lokal", "BBx Sim", "BBx Lim",
    "Simx Lim", "BBx Pes", "Limx Pes",
}


def load_env():
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def get_client() -> Client:
    load_env()
    url = os.environ.get("SUPABASE_URL") if USE_ENV else SUPABASE_URL
    key = (os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
           or os.environ.get("SUPABASE_KEY")) if USE_ENV else SUPABASE_KEY
    if not url or not key or "your-" in (url + key):
        sys.exit("ERROR: Isi SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY.")
    return create_client(url, key)


def strip_all_spaces(v):
    """Buang SELURUH whitespace dari nilai. None/kosong -> None.
    Dipakai untuk field identifier/teks bebas (eartag, induk, bapak, catatan)."""
    if v is None:
        return None
    s = re.sub(r"\s+", "", str(v).strip())
    return s if s else None


def norm_rumpun(v):
    """Validasi nilai rumpun (harus ada di ENUM_RUMPUN). Tidak mengubah/spasi
    tidak dihapus -> 'lain bebas'. Mengembalikan boolean untuk pengecekan."""
    return (v or "") in ENUM_RUMPUN


def norm_header(h):
    return re.sub(r"\s+", "", str(h).strip()).lower()


def map_header(h):
    n = norm_header(h)
    if n in TERNAK_COLUMNS:
        return n
    return COL_MAP.get(n, "__skip__")


def canonical_columns(df: pd.DataFrame):
    ren = {}
    for c in df.columns:
        mapped = map_header(c)
        if mapped in (None, "__skip__"):
            continue
        ren[c] = mapped
    df = df.rename(columns=ren)
    drop = [c for c in df.columns if c not in TERNAK_COLUMNS]
    return df.drop(columns=drop, errors="ignore")


def norm_date(s):
    s = (s or "").strip()
    if not s or s in ("-", "NULL", "null"):
        return None
    if "/" in s:
        d, m, y = s.split("/")
        if int(m) > 12:
            d, m = m, d
        return f"{int(y):04d}-{int(m):02d}-{int(d):02d}"
    if "-" in s and len(s.split("-")[0]) == 4:
        return s[:10]
    return s[:10] if s else None


def main():
    print(f"[DRY_RUN = {DRY_RUN}] Membaca CSV: {CSV_SOURCE_PATH}")
    try:
        try:
            df = pd.read_csv(CSV_SOURCE_PATH, dtype=str, keep_default_na=False,
                             sep=";", encoding="utf-8-sig")
        except Exception:
            df = pd.read_csv(CSV_SOURCE_PATH, dtype=str, keep_default_na=False,
                             sep=",", encoding="utf-8-sig")
    except FileNotFoundError:
        sys.exit(f"File sumber tidak ditemukan: {CSV_SOURCE_PATH}")
    except Exception as exc:
        sys.exit(f"Gagal baca CSV: {exc}")

    df = canonical_columns(df)
    print(f"Baris dimuat: {len(df)}")
    print("Kolom hasil pemetaan:", list(df.columns))

    # Tampilkan 3 baris contoh: eartag/induk dibuang spasinya, rumpun &
    # kolom lain tetap apa adanya ("lain bebas"), tanggal -> YYYY-MM-DD.
    print("\n--- CONTOH 3 BARIS (hasil final sebelum insert) ---")
    for i, raw in enumerate(df.head(3).to_dict(orient="records")):
        sample = {}
        for k, v in raw.items():
            if k == "eartag" or k == "induk":
                sample[k] = strip_all_spaces(v)   # hanya eartag + induk (ref eartag)
            elif k == "tanggal_lahir":
                sample[k] = norm_date(v)           # format, bukan soal spasi
            else:
                sample[k] = v                       # lainnya bebas (termasuk rumpun ber-spasi)
        print(f"  [{i+1}] {sample}")

    if DRY_RUN:
        print("\nDRY_RUN aktif: tidak ada data yang diimpor.")
        print("Verifikasi pemetaan kolom di atas. Jika ada yg salah, edit COL_MAP,")
        print("lalu setel DRY_RUN = False dan jalankan ulang.")
        return

    try:
        client = get_client()
    except Exception as exc:
        sys.exit(f"Gagal konek Supabase: {exc}")

    rejects, success = [], 0
    records = df.where(pd.notnull(df), None).to_dict(orient="records")
    induk_updates = []  # (eartag, induk) untuk tahap 2

    for idx, raw in enumerate(records, start=1):
        # Hanya eartag (dan induk, karena induk MERUJUK ke eartag) yang
        # dibuang spasinya. Kolom LAIN dibiarkan apa adanya ("lain bebas"):
        # rumpun, catatan, bapak, dst tetap boleh mengandung spasi.
        r = dict(raw)
        r["eartag"] = strip_all_spaces(r.get("eartag"))
        if "induk" in r:
            r["induk"] = strip_all_spaces(r.get("induk"))

        eartag = r.get("eartag")
        errors = []
        if not eartag:
            errors.append("eartag kosong")
        if r.get("rumpun_ternak") and r["rumpun_ternak"] not in ENUM_RUMPUN:
            errors.append(f"rumpun_ternak invalid: '{r['rumpun_ternak']}'")
        if r.get("jenis_kelamin") and r["jenis_kelamin"] not in ENUM_JK:
            errors.append(f"jenis_kelamin invalid: '{r['jenis_kelamin']}'")
        if r.get("status_ternak") and r["status_ternak"] not in ENUM_STATUS:
            errors.append(f"status_ternak invalid: '{r['status_ternak']}'")
        if r.get("registrasi") and r["registrasi"] not in ENUM_REGISTRASI:
            errors.append(f"registrasi invalid: '{r['registrasi']}'")

        tl = norm_date(r.get("tanggal_lahir"))
        if tl is None:
            errors.append("tanggal_lahir invalid/kosong")

        if errors:
            failed = dict(r); failed["__row"] = idx; failed["__error"] = "; ".join(errors)
            rejects.append(failed)
            continue

        induk_val = r.get("induk")
        # Tahap 1: insert TANPA induk (hindari self-FK melanggar saat induk
        # belum ter-insert). induk di-update di tahap 2.
        payload = {k: v for k, v in r.items() if k != "induk" and v is not None}
        payload["tanggal_lahir"] = tl

        try:
            client.table(TABLE).insert(payload).execute()
            success += 1
            if induk_val:
                induk_updates.append((eartag, induk_val))
        except Exception as exc:
            reason = str(exc).replace(chr(10), " ")[:500]
            failed = dict(r); failed["__row"] = idx; failed["__error"] = reason
            rejects.append(failed)
            print(f"  Baris {idx} ditolak: {reason}")

    # Tahap 2: update induk (semua eartag induk sudah ada -> FK valid).
    for eartag, induk in induk_updates:
        try:
            client.table(TABLE).update({"induk": induk}).eq("eartag", eartag).execute()
        except Exception as exc:
            print(f"  Gagal update induk {eartag} -> {induk}: {exc}")

    print(f"\nSelesai. Import ternak: {success}/{len(records)} | Ditolak: {len(rejects)}")
    if rejects:
        pd.DataFrame(rejects).to_csv(CSV_REJECT_PATH, index=False, encoding="utf-8-sig")
        print(f"Baris tolakan: {CSV_REJECT_PATH}")


if __name__ == "__main__":
    main()
