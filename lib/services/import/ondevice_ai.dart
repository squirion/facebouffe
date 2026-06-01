import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../recipe_import.dart' show ImportException;
import 'import_debug.dart';

/// Progress/state of the one-time on-device model download.
class ModelDownloadStatus {
  final String state; // none | running | done | failed
  final int downloaded;
  final int total;
  final String? reason;
  const ModelDownloadStatus(this.state, this.downloaded, this.total, this.reason);

  double? get progress => total > 0 ? downloaded / total : null;
  bool get isRunning => state == 'running';
  bool get isDone => state == 'done';
  bool get isFailed => state == 'failed';
}

/// Tier 1 on-device LLM. One hardcoded model (Phi-4-mini-instruct, ekv4096,
/// ungated MIT) downloaded once via Android DownloadManager (robust to
/// backgrounding / screen-lock / doze) and run locally with MediaPipe.
class OnDeviceAi {
  static const _channel = MethodChannel('facebouffe/ondevice_ai');

  /// Direct, ungated download of the LiteRT-community Phi-4-mini .task (~3.9 GB).
  static const phiUrl =
      'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.task?download=true';
  static const _maxTokens = 4096; // Phi model's compiled context (ekv4096)
  static const _maxInputChars = 8000; // leave room for the JSON output within 4096 tokens

  /// True once the model file is present.
  static Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('ready') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startDownload() async {
    await _channel.invokeMethod('startDownload', {'url': phiUrl});
  }

  static Future<void> cancelDownload() async {
    try {
      await _channel.invokeMethod('cancelDownload');
    } catch (_) {}
  }

  static Future<void> deleteModel() async {
    try {
      await _channel.invokeMethod('deleteModel');
    } catch (_) {}
  }

  static Future<ModelDownloadStatus> downloadStatus() async {
    try {
      final m = (await _channel.invokeMethod<Map>('downloadStatus')) ?? const {};
      return ModelDownloadStatus(
        m['state'] as String? ?? 'none',
        (m['downloaded'] as num?)?.toInt() ?? 0,
        (m['total'] as num?)?.toInt() ?? 0,
        m['reason'] as String?,
      );
    } catch (e) {
      return ModelDownloadStatus('failed', 0, 0, '$e');
    }
  }

  // Phi-3 / Phi-4-mini chat template.
  static String _wrap(String body) => '<|user|>\n$body<|end|>\n<|assistant|>\n';

  /// Run the local model on [text], guided by [schemaPrompt]. Returns raw JSON.
  static Future<String> generate(String text, String schemaPrompt) async {
    final clipped = text.length > _maxInputChars ? text.substring(0, _maxInputChars) : text;
    importLog('on-device generate: textLen=${clipped.length}/${text.length} promptLen=${schemaPrompt.length}');
    final full = _wrap('$schemaPrompt\n\nRecipe input:\n$clipped');
    final String? out;
    try {
      out = await _channel.invokeMethod<String>('generate', {'text': '', 'prompt': full, 'maxTokens': _maxTokens});
    } on PlatformException catch (e) {
      final detail = '${e.code}: ${e.message}${e.details != null ? '\n${e.details}' : ''}';
      importLog('on-device generate FAILED → $detail');
      throw ImportException(e.code == 'no_model' ? 'ondevice_unavailable' : 'ondevice', detail);
    }
    importLog('on-device generate OK: responseLen=${out?.length ?? 0}');
    if (out == null || out.trim().isEmpty) throw ImportException('ondevice', 'empty on-device response');
    return out;
  }
}
