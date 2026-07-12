"""
SISCOPATAS - Sync Check: CSV Pengukuran vs Supabase (tabel `pengukuran`)
=======================================================================
Tujuannya:
  1. Menghitung TOTAL record pengukuran di Supabase (tabel `pengukuran`).
  2. Membandingkan file CSV lokal dengan isi database untuk mengetahui
     record mana yang SUDAH ter-upload dan mana yang MASIH HILANG.

Kunci pencocokan (natural business key):
  Tabel `pengukuran` memaksa 1 record per (eartag, periode_ukur)
  -- lihat frontend/index.html (cek duplikat eartag + periode_ukur).
  Jadi key = "EARTAG|PERIODE_UKUR" (di-normalisasi upper + strip).

Sebagai verifikasi tambahan, tanggal_ukur ikut dibandingkan; bila
key cocok tapi tanggal beda, dicatat sebagai "uploaded (tgl beda)".

Kredensial diambil dari .env (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY).
"""

import os
import sys

try:
    import pandas as pd
except Exception:
    sys.exit("Module 'pandas' belum terinstall.")

try:
    from supabase import create_client, Client
except Exception:
    sys.exit("Module 'supabase' belum terinstall.")

# ------------------------------- KONFIGURASI -----------------------------
USE_ENV = True
SUPABASE_URL = "https://your-project.supabase.co"
SUPABASE_KEY = "your-service-role-key"

CSV_SOURCE_PATH = r"E:\csv\Laporan_Database_Pengukuran_Performans.csv"
CSV_MISSING_PATH = r"E:\csv\pengukuran_missing.csv"
CSV_UPLOADED_PATH = r"E:\csv\pengukuran_uploaded.csv"
REPORT_PATH = r"E:\csv\sync_pengukuran_report.txt"

TABLE = "pengukuran"
BATCH_SIZE = 1000

# Pemetaan header CSV (Indonesia) -> nama kolom tabel
COL_MAP = {
    "no": None,
    "tanggal ukur": "tanggal_ukur",
    "no. eartag sapi": "eartag",
    "rumpun": "rumpun",
    "jenis kelamin": "sex",
    "tanggal lahir": "tanggal_lahir",
    "periode ukur": "periode_ukur",
    "panjang badan (pb - cm)": "panjang_badan",
    "lingkar dada (ld - cm)": "lingkar_dada",
    "tinggi pundak (tp - cm)": "tinggi_pundak",
    "berat badan (bb - kg)": "berat_badan",
    "lingkar scrotum (ls - cm)": "lingkar_scrotum",
    "penilaian kualitatif": "penilaian_kualitatif",
    "keterangan malformasi/cacat": "keterangan",
    "hasil evaluasi grade sni": "grade_sni",
    "rekomendasi seleksi": "rekomendasi_seleksi",
    "keterangan audit admin": "keterangan_audit_admin",
    "petugas pencatat field": None,  # di luar skema tabel pengukuran -> dibuang
}
# -------------------------------------------------------------------------


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


def norm_date(s):
    """DD/MM/YYYY atau YYYY-MM-DD -> 'YYYY-MM-DD'. None bila kosong."""
    s = (s or "").strip()
    if not s or s in ("-", "NULL", "null"):
        return None
    if "/" in s:                       # DD/MM/YYYY
        d, m, y = s.split("/")
        if int(m) > 12:
            d, m = m, d
        return f"{int(y):04d}-{int(m):02d}-{int(d):02d}"
    if "-" in s and len(s.split("-")[0]) == 4:   # YYYY-MM-DD
        return s[:10]
    return s[:10] if s else None


def norm_key(eartag, periode):
    e = (eartag or "").strip().upper()
    p = (periode or "").strip()
    return f"{e}|{p}"


def count_total(client: Client) -> int:
    res = (client.table(TABLE)
           .select("id_ukur", count="exact")
           .limit(1)
           .execute())
    return int(getattr(res, "count", 0) or 0)


def load_db_keys(client: Client):
    """Ambil (eartag, periode_ukur, tanggal_ukur) dari DB via pagination."""
    keys = set()        # "EARTAG|PERIODE"
    full = set()        # "EARTAG|PERIODE|TANGGAL"
    offset = 0
    while True:
        rows = (client.table(TABLE)
                .select("eartag,periode_ukur,tanggal_ukur")
                .range(offset, offset + BATCH_SIZE - 1)
                .execute())
        data = getattr(rows, "data", None) or []
        if not data:
            break
        for r in data:
            e = (r.get("eartag") or "").strip().upper()
            p = (r.get("periode_ukur") or "").strip()
            t = norm_date(r.get("tanggal_ukur")) or ""
            keys.add(f"{e}|{p}")
            full.add(f"{e}|{p}|{t}")
        if len(data) < BATCH_SIZE:
            break
        offset += BATCH_SIZE
    return keys, full


