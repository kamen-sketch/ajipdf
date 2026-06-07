import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'ocr_service_web.dart' if (dart.library.io) 'ocr_service_native.dart';

/// Hasil OCR
class OcrResult {
  final bool success;
  final String text;
  final double confidence;
  final String? error;

  const OcrResult({
    required this.success,
    this.text = '',
    this.confidence = 0,
    this.error,
  });
}

/// OCR Service — cross platform
/// Web: tesseract.js (via JS interop)
/// Native: google_mlkit_text_recognition
abstract class OcrService {
  /// Singleton factory — returns platform-specific implementation
  factory OcrService() => createOcrService();

  /// Perform OCR on image bytes
  /// [imageBytes] — PNG/JPEG image bytes
  /// [lang] — language code: 'eng', 'ind', 'chi_sim', 'jpn', 'ara'
  Future<OcrResult> recognizeFromBytes(Uint8List imageBytes,
      {String lang = 'eng'});

  /// Check if OCR is available on this platform
  bool get isAvailable;

  /// Supported languages
  List<String> get supportedLanguages;
}
