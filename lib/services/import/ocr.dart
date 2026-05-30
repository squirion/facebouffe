import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR (Google ML Kit Text Recognition) — free, local, no network.
/// Turns a recipe photo/screenshot into plain text for Tier 1 import.
class Ocr {
  /// Recognize text in [bytes] (a JPEG/PNG). Writes a temp file because ML Kit
  /// reads from a file path. Returns the extracted text (may be empty).
  static Future<String> recognize(Uint8List bytes) async {
    if (kIsWeb) throw UnsupportedError('OCR unavailable on web');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      return result.text;
    } finally {
      await recognizer.close();
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
