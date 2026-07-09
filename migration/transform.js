/**
 * SISCOPATAS — Transform Script Google Sheets → Supabase
 * =======================================================
 * 
 * Cara pakai (Node.js):
 *   1. Export setiap sheet dari Google Sheets sebagai file CSV
 *   2. Letakkan file CSV di folder ./migration/csv/
 *   3. Jalankan: node migration/transform.js
 *   4. Hasil JSON akan muncul di folder ./migration/json/
 * 
 * Pemetaan sheet → tabel Supabase:
 *   Sheet "Database Ternak"        → ternak
 *   Sheet "Laporan Berahi"         → laporan_berahi
 *   Sheet "Database IB"            → ib
 *   Sheet "Kebuntingan"            → kebuntingan
 *   Sheet "Database Kelahiran"     → kelahiran
 *   Sheet "Database Pengukuran"    → pengukuran
 *   Sheet "Penjualan"              → penjualan
 *   Sheet "Keswan"                 → keswan
 *   Sheet "Gangrep"                → laporan_gangrep
 *   Sheet "Mutasi"                 → log_mutasi
 *   Sheet "Database Bull"          → bull
 *   Sheet "Database Petugas"       → petugas_reproduksi & petugas_keswan
 *   Sheet "Database User"          → users
 *   Sheet "Database Lokasi"        → ref_lokasi
 *   Sheet "Aturan SNI"             → ref_sni
 *   Sheet "Eartag Terpasang"       → eartag_pasang
 */

const fs = require('fs');
const path = require('path');

// ===================== KONFIGURASI =====================
const CSV_DIR = path.join(__dirname, 'csv');
const JSON_DIR = path.join(__dirname, 'json');

// Pastikan folder tujuan ada
if (!fs.existsSync(JSON_DIR)) fs.mkdirSync(JSON_DIR, { recursive: true });
if (!fs.existsSync(CSV_DIR)) {
    fs.mkdirSync(CSV_DIR, { recursive: true });
    console.log("📁 Folder 'migration/csv/' telah dibuat. Letakkan file CSV di sini.");
    console.log("📄 Contoh: Database Ternak.csv, Laporan Berahi.csv, dll.");
    process.exit(0);
}

// ===================== PEMETAAN SHEET → TABEL =====================
const TABLE_MAP = {
    'Database Ternak': { table: 'ternak', transform: transformTernak },
    'Laporan Berahi': { table: 'laporan_berahi', transform: (r) => r },
    'Database IB': { table: 'ib', transform: transformIB },
    'Kebuntingan': { table: 'kebuntingan', transform: transformKebuntingan },
    'Database Kelahiran': { table: 'kelahiran', transform: transformKelahiran },
    'Database Pengukuran': { table: 'pengukuran', transform: transformPengukuran },
    'Penjualan': { table: 'penjualan', transform: transformPenjualan },
    'Keswan': { table: 'keswan', transform: (r) => r },
    'Gangrep': { table: 'laporan_gangrep', transform: (r) => r },
    'Mutasi': { table: 'log_mutasi', transform: (r) => r },
    'Database Bull': { table: 'bull', transform: transformBull },
    'Database Petugas': { table: 'petugas_reproduksi', transform: transformPetugas },
    'Database User': { table: 'users', transform: transformUser },
    'Database Lokasi': { table: 'ref_lokasi', transform: (r) => r },
    'Aturan SNI': { table: 'ref_sni', transform: (r) => r },
    'Eartag Terpasang': { table: 'eartag_pasang', transform: (r) => r }
};

// ===================== FUNGSI TRANSFORM =====================

/**
 * Transformasi baris Database Ternak
 * Map kolom GAS → kolom Supabase
 */
