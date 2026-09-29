import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device text recognition using Google ML Kit (Android/iOS only).
class OcrService {
  TextRecognizer? _recognizer;

  bool get isAvailable =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  TextRecognizer get _recognizerOrCreate {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Extract raw text from an image file. Lines come back in reading order.
  Future<String> extractText(String imagePath) async {
    if (!isAvailable) {
      throw UnsupportedError('ML Kit OCR is only available on Android/iOS');
    }
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizerOrCreate.processImage(input);
    return result.text;
  }

  void dispose() {
    // No-op on desktop/web — ML Kit has no native plugin there.
    _recognizer?.close();
    _recognizer = null;
  }
}
