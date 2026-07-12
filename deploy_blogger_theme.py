"""
Deploy tema Blogger secara penuh via Blogger API v3.
Kelebihan vs paste manual ke "Edit HTML":
  - Tidak ada pemotongan (truncation) oleh textarea editor.
  - File dikirim utuh -> tidak memicu error XML "must start and end
    within the same entity" (Error 400).

Prasyarat (one-time):
  1. Google Cloud Console -> buat project -> enable "Blogger API v3".
  2. OAuth consent screen (External, testing) -> add user tester.
  3. Credentials -> OAuth client ID -> "Desktop App" -> download
     client_secret.json ke folder ini.
  4. Ambil access token (cara termudah): Google OAuth 2.0 Playground
     https://developers.google.com/oauthplayground/
       - gear icon -> "Use your own OAuth credentials" -> isi Client ID/Secret
       - pilih scope: https://www.googleapis.com/auth/blogger
       - Authorize -> Exchange -> copy "Access token"
  5. Set env var di bawah, lalu jalankan.

Cara jalan (Python 3.11 yang sudah ada library requests):
  $env:BLOGGER_BLOG_ID="1234567890"        # lihat di Blogger -> Setelan -> Dasbor / URL
  $env:BLOGGER_ACCESS_TOKEN="ya29...."      # dari OAuth Playground
  py deploy_blogger_theme.py
"""

import os
import sys
import requests

try:
    import requests  # noqa
except Exception:
    sys.exit("pip install requests")

BLOG_ID = os.environ.get("BLOGGER_BLOG_ID")
TOKEN = os.environ.get("BLOGGER_ACCESS_TOKEN")
THEME_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "frontend", "index.html")

if not BLOG_ID or not TOKEN:
    sys.exit("Set env BLOGGER_BLOG_ID dan BLOGGER_ACCESS_TOKEN terlebih dahulu.")
if not os.path.exists(THEME_PATH):
    sys.exit(f"File tidak ditemukan: {THEME_PATH}")

with open(THEME_PATH, encoding="utf-8") as f:
    theme_xml = f.read()

print(f"Ukuran tema: {len(theme_xml):,} bytes")
print("Mengirim ke Blogger API (themes.update) ...")

url = f"https://www.googleapis.com/blogger/v3/blogs/{BLOG_ID}/themes"
headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}
payload = {"theme": {"body": theme_xml}}

r = requests.put(url, headers=headers, json=payload, timeout=120)

print("HTTP", r.status_code)
if r.ok:
    print("SUKSES: tema berhasil di-deploy secara utuh.")
    try:
        print("Blog:", r.json().get("blog", {}).get("name", "(n/a)"))
    except Exception:
        pass
else:
    print("GAGAL. Respons Blogger:")
    print(r.text[:1500])
    sys.exit(1)
