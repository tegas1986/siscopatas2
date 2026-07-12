"""
SISCOPATAS - Normalisasi & Validasi Format Eartag
=================================================
ATURAN (berlaku untuk SEMUA eartag, apa pun tipenya):
  - eartag TIDAK BOLEH mengandung spasi/whitespace sama sekali.
  - Spasi dihapus OTOMATIS saat koreksi (regexp_replace '\s+' -> '').
  - eartag kosong -> ditandai perlu review manual.

Keputusan (lihat diskusi): eartag tetap BUKAN Primary Key. PK tetap
id_ternak (UUID) yg stabil, sehingga fitur rename eartag tetap aman.
eartag cukup UNIQUE NOT NULL + CHECK ^\\S+$ (sudah di-apply lewat
database/15_eartag_tanpa_spasi.sql).

Regex validasi:
  r'^\\S+$'   -> valid bila TIDAK ada whitespace sama sekali.

Cara pakai cepat:
  python norm_eartag.py
Atau import sebagai modul:
  from norm_eartag import correct_eartag, is_valid
"""

import os
import re
import sys

try:
    import pandas as pd
except Exception:
    sys.exit("Module 'pandas' belum terinstall. Jalankan: pip install pandas")

# ------------------------------- KONFIGURASI -----------------------------
CSV_SOURCE_PATH = r"E:\csv\Database_Eartag.csv"
CSV_CLEAN_PATH = r"E:\csv\Database_Eartag_bersih.csv"
CSV_REVIEW_PATH = r"E:\csv\Database_Eartag_review.csv"

EARTAG_COL = "eartag"          # nama kolom eartag di CSV
# -------------------------------------------------------------------------

_RE_ONLY_NONSPACE = re.compile(r"^\S+$")   # valid bila tanpa whitespace


def normalize_whitespace(value):
    """Trim spasi di pinggir; kembalikan '' bila None/kosong."""
    return (value or "").strip()


def is_valid(value):
    """True bila eartag tidak kosong dan sama sekali tanpa whitespace."""
    v = (value or "").strip()
    return bool(v) and bool(_RE_ONLY_NONSPACE.match(v))


def correct_eartag(value):
    """Koreksi otomatis + laporan status.

    Return dict:
      {
        "value"       : nilai setelah koreksi (spasi dihapus),
        "corrected"   : True bila nilai diubah,
        "needs_review": True bila eartag kosong (tidak bisa dikoreksi),
        "reason"      : penjelasan singkat,
      }
    """
    original = (value or "").strip()
    if not original:
        return {"value": "", "corrected": False,
                "needs_review": True, "reason": "eartag kosong"}

    # Hapus SEMUA whitespace (spasi, tab, newline, dll) dari mana pun posisinya.
    cleaned = re.sub(r"\s+", "", original)
    if cleaned != original:
        return {"value": cleaned, "corrected": True,
                "needs_review": False, "reason": "spasi dihapus"}
    return {"value": cleaned, "corrected": False,
            "needs_review": False, "reason": ""}


def process_dataframe(df: pd.DataFrame):
    """Proses seluruh baris. Return (df_clean, df_review)."""
    if EARTAG_COL not in df.columns:
        sys.exit(f"ERROR: kolom '{EARTAG_COL}' tidak ditemukan di CSV.")

    clean_rows, review_rows = [], []
    for idx, raw in enumerate(df.to_dict(orient="records"), start=1):
        r = {k: (v.strip() if isinstance(v, str) else v) for k, v in raw.items()}
        res = correct_eartag(r.get(EARTAG_COL))
        out = dict(r)
        out[EARTAG_COL] = res["value"]
        out["__row_number"] = idx
        out["__status"] = ("dikoreksi" if res["corrected"]
                           else "ok" if not res["needs_review"] else "review")
        out["__note"] = res["reason"]
        (review_rows if res["needs_review"] else clean_rows).append(out)

    return pd.DataFrame(clean_rows), pd.DataFrame(review_rows)


def main():
    print(f"Membaca CSV: {CSV_SOURCE_PATH}")
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

    print(f"Baris dimuat: {len(df)} | kolom: {list(df.columns)}")

    df_clean, df_review = process_dataframe(df)

    n_fixed = (df_clean["__status"] == "dikoreksi").sum() if not df_clean.empty else 0
    n_ok = (df_clean["__status"] == "ok").sum() if not df_clean.empty else 0
    n_rev = len(df_review)

    print("\n============ HASIL NORMALISASI EARTAG ============")
    print(f"Valid (tidak diubah)      : {n_ok}")
    print(f"Dikoreksi (spasi dihapus) : {n_fixed}")
    print(f"Butuh review manual       : {n_rev}")
    print("==================================================")

    df_clean.to_csv(CSV_CLEAN_PATH, index=False, encoding="utf-8-sig")
    print(f"CSV bersih   : {CSV_CLEAN_PATH}")
    if n_rev:
        df_review.to_csv(CSV_REVIEW_PATH, index=False, encoding="utf-8-sig")
        print(f"CSV review   : {CSV_REVIEW_PATH}")


if __name__ == "__main__":
    main()
