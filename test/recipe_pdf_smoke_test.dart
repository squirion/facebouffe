// Smoke test / visual harness for the glorious recipe PDF export. Renders real
// seed recipes through buildRecipePdfHtml and writes the document to
// build/recipe-pdf-sample.html so it can be eyeballed against MockUp/Recipe PDF.html.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:facebouffe/data/format.dart';
import 'package:facebouffe/data/models.dart';
import 'package:facebouffe/services/recipe_pdf_html.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a glorious recipe PDF document from seed data', () async {
    final seed = jsonDecode(await rootBundle.loadString('assets/facebouffe-seed.json')) as Map<String, dynamic>;
    final recipes = (seed['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    final tags = (seed['tags'] as List).map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    final profile = Profile.fromJson(seed['profile'] as Map<String, dynamic>);
    final tagsById = {for (final t in tags) t.id: t};
    final prefs = UnitPrefs(
      temperature: profile.temperature,
      volume: profile.volume,
      weight: profile.weight,
      keepCups: profile.keepCups,
    );
    Recipe? byId(String? id) => recipes.where((r) => r.id == id).firstOrNull;

    // seed-1 = ingredient + step sub-groups, nutrition, source; seed-3 = timer.
    final pick = [byId('seed-1')!, byId('seed-3')!];

    final html = await buildRecipePdfHtml(
      recipes: pick,
      lang: profile.language,
      prefs: prefs,
      tagsById: tagsById,
      paper: 'letter',
      images: const {}, // no photos → colored fallback heroes
      resolveRecipe: byId,
    );

    // Structural sanity checks. NB: block HTML lives inside the JSON data island,
    // so quotes are escaped — assert on unescaped substrings (class names / text).
    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('@font-face')); // fonts embedded
    expect(html, contains('data:font/ttf;base64,')); // ...as base64
    expect(html, contains('Nutrition Facts')); // nutrition facts label
    expect(html, contains('hero-fallback')); // fallback hero (no photo)
    expect(html, contains('ing-sub')); // ingredient sub-group header (Garniture/Sauce)
    expect(html, contains('step-sub')); // step sub-group header (Cuisson/…)
    expect(html, contains('Garniture')); // a real ingredient group label from seed-1
    expect(html, contains('fb-pages-data')); // paginator data island
    expect(html, contains('@page { size: Letter; margin: 0; }'));

    final out = File('build/recipe-pdf-sample.html');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(html);
    // ignore: avoid_print
    print('Wrote ${out.absolute.path} (${(html.length / 1024).round()} KB)');
  });
}
