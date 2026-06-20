import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../recipe_import.dart' show ImportException;
import 'gemini_fallback.dart';
import 'recipe_schema.dart';

/// Tier 2 — "bring your own key" cloud LLM extraction. Sends recipe input
/// (text and/or image) plus the strict schema prompt to the user's own
/// provider account and returns the raw JSON string the model produced.
///
/// The recipe content is sent to the chosen provider under the user's own key;
/// nothing is sent anywhere else, and the key is only used here.
class ByokClient {
  // Cheap, fast, multimodal models per provider. Centralized so they're easy
  // to bump as providers rev their lineups.
  // Claude/OpenAI use a single model each; Gemini's model chain + rate-limit
  // fallback lives in gemini_fallback.dart.
  static const _models = {
    'claude': 'claude-haiku-4-5-20251001',
    'openai': 'gpt-4o-mini',
  };

  // Headroom for a long multi-page recipe's JSON (Gemini already uses 8192).
  static const _maxTokens = 8192;

  /// Returns raw model output (expected to be JSON). [images] (each with its own
  /// media type) drive the multimodal path — multiple pages/photos of one recipe
  /// are sent together; [text] is appended to the instruction.
  static Future<String> extract({
    required String provider,
    required String apiKey,
    String? text,
    List<({Uint8List bytes, String type})> images = const [],
  }) async {
    if (images.isEmpty && (text == null || text.trim().isEmpty)) {
      throw ImportException('empty_input');
    }
    final userText = _userText(text, images.length);
    switch (provider) {
      case 'claude':
        return _anthropic(apiKey, kImportPrompt, userText, images);
      case 'openai':
        return _openai(apiKey, kImportPrompt, userText, images);
      case 'gemini':
        return _gemini(apiKey, kImportPrompt, userText, images);
      default:
        throw ImportException('bad_provider');
    }
  }

  /// Invent a brand-new recipe from free-form [request] constraints (the
  /// "I'm feeling adventurous!" generator). Same strict-JSON contract as
  /// [extract]; text-only, no image.
  static Future<String> generate({required String provider, required String apiKey, required String request, String system = kAdventurePrompt, void Function(String model)? onModel}) {
    switch (provider) {
      case 'claude':
        onModel?.call(_models['claude']!);
        return _anthropic(apiKey, system, request, const []);
      case 'openai':
        onModel?.call(_models['openai']!);
        return _openai(apiKey, system, request, const []);
      case 'gemini':
        return GeminiFallback.generate(apiKey: apiKey, system: system, userText: request, onAttempt: onModel);
      default:
        throw ImportException('bad_provider');
    }
  }

  static String _userText(String? text, int imageCount) {
    if (text != null && text.trim().isNotEmpty) return 'Recipe input:\n\n${text.trim()}';
    if (imageCount > 1) {
      return 'The $imageCount attached images are pages/photos of a SINGLE recipe. Combine them into one recipe.';
    }
    return 'Extract the recipe from the attached image.';
  }

  static Never _fail(http.Response r) {
    final body = r.body.length > 400 ? r.body.substring(0, 400) : r.body;
    final detail = 'HTTP ${r.statusCode}\n$body';
    if (r.statusCode == 401 || r.statusCode == 403) throw ImportException('bad_key', detail);
    if (r.statusCode == 429) throw ImportException('rate_limited', detail);
    throw ImportException('provider_error', detail);
  }

  // ── Anthropic Messages API ──
  static Future<String> _anthropic(String key, String system, String userText, List<({Uint8List bytes, String type})> images) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': userText},
      for (final im in images)
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': im.type, 'data': base64Encode(im.bytes)},
        },
    ];
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _models['claude'],
        'max_tokens': _maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );
    if (res.statusCode != 200) _fail(res);
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final parts = (j['content'] as List?) ?? const [];
    final buf = StringBuffer();
    for (final p in parts) {
      if (p is Map && p['type'] == 'text') buf.write(p['text']);
    }
    return buf.toString();
  }

  // ── OpenAI Chat Completions ──
  static Future<String> _openai(String key, String system, String userText, List<({Uint8List bytes, String type})> images) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': userText},
      for (final im in images)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:${im.type};base64,${base64Encode(im.bytes)}'},
        },
    ];
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer $key'},
      body: jsonEncode({
        'model': _models['openai'],
        'max_tokens': _maxTokens,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': content},
        ],
      }),
    );
    if (res.statusCode != 200) _fail(res);
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = (j['choices'] as List?) ?? const [];
    if (choices.isEmpty) throw ImportException('provider_error');
    return (choices.first as Map)['message']?['content']?.toString() ?? '';
  }

  // ── Google Gemini — delegates to the multi-model fallback (gemini_fallback.dart) ──
  static Future<String> _gemini(String key, String system, String userText, List<({Uint8List bytes, String type})> images) =>
      GeminiFallback.generate(apiKey: key, system: system, userText: userText, images: images);

  /// Lightweight key check used by the "Test key" button — a tiny request that
  /// only needs to authenticate, not produce a recipe.
  static Future<bool> testKey(String provider, String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final out = await extract(provider: provider, apiKey: apiKey, text: 'ping — reply with {"title":"ok","ingredients":[],"steps":[]}');
      return out.trim().isNotEmpty;
    } on ImportException catch (e) {
      if (e.code == 'bad_key') return false;
      // Any non-auth error (rate limit, transient) still implies the key authenticated.
      return e.code != 'bad_provider';
    } catch (_) {
      return false;
    }
  }
}
