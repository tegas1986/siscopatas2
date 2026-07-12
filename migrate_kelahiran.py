"""
SISCOPATAS - Migrasi CSV Kelahiran -> Supabase (dengan auto-daftar INDUK)
========================================================================
Sumber : E:\\csv\\database_kelahitan.csv
Tolak  : E:\\csv\\database_kelahiran_tolak.csv

Alur:
  1. Bersihkan semua record di tabel 'kelahiran' (target) agar tidak duplikat.
  2. Baca CSV sumber.
  3. Untuk setiap baris:
       a. Jika eartag_induk BELUM ada di tabel 'ternak' (Database Ternak),
          daftarkan/insert induk tersebut ke tabel 'ternak' terlebih dahulu.
       b. Insert record kelahiran.
  4. Baris yang gagal (validasi / mismatch tipe) dikumpulkan.
  5. Export baris gagal ke database_kelahiran_tolak.csv.

--- Konfigurasi kredensial Supabase ---------------------------------------
Rekomendasi: set environment variable
    $env:SUPABASE_URL="https://xxxx.supabase.co"
    $env:SUPABASE_SERVICE_ROLE_KEY="eyJ...service_role..."
Atau set USE_ENV = False dan isi SUPABASE_URL / SUPABASE_KEY di bawah.
Gunakan SERVICE ROLE KEY (bukan anon) agar bisa delete & insert.
---------------------------------------------------------------------------
"""

import os
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
USE_ENV = True  # False -> pakai nilai literal di bawah

SUPABASE_URL = "https://your-project.supabase.co"
SUPABASE_KEY = "your-service-role-key"

CSV_SOURCE_PATH = r"E:\csv\Database Kelahiran.csv"
CSV_REJECT_PATH = r"E:\csv\database_kelahiran_tolak.csv"

TABLE_KELAHIRAN = "kelahiran"
TABLE_TERNAK = "ternak"
PRIMARY_KEY_KELAHIRAN = "id_kelahiran"
BATCH_SIZE = 200

# Auto-daftarkan induk ke tabel ternak bila belum ada?
AUTO_REGISTER_INDUK = True
# Jenis kelamin induk selalu Betina (induk = ibu).
INDUK_JENIS_KELAMIN = "Betina"
# tanggal_lahir induk wajib (NOT NULL) tapi tidak ada di CSV kelahiran.
#   - None  -> pakai tanggal_lahir ANAK sebagai placeholder (ditandai di catatan)
#   - 'YYYY-MM-DD' -> pakai tanggal tetap tersebut
INDUK_TANGGAL_LAHIR = None
# Rumpun tak dikenal ('-', kosong) diganti dengan default ini agar tetap ter-upload.
# (Enum valid: Simmental, Limousin, Pesisir, Brahman, Belgian Blue, FH, Silangan, Lokal)
RUMPUN_UNKNOWN_DEFAULT = "Silangan"
# -------------------------------------------------------------------------

ENUM_RUMPUN = {
    "Simmental", "Limousin", "Pesisir", "Brahman",
    "Belgian Blue", "FH", "Silangan", "Lokal",
}


def load_env():
    """Muat .env di root project bila ada (tanpa dependency ekstra)."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k, v = k.strip(), v.strip().strip('"').strip("'")
            os.environ.setdefault(k, v)


def get_client() -> Client:
    load_env()
    url = os.environ.get("SUPABASE_URL") if USE_ENV else SUPABASE_URL
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY",
                         os.environ.get("SUPABASE_KEY")) if USE_ENV else SUPABASE_KEY
    if not url or not key or "your-" in (url + key):
        sys.exit("ERROR: Isi SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY (env var "
                 "atau CONFIG block).")
    return create_client(url, key)


def norm_date(s):
    s = (s or "").strip()
    if not s or s in ("-", "NULL", "null"):
        return None
    if "/" in s:                       # DD/MM/YYYY
        d, m, y = s.split("/")
        if int(m) > 12:
            d, m = m, d
        return f"{y}-{int(m):02d}-{int(d):02d}"
    if "-" in s and len(s.split("-")[2]) == 4:   # YYYY-MM-DD
        return s[:10]
    return s[:10] if s else None


def canonical_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Samakan nama kolom (terima header Indonesia maupun snake_case).
    Buang kolom kosong / NaN (akibat BOM atau pemisah di awal/akhir)."""
    mapping = {
        "no": None,
        "tanggal_lahir": "tanggal_lahir",
        "tanggal lahir": "tanggal_lahir",
        "eartag_anak": "eartag_anak",
        "eartag anak": "eartag_anak",
        "rumpun_anak": "rumpun_anak",
        "rumpun anak": "rumpun_anak",
        "jenis_kelamin": "jenis_kelamin",
        "jenis kelamin": "jenis_kelamin",
        "eartag_induk": "eartag_induk",
        "eartag induk": "eartag_induk",
        "rumpun_induk": "rumpun_induk",
        "rumpun induk": "rumpun_induk",
        "bapak": "bapak",
        "link_foto": "link_foto",
        "link foto": "link_foto",
        "otorisator input data": None,  # kolom di luar skema -> dibuang
    }
    ren = {}
    for c in df.columns:
        name = str(c).strip()
        if name.lower() in ("nan", "none", ""):
            continue  # kolom kosong -> dibuang
        ren[c] = mapping.get(name.lower(), name.lower())
    df = df.rename(columns=ren)
    drop = [c for c in df.columns if c is None or str(c).strip().lower() in ("nan", "none", "")]
    df = df.drop(columns=drop, errors="ignore")
    return df


