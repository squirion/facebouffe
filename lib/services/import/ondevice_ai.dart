import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../recipe_import.dart' show ImportException;
import 'import_debug.dart';

/// Tier 1 on-device LLM via MediaPipe LLM Inference (native). Runs a local
/// Gemma `.task` model the user has loaded onto the device — no network, no
/// AICore allowlist. "Available" simply means a model file is present.
class OnDeviceAi {
  static const _channel = MethodChannel('facebouffe/ondevice_ai');
  static const _modelFileName = 'ondevice_llm.task';

  static Future<File> _modelFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_modelFileName');
  }

  /// Absolute path to the loaded model, or null if none is present.
  static Future<String?> modelPath() async {
    if (kIsWeb) return null;
    final f = await _modelFile();
    return await f.exists() ? f.path : null;
  }

  /// Tier 1 is available iff a model file has been loaded.
  static Future<bool> available() async => (await modelPath()) != null;

  static Future<int> modelSizeBytes() async {
    final p = await modelPath();
    return p == null ? 0 : File(p).length();
  }

  /// Copy a user-picked model file into app storage (becomes the active model).
  static Future<void> importModelFromFile(String srcPath) async {
    final dest = await _modelFile();
    await File(srcPath).copy(dest.path);
  }

  /// Stream-download a model from [url] into app storage, reporting 0..1 progress.
  static Future<void> downloadModel(String url, {void Function(double)? onProgress}) async {
    final dest = await _modelFile();
    final tmp = File('${dest.path}.part');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req);
      if (res.statusCode != 200) throw ImportException('download_failed', 'HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.close();
      await tmp.rename(dest.path);
    } finally {
      client.close();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> deleteModel() async {
    final f = await _modelFile();
    if (await f.exists()) await f.delete();
  }

  /// A short capability report from the native side (debugging only).
  static Future<String> diagnose() async {
    try {
      return await _channel.invokeMethod<String>('diagnose') ?? '(no diagnose)';
    } catch (e) {
      return 'diagnose error: $e';
    }
  }

  /// Run the local model on [text], guided by [schemaPrompt]. Returns raw JSON.
  static Future<String> generate(String text, String schemaPrompt) async {
    final mp = await modelPath();
    if (mp == null) throw ImportException('ondevice_unavailable', 'no on-device model loaded');
    importLog('on-device generate: model=$mp textLen=${text.length} promptLen=${schemaPrompt.length}');
    final String? out;
    try {
      out = await _channel.invokeMethod<String>('generate', {
        'modelPath': mp,
        'text': text,
        'prompt': schemaPrompt,
      });
    } on PlatformException catch (e) {
      final detail = '${e.code}: ${e.message}${e.details != null ? '\n${e.details}' : ''}';
      importLog('on-device generate FAILED → $detail');
      throw ImportException('ondevice', detail);
    }
    importLog('on-device generate OK: responseLen=${out?.length ?? 0}');
    if (out == null || out.trim().isEmpty) throw ImportException('ondevice', 'empty on-device response');
    return out;
  }
}
