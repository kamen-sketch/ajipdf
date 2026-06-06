import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Implementasi native: simpan ke lokasi pilihan user, fallback ke folder dokumen.
Future<bool> savePdfImpl(String fileName, Uint8List bytes) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // Coba juga buka dialog "save as" jika didukung.
    try {
      await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
    } catch (_) {
      // abaikan jika tidak didukung, file sudah tersimpan di dokumen.
    }
    return true;
  } catch (_) {
    return false;
  }
}
