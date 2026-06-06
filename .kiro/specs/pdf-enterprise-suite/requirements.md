# Requirements Document

## Introduction

PDF Enterprise Suite adalah aplikasi PDF all-in-one cross-platform (iOS, Android, Web) dengan model freemium yang menyediakan fitur lengkap untuk mengelola dokumen PDF termasuk viewing, editing, signing, dan sharing dengan integrasi cloud storage. Aplikasi ini dirancang untuk kebutuhan enterprise namun tetap mudah digunakan dengan model gratis dan berbayar (Pro).

Model Freemium:
- **Free Tier**: Split/Merge maksimal 10 dokumen/bulan, tanpa digital signature, tanpa lock/encrypt, annotate dasar
- **Pro Tier**: Unlimited split/merge, digital signature, lock/encrypt, full annotate, compress, watermark, OCR, tanpa iklan

---

## Glossary

- **PDFDocument**: Representasi dokumen PDF dalam sistem yang menyimpan metadata, konten, dan status dokumen
- **PDFViewerEngine**: Komponen yang bertanggung jawab untuk render dan menampilkan dokumen PDF
- **PDFEditorEngine**: Komponen yang memproses operasi editing PDF seperti split, merge, compress, watermark
- **AnnotationEngine**: Komponen yang mengelola anotasi, highlight, dan catatan pada PDF
- **DigitalSignatureEngine**: Komponen yang menangani pembuatan dan aplikasi tanda tangan digital
- **OCREngine**: Komponen yang mengkonversi gambar dan scanned PDF menjadi teks searchable
- **CloudSyncService**: Komponen yang menangani sinkronisasi dokumen dengan cloud storage
- **SubscriptionManager**: Komponen yang mengelola subscription dan feature gating untuk model freemium
- **ExportShareService**: Komponen yang menangani export dan share dokumen melalui berbagai channel
- **User**: Entitas pengguna aplikasi dengan subscription tier dan usage statistics
- **Signature**: Representasi tanda tangan digital yang dapat dibuat melalui drawing, upload gambar, atau typed text
- **Annotation**: Catatan atau markup pada dokumen PDF termasuk highlight, underline, strikethrough, text, drawing, dan stamp
- **CloudProvider**: Provider cloud storage yang didukung (Google Drive, iCloud)

---

## Requirements

### Requirement 1: PDF Viewer

**User Story:** Sebagai pengguna, saya ingin melihat dokumen PDF dengan performa tinggi, sehingga saya dapat membaca dan menavigasi dokumen dengan lancar.

#### Acceptance Criteria

1. WHEN pengguna membuka file PDF dengan ukuran 1 sampai 50 halaman, THE PDFViewerEngine SHALL me-render dan menampilkan halaman pertama dalam waktu kurang dari 1 detik
2. WHEN pengguna melakukan scroll pada dokumen, THE PDFViewerEngine SHALL mempertahankan frame rate minimal 60fps pada perangkat dengan RAM 4GB atau lebih
3. WHEN pengguna melakukan zoom pada halaman, THE PDFViewerEngine SHALL me-render ulang halaman dengan resolusi yang sesuai dengan tingkat zoom dalam waktu kurang dari 100ms
4. THE PDFViewerEngine SHALL menyimpan metadata dokumen termasuk judul, penulis, jumlah halaman, dan tanggal pembuatan
5. IF metadata dokumen tidak tersedia, THE PDFViewerEngine SHALL menampilkan nilai kosong atau "Tidak tersedia" untuk field yang hilang
6. WHEN dokumen memiliki lebih dari 100 halaman, THE PDFViewerEngine SHALL memuat halaman secara bertahap dengan maksimal 20 halaman per batch
7. IF file yang dibuka bukan PDF valid atau dokumen rusak, THE PDFViewerEngine SHALL menampilkan pesan error yang menunjukkan file tidak dapat dibuka
8. THE PDFViewerEngine SHALL menyediakan panel thumbnail yang menampilkan hingga 20 thumbnail halaman sekaligus dalam ukuran 80x100 piksel

### Requirement 2: Split/Merge PDF

