import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'pdf_raster_service.dart';

Future<List<RasterPage>> rasterizeToJpegImpl(
  Uint8List pdfBytes, {
  double scale = 1.5,
  double quality = 0.6,
}) async {
  final base64 = base64Encode(pdfBytes);
  final jsonStr = await _callJs(
    'rasterizePdfPages("$base64", $scale, $quality)',
    'raster_done',
    'rasterResult',
  );
  final result = jsonDecode(jsonStr) as Map<String, dynamic>;
  if (result['success'] != true) {
    throw Exception(result['error'] ?? 'Rasterisasi gagal');
  }
  return (result['pages'] as List).map((p) {
    final m = Map<String, dynamic>.from(p as Map);
    return RasterPage(
      imageBytes: base64Decode(m['jpegBase64'] as String),
      pixelWidth: (m['width'] as num).toInt(),
      pixelHeight: (m['height'] as num).toInt(),
      pointWidth: (m['ptWidth'] as num).toDouble(),
      pointHeight: (m['ptHeight'] as num).toDouble(),
    );
  }).toList();
}

Future<RasterPage> renderPageImpl(
  Uint8List pdfBytes,
  int pageNumber, {
  double scale = 2.0,
}) async {
  final base64 = base64Encode(pdfBytes);
  final jsonStr = await _callJs(
    'renderPdfPage("$base64", $pageNumber, $scale)',
    'render_done',
    'renderResult',
  );
  final result = jsonDecode(jsonStr) as Map<String, dynamic>;
  if (result['success'] != true) {
    throw Exception(result['error'] ?? 'Render gagal');
  }
  return RasterPage(
    imageBytes: base64Decode(result['pngBase64'] as String),
    pixelWidth: (result['width'] as num).toInt(),
    pixelHeight: (result['height'] as num).toInt(),
    pointWidth: (result['ptWidth'] as num).toDouble(),
    pointHeight: (result['ptHeight'] as num).toDouble(),
  );
}

/// Memanggil fungsi JS async (mengembalikan Promise<String>) lewat injeksi
/// script + DOM event, mengikuti pola yang dipakai OCR service.
Future<String> _callJs(String jsCall, String eventName, String datasetKey) {
  final completer = Completer<String>();
  final scriptId = 'raster_${DateTime.now().microsecondsSinceEpoch}';

  final script = html.ScriptElement()
    ..id = scriptId
    ..text = '''
      (async function() {
        try {
          const result = await $jsCall;
          document.body.dataset.$datasetKey = result;
        } catch(e) {
          document.body.dataset.$datasetKey = JSON.stringify({success:false,error:e.toString()});
        }
        window.dispatchEvent(new Event('$eventName'));
      })();
    ''';

  late html.EventListener listener;
  listener = (event) {
    html.window.removeEventListener(eventName, listener);
    final result = html.document.body?.dataset[datasetKey] ??
        '{"success":false,"error":"no result"}';
    html.document.body?.dataset.remove(datasetKey);
    html.document.getElementById(scriptId)?.remove();
    if (!completer.isCompleted) completer.complete(result);
  };
  html.window.addEventListener(eventName, listener);
  html.document.body!.append(script);

  // Timeout 5 menit untuk dokumen besar.
  Future.delayed(const Duration(seconds: 300), () {
    if (!completer.isCompleted) {
      html.window.removeEventListener(eventName, listener);
      html.document.getElementById(scriptId)?.remove();
      completer.complete('{"success":false,"error":"Timeout rasterisasi"}');
    }
  });

  return completer.future;
}
