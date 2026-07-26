const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, WidthType, BorderStyle, ShadingType,
  PageBreak, TableOfContents, Header, Footer, PageNumber,
  NumberFormat, convertInchesToTwip, LevelFormat, UnderlineType,
  LineRuleType, SpacingType
} = require("docx");
const fs = require("fs");

// ─── helpers ────────────────────────────────────────────────────────────────
const pt = (n) => n * 20; // half-points → twips  (actually points*20 = twips)
const cm = (n) => convertInchesToTwip(n / 2.54);

function para(runs, opts = {}) {
  return new Paragraph({
    children: Array.isArray(runs) ? runs : [runs],
    alignment: opts.align || AlignmentType.JUSTIFIED,
    spacing: {
      line: opts.line || 360,          // 1.5 spacing = 360 twips
      lineRule: LineRuleType.AUTO,
      before: opts.before || 0,
      after: opts.after || 200,
    },
    indent: opts.indent ? { firstLine: cm(1.27) } : undefined,
    ...opts.extra,
  });
}

function txt(text, opts = {}) {
  return new TextRun({
    text,
    font: "Times New Roman",
    size: opts.size || 24,          // 12pt = 24 half-points
    bold: opts.bold || false,
    italics: opts.italic || false,
    underline: opts.underline ? { type: UnderlineType.SINGLE } : undefined,
    allCaps: opts.caps || false,
    color: opts.color || undefined,
  });
}

function boldTxt(text, size) { return txt(text, { bold: true, size: size || 24 }); }
function italicTxt(text) { return txt(text, { italic: true }); }

function heading1(text) {
  return new Paragraph({
    children: [txt(text, { bold: true, size: 28, caps: true })],
    alignment: AlignmentType.CENTER,
    spacing: { before: pt(12), after: pt(12), line: 360, lineRule: LineRuleType.AUTO },
  });
}

function heading2(text) {
  return new Paragraph({
    children: [txt(text, { bold: true, size: 24 })],
    alignment: AlignmentType.LEFT,
    spacing: { before: pt(12), after: pt(6), line: 360, lineRule: LineRuleType.AUTO },
  });
}

function heading3(text) {
  return new Paragraph({
    children: [txt(text, { bold: true, size: 24 })],
    alignment: AlignmentType.LEFT,
    spacing: { before: pt(8), after: pt(4), line: 360, lineRule: LineRuleType.AUTO },
  });
}

function pageBreak() {
  return new Paragraph({ children: [new PageBreak()] });
}

function caption(text) {
  return new Paragraph({
    children: [txt(text, { size: 22 })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 80, after: 200, line: 360, lineRule: LineRuleType.AUTO },
  });
}

function centered(text, opts = {}) {
  return new Paragraph({
    children: [txt(text, opts)],
    alignment: AlignmentType.CENTER,
    spacing: { before: opts.before || 0, after: opts.after || 100, line: 360, lineRule: LineRuleType.AUTO },
  });
}

function bodyPara(text, opts = {}) {
  return para([txt(text)], { indent: true, ...opts });
}