**User Story:** Sebagai pengguna, saya ingin memisahkan atau menggabungkan dokumen PDF, sehingga saya dapat mengorganisir dokumen sesuai kebutuhan.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi split, THE PDFEditorEngine SHALL memisahkan dokumen berdasarkan range halaman atau ukuran chunk yang ditentukan
2. IF range halaman yang ditentukan tidak valid (start > end, nilai negatif, atau melebihi jumlah halaman dokumen), THEN THE PDFEditorEngine SHALL menampilkan pesan error yang menunjukkan range yang valid
3. WHEN operasi split selesai, THE total jumlah halaman dari semua dokumen hasil SHALL sama dengan jumlah halaman dokumen asli
4. WHEN pengguna memilih opsi merge, THE PDFEditorEngine SHALL menggabungkan minimum 2 dokumen PDF menjadi satu dokumen
5. IF jumlah dokumen yang dipilih untuk merge kurang dari 2, THEN THE System SHALL menampilkan pesan error yang menunjukkan minimum 2 dokumen diperlukan
6. WHEN operasi merge selesai, THE dokumen hasil SHALL memiliki jumlah halaman yang sama dengan total semua halaman dari dokumen input
7. IF salah satu dokumen input untuk split atau merge terenkripsi dengan password, THEN THE System SHALL meminta password untuk dokumen tersebut sebelum melanjutkan operasi
8. WHEN pengguna Free tier melakukan split/merge, THE SubscriptionManager SHALL menginkrementasi usage count sebesar 1 untuk setiap operasi yang berhasil
9. WHEN pengguna Free tier melakukan split/merge, THE SubscriptionManager SHALL membatasi penggunaan maksimal 10 operasi per bulan
10. WHEN pengguna Pro tier melakukan split/merge, THE SubscriptionManager SHALL mengizinkan penggunaan tanpa batas
11. IF pengguna Free tier mencoba melakukan split/merge saat usage count sudah mencapai 10, THEN THE System SHALL menolak operasi dan menampilkan prompt untuk upgrade ke Pro
12. WHEN pengguna Free tier mendekati batas bulanan dengan 8 atau 9 operasi terpakai, THE System SHALL menampilkan peringatan sisa kuota sebelum operasi dimulai

### Requirement 3: Digital Signature

**User Story:** Sebagai pengguna Pro, saya ingin menandatangani dokumen PDF secara digital, sehingga saya dapat menandatangani dokumen tanpa perlu mencetak.

#### Acceptance Criteria

1. WHEN pengguna membuat tanda tangan baru, THE DigitalSignatureEngine SHALL menyediakan tiga metode: drawing, upload gambar (PNG/JPEG, maks 5MB), dan typed text
2. WHEN tanda tangan dibuat, THE DigitalSignatureEngine SHALL menyimpannya untuk penggunaan ulang dengan nama yang ditentukan
3. WHEN pengguna menerapkan tanda tangan ke dokumen, THE DigitalSignatureEngine SHALL menempatkannya pada posisi yang ditentukan dengan skala 25%-200% dan rotasi 0°, 90°, 180°, atau 270°
4. WHEN tanda tangan diterapkan, THE System SHALL menyimpan timestamp dan user ID untuk tujuan verifikasi
5. WHERE pengguna adalah Free tier, THE System SHALL menampilkan prompt upgrade saat mencoba mengakses fitur signature
6. WHEN pengguna Pro tier membuat tanda tangan, THE DigitalSignatureEngine SHALL menyimpan maksimal 10 signature untuk penggunaan ulang
7. IF pengguna Pro tier mencoba membuat signature ke-11, THEN THE System SHALL menampilkan pesan error yang menunjukkan batas maksimum 10 signature
8. IF proses pembuatan signature gagal karena input tidak valid, THEN THE DigitalSignatureEngine SHALL menampilkan pesan error yang menjelaskan masalah dan tidak menyimpan signature

### Requirement 4: Lock/Encrypt PDF

**User Story:** Sebagai pengguna Pro, saya ingin mengunci dokumen PDF dengan password, sehingga dokumen saya tetap aman dan hanya dapat diakses oleh orang yang berwenang.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi lock/encrypt, THE PDFEditorEngine SHALL mengenkripsi dokumen dengan AES-256 encryption menggunakan password dengan panjang minimum 4 karakter dan maksimum 128 karakter
2. WHEN dokumen berhasil dienkripsi, THE System SHALL menyimpan status enkripsi dalam metadata dokumen
3. WHEN pengguna mencoba membuka dokumen terenkripsi, THE PDFViewerEngine SHALL meminta password yang valid dengan maksimal 5 percobaan
4. IF password yang dimasukkan salah, THEN THE System SHALL menampilkan pesan error, tidak membuka dokumen, dan mengurangi sisa percobaan
5. IF percobaan password mencapai batas maksimum, THEN THE System SHALL menampilkan pesan error dan menonaktifkan input password selama 30 detik
6. WHERE pengguna adalah Free tier, THE System SHALL menampilkan prompt upgrade saat mencoba mengakses fitur lock
7. WHEN dokumen dienkripsi, THE System SHALL menyimpan permission flags (print, copy, modify, annotate) dalam dokumen
8. IF proses enkripsi gagal, THEN THE System SHALL menampilkan pesan error dan menyimpan dokumen dalam kondisi tidak terenkripsi

