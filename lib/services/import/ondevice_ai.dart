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

  /// Stream a picked model file into app storage in chunks (robust for multi-GB
  /// files where a plain copy of file_picker's cached temp can truncate), then
  /// unwrap it if it's a .tar.gz / .tar (Kaggle ships models wrapped).
  static Future<void> importModelFromStream(Stream<List<int>> stream, {int total = 0, void Function(double)? onProgress}) async {
    final dest = await _modelFile();
    final tmp = File('${dest.path}.part');
    final sink = tmp.openWrite();
    var received = 0;
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.close();
      await _finalizeModel(tmp);
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      await _cleanup(tmp);
      rethrow;
    }
  }

  // Turn whatever was downloaded/picked (raw [src]) into the final `.task` model
  // at the canonical path: gunzip + untar a Kaggle bundle, or use it directly.
  static Future<void> _finalizeModel(File src) async {
    final dest = await _modelFile();
    final head = await _peek(src, 6);
    final isGzip = head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b;
    // ustar magic lives at offset 257, but the cheap signal is gzip; for a bare
    // .tar we detect by extension-less header check below.
    if (isGzip) {
      final tar = File('${dest.path}.tar');
      try {
        await src.openRead().transform(gzip.decoder).pipe(tar.openWrite());
        await _extractLargestFromTar(tar, dest);
      } finally {
        await _cleanup(src);
        await _cleanup(tar);
      }
    } else if (await _looksLikeTar(src)) {
      try {
        await _extractLargestFromTar(src, dest);
      } finally {
        await _cleanup(src);
      }
    } else {
      if (await dest.exists()) await dest.delete();
      await src.rename(dest.path);
    }
    await _validateTaskBundle(dest);
  }

  static Future<List<int>> _peek(File f, int n) async {
    final raf = await f.open();
    final b = await raf.read(n);
    await raf.close();
    return b;
  }

  static Future<bool> _looksLikeTar(File f) async {
    final raf = await f.open();
    try {
      if (await f.length() < 263) return false;
      await raf.setPosition(257);
      final magic = await raf.read(5); // "ustar"
      return magic.length == 5 && magic[0] == 0x75 && magic[1] == 0x73 && magic[2] == 0x74 && magic[3] == 0x61 && magic[4] == 0x72;
    } finally {
      await raf.close();
    }
  }

  // Extract the largest regular file from an (uncompressed) tar — the model
  // bundle — streaming, so we never hold the ~1 GB payload in memory.
  static Future<void> _extractLargestFromTar(File tar, File dest) async {
    final raf = await tar.open();
    try {
      final length = await tar.length();
      var pos = 0, bestOff = -1, bestSize = 0;
      while (pos + 512 <= length) {
        await raf.setPosition(pos);
        final header = await raf.read(512);
        if (header.every((b) => b == 0)) break; // end-of-archive
        final size = _tarSize(header);
        final dataOff = pos + 512;
        if (size > bestSize) {
          bestSize = size;
          bestOff = dataOff;
        }
        pos = dataOff + ((size + 511) ~/ 512) * 512;
      }
      if (bestOff < 0 || bestSize == 0) throw ImportException('bad_model', 'tar bundle had no extractable file');
      await raf.setPosition(bestOff);
      if (await dest.exists()) await dest.delete();
      final sink = dest.openWrite();
      var remaining = bestSize;
      const chunk = 1 << 20;
      while (remaining > 0) {
        final bytes = await raf.read(remaining < chunk ? remaining : chunk);
        if (bytes.isEmpty) break;
        sink.add(bytes);
        remaining -= bytes.length;
      }
      await sink.close();
    } finally {
      await raf.close();
    }
  }

  static int _tarSize(List<int> header) {
    // size: 12 octal-ASCII bytes at offset 124
    final raw = header.sublist(124, 136);
    final s = String.fromCharCodes(raw).replaceAll('\x00', '').trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s, radix: 8) ?? 0;
  }

  static Future<void> _cleanup(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // Sanity-check the model file. Accept a `.task` ZIP bundle ("PK"), a `.bin`
  // TFLite flatbuffer ("TFL3" at offset 4), or any sufficiently large file
  // (let MediaPipe give the authoritative verdict). Only reject small junk —
  // an HTML error page from a gated download, or a truncated stub.
  static Future<void> _validateTaskBundle(File f) async {
    final raf = await f.open();
    final head = await raf.read(8);
    await raf.close();
    final size = await f.length();
    final isZip = head.length >= 4 && head[0] == 0x50 && head[1] == 0x4B && head[2] == 0x03 && head[3] == 0x04;
    final isTflite = head.length >= 8 && head[4] == 0x54 && head[5] == 0x46 && head[6] == 0x4C && head[7] == 0x33; // "TFL3"
    if (isZip) {
      // A `.task` is a ZIP; verify the End-Of-Central-Directory record is present
      // so a truncated transfer is caught here, not as a cryptic native crash.
      if (!await _hasZipEocd(f)) {
        try {
          await f.delete();
        } catch (_) {}
        throw ImportException('bad_model', 'The model ZIP is incomplete (no end-of-central-directory at $size bytes) — the file didn\'t fully download/transfer. Re-download and re-import.');
      }
      return;
    }
    if (isTflite || size > 50 * 1024 * 1024) return;
    final hex = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    try {
      await f.delete();
    } catch (_) {}
    throw ImportException('bad_model', 'This doesn\'t look like a model file. size=$size bytes, header [$hex] — likely an HTML/error page or the wrong file.');
  }

  // Look for the ZIP end-of-central-directory signature (PK\x05\x06) in the last
  // ~64 KB. Present → the archive is complete; absent → truncated/not a real zip.
  static Future<bool> _hasZipEocd(File f) async {
    final len = await f.length();
    if (len < 22) return false;
    final raf = await f.open();
    try {
      final readLen = len < 65557 ? len : 65557;
      await raf.setPosition(len - readLen);
      final tail = await raf.read(readLen);
      for (var i = tail.length - 22; i >= 0; i--) {
        if (tail[i] == 0x50 && tail[i + 1] == 0x4B && tail[i + 2] == 0x05 && tail[i + 3] == 0x06) return true;
      }
      return false;
    } finally {
      await raf.close();
    }
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
      await _finalizeModel(tmp);
    } finally {
      client.close();
      await _cleanup(tmp);
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

  // Cap the recipe text so prompt+input stays well under small models' context
  // (e.g. ekv1280); without this a long OCR result overflows the KV cache.
  static const _maxInputChars = 1400;

  static String _wrapPrompt(String template, String body) {
    switch (template) {
      case 'qwen': // ChatML
        return '<|im_start|>user\n$body<|im_end|>\n<|im_start|>assistant\n';
      case 'generic':
        return body;
      case 'gemma':
      default:
        return '<start_of_turn>user\n$body<end_of_turn>\n<start_of_turn>model\n';
    }
  }

  /// Run the local model on [text], guided by [schemaPrompt], formatted with the
  /// [template] matching the loaded model family. [maxTokens] is the model's
  /// compiled context (input+output) — must not be exceeded or the engine
  /// crashes natively. Returns raw JSON.
  static Future<String> generate(String text, String schemaPrompt, {String template = 'gemma', int maxTokens = 1280}) async {
    final mp = await modelPath();
    if (mp == null) throw ImportException('ondevice_unavailable', 'no on-device model loaded');
    final clipped = text.length > _maxInputChars ? text.substring(0, _maxInputChars) : text;
    importLog('on-device generate: model=$mp template=$template maxTokens=$maxTokens textLen=${clipped.length}/${text.length} promptLen=${schemaPrompt.length}');
    final full = _wrapPrompt(template, '$schemaPrompt\n\nRecipe input:\n$clipped');
    final String? out;
    try {
      out = await _channel.invokeMethod<String>('generate', {
        'modelPath': mp,
        'text': '',
        'prompt': full,
        'maxTokens': maxTokens,
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
