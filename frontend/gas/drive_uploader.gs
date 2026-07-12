// ============================================================
// drive_uploader.gs
// Google Apps Script - Web App proxy untuk mengunggah HANYA FOTO
// "Kelahiran Mandiri" ke Google Drive (folder "Galeri Siscopatas").
//
// PENTING: File ini TIDAK menyimpan data teks/metadata. Data input
// (eartag, tanggal, rumpun, dll) tetap disimpan ke Supabase oleh
// frontend. Di sini hanya gambar yang di-upload ke Drive, lalu
// URL-nya dikembalikan agar disimpan ke kolom link_foto di Supabase.
//
// CARA DEPLOY:
//   1. Buka https://script.google.com -> New Project.
//   2. Paste kode ini, lalu Save.
//   3. Deploy -> New deployment -> pilih type "Web app".
//   4. Execute as: Me
//      Who has access: Anyone  (agar bisa dipanggil dari frontend Blogger)
//   5. Copy URL Web App hasil deploy, lalu isikan ke konstanta
//      GAS_DRIVE_WEBAPP_URL di frontend/index.html.
//
// Folder tujuan sudah di-hardcode di frontend (DRIVE_FOLDER_ID).
// Pastikan akun Google yang menjalankan script punya akses EDIT
// ke folder tersebut.
// ============================================================

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    status: 'ok',
    message: 'Drive uploader ready'
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const folderId = data.folderId;

    if (!folderId) throw new Error('folderId wajib diisi.');
    const folder = DriveApp.getFolderById(folderId);

    // HANYA file gambar yang diproses. Jika tidak ada foto, kembalikan
    // success dengan fotoUrl kosong (frontend menyimpan data tanpa foto).
    if (!data.foto || !data.foto.base64) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        fotoUrl: ''
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const tz = Session.getScriptTimeZone();
    const ts = Utilities.formatDate(new Date(), tz, 'yyyyMMdd_HHmmss');
    const tag = String(data.foto.name || 'foto')
      .replace(/\.[^.]+$/, '')
      .replace(/[^\w-]/g, '_');

    const bytes = Utilities.base64Decode(data.foto.base64);
    const mime = data.foto.mime || 'image/jpeg';
    let ext = '.jpg';
    if (mime.indexOf('png') > -1) ext = '.png';
    else if (mime.indexOf('webp') > -1) ext = '.webp';
    else if (mime.indexOf('gif') > -1) ext = '.gif';

    const fotoName = tag + '_' + ts + ext;
    const imgBlob = Utilities.newBlob(bytes, mime, fotoName);
    const imgFile = folder.createFile(imgBlob);

    // Coba buat file bisa diakses publik agar <img> di frontend bisa merender.
    // JIKA kebijakan org/domain melarang sharing "Anyone with link", setSharing
    // akan melempar "Akses ditolak". Ini dibiarkan BEST-EFFORT agar unggahan
    // tetap sukses (file sudah terbuat) dan frontend bisa melanjutkan menyimpan
    // data ke database. Tanpa blok try ini, seluruh request dianggap gagal.
    try {
      imgFile.setSharing(DriveApp.Access.ANYONE, DriveApp.Permission.VIEW);
    } catch (shErr) {
      // Abaikan: file sudah terunggah; hanya URL publik yang mungkin tidak
      // bisa diakses oleh pengguna lain. Lihat catatan izin di bawah.
      console.log('setSharing dilewati (kebijakan sharing): ' + shErr.message);
    }

    const fotoUrl = 'https://drive.google.com/uc?export=view&id=' + imgFile.getId();

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      fotoId: imgFile.getId(),
      fotoUrl: fotoUrl
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.message
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