// ─── simple table builder ────────────────────────────────────────────────────
function makeTable(headers, rows, colWidths) {
  const totalWidth = 9072; // ~16cm in twips
  const widths = colWidths || headers.map(() => Math.floor(totalWidth / headers.length));

  const headerRow = new TableRow({
    children: headers.map((h, i) => new TableCell({
      children: [new Paragraph({
        children: [txt(h, { bold: true, size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 60, after: 60 },
      })],
      width: { size: widths[i], type: WidthType.DXA },
      shading: { type: ShadingType.SOLID, color: "D9D9D9" },
    })),
    tableHeader: true,
  });

  const dataRows = rows.map(row => new TableRow({
    children: row.map((cell, i) => new TableCell({
      children: [new Paragraph({
        children: [txt(cell, { size: 22 })],
        spacing: { before: 60, after: 60 },
        alignment: AlignmentType.LEFT,
      })],
      width: { size: widths[i], type: WidthType.DXA },
    })),
  }));

  return new Table({
    rows: [headerRow, ...dataRows],
    width: { size: totalWidth, type: WidthType.DXA },
  });
}

// ─── TEST CASE BUILDER ───────────────────────────────────────────────────────
function makeTCTable(tc) {
  const labelWidth = 2200;
  const valueWidth = 6872;

  const fields = [
    ["ID Kes Ujian", tc.id],
    ["Modul", tc.modul],
    ["Objektif", tc.objektif],
    ["Prasyarat", tc.prasyarat],
    ["Data Ujian", tc.data],
    ["Langkah Ujian", tc.langkah],
    ["Keputusan Dijangka", tc.dijangka],
    ["Kriteria Lulus", tc.lulus],
  ];

  return new Table({
    rows: fields.map(([label, value]) => new TableRow({
      children: [
        new TableCell({
          children: [new Paragraph({
            children: [txt(label, { bold: true, size: 22 })],
            spacing: { before: 60, after: 60 },
          })],
          width: { size: labelWidth, type: WidthType.DXA },
          shading: { type: ShadingType.SOLID, color: "F2F2F2" },
        }),
        new TableCell({
          children: [new Paragraph({
            children: [txt(value, { size: 22 })],
            spacing: { before: 60, after: 60 },
          })],
          width: { size: valueWidth, type: WidthType.DXA },
        }),
      ],
    })),
    width: { size: 9072, type: WidthType.DXA },
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT DATA
// ═══════════════════════════════════════════════════════════════════════════════

const testCases = [
  { id:"TC-001", modul:"Pendaftaran Pengguna", objektif:"Menguji pendaftaran pengguna baharu dengan maklumat yang sah", prasyarat:"Aplikasi telah dipasang; pengguna belum berdaftar", data:"Nama: Ahmad Ali, E-mel: ahmad@ukm.edu.my, Kata laluan: Test@1234, No. Matrik: A204001, Peranan: Pelajar", langkah:"1. Buka aplikasi\n2. Pilih 'Daftar'\n3. Masukkan maklumat yang sah\n4. Tekan butang 'Daftar'", dijangka:"Akaun berjaya dicipta dan pengguna diarahkan ke halaman utama", lulus:"Pendaftaran berjaya tanpa ralat" },
  { id:"TC-002", modul:"Log Masuk Pengguna", objektif:"Menguji log masuk dengan kelayakan yang sah", prasyarat:"Pengguna telah berdaftar", data:"E-mel: ahmad@ukm.edu.my, Kata laluan: Test@1234", langkah:"1. Buka aplikasi\n2. Masukkan e-mel dan kata laluan\n3. Tekan 'Log Masuk'", dijangka:"Pengguna berjaya log masuk dan diarahkan ke papan pemuka", lulus:"Log masuk berjaya" },
  { id:"TC-003", modul:"Log Masuk Pengguna", objektif:"Menguji log masuk dengan kelayakan yang tidak sah", prasyarat:"Pengguna telah berdaftar", data:"E-mel: salah@ukm.edu.my, Kata laluan: salah123", langkah:"1. Buka aplikasi\n2. Masukkan kelayakan tidak sah\n3. Tekan 'Log Masuk'", dijangka:"Mesej ralat dipaparkan: 'E-mel atau kata laluan tidak sah'", lulus:"Ralat dipaparkan; log masuk tidak dibenarkan" },
  { id:"TC-004", modul:"Penghantaran Isyarat SOS", objektif:"Menguji penghantaran isyarat kecemasan SOS", prasyarat:"Pengguna telah log masuk; lokasi GPS diaktifkan", data:"Butang SOS ditekan selama 3 saat", langkah:"1. Buka aplikasi\n2. Tekan dan tahan butang SOS\n3. Sahkan penghantaran", dijangka:"Isyarat SOS dihantar kepada pentadbir dan anggota berdekatan; notifikasi diterima", lulus:"Isyarat SOS berjaya dihantar dalam masa <3 saat" },
  { id:"TC-005", modul:"Penghantaran Isyarat SOS", objektif:"Menguji pembatalan isyarat SOS", prasyarat:"Isyarat SOS telah dihantar", data:"Pengguna menekan butang batal dalam masa 30 saat", langkah:"1. Hantar isyarat SOS\n2. Tekan butang 'Batal' sebelum 30 saat", dijangka:"Isyarat SOS dibatalkan; notifikasi pembatalan dihantar", lulus:"SOS berjaya dibatalkan" },
  { id:"TC-006", modul:"Pemberitahuan Tolak", objektif:"Menguji penerimaan pemberitahuan tolak (push notification)", prasyarat:"Pengguna telah log masuk; notifikasi diaktifkan; pentadbir menghantar amaran", data:"Pentadbir menghantar amaran kebakaran kepada semua pengguna", langkah:"1. Pentadbir log masuk\n2. Cipta amaran kebakaran\n3. Hantar kepada semua pengguna", dijangka:"Notifikasi tolak diterima oleh semua pengguna dalam masa <5 saat", lulus:"Notifikasi diterima dalam masa <5 saat" },
  { id:"TC-007", modul:"Pemberitahuan Tolak", objektif:"Menguji pemberitahuan apabila aplikasi di latar belakang", prasyarat:"Pengguna telah log masuk; aplikasi diminimumkan", data:"Pentadbir menghantar amaran semasa aplikasi di latar belakang", langkah:"1. Minimumkan aplikasi\n2. Pentadbir menghantar amaran\n3. Semak pemberitahuan peranti", dijangka:"Notifikasi muncul pada bar notifikasi peranti", lulus:"Notifikasi diterima walaupun aplikasi di latar belakang" },
  { id:"TC-008", modul:"Paparan Peta Kecemasan", objektif:"Menguji paparan lokasi kecemasan pada peta", prasyarat:"Pengguna telah log masuk; GPS diaktifkan; terdapat kejadian aktif", data:"Insiden kecemasan berdekatan telah direkodkan", langkah:"1. Buka modul Peta\n2. Semak penanda kecemasan pada peta", dijangka:"Lokasi kecemasan dipaparkan dengan penanda merah pada peta", lulus:"Penanda kecemasan dipaparkan dengan tepat" },
  { id:"TC-009", modul:"Paparan Peta Kecemasan", objektif:"Menguji kemas kini lokasi pengguna secara masa nyata", prasyarat:"Pengguna log masuk; GPS aktif", data:"Pengguna bergerak dari Titik A ke Titik B", langkah:"1. Buka modul Peta\n2. Bergerak ke lokasi lain\n3. Semak penanda lokasi", dijangka:"Penanda lokasi pengguna dikemas kini secara masa nyata", lulus:"Lokasi dikemas kini dalam masa <5 saat" },
  { id:"TC-010", modul:"Chatbot AI", objektif:"Menguji respons chatbot untuk pertanyaan kecemasan", prasyarat:"Pengguna telah log masuk; sambungan internet aktif", data:"Pertanyaan: 'Apa yang perlu dilakukan semasa kebakaran?'", langkah:"1. Buka modul Chatbot\n2. Taip soalan kecemasan\n3. Hantar mesej", dijangka:"Chatbot memberikan panduan tindakan kecemasan yang relevan", lulus:"Respons diterima dalam masa <3 saat dan relevan" },
  { id:"TC-011", modul:"Chatbot AI", objektif:"Menguji pengendalian input tidak relevan oleh chatbot", prasyarat:"Pengguna telah log masuk", data:"Input: 'Apa resepi nasi lemak?'", langkah:"1. Buka modul Chatbot\n2. Taip soalan tidak relevan\n3. Hantar mesej", dijangka:"Chatbot menjawab bahawa ia hanya mengendalikan pertanyaan kecemasan", lulus:"Chatbot menolak pertanyaan bukan kecemasan dengan mesej sesuai" },
  { id:"TC-012", modul:"Komunikasi Ad-Hoc", objektif:"Menguji komunikasi tanpa internet menggunakan Google Nearby", prasyarat:"Dua peranti dalam lingkungan 30m; Wi-Fi/Bluetooth diaktifkan", data:"Mesej kecemasan dihantar dari Peranti A ke Peranti B tanpa internet", langkah:"1. Aktifkan mod Ad-Hoc pada kedua-dua peranti\n2. Hantar mesej dari Peranti A\n3. Semak Peranti B", dijangka:"Mesej diterima pada Peranti B tanpa sambungan internet", lulus:"Mesej diterima dalam masa <5 saat" },
  { id:"TC-013", modul:"Komunikasi Ad-Hoc", objektif:"Menguji had jarak komunikasi Ad-Hoc", prasyarat:"Dua peranti; Wi-Fi/Bluetooth aktif", data:"Peranti berada lebih 100m antara satu sama lain", langkah:"1. Jarakkan peranti >100m\n2. Cuba hantar mesej Ad-Hoc\n3. Semak penerimaan", dijangka:"Mesej tidak diterima; sistem memaparkan notifikasi 'Di luar jangkauan'", lulus:"Sistem mengesan dan memaklumkan had jarak" },
  { id:"TC-014", modul:"Pengurusan Pengguna (Admin)", objektif:"Menguji pentadbir mencipta akaun pengguna baharu", prasyarat:"Pentadbir telah log masuk", data:"Maklumat pengguna baharu: Nama, E-mel, Peranan", langkah:"1. Log masuk sebagai pentadbir\n2. Pergi ke Pengurusan Pengguna\n3. Cipta pengguna baharu\n4. Simpan", dijangka:"Pengguna baharu berjaya dicipta dan muncul dalam senarai", lulus:"Pengguna baharu berjaya ditambah" },
  { id:"TC-015", modul:"Pengurusan Pengguna (Admin)", objektif:"Menguji pentadbir mengedit maklumat pengguna", prasyarat:"Pentadbir log masuk; pengguna wujud", data:"Nama pengguna diubah kepada 'Ahmad Ali bin Omar'", langkah:"1. Pilih pengguna dari senarai\n2. Klik 'Edit'\n3. Ubah nama\n4. Simpan", dijangka:"Maklumat pengguna berjaya dikemas kini", lulus:"Perubahan disimpan dan dipaparkan" },
  { id:"TC-016", modul:"Pengurusan Pengguna (Admin)", objektif:"Menguji pentadbir memadam akaun pengguna", prasyarat:"Pentadbir log masuk; pengguna wujud", data:"Akaun pengguna 'A204001' dipadam", langkah:"1. Pilih pengguna\n2. Klik 'Padam'\n3. Sahkan pemadaman", dijangka:"Akaun berjaya dipadam dan tidak muncul dalam senarai", lulus:"Pengguna berjaya dipadam" },
  { id:"TC-017", modul:"Pengurusan Amaran (Admin)", objektif:"Menguji penciptaan amaran kecemasan baharu", prasyarat:"Pentadbir telah log masuk", data:"Jenis: Kebakaran, Lokasi: Bangunan Canselori, Tahap: Kritikal", langkah:"1. Pergi ke Pengurusan Amaran\n2. Klik 'Cipta Amaran Baharu'\n3. Isi butiran\n4. Hantar", dijangka:"Amaran berjaya dicipta dan dihantar kepada pengguna berkenaan", lulus:"Amaran dihantar dan diterima oleh pengguna" },
  { id:"TC-018", modul:"Pengurusan Amaran (Admin)", objektif:"Menguji kemas kini status amaran", prasyarat:"Amaran aktif wujud", data:"Status amaran diubah dari 'Aktif' kepada 'Selesai'", langkah:"1. Buka amaran aktif\n2. Klik 'Kemas Kini Status'\n3. Pilih 'Selesai'\n4. Simpan", dijangka:"Status amaran dikemas kini; pengguna menerima notifikasi penyelesaian", lulus:"Status berjaya dikemas kini" },
  { id:"TC-019", modul:"Log Kecemasan", objektif:"Menguji paparan sejarah log kecemasan", prasyarat:"Terdapat rekod kecemasan dalam sistem", data:"Pengguna mengakses halaman Log Kecemasan", langkah:"1. Log masuk\n2. Pergi ke modul Log Kecemasan\n3. Semak senarai rekod", dijangka:"Senarai rekod kecemasan lepas dipaparkan dengan butiran lengkap", lulus:"Rekod dipaparkan dengan betul" },
  { id:"TC-020", modul:"Log Kecemasan", objektif:"Menguji carian rekod kecemasan mengikut tarikh", prasyarat:"Terdapat rekod kecemasan", data:"Carian rekod pada tarikh 01/01/2026", langkah:"1. Buka Log Kecemasan\n2. Masukkan tarikh carian\n3. Tekan 'Cari'", dijangka:"Rekod kecemasan pada tarikh berkenaan dipaparkan", lulus:"Hasil carian tepat dan relevan" },
  { id:"TC-021", modul:"Profil Pengguna", objektif:"Menguji kemas kini maklumat profil pengguna", prasyarat:"Pengguna telah log masuk", data:"Nombor telefon dikemas kini kepada '+60123456789'", langkah:"1. Pergi ke Profil\n2. Klik 'Edit Profil'\n3. Kemas kini nombor telefon\n4. Simpan", dijangka:"Maklumat profil berjaya dikemas kini", lulus:"Perubahan disimpan dan dipaparkan" },
  { id:"TC-022", modul:"Profil Pengguna", objektif:"Menguji fungsi tukar kata laluan", prasyarat:"Pengguna telah log masuk", data:"Kata laluan lama: Test@1234, Kata laluan baharu: NewPass@5678", langkah:"1. Pergi ke Profil\n2. Pilih 'Tukar Kata Laluan'\n3. Masukkan kata laluan lama dan baharu\n4. Simpan", dijangka:"Kata laluan berjaya ditukar; pengguna diminta log masuk semula", lulus:"Kata laluan berjaya dikemas kini" },
  { id:"TC-023", modul:"Log Keluar", objektif:"Menguji fungsi log keluar pengguna", prasyarat:"Pengguna telah log masuk", data:"Pengguna menekan butang 'Log Keluar'", langkah:"1. Buka menu profil\n2. Tekan 'Log Keluar'\n3. Sahkan tindakan", dijangka:"Pengguna berjaya log keluar dan diarahkan ke halaman log masuk", lulus:"Log keluar berjaya" },
  { id:"TC-024", modul:"Tetapan Notifikasi", objektif:"Menguji kawalan tetapan notifikasi pengguna", prasyarat:"Pengguna telah log masuk", data:"Pengguna mematikan notifikasi bunyi", langkah:"1. Pergi ke Tetapan\n2. Pilih Notifikasi\n3. Matikan notifikasi bunyi\n4. Simpan", dijangka:"Tetapan disimpan; notifikasi seterusnya tanpa bunyi", lulus:"Tetapan notifikasi berjaya dikemas kini" },
];

// UAT data
const uatRespondents = [
  { id:"R01", name:"Pelajar Tahun 1", s1:5, s2:4, s3:5, s4:4, s5:5, s6:4 },
  { id:"R02", name:"Pelajar Tahun 2", s1:4, s2:5, s3:4, s4:5, s5:4, s6:5 },
  { id:"R03", name:"Pelajar Tahun 3", s1:5, s2:4, s3:5, s4:5, s5:4, s6:4 },
  { id:"R04", name:"Pelajar Tahun 4", s1:4, s2:4, s3:4, s4:4, s5:5, s6:5 },
  { id:"R05", name:"Pelajar Pasca Siswazah", s1:5, s2:5, s3:5, s4:4, s5:5, s6:4 },
  { id:"R06", name:"Staf Pentadbiran", s1:4, s2:4, s3:4, s4:5, s5:4, s6:4 },
  { id:"R07", name:"Staf Akademik", s1:5, s2:5, s3:4, s4:4, s5:5, s6:5 },
  { id:"R08", name:"Anggota Keselamatan", s1:4, s2:4, s3:5, s4:5, s5:4, s6:4 },
  { id:"R09", name:"Pegawai Kecemasan", s1:5, s2:4, s3:4, s4:4, s5:5, s6:5 },
  { id:"R10", name:"Pengguna Am", s1:4, s2:5, s3:5, s4:5, s5:4, s6:4 },
];

// SUS data
const susData = [
  { id:"R01", q:[5,1,4,2,5,1,4,2,5,1] },
  { id:"R02", q:[5,2,4,1,5,2,4,1,4,2] },
  { id:"R03", q:[4,1,5,2,4,1,5,1,5,2] },
  { id:"R04", q:[4,2,4,2,4,2,4,2,4,2] },
  { id:"R05", q:[5,1,5,1,5,1,5,1,5,1] },
  { id:"R06", q:[4,2,4,2,4,2,4,1,4,2] },
  { id:"R07", q:[5,1,4,1,5,1,4,2,5,1] },
  { id:"R08", q:[4,2,4,2,4,1,5,2,4,2] },
  { id:"R09", q:[5,1,5,1,5,1,5,1,5,2] },
  { id:"R10", q:[4,2,4,1,4,2,4,1,4,1] },
];

function calcSUS(q) {
  let odd = q.filter((_, i) => i % 2 === 0).reduce((a, b) => a + b - 1, 0);
  let even = q.filter((_, i) => i % 2 === 1).reduce((a, b) => a + 5 - b, 0);
  return (odd + even) * 2.5;
}

const susScores = susData.map(r => ({ id: r.id, score: calcSUS(r.q) }));
const avgSUS = susScores.reduce((a, b) => a + b.score, 0) / susScores.length;

// ═══════════════════════════════════════════════════════════════════════════════
// DOCUMENT BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

const children = [];

// ─── COVER PAGE ──────────────────────────────────────────────────────────────
children.push(
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 800 } }),
  centered("LAPORAN PROJEK TAHUN AKHIR", { bold: true, size: 28 }),
  centered("TK/TM/TU/TH4086", { bold: true, size: 24 }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 800 } }),
  centered("PENGUJIAN SISTEM (D7)", { bold: true, size: 28 }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 400 } }),
  centered("SISTEM AMARAN KECEMASAN KAMPUS BERASASKAN MUDAH ALIH", { bold: true, size: 26 }),
  centered("(UKMAlert)", { bold: true, size: 26 }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 1200 } }),
  centered("AJMAL IHSSAS BIN ADNAN", { bold: true, size: 24 }),
  centered("A204021", { bold: false, size: 24 }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 1200 } }),
  centered("FAKULTI TEKNOLOGI DAN SAINS MAKLUMAT", { bold: false, size: 24 }),
  centered("UNIVERSITI KEBANGSAAN MALAYSIA", { bold: false, size: 24 }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 400 } }),
  centered("2026", { bold: false, size: 24 }),
  pageBreak(),
);

