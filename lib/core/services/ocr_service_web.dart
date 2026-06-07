import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'ocr_service.dart';

/// Create platform-specific OCR service (web)
OcrService createOcrService() => OcrServiceWeb();

/// Web OCR via tesseract.js + pdf.js
/// Flow: PDF bytes → pdf.js render ke canvas → PNG → tesseract.js → text
class OcrServiceWeb implements OcrService {
  @override
  bool get isAvailable => true;

  @override
  List<String> get supportedLanguages => [
        'eng',
        'ind',
        'chi_sim',
        'jpn',
        'ara',
        'kor',
        'fra',
        'deu',
        'spa',
        'por'
      ];

  @override
  Future<OcrResult> recognizeFromBytes(Uint8List imageBytes,
      {String lang = 'eng'}) async {
    try {
      // Encode PDF bytes ke base64 (bukan data URL — JS function yang decode)
      final base64 = base64Encode(imageBytes);

      // Call performOCR(pdfBase64, lang, pageNum=0 → ALL pages)
      final resultStr = await _callPerformOCR(base64, lang, 0);

      final map = jsonDecode(resultStr) as Map<String, dynamic>;

      if (map['success'] == true) {
        return OcrResult(
          success: true,
          text: map['fullText'] as String? ?? '',
          confidence: 0,
        );
      } else {
        return OcrResult(
          success: false,
          error: map['error'] as String? ?? 'Unknown OCR error',
        );
      }
    } catch (e) {
      return OcrResult(success: false, error: 'OCR failed: $e');
    }
  }

  /// Call performOCR JS function and await result via DOM event
  Future<String> _callPerformOCR(String pdfBase64, String lang, int pageNum) {
    final completer = Completer<String>();

    // Inject script that calls performOCR and stores result in DOM
    final scriptId = 'ocr_script_${DateTime.now().millisecondsSinceEpoch}';
    final script = html.ScriptElement()
      ..id = scriptId
      ..text = '''
        (async function() {
          try {
            const result = await performOCR("$pdfBase64", "$lang", $pageNum);
            document.body.dataset.ocrResult = result;
          } catch(e) {
            document.body.dataset.ocrResult = JSON.stringify({success: false, error: e.toString()});
          }
          window.dispatchEvent(new Event('ocr_complete'));
        })();
      ''';

    // Listen for completion
    late html.EventListener listener;
    listener = (event) {
      html.window.removeEventListener('ocr_complete', listener);
      final result = html.document.body?.dataset['ocrResult'] ??
          '{"success":false,"error":"no result"}';
      // Clean up
      html.document.body?.dataset.remove('ocrResult');
      html.document.getElementById(scriptId)?.remove();
      if (!completer.isCompleted) completer.complete(result);
    };
    html.window.addEventListener('ocr_complete', listener);

    html.document.body!.append(script);

    // Timeout 3600 seconds (1 jam — OCR bisa sangat lama untuk dokumen besar)
    Future.delayed(const Duration(seconds: 3600), () {
      if (!completer.isCompleted) {
        html.window.removeEventListener('ocr_complete', listener);
        html.document.getElementById(scriptId)?.remove();
        completer.complete('{"success":false,"error":"OCR timeout (1 jam)"}');
      }
    });

    return completer.future;
  }
}