### Requirement 5: Annotate/Highlight

**User Story:** Sebagai pengguna, saya ingin menambahkan anotasi dan highlight pada dokumen PDF, sehingga saya dapat menandai bagian penting dan membuat catatan.

#### Acceptance Criteria

1. WHEN pengguna menambahkan anotasi, THE AnnotationEngine SHALL menyimpan anotasi dengan tipe, posisi dalam format nomor halaman dan koordinat, dan data yang ditentukan termasuk warna RGB, konten teks atau gambar, dengan ukuran maksimal 10 MB per anotasi
2. THE AnnotationEngine SHALL mendukung tipe anotasi: highlight, underline, strikethrough, text, drawing, dan stamp
3. WHEN pengguna mengubah anotasi yang ada, THE AnnotationEngine SHALL memperbarui data anotasi dan timestamp
4. WHEN pengguna menghapus anotasi, THE AnnotationEngine SHALL menghapus data anotasi dari dokumen
5. WHERE pengguna adalah Free tier, THE System SHALL membatasi tipe anotasi ke highlight dan text saja dengan maksimal 50 anotasi per dokumen
6. WHERE pengguna adalah Pro tier, THE System SHALL menyediakan semua tipe anotasi dengan maksimal 500 anotasi per dokumen
7. WHEN pengguna mengekspor dokumen dengan anotasi, THE System SHALL menyertakan semua anotasi dalam file yang diekspor
8. IF pengguna Free tier mencoba menambahkan anotasi tipe Pro-only (underline, strikethrough, drawing, stamp), THEN THE System SHALL menampilkan prompt upgrade ke Pro

### Requirement 6: Compress PDF

**User Story:** Sebagai pengguna Pro, saya ingin mengompres dokumen PDF, sehingga saya dapat mengurangi ukuran file untuk berbagi atau penyimpanan.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi compress, THE PDFEditorEngine SHALL mengurangi ukuran file dengan salah satu tingkat kompresi: Low (10-30% reduction), Medium (30-50% reduction), atau High (50-70% reduction)
2. WHEN kompresi selesai, THE System SHALL menampilkan ukuran file sebelum dan sesudah kompresi
3. WHEN kompresi diterapkan, THE PDFEditorEngine SHALL mempertahankan kualitas teks yang tetap selectable dan searchable, serta gambar dengan resolusi minimal 150 DPI
4. WHERE pengguna adalah Free tier, THE System SHALL menampilkan prompt upgrade saat mencoba mengakses fitur compress
5. IF hasil kompresi menghasilkan ukuran file yang sama atau lebih besar dari file asli, THEN THE System SHALL menampilkan notifikasi dan menyimpan dokumen asli
6. IF operasi kompresi gagal karena error pemrosesan atau file rusak, THEN THE System SHALL menampilkan pesan error dan mempertahankan dokumen asli

### Requirement 7: Rotate/Reorder Pages

**User Story:** Sebagai pengguna, saya ingin memutar dan mengubah urutan halaman dokumen PDF, sehingga saya dapat menyesuaikan orientasi dan urutan dokumen sesuai kebutuhan.

#### Acceptance Criteria

1. WHEN pengguna memilih satu atau beberapa halaman dan memutar, THE PDFEditorEngine SHALL memutar halaman sesuai sudut 90°, 180°, atau 270° dalam waktu maksimal 2 detik
2. WHEN pengguna mengubah urutan halaman melalui drag-and-drop atau input indeks, THE PDFEditorEngine SHALL menyusun ulang halaman sesuai urutan baru dalam waktu maksimal 3 detik untuk dokumen dibawah 50 halaman
3. WHEN operasi rotate atau reorder selesai, THE System SHALL mempertahankan semua anotasi dan tanda tangan pada halaman yang dimodifikasi
4. WHEN pengguna memilih halaman untuk dipreview, THE PDFEditorEngine SHALL menampilkan preview orientasi dan posisi halaman yang baru dalam waktu maksimal 500ms
5. WHEN pengguna membatalkan operasi sebelum mengonfirmasi perubahan, THE System SHALL mengembalikan dokumen ke kondisi sebelumnya
6. IF pengguna memilih halaman dengan nomor tidak valid, THEN THE System SHALL menampilkan pesan error dan tidak melanjutkan operasi

