import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../recipe_import.dart' show ImportException;
import 'import_debug.dart';

/// Gemini-only multi-model fallback (kept out of the provider-agnostic
/// ByokClient). Free-tier quota is per-model, so on a 429 (rate-limited) or 503
/// (overloaded) we DON'T wait — we instantly pivot to the next model in the
/// chain. There is no pre-flight "am I rate-limited?" endpoint; the 429 itself
/// is the (instant) signal. A short in-memory cooldown remembers an exhausted
/// model so the next call skips straight to a ready one.
class GeminiFallback {
  /// Ordered free-tier model chain, best first. EDIT to match the current
  /// Gemini model ids (verify at ai.dev). Keep a known-good model last as the
  /// anchor — an unknown/unavailable id (404) transparently falls through.
  static const List<String> models = [
    'gemini-3.5-flash',
    'gemini-3.0-flash',
    'gemini-2.5-flash',
  ];

  static const Duration _maxCooldown = Duration(seconds: 60);
  static const Duration _overloadCooldown = Duration(seconds: 15);
  static const Duration _defaultCooldown = Duration(seconds: 45);

  // model id -> instant until which we deprioritize it (in-memory; clears on
  // app restart). Lets repeated imports skip a known-exhausted model.
  static final Map<String, DateTime> _coolUntil = {};

  static Future<String> generate({
    required String apiKey,
    required String system,
    required String userText,
    Uint8List? img,
    String mediaType = 'image/jpeg',
  }) async {
    final now = DateTime.now();
    final ready = <String>[];
    final cooling = <String>[];
    for (final m in models) {
      final until = _coolUntil[m];
      (until != null && until.isAfter(now) ? cooling : ready).add(m);
    }
    // ready models first (chain order), then cooling ones as a last resort.
    final order = [...ready, ...cooling];

    ImportException? last;
    for (final model in order) {
      try {
        final text = await _call(model, apiKey, system, userText, img, mediaType);
        _coolUntil.remove(model); // success clears any cooldown
        importLog('gemini ok via $model');
        return text;
      } on _RateLimited catch (e) {
        _coolUntil[model] = DateTime.now().add(e.retry);
        importLog('gemini 429 on $model → cooling ${e.retry.inSeconds}s, pivoting');
        last = ImportException('rate_limited', 'Gemini $model rate-limited');
      } on _Overloaded {
        _coolUntil[model] = DateTime.now().add(_overloadCooldown);
        importLog('gemini 503 on $model → pivoting');
        last = ImportException('provider_error', 'Gemini $model overloaded');
      } on _ModelUnavailable {
        importLog('gemini 404 on $model (bad/unavailable id) → pivoting');
        last = ImportException('provider_error', 'Gemini $model unavailable');
      }
    }
    throw last ?? ImportException('provider_error', 'No Gemini model available');
  }

  static Future<String> _call(String model, String key, String system, String userText, Uint8List? img, String mediaType) async {
    final parts = <Map<String, dynamic>>[
      {'text': userText},
      if (img != null)
        {
          'inline_data': {'mime_type': mediaType, 'data': base64Encode(img)},
        },
    ];
    final res = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );
    final code = res.statusCode;
    if (code == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final cands = (j['candidates'] as List?) ?? const [];
      if (cands.isEmpty) throw ImportException('provider_error', 'empty Gemini response');
      final partsOut = ((cands.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
      final buf = StringBuffer();
      for (final p in partsOut) {
        if (p is Map && p['text'] != null) buf.write(p['text']);
      }
      return buf.toString();
    }
    final body = res.body.length > 400 ? res.body.substring(0, 400) : res.body;
    if (code == 429) throw _RateLimited(_parseRetry(res.body));
    if (code == 503) throw _Overloaded();
    if (code == 404) throw _ModelUnavailable();
    if (code == 401 || code == 403) throw ImportException('bad_key', 'HTTP $code\n$body');
    throw ImportException('provider_error', 'HTTP $code\n$body');
  }

  // Pull the suggested wait out of a 429 body's RetryInfo (e.g. "retryDelay":
  // "27s"), capped; falls back to a sane default.
  static Duration _parseRetry(String body) {
    try {
      final j = jsonDecode(body);
      final details = (j['error']?['details'] as List?) ?? const [];
      for (final d in details) {
        if (d is Map && (d['@type']?.toString().contains('RetryInfo') ?? false)) {
          final m = RegExp(r'([0-9.]+)s').firstMatch(d['retryDelay']?.toString() ?? '');
          if (m != null) {
            final dur = Duration(milliseconds: ((double.tryParse(m.group(1)!) ?? 30) * 1000).round());
            return dur > _maxCooldown ? _maxCooldown : dur;
          }
        }
      }
    } catch (_) {}
    return _defaultCooldown;
  }
}

class _RateLimited implements Exception {
  final Duration retry;
  _RateLimited(this.retry);
}

class _Overloaded implements Exception {}

class _ModelUnavailable implements Exception {}
