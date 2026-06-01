import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../../state/app_state.dart';
import '../recipe_import.dart';
import 'byok_client.dart';
import 'import_debug.dart';
import 'ocr.dart';
import 'ondevice_ai.dart';
import 'recipe_schema.dart';

/// Which starting point the user chose in the "+" method chooser / share sheet.
enum ImportMethod { link, text, photo }

/// Orchestrates the tiered import (§2f). A connectivity-aware decision tree
/// picks which engine to use per source (Tier 0 link parser / Tier 1 on-device /
/// Tier 2 online API), honoring the user's preferred AI and falling back when an
/// engine is unavailable or fails. Always returns a reviewable [ImportResult].
class ImportEngine {
  static const _providerNames = {'claude': 'Claude', 'openai': 'ChatGPT', 'gemini': 'Gemini'};

  /// Ordered engines to try for [method], best-available first (decision tree):
  /// AI engines appear only when usable (model present / key + connection), in
  /// the user's preferred order. Links always try the rule-based parser first.
  static List<String> resolveChain(ImportMethod method, AppState app) {
    final ai = <String>[];
    if (app.preferredAI == 'online') {
      if (app.onlineAiReady) ai.add('online');
      if (app.onDeviceReady) ai.add('ondevice');
    } else {
      if (app.onDeviceReady) ai.add('ondevice');
      if (app.onlineAiReady) ai.add('online');
    }
    // Links: Tier 0 (any-site JSON-LD) first. (Phase 2 will append `ai` so an
    // unsupported URL can fold to an LLM.)
    if (method == ImportMethod.link) return ['tier0'];
    return ai;
  }

  /// The engine that will run first for [method] ('none' if nothing is usable).
  static String resolve(ImportMethod method, AppState app) {
    final chain = resolveChain(method, app);
    return chain.isEmpty ? 'none' : chain.first;
  }

  /// Human label for an engine, for the "engine used" badge and messages.
  static String engineLabel(String engine, AppState app) {
    final fr = app.lang == 'fr';
    switch (engine) {
      case 'tier0':
        return fr ? 'Niveau 0 · Règles' : 'Tier 0 · Rules';
      case 'ondevice':
        return fr ? 'Sur l\'appareil' : 'On-device';
      case 'online':
        return _providerNames[app.importProvider] ?? (fr ? 'API en ligne' : 'Online API');
      default:
        return fr ? 'Aucun moteur' : 'No engine';
    }
  }

  /// Run a SPECIFIC [engine] for [method]. Used by the sheet so it can drive the
  /// fallback chain (bump to the next tier on failure).
  static Future<ImportResult> runWith({
    required String engine,
    required ImportMethod method,
    required AppState app,
    String? url,
    String? text,
    Uint8List? imageBytes,
    String mediaType = 'image/jpeg',
  }) async {
    importLog('runWith engine=$engine method=$method online=${app.online}');
    switch (engine) {
      case 'tier0':
        final u = (url ?? '').trim();
        if (u.isEmpty) throw ImportException('empty_input');
        try {
          return await RecipeImport.importFromUrl(u);
        } on ImportException {
          rethrow;
        } catch (e) {
          importLog('Tier 0 error: $e');
          throw ImportException('provider_error', e.toString());
        }
      case 'online':
        final provider = app.importProvider;
        final key = app.importKeys[provider] ?? '';
        if (key.trim().isEmpty) throw ImportException('needs_ai');
        if (method == ImportMethod.link) throw ImportException('url_ai_pending', 'URL import via AI arrives in Phase 2');
        final raw = await ByokClient.extract(provider: provider, apiKey: key, text: text, imageBytes: imageBytes, mediaType: mediaType);
        importLog('online raw (first 300): ${raw.length > 300 ? raw.substring(0, 300) : raw}');
        return draftFromModelJson(raw, source: _sourceLabel(method));
      case 'ondevice':
        if (method == ImportMethod.link) throw ImportException('url_ai_pending', 'URL import via AI arrives in Phase 2');
        var input = text ?? '';
        if (method == ImportMethod.photo && imageBytes != null) {
          importLog('ondevice → OCR ${imageBytes.length} bytes');
          input = await Ocr.recognize(imageBytes);
        }
        if (input.trim().isEmpty) throw ImportException('empty_input', 'no text to feed the on-device model');
        final raw = await OnDeviceAi.generate(input, kImportPrompt);
        importLog('ondevice raw (first 300): ${raw.length > 300 ? raw.substring(0, 300) : raw}');
        return draftFromModelJson(raw, source: _sourceLabel(method));
      default:
        throw ImportException('needs_ai');
    }
  }

