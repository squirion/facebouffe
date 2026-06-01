import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';

/// Thrown when an import can't be completed (network blocked, no recipe data…).
/// [detail] carries a verbose, developer-facing reason (surfaced in the UI while
/// debugging the import engine — see import_debug.dart).
class ImportException implements Exception {
  final String code;
  final String? detail;
  ImportException(this.code, [this.detail]);

  @override
  String toString() => 'ImportException($code${detail != null ? ': $detail' : ''})';
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
    final target = await resolveShareUrl(url.trim());
    final html = await _fetch(target);
    return parseHtml(target, html);
  }

  /// Parse already-fetched HTML (no network) — also the unit-test seam.
  static ImportResult parseHtml(String url, String html) {
    final recipe = _findRecipeJsonLd(html);
    if (recipe == null) throw ImportException('no_recipe');
    return _build(url.trim(), recipe);
  }

  /// Fetch a web page and reduce it to whitespace-collapsed plain text, for an
  /// LLM engine to read when a URL has no parseable schema.org recipe (Phase 2:
  /// import from an unsupported site). [maxChars] caps the feed (cloud models
  /// take more; the on-device model's small context wants less).
  ///
  /// Tries a direct fetch first (fast, and the content stays between the device
  /// and the recipe site). If the site bot-blocks us (Akamai/Cloudflare → 403)
  /// or returns nothing usable, it falls back to the Jina reader, which renders
  /// the page with a real browser — this sends the URL to a third-party service
  /// (r.jina.ai). Used only by the AI engines, never by Tier 0.
  ///
  /// When [allowReader] is false (the on-device path, which is meant to stay
  /// fully local), a needed reader fallback instead throws `reader_consent` so
  /// the UI can ask the user before anything leaves the device.
  static Future<String> fetchReadableText(String url, {int maxChars = 16000, bool allowReader = true}) async {
    final u = await resolveShareUrl(url.trim());
    String text = '';
    try {
      text = htmlToText(await _fetch(u));
    } catch (_) {
      // fall through to the reader proxy
    }
    if (text.trim().length < 200) {
      if (!allowReader) throw ImportException('reader_consent');
      text = await _fetchViaReader(u);
    }
    if (text.trim().isEmpty) throw ImportException('no_recipe', 'page had no readable text');
    return text.length > maxChars ? text.substring(0, maxChars) : text;
  }

  /// Jina AI Reader fallback — renders [url] in a real browser (defeating most
  /// bot walls) and returns clean text. Third-party; only a fallback for AI
  /// URL import. Already plain text, so no htmlToText pass.
  static Future<String> _fetchViaReader(String url) async {
    final withScheme = url.startsWith(RegExp(r'https?://', caseSensitive: false)) ? url : 'https://$url';
    final http.Response res;
    try {
      res = await http.get(
        Uri.parse('https://r.jina.ai/$withScheme'),
        headers: {'Accept': 'text/plain', 'X-Return-Format': 'text'},
      ).timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ImportException('network');
    }
    if (res.statusCode != 200) throw ImportException('http_${res.statusCode}');
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  /// Strip HTML to plain readable text (no network — also the unit-test seam).
  static String htmlToText(String html) {
    var s = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
    // Drop non-content elements (and their contents) entirely.
    for (final tag in ['script', 'style', 'head', 'noscript', 'svg', 'template', 'iframe']) {
      s = s.replaceAll(RegExp('<$tag[^>]*>.*?</$tag>', dotAll: true, caseSensitive: false), ' ');
    }
    // Block-level boundaries → newlines so ingredients/steps stay on their own lines.
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(p|div|li|ul|ol|tr|h[1-6]|section|article|header|footer|table|blockquote)\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' '); // remaining tags
    s = _decodeEntities(s);
    s = s.replaceAll(RegExp(r'[ \t\x0B\f\r]+'), ' ');
    s = s.replaceAll(RegExp(r' *\n *'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static const Map<String, String> _namedEntities = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
    'eacute': 'é', 'egrave': 'è', 'ecirc': 'ê', 'euml': 'ë',
    'agrave': 'à', 'acirc': 'â', 'auml': 'ä', 'ccedil': 'ç',
    'icirc': 'î', 'iuml': 'ï', 'ocirc': 'ô', 'ouml': 'ö',
    'ugrave': 'ù', 'ucirc': 'û', 'uuml': 'ü', 'deg': '°',
    'frac12': '½', 'frac14': '¼', 'frac34': '¾',
    'hellip': '…', 'rsquo': '’', 'lsquo': '‘', 'ldquo': '“', 'rdquo': '”',
    'ndash': '–', 'mdash': '—', 'middot': '·', 'times': '×',
  };

  static String _decodeEntities(String s) {
    return s.replaceAllMapped(RegExp(r'&(#[xX][0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x') || e.startsWith('#X')) {
        final code = int.tryParse(e.substring(2), radix: 16);
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      } else if (e.startsWith('#')) {
        final code = int.tryParse(e.substring(1));
        return code != null ? String.fromCharCode(code) : m.group(0)!;
      }
      return _namedEntities[e] ?? m.group(0)!;
    });
  }

  // Share / URL-shortener hosts whose links wrap the real destination. Sharing
  // a page from Chrome / the Google app yields a share.google link, not the
  // page URL, so we resolve it to the real recipe page before fetching.
  static const _shortenerHosts = ['share.google', 'g.co', 'goo.gl', 'bit.ly', 'tinyurl.com', 'ow.ly', 't.co', 'l.facebook.com', 'lnkd.in'];

  static bool _isShortener(String url) {
    final h = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return _shortenerHosts.any((s) => h == s || h.endsWith('.$s'));
  }

  /// Resolve a share/short link to the real page URL by following HTTP 30x and,
  /// if the landing page is a `<meta refresh>` / JS interstitial, the redirect
  /// embedded in it. Non-shortener URLs pass through untouched (no extra
  /// request); on any error the input is returned as-is. (No-op on web.)
  static Future<String> resolveShareUrl(String url) async {
    var current = url.trim();
    if (kIsWeb || !_isShortener(current)) return current;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      for (var hop = 0; hop < 5; hop++) {
        final req = await client.getUrl(Uri.parse(current));
        req.followRedirects = false;
        req.headers.set(HttpHeaders.userAgentHeader, _uaDesktop);
        final resp = await req.close();
        if (resp.isRedirect) {
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          await resp.drain<void>();
          if (loc == null) break;
          current = Uri.parse(current).resolve(loc).toString();
          continue;
        }
        final body = await resp.transform(const Utf8Decoder(allowMalformed: true)).join();
        final next = _redirectInBody(body);
        if (next == null) break;
        final resolved = Uri.parse(current).resolve(next).toString();
        if (resolved == current) break;
        current = resolved;
      }
    } catch (_) {
      // keep the best URL we have
    } finally {
      client.close();
    }
    return current;
  }

  /// Pull a redirect target out of an interstitial page: a <meta refresh> or a
  /// common JS `location` assignment. Returns null if none found.
  static String? _redirectInBody(String html) {
    final head = html.length > 12000 ? html.substring(0, 12000) : html;
    final meta = RegExp(r'''<meta[^>]+http-equiv=["']?refresh["']?[^>]*content=["'][^"']*url=([^"'>]+)''', caseSensitive: false).firstMatch(head);
    if (meta != null) return _unescapeUrl(meta.group(1)!.trim());
    for (final re in [
      RegExp(r'''location\.replace\(\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''location\.href\s*=\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''window\.location(?:\.href)?\s*=\s*["']([^"']+)["']''', caseSensitive: false),
    ]) {
      final m = re.firstMatch(head);
      if (m != null) return _unescapeUrl(m.group(1)!.trim());
    }
    return null;
  }

  static String _unescapeUrl(String u) => u
      .replaceAll('&amp;', '&')
      .replaceAll(r'\/', '/')
      .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));

  // A current desktop-Chrome UA + a Googlebot fallback. Many sites bot-block an
  // unfamiliar client (→ 403) but serve crawlers the full page, JSON-LD and all,
  // for SEO — so retrying as Googlebot recovers a lot of otherwise-blocked sites.
  static const _uaDesktop = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  static const _uaBot = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';

  static Future<String> _fetch(String url) async {
    final uri = Uri.parse(url);
    http.Response? res;
    for (final ua in [_uaDesktop, _uaBot]) {
      try {
        res = await http.get(uri, headers: {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'fr-CA,fr;q=0.9,en;q=0.8',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-User': '?1',
        }).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw ImportException('network');
      }
      if (res.statusCode == 200) return res.body;
      // Only the bot-block family is worth a second UA; bail on 404/500/etc.
      if (![401, 403, 406, 429].contains(res.statusCode)) break;
    }
    throw ImportException('http_${res!.statusCode}');
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