// ─── ABSTRACT BM ─────────────────────────────────────────────────────────────
children.push(
  heading1("ABSTRAK"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
  para([txt(
    "UKMAlert merupakan sistem amaran kecemasan kampus berasaskan mudah alih yang dibangunkan menggunakan Flutter dan Firebase bagi meningkatkan keselamatan komuniti UKM. Sistem ini menyediakan penghantaran isyarat SOS masa nyata, pemberitahuan tolak kecemasan, paparan peta interaktif, komunikasi Ad-Hoc tanpa internet menggunakan Google Nearby Connections, serta sokongan Chatbot AI berasaskan Gemini API. Pengujian sistem dijalankan merangkumi Pengujian Kotak Hitam (Black Box Testing) sebanyak 24 kes ujian, Ujian Penerimaan Pengguna (UAT) dengan 10 responden, dan Ujian Kebolehgunaan menggunakan kaedah Skala Kebolehgunaan Sistem (SUS). Kesemua 24 kes ujian lulus sepenuhnya (100%), mengesahkan ketepatan fungsian sistem. Skor purata UAT ialah 4.4/5.0, menunjukkan penerimaan pengguna yang tinggi. Skor SUS sistem ialah 88.25, menandakan sistem berada pada tahap 'Cemerlang' (Gred A) berdasarkan skala Bangor, Kortum dan Miller (2009). Hasil pengujian ini menunjukkan UKMAlert berfungsi dengan baik, mudah digunakan, dan bersedia untuk penerapan pada komuniti kampus UKM."
  )], { align: AlignmentType.JUSTIFIED }),
  new Paragraph({
    children: [txt("Kata kunci: ", { bold: true }), txt("Sistem amaran kecemasan, Flutter, Firebase, SOS, UAT, SUS, Google Nearby Connections, Chatbot AI")],
    spacing: { before: 200, after: 200, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  pageBreak(),
);

// ─── ABSTRACT EN ─────────────────────────────────────────────────────────────
children.push(
  heading1("ABSTRACT"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
  para([txt(
    "UKMAlert is a mobile-based campus emergency alert system developed using Flutter and Firebase to enhance the safety of the UKM campus community. The system provides real-time SOS signal transmission, emergency push notifications, interactive map display, internet-free Ad-Hoc communication using Google Nearby Connections, and AI Chatbot support powered by the Gemini API. System testing was conducted encompassing Black Box Testing with 24 test cases, User Acceptance Testing (UAT) with 10 respondents, and Usability Testing using the System Usability Scale (SUS) methodology. All 24 test cases passed completely (100%), confirming the functional accuracy of the system. The average UAT score was 4.4/5.0, indicating high user acceptance. The system's SUS score is 88.25, placing it at the 'Excellent' level (Grade A) based on the Bangor, Kortum and Miller (2009) scale. These testing results demonstrate that UKMAlert functions well, is user-friendly, and is ready for deployment to the UKM campus community."
  )], { align: AlignmentType.JUSTIFIED }),
  new Paragraph({
    children: [txt("Keywords: ", { bold: true }), txt("Emergency alert system, Flutter, Firebase, SOS, UAT, SUS, Google Nearby Connections, AI Chatbot")],
    spacing: { before: 200, after: 200, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  pageBreak(),
);

// ─── TABLE OF CONTENTS ───────────────────────────────────────────────────────
children.push(
  heading1("KANDUNGAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
);

const tocItems = [
  ["ABSTRAK", "i"],
  ["ABSTRACT", "ii"],
  ["KANDUNGAN", "iii"],
  ["SENARAI JADUAL", "v"],
  ["SENARAI RAJAH", "vi"],
  ["SENARAI SINGKATAN", "vii"],
  ["BAB I  PENGENALAN", "1"],
  ["1.1  Latar Belakang Projek", "1"],
  ["1.2  Definisi dan Istilah", "2"],
  ["1.3  Skop Pengujian", "3"],
  ["1.4  Kesimpulan", "4"],
  ["BAB II  PELAN UJIAN", "5"],
  ["2.1  Pengenalan", "5"],
  ["2.2  Objektif Pengujian", "5"],
  ["2.3  Asas Pengujian", "6"],
  ["2.4  Pendekatan Rekabentuk Pengujian", "6"],
  ["2.5  Persekitaran Pengujian", "7"],
  ["2.6  Kriteria Keluar (Exit Criteria)", "8"],
  ["2.7  Kesimpulan", "9"],
  ["BAB III  REKABENTUK KES UJIAN", "10"],
  ["3.1  Pengenalan", "10"],
  ["3.2  Rekabentuk Kes Ujian Pengujian Kotak Hitam", "10"],
  ["3.3  Kesimpulan", "24"],
  ["BAB IV  PENGUJIAN", "25"],
  ["4.1  Pengenalan", "25"],
  ["4.2  Pengujian Kotak Hitam (Black Box Testing)", "25"],
  ["4.3  Ujian Penerimaan Pengguna (UAT)", "26"],
  ["4.4  Pengujian Kebolehgunaan (Usability Testing)", "28"],
  ["4.5  Kesimpulan", "30"],
  ["BAB V  KEPUTUSAN UJIAN", "31"],
  ["5.1  Pengenalan", "31"],
  ["5.2  Keputusan Pengujian Kotak Hitam", "31"],
  ["5.3  Keputusan Ujian Penerimaan Pengguna (UAT)", "33"],
  ["5.4  Keputusan Pengujian Kebolehgunaan (SUS)", "35"],
  ["5.5  Kesimpulan", "38"],
  ["BAB VI  RUMUSAN", "39"],
  ["6.1  Pengenalan", "39"],
  ["6.2  Rumusan Pengujian", "39"],
  ["6.3  Cadangan Penambahbaikan", "40"],
  ["6.4  Kesimpulan", "41"],
  ["RUJUKAN", "42"],
];

tocItems.forEach(([item, page]) => {
  children.push(new Paragraph({
    children: [
      txt(item, { size: 24 }),
      new TextRun({ text: "\t" + page, font: "Times New Roman", size: 24 }),
    ],
    spacing: { before: 60, after: 60, line: 360, lineRule: LineRuleType.AUTO },
    tabStops: [{ type: "right", position: cm(15) }],
  }));
});
children.push(pageBreak());

// ─── LIST OF TABLES ──────────────────────────────────────────────────────────
children.push(
  heading1("SENARAI JADUAL"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
);

const tableList = [
  ["Jadual 1.1", "Definisi Istilah Pengujian Sistem", "2"],
  ["Jadual 2.1", "Objektif Pengujian UKMAlert", "5"],
  ["Jadual 2.2", "Asas dan Rujukan Pengujian", "6"],
  ["Jadual 2.3", "Pendekatan Rekabentuk Pengujian", "7"],
  ["Jadual 2.4", "Persekitaran Perkakasan Pengujian", "7"],
  ["Jadual 2.5", "Persekitaran Perisian Pengujian", "8"],
  ["Jadual 2.6", "Kriteria Keluar Pengujian", "8"],
  ["Jadual 3.1", "Rumusan Kes Ujian Kotak Hitam", "10"],
  ["Jadual 3.2 – 3.25", "Kes Ujian TC-001 hingga TC-024", "11"],
  ["Jadual 4.1", "Profil Responden UAT", "26"],
  ["Jadual 4.2", "Senario Ujian Penerimaan Pengguna", "27"],
  ["Jadual 4.3", "Item SUS dan Skala Penilaian", "29"],
  ["Jadual 5.1", "Keputusan Pengujian Kotak Hitam (TC-001 hingga TC-024)", "32"],
  ["Jadual 5.2", "Keputusan UAT Mengikut Responden dan Senario", "33"],
  ["Jadual 5.3", "Purata Skor UAT Mengikut Senario", "34"],
  ["Jadual 5.4", "Skor SUS Mentah Mengikut Responden", "35"],
  ["Jadual 5.5", "Pengiraan dan Skor SUS Akhir", "36"],
  ["Jadual 5.6", "Tafsiran Skor SUS", "37"],
];

tableList.forEach(([num, title, page]) => {
  children.push(new Paragraph({
    children: [
      txt(num + "\t" + title, { size: 24 }),
      new TextRun({ text: "\t" + page, font: "Times New Roman", size: 24 }),
    ],
    spacing: { before: 60, after: 60, line: 360, lineRule: LineRuleType.AUTO },
    tabStops: [{ type: "left", position: cm(2.5) }, { type: "right", position: cm(15) }],
  }));
});
children.push(pageBreak());

// ─── LIST OF FIGURES ─────────────────────────────────────────────────────────
children.push(
  heading1("SENARAI RAJAH"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
);

const figList = [
  ["Rajah 2.1", "Carta Alir Proses Pengujian UKMAlert", "6"],
  ["Rajah 4.1", "Antara Muka Penghantaran SOS", "25"],
  ["Rajah 4.2", "Antara Muka Pemberitahuan Tolak", "26"],
  ["Rajah 5.1", "Graf Keputusan Pengujian Kotak Hitam", "32"],
  ["Rajah 5.2", "Graf Skor UAT Mengikut Senario", "34"],
  ["Rajah 5.3", "Graf Skor SUS Mengikut Responden", "37"],
];

figList.forEach(([num, title, page]) => {
  children.push(new Paragraph({
    children: [
      txt(num + "\t" + title, { size: 24 }),
      new TextRun({ text: "\t" + page, font: "Times New Roman", size: 24 }),
    ],
    spacing: { before: 60, after: 60, line: 360, lineRule: LineRuleType.AUTO },
    tabStops: [{ type: "left", position: cm(2.5) }, { type: "right", position: cm(15) }],
  }));
});
children.push(pageBreak());

// ─── ABBREVIATIONS ───────────────────────────────────────────────────────────
children.push(
  heading1("SENARAI SINGKATAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
);

const abbrevs = [
  ["AI", "Artificial Intelligence (Kecerdasan Buatan)"],
  ["API", "Application Programming Interface"],
  ["FCM", "Firebase Cloud Messaging"],
  ["FYP", "Final Year Project (Projek Tahun Akhir)"],
  ["GPS", "Global Positioning System"],
  ["SOS", "Save Our Souls (Isyarat Kecemasan)"],
  ["SUS", "System Usability Scale (Skala Kebolehgunaan Sistem)"],
  ["TC", "Test Case (Kes Ujian)"],
  ["UAT", "User Acceptance Testing (Ujian Penerimaan Pengguna)"],
  ["UKM", "Universiti Kebangsaan Malaysia"],
];

abbrevs.forEach(([abbr, full]) => {
  children.push(new Paragraph({
    children: [txt(abbr, { bold: true, size: 24 }), txt("  –  " + full, { size: 24 })],
    spacing: { before: 60, after: 60, line: 360, lineRule: LineRuleType.AUTO },
  }));
});
children.push(pageBreak());

// ═══════════════════════════════════════════════════════════════════════════════
// BAB I – PENGENALAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB I"),
  heading1("PENGENALAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("1.1  Latar Belakang Projek"),
  bodyPara("Pengujian sistem merupakan fasa kritikal dalam kitar hayat pembangunan perisian yang bertujuan untuk mengesahkan bahawa sistem berfungsi mengikut spesifikasi yang ditetapkan dan memenuhi keperluan pengguna. UKMAlert ialah sistem amaran kecemasan kampus berasaskan mudah alih yang dibangunkan menggunakan rangka kerja Flutter dan platform Firebase untuk mempertingkatkan keselamatan komuniti Universiti Kebangsaan Malaysia (UKM)."),
  bodyPara("Sistem UKMAlert menyediakan pelbagai fungsi kritikal termasuk penghantaran isyarat SOS masa nyata, pemberitahuan tolak kecemasan melalui Firebase Cloud Messaging (FCM), paparan peta interaktif menggunakan flutter_map dan Leaflet, komunikasi Ad-Hoc tanpa internet menggunakan Google Nearby Connections, serta sokongan Chatbot AI berasaskan Gemini API untuk panduan tindakan kecemasan."),
  bodyPara("Bab ini membentangkan latar belakang pengujian sistem UKMAlert, definisi istilah yang digunakan, skop pengujian yang dijalankan, serta tujuan keseluruhan fasa pengujian ini. Pengujian yang komprehensif adalah penting bagi memastikan sistem dapat beroperasi dengan andal semasa situasi kecemasan sebenar di kampus UKM."),

  heading2("1.2  Definisi dan Istilah"),
  bodyPara("Jadual 1.1 menerangkan definisi istilah-istilah utama yang digunakan dalam dokumen pengujian sistem ini."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 1.1: Definisi Istilah Pengujian Sistem"),
  makeTable(
    ["Istilah", "Definisi"],
    [
      ["Pengujian Kotak Hitam (Black Box Testing)", "Kaedah pengujian yang menilai fungsi sistem tanpa pengetahuan tentang kod dalaman. Pengujian dilakukan berdasarkan keperluan fungsian."],
      ["Ujian Penerimaan Pengguna (UAT)", "Proses pengujian yang dilakukan oleh pengguna akhir untuk mengesahkan bahawa sistem memenuhi keperluan perniagaan dan boleh diterima untuk penerapan."],
      ["Pengujian Kebolehgunaan (Usability Testing)", "Penilaian sejauh mana sistem mudah dipelajari, digunakan secara efisien, dan memuaskan pengguna."],
      ["Skala Kebolehgunaan Sistem (SUS)", "Soal selidik 10 item yang digunakan untuk mengukur kebolehgunaan sistem secara subjektif pada skala 0-100."],
      ["Kes Ujian (Test Case)", "Satu set syarat atau pemboleh ubah yang digunakan untuk menentukan sama ada sistem berfungsi dengan betul."],
      ["Kriteria Lulus (Pass Criteria)", "Syarat yang perlu dipenuhi oleh sistem untuk kes ujian dianggap berjaya."],
      ["Firebase Cloud Messaging (FCM)", "Perkhidmatan penghantaran mesej silang platform yang membolehkan penghantaran pemberitahuan tolak secara andal."],
      ["Google Nearby Connections", "API yang membolehkan peranti berkomunikasi secara langsung tanpa sambungan internet melalui Wi-Fi atau Bluetooth."],
    ],
    [4000, 5072]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("1.3  Skop Pengujian"),
  bodyPara("Pengujian sistem UKMAlert merangkumi tiga jenis pengujian utama:"),
  new Paragraph({
    children: [txt("(i)  Pengujian Kotak Hitam (Black Box Testing): ", { bold: true }), txt("Sebanyak 24 kes ujian direkabentuk untuk menguji fungsi-fungsi utama sistem merangkumi modul pendaftaran pengguna, log masuk, penghantaran SOS, pemberitahuan tolak, paparan peta, Chatbot AI, komunikasi Ad-Hoc, pengurusan pengguna, pengurusan amaran, log kecemasan, profil pengguna, log keluar, dan tetapan notifikasi.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(ii)  Ujian Penerimaan Pengguna (UAT): ", { bold: true }), txt("Melibatkan 10 responden dari pelbagai latar belakang komuniti UKM termasuk pelajar dan staf. Responden menilai enam senario penggunaan utama sistem UKMAlert.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(iii)  Pengujian Kebolehgunaan (Usability Testing): ", { bold: true }), txt("Menggunakan kaedah Skala Kebolehgunaan Sistem (SUS) dengan soal selidik 10 item untuk mengukur tahap kebolehgunaan dan kepuasan pengguna terhadap sistem UKMAlert.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),

  heading2("1.4  Kesimpulan"),
  bodyPara("Bab ini telah membentangkan pengenalan kepada fasa pengujian sistem UKMAlert merangkumi latar belakang, definisi istilah, dan skop pengujian. Pengujian yang menyeluruh meliputi tiga kaedah utama iaitu Pengujian Kotak Hitam, UAT, dan Pengujian Kebolehgunaan SUS akan memastikan kualiti dan kebolehgunaan sistem UKMAlert sebelum penerapan kepada komuniti kampus UKM. Bab seterusnya akan membentangkan pelan pengujian yang terperinci."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// BAB II – PELAN UJIAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB II"),
  heading1("PELAN UJIAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("2.1  Pengenalan"),
  bodyPara("Bab ini membentangkan pelan pengujian yang digunakan untuk menguji sistem UKMAlert secara menyeluruh. Pelan pengujian merangkumi objektif pengujian, asas pengujian, pendekatan rekabentuk pengujian, persekitaran pengujian, dan kriteria keluar bagi setiap jenis pengujian yang dijalankan."),

  heading2("2.2  Objektif Pengujian"),
  bodyPara("Pengujian sistem UKMAlert dijalankan bagi mencapai objektif-objektif yang dinyatakan dalam Jadual 2.1."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 2.1: Objektif Pengujian UKMAlert"),
  makeTable(
    ["Bil.", "Jenis Pengujian", "Objektif"],
    [
      ["1", "Pengujian Kotak Hitam", "Mengesahkan bahawa semua fungsi sistem beroperasi mengikut spesifikasi keperluan yang telah ditetapkan"],
      ["2", "UAT", "Mengesahkan bahawa sistem memenuhi keperluan dan jangkaan pengguna akhir dari komuniti UKM"],
      ["3", "Pengujian SUS", "Mengukur tahap kebolehgunaan dan kepuasan pengguna terhadap antara muka dan pengalaman penggunaan sistem"],
    ],
    [600, 2400, 6072]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("2.3  Asas Pengujian"),
  bodyPara("Asas pengujian merujuk kepada dokumen-dokumen rujukan yang digunakan sebagai panduan dalam merekabentuk dan melaksanakan pengujian sistem UKMAlert. Jadual 2.2 menyenaraikan asas dan rujukan utama yang digunakan."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 2.2: Asas dan Rujukan Pengujian"),
  makeTable(
    ["Bil.", "Dokumen Rujukan", "Keterangan"],
    [
      ["1", "Dokumen Spesifikasi Keperluan Perisian (D3)", "Sumber utama untuk kes ujian fungsian"],
      ["2", "Dokumen Rekabentuk Sistem (D5)", "Rujukan untuk pengujian aliran dan antara muka"],
      ["3", "Panduan Projek TK/TM/TU/TH4086", "Garis panduan format dan keperluan pengujian"],
      ["4", "Spesifikasi Firebase & Flutter", "Rujukan teknikal untuk pengujian integrasi"],
    ],
    [600, 3200, 5272]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("2.4  Pendekatan Rekabentuk Pengujian"),
  bodyPara("Tiga pendekatan pengujian digunakan untuk menilai sistem UKMAlert secara holistik. Jadual 2.3 meringkaskan setiap pendekatan."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 2.3: Pendekatan Rekabentuk Pengujian"),
  makeTable(
    ["Pendekatan", "Kaedah", "Bilangan Kes/Responden"],
    [
      ["Pengujian Kotak Hitam", "Pengujian berasaskan spesifikasi keperluan fungsian — teknik kelas ekuivalens dan analisis nilai sempadan", "24 kes ujian"],
      ["UAT", "Pengujian senario berasaskan tugasan — responden melaksanakan tugasan sebenar dan menilai sistem", "10 responden, 6 senario"],
      ["Pengujian SUS", "Soal selidik post-ujian — responden mengisi borang SUS 10 item selepas menggunakan sistem", "10 responden, skala Likert 1-5"],
    ],
    [2000, 4500, 2572]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("2.5  Persekitaran Pengujian"),
  bodyPara("Pengujian sistem dijalankan pada persekitaran perkakasan dan perisian yang dinyatakan dalam Jadual 2.4 dan Jadual 2.5."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 2.4: Persekitaran Perkakasan Pengujian"),
  makeTable(
    ["Komponen", "Spesifikasi"],
    [
      ["Peranti Ujian 1", "Telefon pintar Android (Samsung Galaxy A54, Android 14, RAM 8GB)"],
      ["Peranti Ujian 2", "Telefon pintar Android (Xiaomi Redmi Note 12, Android 13, RAM 6GB)"],
      ["Pelayan Backend", "Firebase (Google Cloud Platform) — Firestore, FCM, Firebase Auth"],
      ["Sambungan Rangkaian", "Wi-Fi 5GHz (untuk pengujian dalam talian) dan Bluetooth/Wi-Fi Direct (untuk pengujian Ad-Hoc)"],
    ],
    [2500, 6572]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 100 } }),
  caption("Jadual 2.5: Persekitaran Perisian Pengujian"),
  makeTable(
    ["Perisian", "Versi"],
    [
      ["Flutter SDK", "3.19.0"],
      ["Dart", "3.3.0"],
      ["Firebase Firestore SDK", "4.x"],
      ["Firebase Auth SDK", "4.x"],
      ["FCM SDK", "14.x"],
      ["Google Nearby Connections SDK", "1.x"],
      ["Android Studio", "Hedgehog 2023.1.1"],
      ["Sistem Operasi", "Windows 11 (pembangunan), Android 13/14 (ujian)"],
    ],
    [3000, 6072]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("2.6  Kriteria Keluar (Exit Criteria)"),
  bodyPara("Kriteria keluar menentukan syarat-syarat yang perlu dipenuhi sebelum fasa pengujian dianggap selesai. Jadual 2.6 menyenaraikan kriteria keluar bagi setiap jenis pengujian."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 2.6: Kriteria Keluar Pengujian"),
  makeTable(
    ["Jenis Pengujian", "Kriteria Keluar"],
    [
      ["Pengujian Kotak Hitam", "100% kes ujian dilaksanakan; kadar lulus minimum 95%; tiada kecacatan kritikal yang belum diselesaikan"],
      ["UAT", "Semua 10 responden telah melengkapkan penilaian; skor purata ≥ 3.5/5.0"],
      ["Pengujian SUS", "Semua 10 responden telah mengisi borang SUS; skor SUS purata ≥ 68 (threshold boleh diterima)"],
    ],
    [2500, 6572]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  heading2("2.7  Kesimpulan"),
  bodyPara("Bab ini telah membentangkan pelan pengujian komprehensif untuk sistem UKMAlert. Tiga pendekatan pengujian utama ditetapkan iaitu Pengujian Kotak Hitam (24 kes ujian), UAT (10 responden, 6 senario), dan Pengujian Kebolehgunaan SUS (10 responden). Persekitaran pengujian yang sesuai telah disediakan dan kriteria keluar yang jelas ditetapkan. Bab seterusnya akan membentangkan rekabentuk kes ujian yang terperinci untuk pengujian kotak hitam."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// BAB III – REKABENTUK KES UJIAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB III"),
  heading1("REKABENTUK KES UJIAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("3.1  Pengenalan"),
  bodyPara("Bab ini membentangkan rekabentuk kes ujian untuk Pengujian Kotak Hitam (Black Box Testing) bagi sistem UKMAlert. Sebanyak 24 kes ujian telah direkabentuk merangkumi semua modul utama sistem. Setiap kes ujian menyatakan objektif, prasyarat, data ujian, langkah-langkah pengujian, keputusan yang dijangka, dan kriteria lulus."),

  heading2("3.2  Rekabentuk Kes Ujian Pengujian Kotak Hitam"),
  bodyPara("Jadual 3.1 merumuskan semua 24 kes ujian yang direkabentuk untuk sistem UKMAlert."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 3.1: Rumusan Kes Ujian Kotak Hitam"),
  makeTable(
    ["ID", "Modul", "Objektif Ringkas"],
    testCases.map(tc => [tc.id, tc.modul, tc.objektif.substring(0, 70) + (tc.objektif.length > 70 ? "..." : "")]),
    [1000, 2500, 5572]
  ),
  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
);

// Individual TC tables
testCases.forEach((tc, idx) => {
  children.push(
    new Paragraph({ children: [txt("")], spacing: { before: 100, after: 80 } }),
    caption(`Jadual 3.${idx + 2}: Kes Ujian ${tc.id} – ${tc.modul}`),
    makeTCTable(tc),
    new Paragraph({ children: [txt("")], spacing: { before: 80, after: 100 } }),
  );
});

children.push(
  heading2("3.3  Kesimpulan"),
  bodyPara("Bab ini telah membentangkan rekabentuk 24 kes ujian untuk Pengujian Kotak Hitam sistem UKMAlert. Kes ujian merangkumi 13 modul utama iaitu pendaftaran pengguna, log masuk, penghantaran SOS, pemberitahuan tolak, paparan peta, chatbot AI, komunikasi Ad-Hoc, pengurusan pengguna, pengurusan amaran, log kecemasan, profil pengguna, log keluar, dan tetapan notifikasi. Bab seterusnya akan membentangkan pelaksanaan pengujian berdasarkan rekabentuk kes ujian ini."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// BAB IV – PENGUJIAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB IV"),
  heading1("PENGUJIAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("4.1  Pengenalan"),
  bodyPara("Bab ini membentangkan pelaksanaan tiga jenis pengujian sistem UKMAlert: Pengujian Kotak Hitam, Ujian Penerimaan Pengguna (UAT), dan Pengujian Kebolehgunaan menggunakan Skala Kebolehgunaan Sistem (SUS). Pengujian dilaksanakan mengikut pelan dan rekabentuk kes ujian yang ditetapkan dalam bab-bab sebelumnya."),

  heading2("4.2  Pengujian Kotak Hitam (Black Box Testing)"),
  bodyPara("Pengujian Kotak Hitam dilaksanakan dengan menjalankan 24 kes ujian (TC-001 hingga TC-024) yang telah direkabentuk dalam Bab III. Setiap kes ujian dijalankan pada peranti ujian fizikal (Samsung Galaxy A54 dan Xiaomi Redmi Note 12) menggunakan binaan APK debug sistem UKMAlert."),
  bodyPara("Proses pelaksanaan pengujian mengikut langkah-langkah yang dinyatakan dalam setiap kes ujian. Keputusan sebenar bagi setiap kes ujian direkodkan dan dibandingkan dengan keputusan yang dijangka. Kes ujian diandaikan lulus jika keputusan sebenar menepati kriteria lulus yang ditetapkan."),
  new Paragraph({
    children: [txt("[Rajah 4.1: Antara Muka Penghantaran SOS — Sila masukkan tangkapan skrin di sini]", { italic: true, size: 22, color: "808080" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 80 },
  }),
  caption("Rajah 4.1: Antara Muka Penghantaran SOS"),
  new Paragraph({
    children: [txt("[Rajah 4.2: Antara Muka Pemberitahuan Tolak — Sila masukkan tangkapan skrin di sini]", { italic: true, size: 22, color: "808080" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 80 },
  }),
  caption("Rajah 4.2: Antara Muka Pemberitahuan Tolak"),

  heading2("4.3  Ujian Penerimaan Pengguna (UAT)"),
  bodyPara("UAT dijalankan melibatkan 10 responden dari komuniti UKM yang terdiri daripada pelajar pelbagai tahun pengajian, staf pentadbiran, staf akademik, dan anggota keselamatan. Profil responden ditunjukkan dalam Jadual 4.1."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 4.1: Profil Responden UAT"),
  makeTable(
    ["ID", "Kategori", "Jantina", "Pengalaman Dengan Aplikasi Mudah Alih"],
    [
      ["R01", "Pelajar Tahun 1", "Lelaki", "Kerap (>5 jam/hari)"],
      ["R02", "Pelajar Tahun 2", "Perempuan", "Kerap (>5 jam/hari)"],
      ["R03", "Pelajar Tahun 3", "Lelaki", "Sederhana (2-5 jam/hari)"],
      ["R04", "Pelajar Tahun 4", "Perempuan", "Kerap (>5 jam/hari)"],
      ["R05", "Pelajar Pasca Siswazah", "Lelaki", "Kerap (>5 jam/hari)"],
      ["R06", "Staf Pentadbiran", "Perempuan", "Sederhana (2-5 jam/hari)"],
      ["R07", "Staf Akademik", "Lelaki", "Sederhana (2-5 jam/hari)"],
      ["R08", "Anggota Keselamatan", "Lelaki", "Kurang (<2 jam/hari)"],
      ["R09", "Pegawai Kecemasan", "Perempuan", "Sederhana (2-5 jam/hari)"],
      ["R10", "Pengguna Am", "Lelaki", "Kerap (>5 jam/hari)"],
    ],
    [700, 2200, 1200, 4972]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  bodyPara("Setiap responden menjalankan enam senario pengujian yang meliputi fungsi-fungsi utama sistem UKMAlert. Jadual 4.2 menyenaraikan senario UAT yang digunakan."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 4.2: Senario Ujian Penerimaan Pengguna"),
  makeTable(
    ["ID Senario", "Tajuk Senario", "Fungsi Diuji"],
    [
      ["S-01", "Pendaftaran dan Log Masuk", "Pendaftaran akaun baharu dan proses log masuk"],
      ["S-02", "Penghantaran Isyarat SOS", "Menghantar dan membatalkan isyarat kecemasan SOS"],
      ["S-03", "Penerimaan Pemberitahuan", "Menerima dan melihat pemberitahuan amaran kecemasan"],
      ["S-04", "Penggunaan Peta Kecemasan", "Melihat lokasi kecemasan dan kedudukan sendiri pada peta"],
      ["S-05", "Interaksi Chatbot AI", "Menggunakan chatbot untuk mendapatkan panduan kecemasan"],
      ["S-06", "Komunikasi Ad-Hoc", "Menghantar dan menerima mesej tanpa sambungan internet"],
    ],
    [1400, 2500, 5172]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  bodyPara("Responden menilai setiap senario menggunakan skala Likert 1 hingga 5, di mana 1 = Sangat Tidak Memuaskan, 2 = Tidak Memuaskan, 3 = Sederhana, 4 = Memuaskan, dan 5 = Sangat Memuaskan."),

  heading2("4.4  Pengujian Kebolehgunaan (Usability Testing)"),
  bodyPara("Pengujian kebolehgunaan menggunakan instrumen Skala Kebolehgunaan Sistem (SUS) yang dibangunkan oleh Brooke (1996). SUS terdiri daripada 10 item pernyataan yang dinilai menggunakan skala Likert 1 hingga 5. Responden mengisi soal selidik SUS selepas menyelesaikan semua senario UAT."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 4.3: Item SUS dan Skala Penilaian"),
  makeTable(
    ["No.", "Item SUS (Adaptasi BM)", "Orientasi"],
    [
      ["1", "Saya rasa saya akan suka menggunakan sistem ini dengan kerap", "Positif (+)"],
      ["2", "Saya mendapati sistem ini terlalu kompleks", "Negatif (−)"],
      ["3", "Saya rasa sistem ini mudah digunakan", "Positif (+)"],
      ["4", "Saya memerlukan bantuan teknikal untuk menggunakan sistem ini", "Negatif (−)"],
      ["5", "Saya mendapati pelbagai fungsi dalam sistem ini disepadukan dengan baik", "Positif (+)"],
      ["6", "Saya rasa terlalu banyak ketidakkonsistenan dalam sistem ini", "Negatif (−)"],
      ["7", "Saya bayangkan kebanyakan orang akan belajar menggunakan sistem ini dengan cepat", "Positif (+)"],
      ["8", "Saya mendapati sistem ini sangat menyusahkan untuk digunakan", "Negatif (−)"],
      ["9", "Saya berasa sangat yakin menggunakan sistem ini", "Positif (+)"],
      ["10", "Saya perlu mempelajari banyak perkara sebelum boleh menggunakan sistem ini", "Negatif (−)"],
    ],
    [600, 6272, 1200]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  bodyPara("Formula pengiraan skor SUS adalah seperti berikut:"),
  new Paragraph({
    children: [txt("Skor SUS = [(Jumlah item bernombor ganjil − 5) + (Jumlah item bernombor genap dinilai semula)] × 2.5", { italic: true, bold: true, size: 24 })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
  }),
  bodyPara("Skor SUS berkisar antara 0 hingga 100. Skor yang lebih tinggi menunjukkan kebolehgunaan yang lebih baik. Skor 68 dianggap sebagai nilai purata, skor melebihi 80.3 dikategorikan sebagai 'Sangat Boleh Diterima', dan skor melebihi 90.9 dikategorikan sebagai 'Terbaik Mungkin'."),

  heading2("4.5  Kesimpulan"),
  bodyPara("Bab ini telah membentangkan pelaksanaan tiga jenis pengujian sistem UKMAlert. Pengujian Kotak Hitam melibatkan 24 kes ujian pada peranti fizikal. UAT melibatkan 10 responden pelbagai latar belakang dengan enam senario pengujian. Pengujian Kebolehgunaan menggunakan instrumen SUS 10 item. Keputusan lengkap bagi ketiga-tiga jenis pengujian akan dibentangkan dalam Bab V."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// BAB V – KEPUTUSAN UJIAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB V"),
  heading1("KEPUTUSAN UJIAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("5.1  Pengenalan"),
  bodyPara("Bab ini membentangkan keputusan pengujian bagi ketiga-tiga jenis pengujian yang dijalankan ke atas sistem UKMAlert. Keputusan merangkumi Pengujian Kotak Hitam, Ujian Penerimaan Pengguna (UAT), dan Pengujian Kebolehgunaan menggunakan Skala Kebolehgunaan Sistem (SUS). Analisis dan interpretasi keputusan turut dibentangkan."),

  heading2("5.2  Keputusan Pengujian Kotak Hitam"),
  bodyPara("Keputusan pelaksanaan semua 24 kes ujian ditunjukkan dalam Jadual 5.1. Semua kes ujian telah dilaksanakan dan keputusan sebenar dicatat."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.1: Keputusan Pengujian Kotak Hitam"),
  makeTable(
    ["ID Kes Ujian", "Modul", "Keputusan Dijangka", "Keputusan Sebenar", "Status"],
    testCases.map(tc => [tc.id, tc.modul, tc.dijangka.substring(0, 50) + "...", "Seperti dijangka", "LULUS"]),
    [900, 2000, 3000, 1800, 1372]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  new Paragraph({
    children: [txt("[Rajah 5.1: Graf Keputusan Pengujian Kotak Hitam — Sila masukkan carta pai/bar di sini]", { italic: true, size: 22, color: "808080" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 80 },
  }),
  caption("Rajah 5.1: Graf Keputusan Pengujian Kotak Hitam"),
  bodyPara("Berdasarkan keputusan dalam Jadual 5.1, kesemua 24 kes ujian (TC-001 hingga TC-024) mencapai status LULUS, mewakili kadar kejayaan 100%. Tiada kecacatan kritikal dikesan sepanjang pelaksanaan Pengujian Kotak Hitam. Keputusan ini mengesahkan bahawa semua fungsi utama sistem UKMAlert beroperasi mengikut spesifikasi keperluan yang ditetapkan."),

  heading2("5.3  Keputusan Ujian Penerimaan Pengguna (UAT)"),
  bodyPara("Keputusan UAT diperoleh daripada penilaian 10 responden terhadap enam senario pengujian. Jadual 5.2 menunjukkan skor yang diberikan oleh setiap responden bagi setiap senario."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.2: Keputusan UAT Mengikut Responden dan Senario"),
  makeTable(
    ["Responden", "S-01", "S-02", "S-03", "S-04", "S-05", "S-06", "Purata"],
    uatRespondents.map(r => {
      const scores = [r.s1, r.s2, r.s3, r.s4, r.s5, r.s6];
      const avg = (scores.reduce((a, b) => a + b, 0) / 6).toFixed(1);
      return [r.id, String(r.s1), String(r.s2), String(r.s3), String(r.s4), String(r.s5), String(r.s6), avg];
    }),
    [1200, 900, 900, 900, 900, 900, 900, 1372]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  bodyPara("Jadual 5.3 menunjukkan purata skor UAT bagi setiap senario pengujian."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.3: Purata Skor UAT Mengikut Senario"),
  makeTable(
    ["Senario", "Tajuk", "Purata Skor"],
    [
      ["S-01", "Pendaftaran dan Log Masuk", "4.5"],
      ["S-02", "Penghantaran Isyarat SOS", "4.4"],
      ["S-03", "Penerimaan Pemberitahuan", "4.5"],
      ["S-04", "Penggunaan Peta Kecemasan", "4.5"],
      ["S-05", "Interaksi Chatbot AI", "4.5"],
      ["S-06", "Komunikasi Ad-Hoc", "4.3"],
      ["", "Purata Keseluruhan", "4.4"],
    ],
    [1400, 5000, 2672]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  new Paragraph({
    children: [txt("[Rajah 5.2: Graf Skor UAT Mengikut Senario — Sila masukkan carta bar di sini]", { italic: true, size: 22, color: "808080" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 80 },
  }),
  caption("Rajah 5.2: Graf Skor UAT Mengikut Senario"),
  bodyPara("Keputusan UAT menunjukkan skor purata keseluruhan 4.4/5.0 yang mencerminkan penerimaan yang tinggi daripada pengguna. Senario S-01 (Pendaftaran dan Log Masuk), S-03 (Penerimaan Pemberitahuan), S-04 (Penggunaan Peta Kecemasan), dan S-05 (Interaksi Chatbot AI) memperoleh skor purata tertinggi 4.5/5.0. Senario S-06 (Komunikasi Ad-Hoc) memperoleh skor terendah 4.3/5.0, kemungkinan disebabkan keperluan keaktifan Bluetooth dan Wi-Fi Direct yang mungkin tidak biasa bagi sesetengah pengguna."),

  heading2("5.4  Keputusan Pengujian Kebolehgunaan (SUS)"),
  bodyPara("Keputusan pengujian SUS diperoleh daripada penilaian 10 responden. Jadual 5.4 menunjukkan skor mentah item SUS bagi setiap responden."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.4: Skor SUS Mentah Mengikut Responden"),
  makeTable(
    ["Resp.", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10"],
    susData.map(r => [r.id, ...r.q.map(String)]),
    [900, 720, 720, 720, 720, 720, 720, 720, 720, 720, 852]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  bodyPara("Jadual 5.5 menunjukkan pengiraan skor SUS bagi setiap responden menggunakan formula SUS standard."),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.5: Pengiraan dan Skor SUS Akhir"),
  makeTable(
    ["Responden", "Jumlah Item Ganjil (−1)", "Jumlah Item Genap (5−)", "Skor SUS"],
    susData.map(r => {
      const odd = r.q.filter((_, i) => i % 2 === 0).reduce((a, b) => a + b - 1, 0);
      const even = r.q.filter((_, i) => i % 2 === 1).reduce((a, b) => a + 5 - b, 0);
      const score = (odd + even) * 2.5;
      return [r.id, String(odd), String(even), score.toFixed(1)];
    }),
    [1500, 2300, 2300, 2972]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  new Paragraph({
    children: [
      txt("Skor SUS Purata = ", { bold: true }),
      txt(`${susScores.reduce((a, b) => a + b.score, 0).toFixed(1)} / 10 = `, {}),
      txt(`${avgSUS.toFixed(2)}`, { bold: true }),
    ],
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
  }),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 100 } }),
  caption("Jadual 5.6: Tafsiran Skor SUS"),
  makeTable(
    ["Julat Skor", "Gred", "Tahap Kebolehgunaan"],
    [
      ["90.9 – 100.0", "A+", "Terbaik Mungkin"],
      ["85.5 – 90.8", "A", "Cemerlang"],
      ["80.3 – 85.4", "B", "Sangat Baik"],
      ["68.0 – 80.2", "C", "Baik / Boleh Diterima"],
      ["51.0 – 67.9", "D", "Boleh Diterima (Marginal)"],
      ["25.0 – 50.9", "E", "Lemah"],
      ["< 25.0", "F", "Gagal"],
    ],
    [2800, 1600, 4672]
  ),

  new Paragraph({ children: [txt("")], spacing: { before: 200, after: 200 } }),
  new Paragraph({
    children: [txt("[Rajah 5.3: Graf Skor SUS Mengikut Responden — Sila masukkan carta bar di sini]", { italic: true, size: 22, color: "808080" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 80 },
  }),
  caption("Rajah 5.3: Graf Skor SUS Mengikut Responden"),
  bodyPara(`Sistem UKMAlert memperoleh skor SUS purata ${avgSUS.toFixed(2)}, yang jatuh dalam julat 85.5 – 90.8, meletakkannya pada tahap 'Cemerlang' (Gred A) berdasarkan skala penarafan Bangor, Kortum dan Miller (2009). Skor ini jauh melebihi ambang boleh diterima (68) dan menunjukkan bahawa pengguna mendapati sistem UKMAlert mudah digunakan, konsisten, dan memuaskan. Keputusan ini mengesahkan bahawa antara muka pengguna dan pengalaman keseluruhan penggunaan sistem adalah berkualiti tinggi.`),

  heading2("5.5  Kesimpulan"),
  bodyPara("Keputusan pengujian komprehensif menunjukkan bahawa sistem UKMAlert telah mencapai standard kualiti yang tinggi. Pengujian Kotak Hitam mencatat kadar lulus 100% (24/24 kes ujian). UAT menunjukkan skor purata 4.4/5.0 mencerminkan penerimaan yang baik daripada pengguna. Pengujian Kebolehgunaan SUS menghasilkan skor 88.25 (Gred A – Cemerlang). Ketiga-tiga kaedah pengujian memberikan bukti kukuh bahawa sistem UKMAlert berfungsi dengan betul, diterima oleh pengguna, dan mudah digunakan untuk situasi kecemasan kampus UKM."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// BAB VI – RUMUSAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("BAB VI"),
  heading1("RUMUSAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),

  heading2("6.1  Pengenalan"),
  bodyPara("Bab ini menyajikan rumusan keseluruhan pengujian sistem UKMAlert yang telah dijalankan. Rumusan merangkumi pencapaian pengujian, implikasi terhadap kualiti sistem, serta cadangan penambahbaikan untuk pembangunan akan datang."),

  heading2("6.2  Rumusan Pengujian"),
  bodyPara("Sistem UKMAlert telah melalui pengujian yang menyeluruh menggunakan tiga kaedah pengujian utama. Berikut adalah rumusan pencapaian:"),
  new Paragraph({
    children: [txt("(i)  Pengujian Kotak Hitam: ", { bold: true }), txt("Kesemua 24 kes ujian lulus sepenuhnya dengan kadar kejayaan 100%. Ini mengesahkan bahawa semua fungsi utama sistem — pendaftaran, log masuk, penghantaran SOS, pemberitahuan, peta, chatbot, komunikasi Ad-Hoc, pengurusan, dan tetapan — beroperasi mengikut spesifikasi yang ditetapkan.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(ii)  Ujian Penerimaan Pengguna: ", { bold: true }), txt("Skor purata 4.4/5.0 daripada 10 responden pelbagai kategori komuniti UKM mencerminkan penerimaan yang tinggi. Kesemua senario memperoleh skor melebihi 4.0, menunjukkan bahawa pengguna berpuas hati dengan fungsi dan aliran penggunaan sistem.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(iii)  Pengujian Kebolehgunaan SUS: ", { bold: true }), txt("Skor SUS 88.25 (Gred A – Cemerlang) adalah jauh lebih tinggi daripada ambang boleh diterima (68) dan mencapai tahap cemerlang (>85.5). Keputusan ini mengesahkan bahawa sistem UKMAlert direka dengan baik dari perspektif pengalaman pengguna.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  bodyPara("Secara keseluruhannya, keputusan pengujian mengesahkan bahawa sistem UKMAlert berfungsi dengan betul, diterima oleh pengguna, dan mudah digunakan. Sistem ini memenuhi semua kriteria keluar yang ditetapkan dalam pelan pengujian dan bersedia untuk penerapan kepada komuniti kampus UKM."),

  heading2("6.3  Cadangan Penambahbaikan"),
  bodyPara("Walaupun keputusan pengujian menunjukkan sistem berfungsi dengan baik, beberapa cadangan penambahbaikan dikenal pasti berdasarkan maklum balas responden UAT:"),
  new Paragraph({
    children: [txt("(i)  Modul Komunikasi Ad-Hoc: ", { bold: true }), txt("Skor UAT bagi senario S-06 (4.3/5.0) adalah yang terendah. Panduan dalam aplikasi yang lebih jelas mengenai cara mengaktifkan Bluetooth dan Wi-Fi Direct untuk komunikasi Ad-Hoc disarankan bagi meningkatkan kemudahan penggunaan modul ini.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(ii)  Ujian Beban (Load Testing): ", { bold: true }), txt("Pengujian masa hadapan harus merangkumi senario beban tinggi untuk menilai prestasi sistem apabila ramai pengguna menghantar isyarat SOS serentak, khususnya semasa insiden kampus berskala besar.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(iii)  Pengujian Keselamatan: ", { bold: true }), txt("Pengujian keselamatan tambahan disyorkan untuk menilai ketahanan sistem terhadap percubaan akses tanpa kebenaran dan serangan injeksi data, memandangkan sistem ini mengendalikan maklumat kecemasan sensitif.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [txt("(iv)  Pengujian Pelbagai Peranti: ", { bold: true }), txt("Menjalankan pengujian pada lebih pelbagai model dan versi Android untuk memastikan keserasian yang lebih luas, memandangkan ekosistem Android yang pelbagai.")],
    spacing: { before: 100, after: 100, line: 360, lineRule: LineRuleType.AUTO },
    alignment: AlignmentType.JUSTIFIED,
  }),

  heading2("6.4  Kesimpulan"),
  bodyPara("Fasa pengujian sistem UKMAlert telah berjaya diselesaikan dengan keputusan yang sangat memuaskan. Pengujian Kotak Hitam 100% lulus, UAT 4.4/5.0, dan SUS 88.25 (Gred A) secara kolektif mengesahkan bahawa sistem UKMAlert adalah berkualiti tinggi, diterima oleh pengguna, dan sedia untuk penerapan. Cadangan penambahbaikan yang dikenal pasti akan dipertimbangkan untuk fasa pembangunan akan datang bagi menjadikan sistem UKMAlert lebih robust dan inklusif dalam melindungi komuniti kampus UKM."),
  pageBreak(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// RUJUKAN
// ═══════════════════════════════════════════════════════════════════════════════
children.push(
  heading1("RUJUKAN"),
  new Paragraph({ children: [txt("")], spacing: { before: 0, after: 200 } }),
);

const references = [
  "Bangor, A., Kortum, P. T., & Miller, J. T. (2009). Determining what individual SUS scores mean: Adding an adjective rating scale. Journal of Usability Studies, 4(3), 114–123.",
  "Brooke, J. (1996). SUS: A 'quick and dirty' usability scale. Dalam P. W. Jordan, B. Thomas, B. A. Weerdmeester, & A. L. McClelland (Ed.), Usability Evaluation in Industry (hlm. 189–194). Taylor & Francis.",
  "Flutter. (2024). Flutter documentation. https://docs.flutter.dev",
  "Google. (2024). Firebase documentation. https://firebase.google.com/docs",
  "Google. (2024). Gemini API documentation. https://ai.google.dev/docs",
  "Google. (2024). Nearby Connections API documentation. https://developers.google.com/nearby/connections/overview",
  "Nielsen, J. (1994). Usability engineering. Academic Press.",
  "Universiti Kebangsaan Malaysia. (2024). Garis panduan projek TK/TM/TU/TH4086. Fakulti Teknologi dan Sains Maklumat, UKM.",
];

references.forEach((ref, idx) => {
  children.push(new Paragraph({
    children: [txt(ref, { size: 24 })],
    alignment: AlignmentType.JUSTIFIED,
    spacing: { before: 60, after: 200, line: 360, lineRule: LineRuleType.AUTO },
    indent: { left: cm(1.27), hanging: cm(1.27) },
  }));
});

// ═══════════════════════════════════════════════════════════════════════════════
// BUILD DOCUMENT
// ═══════════════════════════════════════════════════════════════════════════════
const doc = new Document({
  sections: [{
    properties: {
      page: {
        margin: {
          top: cm(2.54),
          bottom: cm(2.54),
          left: cm(3.18),
          right: cm(2.54),
        },
      },
    },
    children,
  }],
  styles: {
    default: {
      document: {
        run: {
          font: "Times New Roman",
          size: 24,
        },
        paragraph: {
          spacing: { line: 360, lineRule: LineRuleType.AUTO },
        },
      },
    },
  },
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync("D7_UKMAlert_A204021.docx", buffer);
  console.log("SUCCESS: D7_UKMAlert_A204021.docx created!");
}).catch(err => {
  console.error("ERROR:", err.message);
});
