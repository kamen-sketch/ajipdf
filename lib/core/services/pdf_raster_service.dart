import 'dart:typed_data';

import 'pdf_raster_service_stub.dart'
    if (dart.library.html) 'pdf_raster_service_web.dart'
    if (dart.library.io) 'pdf_raster_service_native.dart';

/// Hasil rasterisasi satu halaman PDF menjadi image.
class RasterPage {
  RasterPage({
    required this.imageBytes,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.pointWidth,
    required this.pointHeight,
  });

  /// Bytes image (JPEG untuk compress, PNG untuk preview).
  final Uint8List imageBytes;
  final int pixelWidth;
  final int pixelHeight;

  /// Ukuran asli halaman dalam PDF points (72 dpi) — untuk menjaga dimensi.
  final double pointWidth;
  final double pointHeight;
}

/// Service rasterisasi PDF lintas platform.
///
/// - Web: memakai pdf.js (sudah dimuat di `web/index.html`).
/// - Native: memakai package `pdfx`.
abstract class PdfRasterService {
  /// Render seluruh halaman ke JPEG (untuk kompresi).
  ///
  /// [scale] mengontrol resolusi (1.0 ≈ 72dpi, 1.5 ≈ 108dpi).
  /// [quality] kualitas JPEG 0..1.
  static Future<List<RasterPage>> rasterizeToJpeg(
    Uint8List pdfBytes, {
    double scale = 1.5,
    double quality = 0.6,
  }) {
    return rasterizeToJpegImpl(pdfBytes, scale: scale, quality: quality);
  }

  /// Render satu halaman ke PNG (untuk preview). [pageNumber] 1-based.
  static Future<RasterPage> renderPage(
    Uint8List pdfBytes,
    int pageNumber, {
    double scale = 2.0,
  }) {
    return renderPageImpl(pdfBytes, pageNumber, scale: scale);
  }
}
