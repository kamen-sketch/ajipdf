import 'dart:typed_data';

// Conditional import: gunakan implementasi web jika di browser, native jika tidak.
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';

/// Simpan (native) atau unduh (web) file PDF.
/// Mengembalikan true jika berhasil/diproses.
Future<bool> saveOrDownloadPdf(String fileName, Uint8List bytes) {
  return savePdfImpl(fileName, bytes);
}
