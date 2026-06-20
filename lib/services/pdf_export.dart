import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'recipe_pdf_html.dart';
import 'recipe_pdf_print.dart';

/// Renders one or more recipes to a glorious, print-ready PDF — the editorial
/// "cookbook page" look — and opens the system print/save-to-PDF flow. The
/// document is built as a self-contained HTML page (recipe_pdf_html.dart) and
/// rendered by a real browser engine (recipe_pdf_print.dart): identical output
/// on web and Android, in the user's current language + units.
Future<void> exportRecipesPdf(BuildContext context, List<Recipe> recipes) async {
  if (recipes.isEmpty) return;
  final app = context.read<AppState>();

  // Resolve every recipe's hero/gallery/step images to embeddable sources
  // (data: URIs on native, direct URLs on web) before building the HTML.
  final images = <String, ResolvedImages>{};
  for (final r in recipes) {
    final hero = await _resolveImg(app, app.recipePhotos[r.id]);
    final gallery = <String>[];
    for (final gp in app.galleryOf(r.id)) {
      final g = await _resolveImg(app, gp);
      if (g != null) gallery.add(g);
    }
    final steps = <String?>[for (final s in r.steps) await _resolveImg(app, s.image)];
    images[r.id] = ResolvedImages(hero: hero, gallery: gallery, steps: steps);
  }

  final html = await buildRecipePdfHtml(
    recipes: recipes,
    lang: app.lang,
    prefs: app.prefs,
    tagsById: app.tagsById,
    paper: app.profile.pdfPaper,
    images: images,
    resolveRecipe: app.getRecipe,
  );

  await printRecipeHtml(html, docName: recipes.length == 1 ? recipes.first.title : 'facebouffe');
}

/// Turns a stored image path into a value usable as an `<img src>` in the export
/// HTML: an existing `data:` URI as-is, otherwise embedded bytes as a base64
/// data URI; on web, a non-readable path (signed URL) is used directly. Returns
/// null when there's no usable image (→ colored fallback / omitted).
Future<String?> _resolveImg(AppState app, String? path) async {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) return path;
  final bytes = await app.readImageBytes(path);
  if (bytes != null) return 'data:${_sniffMime(bytes)};base64,${base64Encode(bytes)}';
  if (kIsWeb) return path; // signed URL — the browser fetches it directly
  return null;
}

String _sniffMime(Uint8List b) {
  if (b.length >= 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return 'image/webp';
  if (b.length >= 4 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image/gif';
  return 'image/jpeg';
}
