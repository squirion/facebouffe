import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';

/// Thrown when an import can't be completed (network blocked, no recipe data…).
class ImportException implements Exception {
  final String code;
  ImportException(this.code);
}

class ImportResult {
  final Recipe recipe;
  final List<String> suggestedTags;
  final String? heroImageUrl;
  ImportResult(this.recipe, this.suggestedTags, this.heroImageUrl);
}

/// Imports a recipe from a supported website by parsing its embedded
/// schema.org/Recipe JSON-LD. Ported from ricardo_to_facebouffe.py.
/// Currently supports ricardocuisine.com.
class RecipeImport {
  static const _supportedHosts = ['ricardocuisine.com'];

  static bool isSupported(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    return _supportedHosts.any((h) => host == h || host.endsWith('.$h'));
  }

  static Future<ImportResult> importFromUrl(String url) async {
    final html = await _fetch(url.trim());
    return parseHtml(url.trim(), html);
  }

  /// Parse already-fetched HTML (no network) — also the unit-test seam.
  static ImportResult parseHtml(String url, String html) {
    final recipe = _findRecipeJsonLd(html);
    if (recipe == null) throw ImportException('no_recipe');
    return _build(url.trim(), recipe);
  }

  static Future<String> _fetch(String url) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse(url), headers: {
        // A realistic browser UA gives the best chance past bot protection.
        // (On web the browser sets its own UA and CORS may block the read.)
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; SM-S926) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-CA,fr;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ImportException('network');
    }
    if (res.statusCode != 200) throw ImportException('http_${res.statusCode}');
    return res.body;
  }

  // ── JSON-LD extraction ──
  static Map<String, dynamic>? _findRecipeJsonLd(String html) {
    final re = RegExp(r'''<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>''',
        dotAll: true, caseSensitive: false);
    for (final m in re.allMatches(html)) {
      dynamic data;
      try {
        data = jsonDecode(m.group(1)!.trim());
      } catch (_) {
        continue;
      }
      for (final obj in _iterObjects(data)) {
        final t = obj['@type'];
        final types = t is List ? t : [t];
        if (types.contains('Recipe')) return Map<String, dynamic>.from(obj);
      }
    }
    return null;
  }

  static Iterable<Map> _iterObjects(dynamic data) sync* {
    if (data is List) {
      for (final i in data) {
        yield* _iterObjects(i);
      }
    } else if (data is Map) {
      if (data.containsKey('@graph')) yield* _iterObjects(data['@graph']);
      yield data;
    }
  }

  static List<String> _asTextList(dynamic value) {
    final out = <String>[];
    if (value == null) return out;
    if (value is String) return [value];
    if (value is List) {
      for (final item in value) {
        if (item is String) {
          out.add(item);
        } else if (item is Map) {
          if (item['@type'] == 'HowToSection') {
            for (final sub in (item['itemListElement'] as List? ?? [])) {
              if (sub is Map) {
                out.add((sub['text'] ?? '').toString());
              } else if (sub is String) {
                out.add(sub);
              }
            }
          } else {
            out.add((item['text'] ?? '').toString());
          }
        }
      }
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  // ── build Facebouffe recipe ──
  static ImportResult _build(String url, Map<String, dynamic> r) {
    final now = DateTime.now().toUtc().toIso8601String();

    String createdBy = 'Ricardo';
    final author = r['author'];
    if (author is Map) {
      createdBy = (author['name'] ?? 'Ricardo').toString();
    } else if (author is List && author.isNotEmpty) {
      final a = author.first;
      createdBy = a is Map ? (a['name'] ?? 'Ricardo').toString() : a.toString();
    } else if (author is String && author.isNotEmpty) {
      createdBy = author;
    }

    final canonical = (r['url'] ?? url).toString();
    final source = 'Ricardo (ricardocuisine.com) — $canonical';

    var yieldVal = r['recipeYield'];
    if (yieldVal is List) yieldVal = yieldVal.isNotEmpty ? yieldVal.first : null;
    int servings = 4;
    if (yieldVal != null) {
      final m = RegExp(r'\d+').firstMatch(yieldVal.toString());
      if (m != null) servings = int.parse(m.group(0)!);
    }

    final prep = _isoToMin(r['prepTime']?.toString()) ?? 0;
    final cook = _isoToMin(r['cookTime']?.toString()) ?? 0;

    String? image;
    final img0 = r['image'];
    if (img0 is Map) {
      image = img0['url']?.toString();
    } else if (img0 is List && img0.isNotEmpty) {
      final f = img0.first;
      image = f is Map ? f['url']?.toString() : f.toString();
    } else if (img0 is String) {
      image = img0;
    }

    final ingredients = _asTextList(r['recipeIngredient']).map((l) => _parseIngredient(l)).toList();
    final steps = _asTextList(r['recipeInstructions']).map((t) => Step(text: _tokenizeTemps(t))).toList();

    final cats = r['recipeCategory'];
    final catList = cats is String ? [cats] : (cats is List ? cats : []);
    final kws = r['keywords'];
    final kwList = kws is String ? kws.split(',').map((e) => e.trim()).toList() : (kws is List ? kws : []);
    final (tagIds, suggested) = _mapTags(catList, kwList);

    final recipe = Recipe(
      id: '',
      title: (r['name'] ?? '').toString().trim(),
      createdBy: createdBy,
      dateAdded: now,
      dateModified: now,
      source: source,
      heroImage: null, // actual photo is downloaded into the draft separately
      description: (r['description'] ?? '').toString().trim(),
      servings: servings,
      prepTimeMinutes: prep,
      cookTimeMinutes: cook,
      tags: tagIds,
      ingredients: ingredients,
      steps: steps,
    );
    return ImportResult(recipe, suggested, image);
  }

  // ── durations ──
  static int? _isoToMin(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^P(?:T)?(?:(\d+)H)?(?:(\d+)M)?$').firstMatch(s.trim());
    if (m == null || (m.group(1) == null && m.group(2) == null)) return null;
    return int.parse(m.group(1) ?? '0') * 60 + int.parse(m.group(2) ?? '0');
  }

  // ── temperatures → tokens ──
  static String _tokenizeTemps(String input) {
    var t = input;
    t = t.replaceAllMapped(RegExp(r'\d+\s*°\s*F\s*\(\s*(\d+)\s*°\s*C\s*\)', caseSensitive: false), (m) => '{{temp:${m.group(1)}:c}}');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*°\s*C\s*\(\s*\d+\s*°\s*F\s*\)', caseSensitive: false), (m) => '{{temp:${m.group(1)}:c}}');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*°\s*C\b', caseSensitive: false), (m) => '{{temp:${m.group(1)}:c}}');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*°\s*F\b', caseSensitive: false), (m) => '{{temp:${m.group(1)}:f}}');
    return t;
  }

  // ── quantity / unit / ingredient parsing ──
  static const Map<String, double> _unicodeFractions = {
    '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75,
    '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
    '⅙': 1 / 6, '⅚': 5 / 6, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static num _round4(num n) => (n * 10000).round() / 10000;

  static (num?, String) _parseQuantity(String input) {
    var text = input.trim();
    _unicodeFractions.forEach((ch, val) {
      if (text.contains(ch)) text = text.replaceAll(ch, ' ${val}frac');
    });
    text = text.trim();
    var m = RegExp(r'^(\d+)\s+(\d*\.?\d+)frac').firstMatch(text);
    if (m != null) {
      return (_round4(int.parse(m.group(1)!) + double.parse(m.group(2)!)), text.substring(m.end).trim());
    }
    m = RegExp(r'^(\d*\.?\d+)frac').firstMatch(text);
    if (m != null) {
      return (_round4(double.parse(m.group(1)!)), text.substring(m.end).trim());
    }
    m = RegExp(r'^(?:(\d+)\s+)?(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (m != null) {
      final whole = m.group(1) != null ? int.parse(m.group(1)!) : 0;
      return (_round4(whole + int.parse(m.group(2)!) / int.parse(m.group(3)!)), text.substring(m.end).trim());
    }
    m = RegExp(r'^(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (m != null) {
      return (_round4(double.parse(m.group(1)!.replaceAll(',', '.'))), text.substring(m.end).trim());
    }
    return (null, text);
  }

  // longer/multiword units first
  static const List<List<String>> _unitPatterns = [
    [r'cuill[eè]res?\s+[aà]\s+soupe|c\.\s*[aà]\s*s\.?|c\.\s*[aà]\s*soupe|c\.?\s*soupe', 'tbsp'],
    [r'cuill[eè]res?\s+[aà]\s+(?:th[eé]|caf[eé])|c\.\s*[aà]\s*t\.?|c\.\s*[aà]\s*(?:th[eé]|caf[eé])', 'tsp'],
    [r'tasses?', 'cup'],
    [r'millilitres?|ml\b', 'ml'],
    [r'litres?|l\b', 'l'],
    [r'kilogrammes?|kg\b', 'kg'],
    [r'grammes?|g\b', 'g'],
    [r'livres?|lb\b', 'lb'],
    [r'onces?|oz\b', 'oz'],
    [r'pinc[eé]es?', 'pinch'],
  ];

  static (String?, String) _parseUnit(String input) {
    final text = input.trim();
    for (final p in _unitPatterns) {
      final m = RegExp('^(?:${p[0]})\\b\\.?', caseSensitive: false).firstMatch(text);
      if (m != null) return (p[1], text.substring(m.end).trim());
    }
    return (null, text);
  }

  static (String?, num?, String?, String) _parseMetricParen(String text) {
    for (final m in RegExp(r'\(([^)]*)\)').allMatches(text)) {
      final inner = m.group(1)!.trim();
      final (q, rest) = _parseQuantity(inner);
      final (u, _) = _parseUnit(rest);
      if (q == null && u == null) continue;
      final note = inner.replaceAllMapped(RegExp(r'(\d)\s*([a-zA-Zà])'), (mm) => '${mm.group(1)} ${mm.group(2)}');
      final cleaned = (text.substring(0, m.start) + text.substring(m.end)).trim().replaceAll(RegExp(r'\s{2,}'), ' ');
      return (note, q, u, cleaned);
    }
    return (null, null, null, text);
  }

  static String _cleanName(String input) {
    var text = input.trim();
    text = text.replaceFirst(RegExp("^d['’]\\s*", caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^de\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    return text.replaceAll(RegExp(r'^[\s.,]+|[\s.,]+$'), '');
  }

  static String _fmtQty(num q) => (q - q.round()).abs() < 1e-9 ? q.round().toString() : q.toString();

  static Ingredient _parseIngredient(String line, {bool preferMetricWeight = false}) {
    final original = line.trim();
    final (noteMetric, mQty, mUnit, lineWoParen) = _parseMetricParen(original);
    var (qty, rest) = _parseQuantity(lineWoParen);
    String? unit;
    (unit, rest) = _parseUnit(rest);
    final name = _cleanName(rest);
    final noteParts = <String>[];
    if (preferMetricWeight && mQty != null && (mUnit == 'g' || mUnit == 'kg')) {
      if (qty != null) noteParts.add('${_fmtQty(qty)} ${unit ?? ''}'.trim());
      qty = mQty;
      unit = mUnit;
    } else if (noteMetric != null) {
      noteParts.add(noteMetric);
    }
    if (qty != null && (qty - qty.round()).abs() < 1e-9) qty = qty.round();
    return Ingredient(quantity: qty, unit: unit, name: name, note: noteParts.isNotEmpty ? noteParts.join(' · ') : null);
  }

  // ── tags ──
  static const Map<String, String> _systemTagMap = {
    'dessert': 'tag-dessert', 'desserts': 'tag-dessert',
    'déjeuner': 'tag-breakfast', 'dejeuner': 'tag-breakfast',
    'brunch': 'tag-breakfast', 'déjeuners/brunch': 'tag-breakfast',
    'plat principal': 'tag-dinner', 'plats principaux': 'tag-dinner',
    'souper': 'tag-dinner', 'dîner': 'tag-dinner', 'diner': 'tag-dinner',
    'entrée': 'tag-appetizer', 'entree': 'tag-appetizer', 'entrées': 'tag-appetizer',
    'bouchées': 'tag-appetizer',
    'soupe': 'tag-soup', 'soupes': 'tag-soup', 'potage': 'tag-soup',
    'soupes et potages': 'tag-soup',
    'salade': 'tag-salad', 'salades': 'tag-salad',
  };

  static (List<String>, List<String>) _mapTags(List cats, List kws) {
    final ids = <String>[];
    final suggestions = <String>[];
    final pool = <String>[];
    for (final c in cats) {
      final s = c.toString().trim();
      if (s.isNotEmpty) pool.add(s);
    }
    for (final k in kws) {
      final s = k.toString().trim();
      if (s.isNotEmpty) pool.add(s);
    }
    for (final item in pool) {
      final id = _systemTagMap[item.toLowerCase().trim()];
      if (id != null) {
        if (!ids.contains(id)) ids.add(id);
      } else if (item.isNotEmpty && item.length <= 20 && !suggestions.contains(item)) {
        suggestions.add(item);
      }
    }
    return (ids, suggestions);
  }

  // ── hero image download (best-effort) ──
  static Future<String?> downloadImage(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final bytes = res.bodyBytes;
      if (kIsWeb) {
        final decoded = img.decodeImage(bytes);
        List<int> out = bytes;
        if (decoded != null) {
          final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
          out = img.encodeJpg(resized, quality: 80);
        }
        return 'data:image/jpeg;base64,${base64Encode(out)}';
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
