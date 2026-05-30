import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../recipe_import.dart' show ImportException;
import 'import_debug.dart';

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
    } catch (e) {
      importLog('available() channel error: $e');
      _cached = false;
    }
    importLog('on-device available = $_cached');
    return _cached!;
  }

  /// A multiline capability report from the native side (debugging only).
  static Future<String> diagnose() async {
    try {
      return await _channel.invokeMethod<String>('diagnose') ?? '(no diagnose)';
    } catch (e) {
      return 'diagnose error: $e';
    }
  }

  /// Ask the on-device model to return recipe JSON for [text], guided by
  /// [schemaPrompt]. Returns the raw model string (JSON), or throws.
  static Future<String> generate(String text, String schemaPrompt) async {
    importLog('on-device generate: textLen=${text.length} promptLen=${schemaPrompt.length}');
    final String? out;
    try {
      out = await _channel.invokeMethod<String>('generate', {
        'text': text,
        'prompt': schemaPrompt,
      });
    } on PlatformException catch (e) {
      final detail = '${e.code}: ${e.message}${e.details != null ? '\n${e.details}' : ''}';
      importLog('on-device generate FAILED → $detail');
      // AICore declines to serve the LLM feature to this (sideloaded / non-
      // allowlisted) app or un-provisioned device — distinct from a real error.
      final blob = '${e.message ?? ''} ${e.details ?? ''}';
      final unavailable = blob.contains('NOT_AVAILABLE') || blob.contains('feature not found') || blob.contains('FEATURE_NOT_FOUND');
      throw ImportException(unavailable ? 'ondevice_unavailable' : 'ondevice', detail);
    }
    importLog('on-device generate OK: responseLen=${out?.length ?? 0}');
    if (out == null || out.trim().isEmpty) {
      throw ImportException('ondevice', 'empty on-device response');
    }
    return out;
  }
}
