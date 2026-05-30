import 'dart:typed_data';

import '../../state/app_state.dart';
import '../recipe_import.dart';
import 'byok_client.dart';
import 'ocr.dart';
import 'ondevice_ai.dart';
import 'recipe_schema.dart';

/// Which starting point the user chose in the "+" method chooser / share sheet.
enum ImportMethod { link, text, photo }

/// Orchestrates the tiered import (§2f): Tier 0 structured parse for links,
/// else the configured engine (Tier 1 on-device or Tier 2 BYOK). Always returns
/// a reviewable [ImportResult] draft — the caller opens the editor; nothing is
/// saved here.
class ImportEngine {
  /// The tier that will actually run for [method] given the app config —
  /// used for the live "Tier N" badge in the import sheet.
  static String tierFor(ImportMethod method, AppState app) {
    if (method == ImportMethod.link) return 'tier0';
    return app.effectiveBackend; // tier0 | ondevice | byok
  }

  static Future<ImportResult> run({
    required ImportMethod method,
    required AppState app,
    String? url,
    String? text,
    Uint8List? imageBytes,
    String mediaType = 'image/jpeg',
  }) async {
    if (method == ImportMethod.link) {
      final u = (url ?? '').trim();
      if (u.isEmpty) throw ImportException('empty_input');
      return RecipeImport.importFromUrl(u); // Tier 0 — JSON-LD, zero cost
    }

    final backend = app.effectiveBackend;
    if (backend == 'byok') {
      final provider = app.importProvider;
      final key = app.importKeys[provider] ?? '';
      if (key.trim().isEmpty) throw ImportException('needs_ai');
      final raw = await ByokClient.extract(
        provider: provider,
        apiKey: key,
        text: text,
        imageBytes: imageBytes,
        mediaType: mediaType,
      );
      return draftFromModelJson(raw, source: _sourceLabel(method));
    }

    if (backend == 'ondevice') {
      // On-device works on text; for photos we OCR first, then prompt locally.
      var input = text ?? '';
      if (method == ImportMethod.photo && imageBytes != null) {
        input = await Ocr.recognize(imageBytes);
      }
      if (input.trim().isEmpty) throw ImportException('empty_input');
      final raw = await OnDeviceAi.generate(input, kImportPrompt);
      return draftFromModelJson(raw, source: _sourceLabel(method));
    }

    // No AI tier available (tier0 can't handle free text / photos).
    throw ImportException('needs_ai');
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
