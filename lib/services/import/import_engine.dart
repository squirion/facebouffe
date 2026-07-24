import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import '../../state/app_state.dart';
import '../image_ops.dart';
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
  /// [multiImage] true when 2+ photos are being imported together — only the
  /// cloud providers do real multi-image vision, so the on-device engine (OCR →
  /// small-context model) is excluded from the chain in that case.
  static List<String> resolveChain(ImportMethod method, AppState app, {bool multiImage = false}) {
    final ai = <String>[];
    if (app.preferredAI == 'online') {
      if (app.onlineAiReady) ai.add('online');
      if (!multiImage && app.onDeviceReady) ai.add('ondevice');
    } else {
      if (!multiImage && app.onDeviceReady) ai.add('ondevice');
      if (app.onlineAiReady) ai.add('online');
    }
    // Links: Tier 0 (any-site JSON-LD) first, then fold to the AI engines so an
    // unsupported URL can still be read (Phase 2 — fetch + strip + LLM).
    if (method == ImportMethod.link) return ['tier0', ...ai];
    return ai;
  }

  /// The engine that will run first for [method] ('none' if nothing is usable).
  static String resolve(ImportMethod method, AppState app, {bool multiImage = false}) {
    final chain = resolveChain(method, app, multiImage: multiImage);
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
    List<({Uint8List bytes, String type})> images = const [],
    bool allowReader = false, // on-device URL import asks before using the reader proxy
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
        var feed = text;
        if (method == ImportMethod.link) {
          final u = (url ?? '').trim();
          if (u.isEmpty) throw ImportException('empty_input');
          importLog('online ← fetching page for AI read: $u');
          // Cloud is external by definition, so the reader fallback is silent here.
          feed = await RecipeImport.fetchReadableText(u, allowReader: true);
          importLog('online page text len=${feed.length}');
        }
        final raw = await ByokClient.extract(provider: provider, apiKey: key, text: feed, images: images);
        importLog('online raw (first 300): ${raw.length > 300 ? raw.substring(0, 300) : raw}');
        return draftFromModelJson(raw, source: _sourceLabel(method));
      case 'ondevice':
        var input = text ?? '';
        if (method == ImportMethod.link) {
          final u = (url ?? '').trim();
          if (u.isEmpty) throw ImportException('empty_input');
          importLog('ondevice ← fetching page for AI read: $u');
          // Smaller cap: Phi's ~4096-token context truncates long pages anyway.
          // allowReader is gated so the UI can confirm before the URL leaves the device.
          input = await RecipeImport.fetchReadableText(u, maxChars: 8000, allowReader: allowReader);
        } else if (method == ImportMethod.photo && images.isNotEmpty) {
          // On-device has no vision: OCR each page to text and join. Multi-image
          // normally routes to the cloud (resolveChain), so this is usually one page.
          final pages = <String>[];
          for (final im in images) {
            importLog('ondevice → OCR ${im.bytes.length} bytes');
            pages.add(await Ocr.recognize(im.bytes));
          }
          input = pages.join('\n\n--- page ---\n\n');
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
    // Decode + crop off the UI isolate; OCR stays here (MLKit platform channel).
    final crops = await cropRegions(
      imageBytes,
      [for (final b in ingredientBoxes) (b.left, b.top, b.width, b.height)],
      [for (final b in stepBoxes) (b.left, b.top, b.width, b.height)],
    );
    if (crops == null) throw ImportException('no_recipe', 'could not decode image');

    Future<String> ocrCrops(List<Uint8List> jpegs) async {
      final parts = <String>[];
      for (final jpeg in jpegs) {
        final txt = await Ocr.recognize(jpeg);
        if (txt.trim().isNotEmpty) parts.add(txt.trim());
      }
      return parts.join('\n');
    }

    final ing = await ocrCrops(crops.ing);
    final steps = await ocrCrops(crops.steps);
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
