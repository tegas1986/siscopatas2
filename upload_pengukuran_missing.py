"""
SISCOPATAS - Upload record pengukuran yang HILANG ke Supabase
================================================================
Input  : E:\\csv\\pengukuran_missing.csv  (hasil sync_check_pengukuran.py)
Tujuan : Masukkan 992 record yang belum ada di tabel `pengukuran`
         tanpa menduplikasi 986 yang sudah ada, dan tanpa melanggar
         foreign key `pengukuran.eartag -> ternak.eartag`.

Alur:
  1. Tarik eartag `ternak` (FK target) + map username `users` (untuk input_by).
  2. Tarik key unik (eartag|periode_ukur) yang SUDAH ada di DB -> idempoten.
  3. Baca CSV missing, normalisasi & validasi tiap baris
     (mapper di-port dari migration/migrate.js, disesuaikan ke ENUM yang sah).
  4. Partisi:
       - Kelompok A: eartag SUDAH ada di `ternak`  -> langsung insert.
       - Kelompok B: eartag BELUM ada di `ternak`  -> daftarkan induk ke
         `ternak` dulu (AUTO_REGISTER_INDUK), lalu insert.
  5. Insert per-batch dengan isolasi error per-baris (pola insertRows migrate.js).
  6. Rekonsiliasi: hitung berapa dari 992 yang kini ada di DB (target = 992).
  7. Baris gagal/tolak diekspor ke pengukuran_tolak.csv.

Catatan integritas:
  - Numerik di-clip/REJECT bila di luar presisi kolom (02_tables.sql:210-214).
  - 5 baris duplikat key di DB TIDAK disentuh; karena kita hanya insert key
    yang belum ada, tidak akan menambah duplikat baru.
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

CSV_MISSING_PATH = r"E:\csv\pengukuran_missing.csv"
CSV_REJECT_PATH = r"E:\csv\pengukuran_tolak.csv"
REPORT_PATH = r"E:\csv\upload_pengukuran_report.txt"

TABLE = "pengukuran"
TABLE_TERNAK = "ternak"
TABLE_USERS = "users"
BATCH_SIZE = 500

DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"   # set DRY_RUN=1 untuk simulasi
AUTO_REGISTER_INDUK = True                        # daftar induk ke ternak bila belum ada
# -------------------------------------------------------------------------

# Enum sah (database/01_enums.sql)
ENUM_RUMPUN = {"Simmental", "Limousin", "Pesisir", "Brahman",
               "Belgian Blue", "FH", "Silangan", "Lokal"}
ENUM_PERIODE = {"Lahir", "Sapih", "9 Bulan", "12 Bulan", "15 Bulan",
                "18 Bulan", "21 Bulan", "24 Bulan"}
ENUM_PENILAIAN = {"Sesuai SNI", "Tidak Sesuai SNI"}
ENUM_GRADE = {"Grade 1", "Grade 2", "Grade 3", "Non SNI", "Belum Ada SNI"}
ENUM_REKOM = {"Replacement", "Distribusi", "Hold"}

# Map rumpun -> enum sah (perhatikan: 'FH' (bukan 'Frisian Holstein') yg valid)
RUMPUN_MAP = {
    "simmental": "Simmental", "limousin": "Limousin", "pesisir": "Pesisir",
    "brahman": "Brahman", "belgian blue": "Belgian Blue", "bb": "Belgian Blue",
    "fh": "FH", "frisian holstein": "FH", "silangan": "Silangan", "lokal": "Lokal",
    "bbx sim": "Silangan", "bbx lim": "Silangan", "simx lim": "Silangan",
}

# Batas presisi kolom numerik (NUMERIC(p,s))
NUM_MAX = {
    "panjang_badan": 999.9,      # NUMERIC(5,1)
    "lingkar_dada": 999.9,       # NUMERIC(5,1)
    "tinggi_pundak": 999.9,      # NUMERIC(5,1)
    "berat_badan": 9999.9,       # NUMERIC(6,1)
    "lingkar_scrotum": 999.9,    # NUMERIC(4,1)
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


# --------------------------- NORMALISASI ---------------------------------
def norm_date(s):
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


def norm_eartag(v):
    return (v or "").strip().upper()


def map_rumpun(v):
    if not v or not str(v).strip() or str(v).strip() == "-":
        return "Silangan"
    return RUMPUN_MAP.get(str(v).strip().lower(), "Silangan")


def norm_sex(v):
    if not v or not str(v).strip() or str(v).strip() == "-":
        return None
    c = str(v).strip().lower()[0]
    if c == "j":
        return "Jantan"
    if c == "b":
        return "Betina"
    return None


def map_periode(v):
    if not v or not str(v).strip():
        return None
    return next((p for p in ENUM_PERIODE
                 if p.lower() == str(v).strip().lower()), None)


def map_penilaian(v):
    if not v or not str(v).strip() or str(v).strip() == "-":
        return None
    t = str(v).strip().lower()
    if t == "sesuai sni":
        return "Sesuai SNI"
    if t == "tidak sesuai sni":
        return "Tidak Sesuai SNI"
    return None


def map_grade(v):
    if not v or not str(v).strip() or str(v).strip() == "-":
        return None
    return ENUM_GRADE.intersection({str(v).strip()}).__iter__().__next__() \
        if str(v).strip() in ENUM_GRADE else None


def map_rekom(v):
    if not v or not str(v).strip() or str(v).strip() == "-":
        return None
    return next((r for r in ENUM_REKOM
                 if r.lower() == str(v).strip().lower()), None)


def to_num(v):
    if v is None or str(v).strip() in ("", "-"):
        return None
    try:
        return float(str(v).replace(",", ".").replace(" ", ""))
    except Exception:
        return None


# --------------------------- LOAD DB STATE -------------------------------
def load_ternak_eartags(client: Client) -> set:
    s, off = set(), 0
    while True:
        rows = (client.table(TABLE_TERNAK).select("eartag")
                .range(off, off + 1000).execute())
        d = getattr(rows, "data", None) or []
        if not d:
            break
        for r in d:
            if r.get("eartag"):
                s.add(r["eartag"].strip().upper())
        if len(d) < 1000:
            break
        off += 1000
    return s


def load_users_map(client: Client) -> dict:
    m, off = {}, 0
    while True:
        rows = (client.table(TABLE_USERS).select("id_user,username")
                .range(off, off + 1000).execute())
        d = getattr(rows, "data", None) or []
        if not d:
            break
        for r in d:
            if r.get("username"):
                m[r["username"].strip().lower()] = r["id_user"]
        if len(d) < 1000:
            break
        off += 1000
    return m


def load_db_keys(client: Client) -> set:
    keys, off = set(), 0
    while True:
        rows = (client.table(TABLE).select("eartag,periode_ukur")
                .range(off, off + 1000).execute())
        d = getattr(rows, "data", None) or []
        if not d:
            break
        for r in d:
            keys.add(f"{(r.get('eartag') or '').strip().upper()}|"
                     f"{(r.get('periode_ukur') or '').strip()}")
        if len(d) < 1000:
            break
        off += 1000
    return keys


# --------------------------- INSERT HELPERS ------------------------------
def bulk_insert(client: Client, rows: list):
    ok, errors = 0, []
    for i in range(0, len(rows), BATCH_SIZE):
        chunk = rows[i:i + BATCH_SIZE]
        if DRY_RUN:
            ok += len(chunk)
            continue
        res = client.table(TABLE).insert(chunk).execute()
        if getattr(res, "error", None):
            for r in chunk:                # isolasi per-baris
                rr = client.table(TABLE).insert(r).execute()
                if getattr(rr, "error", None):
                    if len(errors) < 15:
                        errors.append(str(rr.error.message)[:200])
                else:
                    ok += 1
        else:
            ok += len(chunk)
    return ok, errors


def register_induk(client: Client, ternak_set: set, ei: str, rumpun: str,
                   tanggal_lahir: str):
    if ei in ternak_set:
        return True, ""
    if DRY_RUN:
        ternak_set.add(ei)
        return True, ""
    payload = {
        "eartag": ei,
        "rumpun_ternak": rumpun,
        "tanggal_lahir": tanggal_lahir,
        "jenis_kelamin": "Betina",   # induk = ibu (pengukuran betina dominan)
        "status_ternak": "Hidup",
        "registrasi": "Persediaan",
        "catatan": "Auto-daftar dari impor pengukuran (eartag belum ada di Database Ternak)",
    }
    try:
        client.table(TABLE_TERNAK).insert(payload).execute()
        ternak_set.add(ei)
        return True, ""
    except Exception as exc:
        return False, str(exc).replace("\n", " ")[:200]


# --------------------------- MAIN ----------------------------------------
def main():
    if DRY_RUN:
        print("*** MODE DRY_RUN: tidak ada data yang ditulis ke DB ***\n")
    try:
        client = get_client()
    except Exception as exc:
        sys.exit(f"Gagal konek Supabase: {exc}")

    print("Memuat state DB (ternak, users, key pengukuran) ...")
    ternak_set = load_ternak_eartags(client)
    users_map = load_users_map(client)
    db_keys = load_db_keys(client)
    print(f"  eartag ternak: {len(ternak_set)} | key pengukuran DB: {len(db_keys)}")

    print(f"Membaca: {CSV_MISSING_PATH}")
    df = pd.read_csv(CSV_MISSING_PATH, dtype=str, keep_default_na=False,
                     encoding="utf-8-sig")
    print(f"  Baris missing: {len(df)}")

    to_insert, rejects = [], []
    registered = 0
    skipped_already = 0

    for idx, raw in enumerate(df.to_dict(orient="records"), start=1):
        r = {k: (v.strip() if isinstance(v, str) else v) for k, v in raw.items()}
        errors = []

        eartag = norm_eartag(r.get("eartag"))
        periode = map_periode(r.get("periode_ukur"))
        sex = norm_sex(r.get("sex"))
        rumpun = map_rumpun(r.get("rumpun"))
        t_ukur = norm_date(r.get("tanggal_ukur"))
        t_lahir = norm_date(r.get("tanggal_lahir"))

        if not eartag:
            errors.append("eartag kosong")
        if not periode:
            errors.append(f"periode_ukur invalid: '{r.get('periode_ukur')}'")
        if not sex:
            errors.append(f"sex invalid: '{r.get('sex')}'")
        if not t_ukur:
            errors.append("tanggal_ukur invalid/kosong")
        if not t_lahir:
            errors.append("tanggal_lahir invalid/kosong")

        nums = {}
        for col, mx in NUM_MAX.items():
            n = to_num(r.get(col))
            if n is not None:
                if n < 0 or n > mx:
                    errors.append(f"{col} di luar rentang ({n} > {mx})")
                else:
                    nums[col] = round(n, 1)

        if errors:
            failed = dict(r); failed["__error"] = "; ".join(errors)
            rejects.append(failed)
            continue

        key = f"{eartag}|{periode}"
        if key in db_keys:          # sudah ada (idempoten)
            skipped_already += 1
            continue

        # Kelompok B: eartag belum ada di ternak -> daftar induk dulu
        if eartag not in ternak_set:
            if not AUTO_REGISTER_INDUK:
                failed = dict(r)
                failed["__error"] = "eartag tidak ada di ternak & AUTO_REGISTER_INDUK=False"
                rejects.append(failed)
                continue
            ok_reg, err = register_induk(client, ternak_set, eartag, rumpun, t_lahir)
            if not ok_reg:
                failed = dict(r); failed["__error"] = f"gagal daftar induk: {err}"
                rejects.append(failed)
                continue
            registered += 1

        payload = {
            "tanggal_ukur": t_ukur,
            "eartag": eartag,
            "rumpun": rumpun,
            "sex": sex,
            "tanggal_lahir": t_lahir,
            "periode_ukur": periode,
            "panjang_badan": nums.get("panjang_badan"),
            "lingkar_dada": nums.get("lingkar_dada"),
            "tinggi_pundak": nums.get("tinggi_pundak"),
            "berat_badan": nums.get("berat_badan"),
            "lingkar_scrotum": nums.get("lingkar_scrotum"),
            "penilaian_kualitatif": map_penilaian(r.get("penilaian_kualitatif")),
            "keterangan": (r.get("keterangan") or "") or None,
            "grade_sni": map_grade(r.get("grade_sni")),
            "rekomendasi_seleksi": map_rekom(r.get("rekomendasi_seleksi")),
            "keterangan_audit_admin": (r.get("keterangan_audit_admin") or "") or None,
        }
        to_insert.append(payload)

    print(f"\nValidasi selesai:")
    print(f"  Siap di-insert           : {len(to_insert)}")
    print(f"  Ditolak (invalid)        : {len(rejects)}")
    print(f"  Dilewati (sudah ada)     : {skipped_already}")
    print(f"  Induk baru didaftarkan   : {registered}")

    ok, errors = (0, []) if DRY_RUN else (0, [])
    if to_insert:
        ok, errors = bulk_insert(client, to_insert)

    print(f"\nINSERT berhasil: {ok}/{len(to_insert)}"
          + ("  [DRY_RUN]" if DRY_RUN else ""))
    for e in errors[:5]:
        print("  !", e)

    # Rekonsiliasi
    if not DRY_RUN and to_insert:
        db_keys2 = load_db_keys(client)
        still_missing = [k for k in
                         (f"{p['eartag']}|{p['periode_ukur']}" for p in to_insert)
                         if k not in db_keys2]
        print(f"Rekonsiliasi: masih missing setelah insert = {len(still_missing)} "
              f"(target 0)")

    if rejects:
        pd.DataFrame(rejects).to_csv(CSV_REJECT_PATH, index=False,
                                     encoding="utf-8-sig")
        print(f"Baris tolak diekspor ke: {CSV_REJECT_PATH}")

    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("SISCOPATAS - Laporan Upload Pengukuran\n")
        f.write(f"Mode                : {'DRY_RUN' if DRY_RUN else 'REAL'}\n")
        f.write(f"Baris missing input : {len(df)}\n")
        f.write(f"Siap di-insert      : {len(to_insert)}\n")
        f.write(f"Insert berhasil     : {ok}\n")
        f.write(f"Ditolak (invalid)   : {len(rejects)}\n")
        f.write(f"Dilewati (sudah ada): {skipped_already}\n")
        f.write(f"Induk didaftarkan   : {registered}\n")
    print(f"Laporan teks         : {REPORT_PATH}")


if __name__ == "__main__":
    main()
