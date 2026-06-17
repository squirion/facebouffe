// One-off: build the curated starter cookbook (assets/facebouffe-seed.json) from
// @seb's exported cookbook (Downloads/facebouffe-livre.json) + hand-saved hero
// photos (Downloads/seed-N.jpg). Re-runnable. Run from repo root:
//   dart run tool/build_seed.dart
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

const _downloads = r'C:\Users\polyr\Downloads';

// Selected recipes: original export id -> seed slug (selection order).
const _remap = <String, String>{
  'ea85f3b3-1630-4362-8e8f-4c73851ae356': 'seed-1', // Pâtes asiatiques porc et cachous
  '0b132b83-ba38-43b9-9c80-804b35d289e4': 'seed-2', // Burgers Surprise!
  '6e614cd4-3121-40e7-9f4c-31de9b498e23': 'seed-3', // Nutella de luxe!  (embeds seed-4)
  '09bc62aa-d9bb-458c-9ab3-8eaf99b53e35': 'seed-4', // Praliné noisette
  '88c824ad-3f07-4be7-b7d8-2edfae4092e4': 'seed-5', // Fruit Froyo
};

// Standard built-in categories kept in the starter (custom user tags dropped).
const _systemTags = {'tag-fav', 'tag-breakfast', 'tag-dinner', 'tag-dessert', 'tag-appetizer', 'tag-soup', 'tag-salad'};

void main() {
  final j = jsonDecode(File('$_downloads\\facebouffe-livre.json').readAsStringSync()) as Map<String, dynamic>;
  final linkRe = RegExp(r'\{\{link:([^}]+)\}\}');

  final selected = (j['recipes'] as List).cast<Map<String, dynamic>>().where((r) => _remap.containsKey(r['id'])).toList()
    ..sort((a, b) => _remap[a['id']]!.compareTo(_remap[b['id']]!));

  final recipes = selected.map((r) {
    final m = Map<String, dynamic>.from(r);
    m['id'] = _remap[r['id']];
    m['createdBy'] = ''; // neutral provenance for the starter set
    m['visibility'] = 'private';
    m['personal'] = {'notes': '', 'rating': 0, 'lastCooked': null, 'madeCount': 0};
    m['variantGroupId'] = null; // no multi-member variant group survives the selection
    m['tags'] = (r['tags'] as List).where(_systemTags.contains).toList();
    // remap in-description {{link:id}} tokens (drop links to unselected recipes)
    m['description'] = ((r['description'] as String?) ?? '').replaceAllMapped(linkRe, (mt) {
      final nid = _remap[mt.group(1)];
      return nid != null ? '{{link:$nid}}' : '';
    });
    m['links'] = ((r['links'] as List?) ?? []).where(_remap.containsKey).map((l) => _remap[l]).toList();
    // remap embedded sub-recipe references (recipeRef.recipeId)
    m['ingredients'] = (r['ingredients'] as List).cast<Map<String, dynamic>>().map((ing) {
      final ni = Map<String, dynamic>.from(ing);
      final rr = ing['recipeRef'];
      if (rr is Map && _remap.containsKey(rr['recipeId'])) {
        ni['recipeRef'] = Map<String, dynamic>.from(rr)..['recipeId'] = _remap[rr['recipeId']];
      }
      return ni;
    }).toList();
    return m;
  }).toList();

  final tags = (j['tags'] as List).cast<Map<String, dynamic>>().where((t) => _systemTags.contains(t['id'])).map((t) {
    final nt = Map<String, dynamic>.from(t);
    if (t['id'] == 'tag-fav') {
      nt['icon'] = 'heart';
      nt['color'] = '#D64545';
    }
    return nt;
  }).toList();

  // Inline hero photos saved as Downloads/seed-N.jpg → data: URLs (only ones
  // present), downscaled to ≤1280px / q80 to keep the bundled asset lean (same
  // treatment the app applies to user photos).
  final photos = <String, String>{};
  for (final seedId in _remap.values) {
    final f = File('$_downloads\\$seedId.jpg');
    if (!f.existsSync()) continue;
    var bytes = f.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
      bytes = img.encodeJpg(resized, quality: 80);
    }
    photos[seedId] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  final seed = {
    'schemaVersion': 1,
    'profile': j['profile'],
    'tags': tags,
    'variantGroups': <dynamic>[],
    'recipes': recipes,
    'photos': photos,
  };

  final out = const JsonEncoder.withIndent('  ').convert(seed);
  File('assets/facebouffe-seed.json').writeAsStringSync(out);
  stdout.writeln('Wrote assets/facebouffe-seed.json — ${recipes.length} recipes, ${tags.length} tags, ${photos.length} photos, ${(out.length / 1024).round()} KB');
  for (final seedId in _remap.values) {
    stdout.writeln('  ${photos.containsKey(seedId) ? "[photo]" : "[ --- ]"} $seedId');
  }
}
