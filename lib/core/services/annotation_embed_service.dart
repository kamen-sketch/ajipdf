import 'dart:convert';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service untuk embed dan extract anotasi aplikasi ke/dari metadata PDF.
///
/// Strategi:
/// - Anotasi SfPdfViewer (highlight, underline dll) di-embed sebagai standard
///   PDF annotations — terbaca oleh semua reader.
/// - Metadata tambahan (app-specific data, warna custom, tipe dll) disimpan di
///   field "Keywords" dokumen sebagai JSON yang di-encode base64.
///   Format: `AJIPDF_ANNOTATIONS_V1:<base64_json>`
/// - Reader PDF lain akan melihat ini sebagai keywords biasa — tidak mengganggu.
/// - Saat app kita buka PDF, kita extract JSON ini dan restore anotasi.
///
/// Dengan pendekatan ini:
/// - PDF bytes sendiri sudah berisi anotasi standar (highlight terlihat semua reader)
/// - Metadata tambahan (id, warna, tipe app-specific) hanya dibaca app kita
/// - Cross-device: upload 1 file PDF, semua data ikut
const String _metaPrefix = 'AJIPDF_ANNOTATIONS_V1:';

class AnnotationEmbedService {
  const AnnotationEmbedService._();

  /// Embed daftar anotasi sebagai JSON ke metadata PDF.
  ///
  /// [pdfBytes] — bytes PDF yang sudah berisi anotasi visual dari SfPdfViewer.
  /// [annotations] — daftar anotasi model app (dari annotationProvider).
  /// Returns bytes PDF baru dengan metadata tertanam.
  static Uint8List embedAnnotations(
    Uint8List pdfBytes,
    List<Map<String, dynamic>> annotations,
  ) {
    final doc = PdfDocument(inputBytes: pdfBytes);

    try {
      // Encode JSON ke base64 agar aman disimpan di metadata teks
      final jsonStr = jsonEncode(annotations);
      final encoded = base64Encode(utf8.encode(jsonStr));
      final metaValue = '$_metaPrefix$encoded';

      // Simpan di field Keywords — field yang jarang dipakai dan aman
      doc.documentInformation.keywords = metaValue;

      final saved = Uint8List.fromList(doc.saveSync());
      return saved;
    } finally {
      doc.dispose();
    }
  }

  /// Extract anotasi dari metadata PDF.
  ///
  /// Returns list annotation maps, atau list kosong jika tidak ada.
  static List<Map<String, dynamic>> extractAnnotations(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);

    try {
      final keywords = doc.documentInformation.keywords;
      if (keywords.isEmpty) return [];
      if (!keywords.startsWith(_metaPrefix)) return [];

      final encoded = keywords.substring(_metaPrefix.length);
      final jsonStr = utf8.decode(base64Decode(encoded));
      final raw = jsonDecode(jsonStr) as List<dynamic>;
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // Data corrupt atau tidak ada → return kosong
      return [];
    } finally {
      doc.dispose();
    }
  }

  /// Hapus metadata anotasi dari PDF (untuk export ke reader lain).
  static Uint8List stripAnnotationMetadata(Uint8List pdfBytes) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    try {
      final keywords = doc.documentInformation.keywords;
      if (keywords.startsWith(_metaPrefix)) {
        doc.documentInformation.keywords = '';
      }
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }
}
