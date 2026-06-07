import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Implementasi web: trigger download lewat anchor element.
Future<bool> savePdfImpl(String fileName, Uint8List bytes) async {
  final base64Data = base64Encode(bytes);
  final href = 'data:application/pdf;base64,$base64Data';
  final anchor = html.AnchorElement(href: href)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