def canonical_columns(df: pd.DataFrame) -> pd.DataFrame:
    ren = {}
    for c in df.columns:
        name = str(c).strip().lower()
        if name in ("nan", "none", ""):
            continue
        ren[c] = COL_MAP.get(name, name)
    df = df.rename(columns=ren)
    drop = [c for c in df.columns if c is None or str(c).strip().lower() in ("nan", "none", "")]
    return df.drop(columns=drop, errors="ignore")


def main():
    try:
        client = get_client()
    except Exception as exc:
        sys.exit(f"Gagal konek Supabase: {exc}")

    total_db = count_total(client)
    print(f"[1] TOTAL record di tabel '{TABLE}' (Supabase): {total_db}")

    print("Memuat kunci (eartag, periode_ukur) dari database ...")
    db_keys, db_full = load_db_keys(client)
    print(f"    Kunci unik di DB: {len(db_keys)}")

    print(f"Membaca CSV: {CSV_SOURCE_PATH}")
    try:
        try:
            df = pd.read_csv(CSV_SOURCE_PATH, dtype=str, keep_default_na=False,
                             sep=";", encoding="utf-8-sig")
        except Exception:
            df = pd.read_csv(CSV_SOURCE_PATH, dtype=str, keep_default_na=False,
                             sep=",", encoding="utf-8-sig")
    except Exception as exc:
        sys.exit(f"Gagal baca CSV: {exc}")

    df = canonical_columns(df)
    print(f"    Baris CSV dimuat: {len(df)} | kolom: {list(df.columns)}")

    uploaded, missing, date_mismatch = [], [], []
    for idx, raw in enumerate(df.to_dict(orient="records"), start=1):
        r = {k: (v.strip() if isinstance(v, str) else v) for k, v in raw.items()}
        key = norm_key(r.get("eartag"), r.get("periode_ukur"))
        t = norm_date(r.get("tanggal_ukur")) or ""
        full = f"{key}|{t}"
        row_out = dict(r)
        row_out["__row_number"] = idx
        if key in db_keys:
            uploaded.append(row_out)
            if full not in db_full:
                date_mismatch.append(row_out)
        else:
            missing.append(row_out)

    n_csv = len(df)
    n_up = len(uploaded)
    n_miss = len(missing)
    print("\n================ HASIL SINKRONISASI ================")
    print(f"Record CSV lokal            : {n_csv}")
    print(f"SUDAH ter-upload ke DB      : {n_up}")
    print(f"MASIH HILANG (belum upload) : {n_miss}")
    print(f"  -> di antaranya cocok key tapi TANGGAL beda: {len(date_mismatch)}")
    if total_db != n_up:
        print(f"Catatan: total baris DB ({total_db}) != record CSV ter-upload ({n_up}). "
              f"Selisih {abs(total_db - n_up)} baris ada di DB tapi tidak ada di CSV ini "
              f"(record lama/berbeda sumber).")
    print("====================================================")

    pd.DataFrame(uploaded).to_csv(CSV_UPLOADED_PATH, index=False, encoding="utf-8-sig")
    pd.DataFrame(missing).to_csv(CSV_MISSING_PATH, index=False, encoding="utf-8-sig")
    print(f"\nCSV record SUDAH upload : {CSV_UPLOADED_PATH}")
    print(f"CSV record HILANG       : {CSV_MISSING_PATH}")

    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("SISCOPATAS - Laporan Sinkronisasi Pengukuran\n")
        f.write(f"Total record di DB (Supabase, tabel {TABLE}) : {total_db}\n")
        f.write(f"Record CSV lokal                              : {n_csv}\n")
        f.write(f"Sudah ter-upload                             : {n_up}\n")
        f.write(f"Masih hilang (belum upload)                  : {n_miss}\n")
        f.write(f"Key cocok tapi tanggal beda                  : {len(date_mismatch)}\n")
    print(f"Laporan teks                 : {REPORT_PATH}")


if __name__ == "__main__":
    main()
