import 'dart:typed_data';

import 'pdf_raster_service.dart';

Future<List<RasterPage>> rasterizeToJpegImpl(
  Uint8List pdfBytes, {
  double scale = 1.5,
  double quality = 0.6,
}) async {
  throw UnsupportedError('Rasterisasi tidak didukung di platform ini.');
}

Future<RasterPage> renderPageImpl(
  Uint8List pdfBytes,
  int pageNumber, {
  double scale = 2.0,
}) async {
  throw UnsupportedError('Rasterisasi tidak didukung di platform ini.');
}
