import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_raster_service.dart';

/// Hasil kompresi PDF.
class CompressResult {
  CompressResult({
    required this.bytes,
    required this.originalSize,
    required this.compressedSize,
  });

  final Uint8List bytes;
  final int originalSize;
  final int compressedSize;

  double get ratio =>
      originalSize == 0 ? 0 : (1 - compressedSize / originalSize);
  String get savedPercent =>
      '${(ratio * 100).clamp(0, 100).toStringAsFixed(0)}%';
}

/// Level kompresi yang dipilih user.
enum CompressLevel { low, medium, high }

extension CompressLevelParams on CompressLevel {
  String get label => switch (this) {
        CompressLevel.low => 'Ringan (kualitas tinggi)',
        CompressLevel.medium => 'Sedang (seimbang)',
        CompressLevel.high => 'Maksimal (ukuran terkecil)',
      };

  double get scale => switch (this) {
        CompressLevel.low => 2.0,
        CompressLevel.medium => 1.4,
        CompressLevel.high => 1.0,
      };

  double get quality => switch (this) {
        CompressLevel.low => 0.7,
        CompressLevel.medium => 0.55,
        CompressLevel.high => 0.4,
      };
}

/// Service kompresi PDF dengan rasterisasi + JPEG recompression.
///
/// Strategi: render tiap halaman menjadi JPEG (resolusi & kualitas sesuai
/// level), lalu bangun ulang PDF baru berisi image tersebut. Ini benar-benar
/// menurunkan ukuran (terutama untuk PDF berbasis scan/gambar) — berbeda dari
/// `PdfCompressionLevel.best` yang hanya mengompres stream.
class PdfCompressService {
  /// Kompres dengan rasterisasi. Mengembalikan hasil terkecil antara metode
  /// rasterisasi dan kompresi stream bawaan.
  static Future<CompressResult> compress(
    Uint8List pdfBytes, {
    CompressLevel level = CompressLevel.medium,
  }) async {
    final originalSize = pdfBytes.length;

    // 1. Coba kompresi via rasterisasi.
    Uint8List? rasterBytes;
    try {
      final pages = await PdfRasterService.rasterizeToJpeg(
        pdfBytes,
        scale: level.scale,
        quality: level.quality,
      );
      if (pages.isNotEmpty) {
        rasterBytes = await _buildPdfFromImages(pages);
      }
    } catch (_) {
      rasterBytes = null;
    }

    // 2. Kompresi stream bawaan sebagai pembanding/fallback.
    Uint8List streamBytes;
    final doc = PdfDocument(inputBytes: pdfBytes);
    doc.compressionLevel = PdfCompressionLevel.best;
    streamBytes = Uint8List.fromList(await doc.save());
    doc.dispose();

    // Pilih hasil terkecil yang masih lebih kecil dari aslinya.
    Uint8List best = streamBytes;
    if (rasterBytes != null && rasterBytes.length < best.length) {
      best = rasterBytes;
    }
    if (best.length >= originalSize) {
      // Tidak ada perbaikan — kembalikan yang terkecil yang ada.
      best = best.length <= originalSize ? best : pdfBytes;
    }

    return CompressResult(
      bytes: best,
      originalSize: originalSize,
      compressedSize: best.length,
    );
  }

  static Future<Uint8List> _buildPdfFromImages(List<RasterPage> pages) async {
    final out = PdfDocument();
    out.pageSettings.margins.all = 0;
    for (final rp in pages) {
      // Set ukuran halaman = ukuran asli (points) agar dimensi terjaga.
      out.pageSettings.size = Size(rp.pointWidth, rp.pointHeight);
      final image = PdfBitmap(rp.imageBytes);
      final page = out.pages.add();
      final size = page.getClientSize();
      page.graphics.drawImage(
        image,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }
    final bytes = Uint8List.fromList(await out.save());
    out.dispose();
    return bytes;
  }
}