### Requirement 8: Watermark

**User Story:** Sebagai pengguna Pro, saya ingin menambahkan watermark pada dokumen PDF, sehingga saya dapat melindungi keaslian dokumen saya.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi watermark, THE PDFEditorEngine SHALL menambahkan watermark teks (maksimal 100 karakter) atau gambar (PNG/JPEG, maksimal 5MB) ke dokumen
2. THE PDFEditorEngine SHALL mendukung konfigurasi posisi (center, top-left, top-right, bottom-left, bottom-right), transparansi (10%-100%), rotasi (0°-360°), dan ukuran watermark (10%-100% dari ukuran halaman)
3. WHEN watermark ditambahkan, THE System SHALL menerapkannya ke semua halaman atau halaman tertentu sesuai konfigurasi
4. WHERE pengguna adalah Free tier, THE System SHALL menampilkan prompt upgrade saat mencoba mengakses fitur watermark
5. THE PDFEditorEngine SHALL membuat watermark read-only untuk menjaga keaslian dokumen
6. IF proses watermark gagal karena format tidak didukung atau file rusak, THEN THE System SHALL menampilkan pesan error dan mempertahankan dokumen asli

### Requirement 9: Dark Mode

**User Story:** Sebagai pengguna, saya ingin menggunakan aplikasi dalam mode gelap, sehingga saya dapat mengurangi eye strain saat menggunakan aplikasi di lingkungan dengan cahaya rendah.

#### Acceptance Criteria

1. WHEN pengguna mengaktifkan dark mode di pengaturan aplikasi, THE System SHALL mengubah tema UI menjadi dark theme pada semua komponen UI yang terlihat termasuk navigation bar, panels, buttons, text fields, dan background surfaces
2. WHEN system device dalam dark mode, THE System SHALL otomatis mengikuti tema device
3. THE System SHALL menyimpan preferensi dark mode dalam UserPreferences
4. WHEN dark mode aktif, THE PDFViewerEngine SHALL menampilkan dokumen dengan background gelap yang memiliki kontras tinggi terhadap teks, sambil mempertahankan warna asli konten dokumen
5. WHEN pengguna mengubah preferensi dark mode, THE System SHALL menerapkan perubahan tema dalam waktu maksimal 500 milidetik tanpa perlu restart aplikasi
6. IF pengguna belum pernah mengatur preferensi dark mode sebelumnya, THEN THE System SHALL menggunakan pengaturan tema device sebagai preferensi default

### Requirement 10: Cloud Sync (Google Drive, iCloud)

**User Story:** Sebagai pengguna, saya ingin menyinkronkan dokumen saya dengan cloud storage, sehingga saya dapat mengakses dokumen dari berbagai perangkat.

#### Acceptance Criteria

1. WHEN pengguna menghubungkan akun cloud storage, THE CloudSyncService SHALL mengautentikasi dengan OAuth 2.0
2. WHEN pengguna mengunggah dokumen, THE CloudSyncService SHALL mengunggah ke provider yang dipilih dengan timeout 30 detik per 10MB dan kompresi opsional
3. WHEN pengguna mengunduh dokumen, THE CloudSyncService SHALL mengunduh dari cloud dengan timeout 30 detik per 10MB dan menyimpan ke penyimpanan lokal
4. WHEN terjadi perubahan pada dokumen lokal, THE CloudSyncService SHALL menyinkronkan perubahan ke cloud dalam waktu maksimal 60 detik
5. THE CloudSyncService SHALL mendukung Google Drive dan iCloud sebagai cloud provider
6. WHEN terjadi konflik antara versi lokal dan cloud, THE CloudSyncService SHALL menyelesaikan konflik dengan strategi local-wins, cloud-wins, atau manual sesuai konfigurasi
7. THE System SHALL menyediakan status sinkronisasi real-time dengan latensi maksimal 500ms melalui Stream
8. WHEN koneksi jaringan tidak tersedia, THE System SHALL mengantre operasi sinkronisasi maksimal 100 operasi dan melanjutkan saat koneksi tersedia dengan interval retry 60 detik
9. IF operasi sinkronisasi gagal karena error jaringan atau autentikasi, THEN THE System SHALL menampilkan pesan error dan menyimpan perubahan lokal untuk retry manual