def norm_rumpun(v):
    """Normalisasi nilai rumpun ke enum valid.
    Notasi persilangan ('BBx Sim', 'Simx Lim', ...) -> 'Silangan'.
    '-'/kosong -> RUMPUN_UNKNOWN_DEFAULT (terkonfigurasi)."""
    v = (v or "").strip()
    if not v or v == "-":
        return RUMPUN_UNKNOWN_DEFAULT
    if "x" in v.lower():
        return "Silangan"
    return v


def clear_kelahiran(client: Client) -> int:
    """Hapus semua baris di tabel kelahiran.
    Kumpulkan semua PK dulu (tanpa hapus di tengah pagination) lalu hapus
    sekaligus, agar offset tidak bergeser saat baris dihapus."""
    ids = []
    offset = 0
    while True:
        rows = (client.table(TABLE_KELAHIRAN)
                .select(PRIMARY_KEY_KELAHIRAN)
                .order(PRIMARY_KEY_KELAHIRAN)
                .range(offset, offset + BATCH_SIZE - 1)
                .execute())
        data = getattr(rows, "data", None) or []
        if not data:
            break
        ids += [r[PRIMARY_KEY_KELAHIRAN] for r in data if PRIMARY_KEY_KELAHIRAN in r]
        if len(data) < BATCH_SIZE:
            break
        offset += BATCH_SIZE

    deleted = 0
    for i in range(0, len(ids), BATCH_SIZE):
        chunk = ids[i:i + BATCH_SIZE]
        client.table(TABLE_KELAHIRAN).delete().in_(PRIMARY_KEY_KELAHIRAN, chunk).execute()
        deleted += len(chunk)
    print(f"Tabel '{TABLE_KELAHIRAN}' dibersihkan: {deleted} record dihapus.")
    return deleted


def load_existing_eartags(client: Client) -> set:
    """Ambil semua eartag ternak yang sudah ada (cache agar cepat)."""
    existing = set()
    offset = 0
    while True:
        rows = (client.table(TABLE_TERNAK)
                .select("eartag")
                .range(offset, offset + BATCH_SIZE - 1)
                .execute())
        data = getattr(rows, "data", None) or []
        if not data:
            break
        for r in data:
            if r.get("eartag"):
                existing.add(r["eartag"])
        if len(data) < BATCH_SIZE:
            break
        offset += BATCH_SIZE
    print(f"Ditemukan {len(existing)} eartag induk yang sudah terdaftar di '{TABLE_TERNAK}'.")
    return existing


def register_induk(client: Client, cache: set, row: dict):
    """Daftarkan induk ke tabel ternak bila belum ada.
    Return (registered: bool, error: str)."""
    ei = row["eartag_induk"]
    if ei in cache:
        return False, ""
    tl = INDUK_TANGGAL_LAHIR or row["tanggal_lahir"]
    catatan = ("Auto-daftar dari migrasi kelahiran"
               if INDUK_TANGGAL_LAHIR else
               "Auto-daftar dari migrasi kelahiran (tgl lahir mengikuti tgl lahir anak)")
    induk = {
        "eartag": ei,
        "rumpun_ternak": norm_rumpun(row["rumpun_induk"]),
        "tanggal_lahir": tl,
        "jenis_kelamin": INDUK_JENIS_KELAMIN,
        "catatan": catatan,
    }
    try:
        client.table(TABLE_TERNAK).insert(induk).execute()
        cache.add(ei)
        print(f"  + Induk {ei} didaftarkan ke '{TABLE_TERNAK}'.")
        return True, ""
    except Exception as exc:
        return False, f"gagal daftar induk {ei}: {str(exc).replace(chr(10), ' ')[:300]}"


