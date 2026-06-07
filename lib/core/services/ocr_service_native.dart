import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_service.dart';

/// Create platform-specific OCR service (native iOS/Android)
OcrService createOcrService() => OcrServiceNative();

/// Native implementation using google_mlkit_text_recognition
class OcrServiceNative implements OcrService {
  @override
  bool get isAvailable => true;

  @override
  List<String> get supportedLanguages => [
        'eng', // English (latin)
        'ind', // Indonesian (latin)
        'chi_sim', // Chinese
        'jpn', // Japanese
        'kor', // Korean
      ];

  @override
  Future<OcrResult> recognizeFromBytes(Uint8List imageBytes,
      {String lang = 'eng'}) async {
    try {
      final script = _langToScript(lang);
      final textRecognizer = TextRecognizer(script: script);

      try {
        final inputImage = InputImage.fromBytes(
          bytes: imageBytes,
          metadata: InputImageMetadata(
            size: const Size(595, 842), // A4
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: 595,
          ),
        );

        final recognizedText = await textRecognizer.processImage(inputImage);

        final buffer = StringBuffer();
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            buffer.writeln(line.text);
          }
          buffer.writeln();
        }

        final text = buffer.toString().trim();
        return OcrResult(
          success: true,
          text: text.isEmpty ? 'No text found.' : text,
          confidence: 0.9, // ML Kit doesn't expose confidence per-result
        );
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      return OcrResult(success: false, error: e.toString());
    }
  }

  TextRecognitionScript _langToScript(String lang) {
    return switch (lang) {
      'chi_sim' => TextRecognitionScript.chinese,
      'jpn' => TextRecognitionScript.japanese,
      'kor' => TextRecognitionScript.korean,
      _ => TextRecognitionScript.latin,
    };
  }
}
