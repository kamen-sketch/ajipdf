import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Implementasi web: trigger download lewat anchor + data URL.
Future<bool> savePdfImpl(String fileName, Uint8List bytes) async {
  final base64Data = base64Encode(bytes);
  final href = 'data:application/pdf;base64,$base64Data';
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