def migrate(client: Client, df: pd.DataFrame):
    rejects = []
    success = 0
    registered = 0
    total = len(df)

    if AUTO_REGISTER_INDUK:
        eartag_cache = load_existing_eartags(client)
    else:
        eartag_cache = set()

    records = df.where(pd.notnull(df), None).to_dict(orient="records")

    for idx, raw in enumerate(records, start=1):
        r = {k: (v.strip() if isinstance(v, str) else v) for k, v in raw.items()}

        ei = (r.get("eartag_induk") or "").upper()
        ea = (r.get("eartag_anak") or "").upper()
        ri = norm_rumpun(r.get("rumpun_induk"))
        ra = norm_rumpun(r.get("rumpun_anak"))
        jk = (r.get("jenis_kelamin") or "").strip()
        tl = norm_date(r.get("tanggal_lahir"))

        errors = []
        if not ei:
            errors.append("eartag_induk kosong")
        if not ea:
            errors.append("eartag_anak kosong")
        if ri not in ENUM_RUMPUN:
            errors.append(f"rumpun_induk invalid: '{ri}'")
        if ra not in ENUM_RUMPUN:
            errors.append(f"rumpun_anak invalid: '{ra}'")
        if jk not in {"Jantan", "Betina"}:
            errors.append(f"jenis_kelamin invalid: '{jk}'")
        if tl is None:
            errors.append("tanggal_lahir invalid/kosong")

        if errors:
            failed = dict(r)
            failed["__row_number"] = idx
            failed["__error"] = "; ".join(errors)
            rejects.append(failed)
            continue

        row_kelahiran = {
            "tanggal_lahir": tl,
            "eartag_induk": ei,
            "rumpun_induk": ri,
            "eartag_anak": ea,
            "jenis_kelamin": jk,
            "rumpun_anak": ra,
            "bapak": (r.get("bapak") or "").strip() or None,
            "link_foto": (r.get("link_foto") or "").strip() or None,
        }

        # 3a. Pastikan induk terdaftar di tabel ternak
        if AUTO_REGISTER_INDUK:
            did_register, err_induk = register_induk(client, eartag_cache, {
                "eartag_induk": ei, "rumpun_induk": ri, "tanggal_lahir": tl,
            })
            if did_register:
                registered += 1
            if err_induk:
                failed = dict(row_kelahiran)
                failed["__row_number"] = idx
                failed["__error"] = err_induk
                rejects.append(failed)
                print(f"  Baris {idx} ditolak: {err_induk}")
                continue

        # 3b. Insert kelahiran
        try:
            client.table(TABLE_KELAHIRAN).insert(row_kelahiran).execute()
            success += 1
        except Exception as exc:
            reason = str(exc).replace(chr(10), " ")[:500]
            failed = dict(row_kelahiran)
            failed["__row_number"] = idx
            failed["__error"] = reason
            rejects.append(failed)
            print(f"  Baris {idx} ditolak: {reason}")

    print(f"\nSelesai. Upload kelahiran: {success}/{total} | "
          f"Ditolak: {len(rejects)} | Induk baru didaftarkan: {registered}.")
    return rejects


def export_rejects(rejects):
    if not rejects:
        print("Tidak ada baris tolakan yang diekspor.")
        return
    pd.DataFrame(rejects).to_csv(CSV_REJECT_PATH, index=False, encoding="utf-8-sig")
    print(f"Baris tolakan ditulis ke: {CSV_REJECT_PATH}")


def main():
    try:
        client = get_client()
    except Exception as exc:
        sys.exit(f"Gagal konek Supabase: {exc}")

    print(f"Membaca CSV: {CSV_SOURCE_PATH}")
    try:
        # CSV ini dipisah titik-koma (';'); coba ';' lalu ',' sebagai fallback.
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
    print(f"Baris dimuat: {len(df)} | kolom: {list(df.columns)}")

    clear_kelahiran(client)
    rejects = migrate(client, df)
    export_rejects(rejects)


if __name__ == "__main__":
    main()