  /// Region-guided photo import: OCR each user-drawn box per element, then feed
  /// the model a clearly LABELLED text so a small model just transcribes instead
  /// of guessing the page layout. Routes to the configured AI backend.
  static Future<ImportResult> extractFromRegions({
    required AppState app,
    required Uint8List imageBytes,
    required List<Rect> ingredientBoxes,
    required List<Rect> stepBoxes,
    String? engineOverride, // force a specific AI engine (for the failure bump)
  }) async {
    final backend = engineOverride ?? resolve(ImportMethod.photo, app);
    if (backend != 'ondevice' && backend != 'online') throw ImportException('needs_ai');
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw ImportException('no_recipe', 'could not decode image');

    Future<String> ocrBoxes(List<Rect> boxes) async {
      final parts = <String>[];
      for (final b in boxes) {
        final x = (b.left * decoded.width).round().clamp(0, decoded.width - 1);
        final y = (b.top * decoded.height).round().clamp(0, decoded.height - 1);
        final w = (b.width * decoded.width).round().clamp(1, decoded.width - x);
        final h = (b.height * decoded.height).round().clamp(1, decoded.height - y);
        final crop = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
        final txt = await Ocr.recognize(Uint8List.fromList(img.encodeJpg(crop)));
        if (txt.trim().isNotEmpty) parts.add(txt.trim());
      }
      return parts.join('\n');
    }

    final ing = ingredientBoxes.isEmpty ? '' : await ocrBoxes(ingredientBoxes);
    final steps = stepBoxes.isEmpty ? '' : await ocrBoxes(stepBoxes);
    importLog('regions OCR: ingLen=${ing.length} stepsLen=${steps.length}');
    if (ing.trim().isEmpty && steps.trim().isEmpty) throw ImportException('no_recipe', 'no text recognized in the selected regions');

    if (backend == 'online') {
      // Big cloud models keep sections straight in one labelled call (cheaper).
      final provider = app.importProvider;
      final key = app.importKeys[provider] ?? '';
      if (key.trim().isEmpty) throw ImportException('needs_ai');
      final sb = StringBuffer();
      if (ing.trim().isNotEmpty) sb.write('INGRÉDIENTS:\n$ing\n\n');
      if (steps.trim().isNotEmpty) sb.write('ÉTAPES (préparation):\n$steps\n');
      final raw = await ByokClient.extract(provider: provider, apiKey: key, text: sb.toString().trim());
      return draftFromModelJson(raw, source: 'Importé d\'une photo');
    }

    // On-device: two single-purpose calls so the small model can't bleed step
    // text into ingredient notes (or vice-versa); then merge.
    Future<List<dynamic>> field(String region, String prompt, String key) async {
      if (region.trim().isEmpty) return const [];
      try {
        final raw = await OnDeviceAi.generate(region, prompt);
        importLog('regions $key raw (first 200): ${raw.length > 200 ? raw.substring(0, 200) : raw}');
        return (parseModelJsonLoose(raw)[key] as List?) ?? const [];
      } catch (e) {
        importLog('regions $key pass failed: $e');
        return const [];
      }
    }

    final ingredients = await field(ing, kPromptIngredients, 'ingredients');
    final stepList = await field(steps, kPromptSteps, 'steps');
    if (ingredients.isEmpty && stepList.isEmpty) throw ImportException('no_recipe', 'model returned nothing for the selected regions');
    final merged = {'title': '', 'ingredients': ingredients, 'steps': stepList};
    return draftFromModelJson(jsonEncode(merged), source: 'Importé d\'une photo');
  }

  static String _sourceLabel(ImportMethod method) {
    switch (method) {
      case ImportMethod.photo:
        return 'Importé d\'une photo';
      case ImportMethod.text:
        return 'Importé d\'un texte';
      case ImportMethod.link:
        return 'Recette importée d\'un lien';
    }
  }
}