### Requirement 11: Share/Export

**User Story:** Sebagai pengguna, saya ingin membagikan dan mengekspor dokumen PDF, sehingga saya dapat berbagi dokumen dengan orang lain melalui berbagai channel.

#### Acceptance Criteria

1. WHEN pengguna memilih opsi share, THE ExportShareService SHALL menampilkan system share sheet dalam waktu kurang dari 500ms
2. THE ExportShareService SHALL mendukung share ke aplikasi messaging dan email yang terinstal pada perangkat
3. WHEN pengguna mengekspor dokumen, THE ExportShareService SHALL mengekspor dalam format PDF
4. WHEN pengguna memilih opsi shareable link, THE ExportShareService SHALL menghasilkan link yang dapat diakses selama 7 hari
5. WHEN membagikan dokumen dengan anotasi, THE System SHALL menyertakan semua anotasi dalam dokumen yang dibagikan
6. WHEN dokumen terenkripsi dibagikan, THE System SHALL meminta password saat penerima membuka dokumen
7. IF operasi share atau ekspor gagal atau dibatalkan oleh pengguna, THEN THE System SHALL menampilkan notifikasi dan mempertahankan dokumen asli tanpa perubahan
8. WHEN operasi ekspor berhasil, THE System SHALL menampilkan notifikasi sukses dan menyimpan file ke lokasi yang ditentukan pengguna

### Requirement 12: OCR

**User Story:** Sebagai pengguna Pro, saya ingin mengkonversi gambar dan scanned PDF menjadi teks yang dapat dicari, sehingga saya dapat mencari dan menyalin teks dari dokumen hasil scan.

#### Acceptance Criteria

1. WHEN pengguna memproses gambar atau scanned PDF, THE OCREngine SHALL mengekstrak teks dari dokumen dengan minimal 150 DPI resolusi
2. THE OCREngine SHALL mendukung minimal 5 bahasa untuk OCR processing termasuk Indonesian, English, Mandarin, Japanese, dan Arabic
3. WHEN OCR selesai, THE System SHALL menyimpan teks hasil ekstraksi dan mengaktifkan fungsi pencarian teks pada dokumen
4. WHERE pengguna adalah Free tier, THE System SHALL menampilkan prompt upgrade saat mencoba mengakses fitur OCR
5. THE OCREngine SHALL memproses satu halaman dalam waktu kurang dari 2 detik pada dokumen dengan resolusi hingga 300 DPI
6. IF resolusi gambar kurang dari 150 DPI, THEN THE System SHALL menampilkan pesan error yang menunjukkan resolusi minimum dan menyarankan scan ulang dengan kualitas lebih tinggi

### Requirement 13: Subscription Management (Free vs Pro)

**User Story:** Sebagai pengguna, saya ingin mengelola subscription saya, sehingga saya dapat mengakses fitur sesuai tier yang saya langgani.

#### Acceptance Criteria

1. WHEN pengguna mendaftar, THE SubscriptionManager SHALL membuat akun dengan tier Free secara default
2. WHEN pengguna memilih untuk upgrade ke Pro, THE SubscriptionManager SHALL memproses pembayaran melalui RevenueCat
3. IF pembayaran gagal atau ditolak, THEN THE SubscriptionManager SHALL menampilkan pesan error yang menjelaskan masalah dan mempertahankan tier Free
4. WHEN pembayaran berhasil, THE SubscriptionManager SHALL mengaktifkan subscription Pro dan memperbarui expiry date dalam waktu maksimal 5 detik
5. THE SubscriptionManager SHALL menyediakan endpoint untuk memeriksa status subscription aktif dengan response time maksimal 500ms
6. WHEN subscription Pro berakhir, THE SubscriptionManager SHALL mengembalikan pengguna ke tier Free dan menampilkan notifikasi perubahan tier
7. WHEN pengguna memulihkan pembelian, THE SubscriptionManager SHALL memvalidasi receipt dengan store dan memulihkan subscription dalam waktu maksimal 10 detik, dengan menampilkan pesan error jika validasi gagal
8. THE SubscriptionManager SHALL menyediakan Stream untuk mendengarkan perubahan status subscription dengan latensi maksimal 1 detik
9. WHEN pengguna Pro mencoba mengakses fitur Pro, THE System SHALL mengizinkan akses tanpa batasan
10. IF pengguna Free tier mencoba mengakses fitur Pro-only, THEN THE System SHALL menampilkan prompt upgrade dan menolak akses

