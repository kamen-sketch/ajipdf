import 'dart:typed_data';

import 'package:pdfx/pdfx.dart' as pdfx;

import 'pdf_raster_service.dart';

Future<List<RasterPage>> rasterizeToJpegImpl(
  Uint8List pdfBytes, {
  double scale = 1.5,
  double quality = 0.6,
}) async {
  final doc = await pdfx.PdfDocument.openData(pdfBytes);
  final pages = <RasterPage>[];
  try {
    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final ptWidth = page.width;
      final ptHeight = page.height;
      final img = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: pdfx.PdfPageImageFormat.jpeg,
        quality: (quality * 100).round(),
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      if (img != null) {
        pages.add(RasterPage(
          imageBytes: img.bytes,
          pixelWidth: img.width ?? (ptWidth * scale).round(),
          pixelHeight: img.height ?? (ptHeight * scale).round(),
          pointWidth: ptWidth,
          pointHeight: ptHeight,
        ));
      }
    }
  } finally {
    await doc.close();
  }
  return pages;
}

Future<RasterPage> renderPageImpl(
  Uint8List pdfBytes,
  int pageNumber, {
  double scale = 2.0,
}) async {
  final doc = await pdfx.PdfDocument.openData(pdfBytes);
  try {
    final page = await doc.getPage(pageNumber);
    final ptWidth = page.width;
    final ptHeight = page.height;
    final img = await page.render(
      width: page.width * scale,
      height: page.height * scale,
      format: pdfx.PdfPageImageFormat.png,
      backgroundColor: '#FFFFFF',
    );
    await page.close();
    if (img == null) throw Exception('Render gagal');
    return RasterPage(
      imageBytes: img.bytes,
      pixelWidth: img.width ?? (ptWidth * scale).round(),
      pixelHeight: img.height ?? (ptHeight * scale).round(),
      pointWidth: ptWidth,
      pointHeight: ptHeight,
    );
  } finally {
    await doc.close();
  }
}