function transformTernak(row) {
    return {
        id_ternak: row.id_ternak || row['ID Ternak'] || row.eartag || '',
        rumpun_ternak: row.rumpun_ternak || row.rumpun || row.Rumpun || '',
        jenis_kelamin: row.jenis_kelamin || row['Jenis Kelamin'] || row.kelamin || 'Jantan',
        registrasi: row.registrasi || row.Registrasi || 'Persediaan',
        tanggal_lahir: normalizeDate(row.tanggal_lahir || row['Tanggal Lahir']),
        bapak: row.bapak || row.Bapak || '',
        induk: row.induk || row.Induk || '',
        status_ternak: row.status_ternak || row['Status Ternak'] || row.status || 'Hidup',
        tanggal_kejadian: normalizeDate(row.tanggal_kejadian || row['Tanggal Kejadian']),
        lokasi_saat_ini: row.lokasi_saat_ini || row['Lokasi Saat Ini'] || row.lokasi || '',
        catatan: row.catatan || row.Catatan || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris IB — pastikan field penting
 */
function transformIB(row) {
    return {
        id_ib: row.id_ib || row['ID IB'] || '',
        id_lapor: row.id_lapor || row['ID Lapor'] || '',
        eartag: row.eartag || row.Eartag || row.id_ternak || '',
        rumpun: row.rumpun || row.Rumpun || '',
        tanggal_ib: normalizeDate(row.tanggal_ib || row['Tanggal IB']),
        nama_bull: row.nama_bull || row['Nama Bull'] || row.bull || '',
        inseminator: row.inseminator || row.Inseminator || '',
        input_by: row.input_by || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Kebuntingan
 */
function transformKebuntingan(row) {
    return {
        id_pkb: row.id_pkb || row['ID PKB'] || '',
        eartag: row.eartag || row.Eartag || row.id_ternak || '',
        rumpun: row.rumpun || row.Rumpun || '',
        tanggal_ib: normalizeDate(row.tanggal_ib || row['Tanggal IB']),
        tanggal_pemeriksaan: normalizeDate(row.tanggal_pemeriksaan || row['Tanggal Pemeriksaan']),
        hasil_pemeriksaan: row.hasil_pemeriksaan || row['Hasil'] || 'Positif',
        prediksi_bulan: row.prediksi_bulan || row['Prediksi Bulan'] || '',
        hpl: row.hpl || row.HPL || '',
        petugas_pemeriksa: row.petugas_pemeriksa || row['Petugas'] || '',
        link_foto_pkb: row.link_foto_pkb || row['Link Foto PKB'] || '',
        input_by: row.input_by || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Kelahiran
 */
function transformKelahiran(row) {
    return {
        id_kelahiran: row.id_kelahiran || row['ID Kelahiran'] || '',
        eartag_induk: row.eartag_induk || row['Eartag Induk'] || '',
        rumpun_induk: row.rumpun_induk || row['Rumpun Induk'] || '',
        bapak: row.bapak || row.Bapak || '',
        tanggal_lahir: normalizeDate(row.tanggal_lahir || row['Tanggal Lahir']),
        eartag_anak: row.eartag_anak || row['Eartag Anak'] || '',
        jenis_kelamin: row.jenis_kelamin || row['Jenis Kelamin'] || 'Jantan',
        rumpun_anak: row.rumpun_anak || row['Rumpun Anak'] || '',
        sumber: row.sumber || row.Sumber || 'IB',
        link_foto: row.link_foto || row['Link Foto'] || '',
        input_by: row.input_by || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Pengukuran
 */
function transformPengukuran(row) {
    return {
        id_ukur: row.id_ukur || row['ID Ukur'] || '',
        eartag: row.eartag || row.Eartag || '',
        rumpun: row.rumpun || row.Rumpun || '',
        tanggal_lahir: normalizeDate(row.tanggal_lahir || row['Tanggal Lahir']),
        periode_ukur: row.periode_ukur || row['Periode Ukur'] || '',
        tanggal_ukur: normalizeDate(row.tanggal_ukur || row['Tanggal Ukur']),
        panjang_badan: parseFloat(row.panjang_badan || row['Panjang Badan'] || 0),
        lingkar_dada: parseFloat(row.lingkar_dada || row['Lingkar Dada'] || 0),
        tinggi_pundak: parseFloat(row.tinggi_pundak || row['Tinggi Pundak'] || 0),
        berat_badan: parseFloat(row.berat_badan || row['Berat Badan'] || 0),
        lingkar_scrotum: parseFloat(row.lingkar_scrotum || row['Lingkar Scrotum'] || 0),
        penilaian_kualitatif: row.penilaian_kualitatif || row['Penilaian Kualitatif'] || 'Sesuai SNI',
        grade_sni: row.grade_sni || row['Grade SNI'] || '',
        adg_harian: row.adg_harian || row['ADG Harian'] || '',
        adg_fase: row.adg_fase || row['ADG Fase'] || '',
        keterangan: row.keterangan || row.Keterangan || '',
        input_by: row.input_by || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Penjualan
 */
function transformPenjualan(row) {
    return {
        id_penjualan: row.id_penjualan || row['ID Penjualan'] || '',
        eartag: row.eartag || row.Eartag || '',
        rumpun: row.rumpun || row.Rumpun || '',
        sex: row.sex || row['Jenis Kelamin'] || '',
        harga: parseFloat(row.harga || row.Harga || 0),
        tanggal_jual: normalizeDate(row.tanggal_jual || row['Tanggal Jual']),
        status_distribusi: row.status_distribusi || row['Status Distribusi'] || '',
        input_by: row.input_by || '',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Bull
 */
function transformBull(row) {
    return {
        id_bull: row.id_bull || row['ID Bull'] || '',
        nama_bull: row.nama_bull || row['Nama Bull'] || '',
        rumpun: row.rumpun || row.Rumpun || '',
        asal: row.asal || row.Asal || '',
        stok_awal: parseInt(row.stok_awal || row['Stok Awal'] || 0),
        stok_saat_ini: parseInt(row.stok_saat_ini || row['Stok Saat Ini'] || 0),
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris Petugas
 */
function transformPetugas(row) {
    return {
        id_petugas: row.id_petugas || row['ID Petugas'] || '',
        nama_petugas: row.nama_petugas || row['Nama Petugas'] || '',
        jabatan: row.jabatan || row.Jabatan || 'Terampil',
        created_at: new Date().toISOString()
    };
}

/**
 * Transformasi baris User
 */
function transformUser(row) {
    return {
        id_user: row.id_user || row['ID User'] || row.username || '',
        username: row.username || row.Username || row.email || '',
        password: row.password || row.Password || '',
        role: row.role || row.Role || 'Viewer',
        permissions: row.permissions || row.Permissions || '[]',
        created_at: new Date().toISOString()
    };
}

// ===================== HELPER =====================

/**
 * Normalisasi format tanggal dari berbagai kemungkinan
 * Input: "DD/MM/YYYY", "YYYY-MM-DD", "DD-MM-YYYY", dll.
 * Output: "YYYY-MM-DD" (format ISO untuk Supabase)
 */
function normalizeDate(dateStr) {
    if (!dateStr || dateStr === '-' || dateStr === '') return null;
    
    // Sudah format ISO
    if (/^\d{4}-\d{2}-\d{2}/.test(dateStr)) return dateStr.substring(0, 10);
    
    // Format DD/MM/YYYY
    const parts = dateStr.split('/');
    if (parts.length === 3) {
        // Coba DD/MM/YYYY
        if (parts[0].length === 2 && parts[1].length === 2 && parts[2].length === 4) {
            return `${parts[2]}-${parts[1]}-${parts[0]}`;
        }
        // Mungkin MM/DD/YYYY — cek apakah month > 12
        if (parseInt(parts[1]) > 12) {
            return `${parts[2]}-${parts[0]}-${parts[1]}`;
        }
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
    }
    
    // Format DD-MM-YYYY
    const parts2 = dateStr.split('-');
    if (parts2.length === 3 && parts2[2].length === 4) {
        return `${parts2[2]}-${parts2[1]}-${parts2[0]}`;
    }
    
    // Fallback: return as-is
    return dateStr;
}

// ===================== UTAMA =====================

function parseCSV(csvText) {
    const lines = csvText.split(/\r?\n/).filter(line => line.trim());
    if (lines.length < 2) return [];
    
    // Ambil header → bersihkan BOM dan quote
    const headers = lines[0].split(',').map(h => 
        h.replace(/^\uFEFF/, '').replace(/^"|"$/g, '').trim()
    );
    
    const results = [];
    for (let i = 1; i < lines.length; i++) {
        // Parse CSV sederhana (handle quoted fields)
        const values = [];
        let current = '';
        let inQuote = false;
        
        for (let ch of lines[i]) {
            if (ch === '"') {
                inQuote = !inQuote;
            } else if (ch === ',' && !inQuote) {
                values.push(current.replace(/^"|"$/g, '').trim());
                current = '';
            } else {
                current += ch;
            }
        }
        values.push(current.replace(/^"|"$/g, '').trim());
        
        // Map ke object
        const row = {};
        headers.forEach((h, idx) => {
            row[h] = values[idx] || '';
        });
        
        // Hanya tambahkan jika ada data minimal
        if (Object.values(row).some(v => v)) {
            results.push(row);
        }
    }
    
    return results;
}

// ===================== EKSEKUSI =====================

console.log("🔄 SISCOPATAS — Transformasi CSV → JSON untuk Supabase");
console.log("===================================================\n");

const csvFiles = fs.readdirSync(CSV_DIR).filter(f => f.endsWith('.csv'));

if (csvFiles.length === 0) {
    console.log("❌ Tidak ada file CSV di folder 'migration/csv/'.");
    console.log("📥 Export sheet dari Google Sheets sebagai CSV dan letakkan di folder tersebut.");
    process.exit(0);
}

let totalRows = 0;

csvFiles.forEach(file => {
    const filePath = path.join(CSV_DIR, file);
    const csvName = file.replace(/\.csv$/i, '');
    
    // Cari mapping berdasarkan nama file (case-insensitive)
    const mappingKey = Object.keys(TABLE_MAP).find(key => 
        csvName.toLowerCase().includes(key.toLowerCase())
    );
    
    if (!mappingKey) {
        console.log(`⚠️  ${file} — Tidak ada mapping untuk file ini. Lewati.`);
        return;
    }
    
    const mapping = TABLE_MAP[mappingKey];
    const csvText = fs.readFileSync(filePath, 'utf8');
    const rows = parseCSV(csvText);
    
    if (rows.length === 0) {
        console.log(`⚠️  ${file} — Kosong atau hanya header. Lewati.`);
        return;
    }
    
    // Transformasi setiap baris
    const transformed = rows.map(mapping.transform);
    
    // Simpan sebagai JSON
    const jsonFile = `${mapping.table}.json`;
    const jsonPath = path.join(JSON_DIR, jsonFile);
    fs.writeFileSync(jsonPath, JSON.stringify(transformed, null, 2), 'utf8');
    
    totalRows += transformed.length;
    console.log(`✅ ${csvName} → ${jsonFile} (${transformed.length} baris)`);
});

console.log(`\n📊 Total: ${totalRows} baris dari ${csvFiles.length} file CSV`);
console.log(`📁 Output: ${JSON_DIR}`);
console.log("\n🚀 Selanjutnya: Import file JSON ke Supabase via SQL Editor atau Dashboard.");
console.log("   Atau gunakan: supabase db push (jika pakai Supabase CLI)");
console.log("\n📖 Urutan import yang benar (ikuti FK):");
console.log("   1. ref_sni, ref_lokasi, users");
console.log("   2. bull, petugas_reproduksi, petugas_keswan");
console.log("   3. ternak (data utama)");
console.log("   4. laporan_berahi, ib, kebuntingan, kelahiran");
console.log("   5. pengukuran, penjualan, keswan, laporan_gangrep");
console.log("   6. log_mutasi, eartag_pasang");
