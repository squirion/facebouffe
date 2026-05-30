import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Bridge to the platform's on-device small LLM (Android Gemini Nano via the
/// Google AI Edge SDK; Apple Foundation Models on native iOS — not the web app).
/// Used by Tier 1 import to turn OCR'd / pasted text into a recipe JSON locally,
/// with no network. Gracefully reports unavailable when the device lacks it.
class OnDeviceAi {
  static const _channel = MethodChannel('facebouffe/ondevice_ai');
  static bool? _cached;

  /// Whether a usable on-device model is present (AICore + Gemini Nano, etc.).
  /// Cached after the first query.
  static Future<bool> available() async {
    if (_cached != null) return _cached!;
    if (kIsWeb) return _cached = false;
    try {
      _cached = await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      _cached = false;
    }
    return _cached!;
  }

  /// Ask the on-device model to return recipe JSON for [text], guided by
  /// [schemaPrompt]. Returns the raw model string (JSON), or throws.
  static Future<String> generate(String text, String schemaPrompt) async {
    final out = await _channel.invokeMethod<String>('generate', {
      'text': text,
      'prompt': schemaPrompt,
    });
    if (out == null || out.trim().isEmpty) {
      throw Exception('empty on-device response');
    }
    return out;
  }
}