### Requirement 14: User Authentication

**User Story:** Sebagai pengguna, saya ingin membuat akun dan login ke aplikasi, sehingga saya dapat mengakses dokumen dan preferensi saya dari berbagai perangkat.

#### Acceptance Criteria

1. WHEN pengguna mendaftar dengan email dan password (minimum 8 karakter), THE Firebase Auth SHALL membuat akun baru dan mengirim email verifikasi dalam waktu maksimal 30 detik
2. WHEN pengguna login dengan email dan password yang valid, THE Firebase Auth SHALL mengautentikasi dan mengembalikan auth token dalam waktu maksimal 3 detik
3. WHEN pengguna memilih OAuth login, THE System SHALL mengautentikasi melalui Google atau Apple dan mengembalikan auth token
4. IF kredensial login tidak valid, THEN THE System SHALL menampilkan pesan error "Email atau password salah" tanpa memberikan informasi spesifik
5. IF proses registrasi gagal karena email sudah terdaftar atau error jaringan, THEN THE System SHALL menampilkan pesan error yang sesuai
6. WHEN auth token kedaluwarsa, THE System SHALL secara otomatis me-refresh token dalam waktu maksimal 2 detik
7. WHEN pengguna logout, THE System SHALL menghapus session dan auth token dari penyimpanan lokal
8. THE System SHALL menyimpan auth tokens di secure storage (Keychain untuk iOS, Keystore untuk Android)
9. WHEN pengguna login, THE System SHALL memuat UserPreferences dan UsageStats dari Firestore dalam waktu maksimal 2 detik
10. IF Firestore tidak tersedia saat login, THEN THE System SHALL menggunakan nilai default untuk UserPreferences dan UsageStats, dan mencoba sinkronisasi saat koneksi tersedia

### Requirement 15: Usage Tracking

**User Story:** Sebagai sistem, saya ingin melacak penggunaan fitur oleh pengguna, sehingga saya dapat menerapkan batasan tier dan memberikan informasi penggunaan kepada pengguna.

#### Acceptance Criteria

1. WHEN pengguna menggunakan fitur metered yaitu split atau merge, THE SubscriptionManager SHALL menginkrementasi usage count sebanyak 1
2. WHEN tanggal berganti ke hari pertama bulan berikutnya pada 00:00 UTC, THE SubscriptionManager SHALL mereset usage count bulanan menjadi 0
3. WHEN usage count pengguna Free tier mencapai 80% atau 100% dari batas bulanan, THE System SHALL menampilkan peringatan yang menampilkan jumlah penggunaan tersisa
4. WHEN aplikasi meminta informasi penggunaan, THE SubscriptionManager SHALL menyediakan usage count saat ini dan limit bulanan untuk fitur metered
5. WHEN usage count melebihi limit bulanan, THE SubscriptionManager SHALL menolak akses ke fitur dan menampilkan prompt upgrade ke Pro tier
6. WHEN operasi pada dokumen selesai, THE System SHALL menyimpan usage statistics termasuk total documents processed dan storage used dalam megabytes dengan presisi 2 desimal
7. WHEN pengguna upgrade dari Free ke Pro, THE System SHALL menghapus batasan penggunaan bulanan untuk fitur metered dan mempertahankan usage statistics untuk keperluan reporting

---

## Feature Matrix by Subscription Tier

| Feature | Free Tier | Pro Tier |
|---------|-----------|----------|
| PDF Viewer | ✓ Full | ✓ Full |
| Split/Merge | 10 docs/month | Unlimited |
| Digital Signature | ✗ | ✓ |
| Lock/Encrypt | ✗ | ✓ |
| Annotate/Highlight | Basic (highlight, text) | Full (all types) |
| Compress | ✗ | ✓ |
| Rotate/Reorder | ✓ | ✓ |
| Watermark | ✗ | ✓ |
| Dark Mode | ✓ | ✓ |
| Cloud Sync | ✓ | ✓ |
| Share/Export | ✓ | ✓ |
| OCR | ✗ | ✓ |
| Ads | Yes | No |
