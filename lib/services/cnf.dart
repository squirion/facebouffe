import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../data/models.dart';

/// One Canadian Nutrient File food: per-100 g nutrients (index-aligned with
/// [Cnf.nutrientOrder]) plus optional grams-per-millilitre (density) and
/// grams-per-piece, derived from the food's household measures.
class CnfFood {
  final String code;
  final String fr;
  final String en;
  final List<num> n;
  final double? gml;
  final double? gpc;
  const CnfFood(this.code, this.fr, this.en, this.n, this.gml, this.gpc);

  String name(String lang) => lang == 'en' ? en : fr;
}

/// Local Canadian Nutrient File: loads the bundled asset once, then matches
/// ingredients to foods and estimates a recipe's nutrition. Everything is an
/// estimate — never a regulatory panel.
class Cnf {
  Cnf._();
  static final Cnf instance = Cnf._();

  final List<CnfFood> foods = [];
  final Map<String, CnfFood> _byCode = {};
  List<String> nutrientOrder = const [];
  final List<String> _folded = []; // foods[i] folded name haystack, for picker search
  final List<List<String>> _tokFr = []; // foods[i] French name tokens, for matching
  final List<List<String>> _tokEn = []; // foods[i] English name tokens, for matching
  final Map<String, String> _seed = {}; // folded ingredient name → CNF code (curated)
  Future<void>? _loadFuture;

  bool get loaded => foods.isNotEmpty;

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/cnf.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    nutrientOrder = (j['nutrients'] as List).map((e) => e as String).toList();
    for (final f in (j['foods'] as List)) {
      final m = f as Map<String, dynamic>;
      final food = CnfFood(
        m['c'] as String,
        m['fr'] as String? ?? '',
        m['en'] as String? ?? '',
        (m['n'] as List).map((e) => e as num).toList(),
        (m['gml'] as num?)?.toDouble(),
        (m['gpc'] as num?)?.toDouble(),
      );
      foods.add(food);
      _byCode[food.code] = food;
      _folded.add(_fold('${food.fr} ${food.en}'));
      _tokFr.add(_toks(food.fr));
      _tokEn.add(_toks(food.en));
    }
    _seedSpec.forEach((code, variants) {
      for (final v in variants) {
        _seed[_seedNorm(v)] = code;
      }
    });
  }

  CnfFood? byCode(String? code) => code == null ? null : _byCode[code];

  String cnfName(String? code, String lang) => byCode(code)?.name(lang) ?? '';

  num _nutrient(CnfFood f, String key) {
    final i = nutrientOrder.indexOf(key);
    return (i >= 0 && i < f.n.length) ? f.n[i] : 0;
  }

  // ── matching ──
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ûüù]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('œ', 'oe')
      .replaceAll('æ', 'ae');

  // Filler words that carry no matching signal in either language.
  static const _stop = {'de', 'le', 'la', 'les', 'des', 'du', 'au', 'aux', 'et', 'en', 'the', 'of', 'and', 'with', 'to', 'ou', 'or', 'a'};

  static List<String> _toks(String s) =>
      _fold(s).split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 2 && !_stop.contains(w)).toList();

  // A query token matches a food token on equality or a shared prefix (≥3
  // chars) — this absorbs plurals and inflections (sucre/sucré, oeuf/oeufs).
  static bool _tokMatch(String q, String f) {
    if (q == f) return true;
    return q.length >= 3 && f.length >= 3 && (f.startsWith(q) || q.startsWith(f));
  }

  // Score query against one language's tokens: recall of the query times a
  // precision factor that rewards concise names (so a category-prefixed
  // staple beats a long prepared-food name that merely mentions the word).
  static double _sideScore(List<String> qt, List<String> ft) {
    if (qt.isEmpty || ft.isEmpty) return 0;
    var matchedQuery = 0;
    final usedFood = <int>{};
    for (final q in qt) {
      var hit = false;
      for (var i = 0; i < ft.length; i++) {
        if (_tokMatch(q, ft[i])) {
          hit = true;
          usedFood.add(i);
        }
      }
      if (hit) matchedQuery++;
    }
    final qcov = matchedQuery / qt.length;
    final fcov = usedFood.length / ft.length;
    return qcov * (0.45 + 0.55 * fcov);
  }

  static String _seedNorm(String s) => _fold(s).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Top matches for the food picker, ranked by the same scorer as auto-match
  /// (falls back to substring when the query is too short to tokenize).
  List<CnfFood> search(String query, {int limit = 12}) {
    final qt = _toks(query);
    if (qt.isEmpty) {
      final q = _fold(query.trim());
      if (q.isEmpty) return foods.take(limit).toList();
      final out = <CnfFood>[];
      for (var i = 0; i < foods.length && out.length < limit; i++) {
        if (_folded[i].contains(q)) out.add(foods[i]);
      }
      return out;
    }
    final scored = <(int, double)>[];
    for (var i = 0; i < foods.length; i++) {
      final s = _sideScore(qt, _tokFr[i]);
      final e = _sideScore(qt, _tokEn[i]);
      final best = s > e ? s : e;
      if (best > 0) scored.add((i, best));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (i, _) in scored.take(limit)) foods[i]];
  }

  /// Best fuzzy match by per-language token scoring. Returns (food, confidence).
  ({CnfFood food, double confidence})? _bestMatch(String name) {
    final qt = _toks(name);
    if (qt.isEmpty) return null;
    CnfFood? best;
    var bestScore = 0.0;
    for (var i = 0; i < foods.length; i++) {
      final s = _sideScore(qt, _tokFr[i]);
      final e = _sideScore(qt, _tokEn[i]);
      final sc = s > e ? s : e;
      if (sc > bestScore) {
        bestScore = sc;
        best = foods[i];
      }
    }
    if (best == null || bestScore <= 0) return null;
    return (food: best, confidence: bestScore.clamp(0, 0.98));
  }

  /// Default include-in-calc = false for things you don't actually eat:
  /// frying oil, "sel au goût", pinch items.
  bool defaultExcluded(Ingredient ing) {
    final n = ing.name.toLowerCase();
    final note = (ing.note ?? '').toLowerCase();
    if (ing.unit == 'pinch') return true;
    if (RegExp(r'\bsel\b|\bsalt\b').hasMatch(n)) return true;
    if (RegExp(r'huile|oil').hasMatch(n) &&
        (ing.unit == 'l' || (ing.unit == 'ml' && (ing.quantity ?? 0) >= 500) || RegExp(r'friture|frying').hasMatch('$n $note'))) {
      return true;
    }
    return false;
  }

  /// Resolve a per-ingredient match, in priority order: a user-learned alias,
  /// then the curated common-staples seed table, then fuzzy matching.
  NutritionRef resolveMatch(Ingredient ing, Map<String, String> aliases) {
    final excluded = defaultExcluded(ing);
    // 1. user-learned alias
    final key = ing.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final aliasCode = aliases[key];
    if (aliasCode != null && _byCode.containsKey(aliasCode)) {
      return NutritionRef(foodCode: aliasCode, matchedName: cnfName(aliasCode, 'fr'), confidence: 1, includeInCalc: !excluded, fromAlias: true);
    }
    // 2. curated seed for common Canadian-recipe staples
    final seedCode = _seed[_seedNorm(ing.name)];
    if (seedCode != null && _byCode.containsKey(seedCode)) {
      return NutritionRef(foodCode: seedCode, matchedName: cnfName(seedCode, 'fr'), confidence: 0.95, includeInCalc: !excluded);
    }
    // 3. fuzzy match
    final m = _bestMatch(ing.name);
    if (m == null) return NutritionRef(foodCode: null, matchedName: null, confidence: 0, includeInCalc: !excluded);
    return NutritionRef(foodCode: m.food.code, matchedName: m.food.fr, confidence: (m.confidence * 100).round() / 100, includeInCalc: !excluded);
  }

  // Curated matches for the most common Canadian-recipe staples → CNF code.
  // Each food lists the spellings (FR + EN) a user is likely to type; keys are
  // normalized (diacritic-folded, punctuation stripped) when the table loads.
  static const Map<String, List<String>> _seedSpec = {
    '4501': ['farine', 'farine tout usage', 'farine blanche', 'flour', 'all-purpose flour', 'all purpose flour', 'white flour'],
    '4318': ['sucre', 'sucre blanc', 'sucre granule', 'sugar', 'white sugar', 'granulated sugar'],
    '4317': ['cassonade', 'sucre brun', 'brown sugar'],
    '4319': ['sucre a glacer', 'sucre glace', 'sucre en poudre', 'icing sugar', 'powdered sugar', 'confectioners sugar'],
    '214': ['sel', 'salt', 'table salt', 'sel de table'],
    '118': ['beurre', 'beurre sale', 'butter', 'salted butter'],
    '92': ['beurre non sale', 'beurre doux', 'unsalted butter'],
    '125': ['oeuf', 'oeufs', 'oeuf entier', 'egg', 'eggs', 'whole egg'],
    '113': ['lait', 'lait entier', 'milk', 'whole milk'],
    '4003': ['poudre a pate', 'levure chimique', 'baking powder'],
    '4005': ['bicarbonate', 'bicarbonate de soude', 'baking soda'],
    '216': ['vanille', 'extrait de vanille', 'vanilla', 'vanilla extract'],
    '4294': ['miel', 'honey'],
    '4326': ['sirop d erable', 'sirop derable', "sirop d'erable", 'maple syrup'],
    '451': ['huile', 'huile vegetale', 'huile de canola', 'vegetable oil', 'canola oil', 'oil', 'cooking oil'],
    '422': ["huile d'olive", 'huile d olive', 'huile dolive', 'olive oil'],
    '2401': ['oignon', 'oignons', 'onion'],
    '2394': ['ail', 'gousse d ail', "gousse d'ail", 'garlic'],
    '2380': ['carotte', 'carottes', 'carrot', 'carrots'],
    '2417': ['pomme de terre', 'pommes de terre', 'patate', 'patates', 'potato', 'potatoes'],
    '2460': ['tomate', 'tomates', 'tomato', 'tomatoes'],
    '198': ['poivre', 'poivre noir', 'black pepper', 'pepper'],
    '178': ['cannelle', 'cinnamon'],
    '2786': ['boeuf hache', 'viande hachee', 'ground beef'],
    '841': ['poitrine de poulet', 'poulet', 'chicken breast', 'chicken'],
    '4471': ['riz', 'riz blanc', 'rice', 'white rice'],
    '119': ['cheddar', 'fromage cheddar', 'cheddar cheese'],
    '2933': ['eau', 'water'],
  };

  // ── volume / count / weight → grams (uses CNF measures) ──
  // Metric measures consistent with the CNF-derived density (cup = 250 ml).
  static const _mlPer = {'ml': 1.0, 'l': 1000.0, 'cup': 250.0, 'tbsp': 15.0, 'tsp': 5.0, 'floz': 30.0, 'pinch': 0.3};
  static const _gPer = {'g': 1.0, 'kg': 1000.0, 'oz': 28.3495, 'lb': 453.592};

  /// Grams for an ingredient amount given its matched food, or null if it can't
  /// be determined (e.g. a countable food with no per-piece measure).
  double? gramsFor(num? quantity, String? unit, CnfFood food) {
    if (quantity == null) return null;
    final q = quantity.toDouble();
    if (unit == null) {
      // countable
      return food.gpc != null ? q * food.gpc! : null;
    }
    if (_gPer.containsKey(unit)) return q * _gPer[unit]!;
    if (_mlPer.containsKey(unit)) return q * _mlPer[unit]! * (food.gml ?? 1.0);
    return null;
  }

  /// Estimate nutrition for a recipe's ingredients at [servings].
  Nutrition compute(List<Ingredient> ingredients, int servings, {required String computedAt}) {
    final total = {for (final k in nutrientOrder) k: 0.0};
    var hasUnmatched = false;
    for (final ing in ingredients) {
      if (ing.name.trim().isEmpty) continue;
      final ref = ing.nutritionRef;
      if (ref == null || !ref.matched || !ref.includeInCalc) {
        hasUnmatched = true;
        continue;
      }
      final food = byCode(ref.foodCode);
      if (food == null) {
        hasUnmatched = true;
        continue;
      }
      final grams = gramsFor(ing.quantity, ing.unit, food);
      if (grams == null) {
        hasUnmatched = true;
        continue;
      }
      final factor = grams / 100.0;
      for (final k in nutrientOrder) {
        total[k] = total[k]! + _nutrient(food, k) * factor;
      }
    }
    final basis = servings < 1 ? 1 : servings;
    num r2(num v) => (v * 100).round() / 100;
    final per = {for (final k in nutrientOrder) k: r2(total[k]! / basis)};
    final tot = {for (final k in nutrientOrder) k: r2(total[k]!)};
    return Nutrition(perServing: per, total: tot, isEstimate: true, hasUnmatched: hasUnmatched, computedAt: computedAt, servingsBasis: basis);
  }
}

// ── Daily Values (Canada, 2016) for the % DV column ──
const Map<String, num> kDvRef = {'fat': 75, 'satTrans': 20, 'sodium': 2300, 'fiber': 28, 'sugars': 100, 'potassium': 3400, 'calcium': 1300, 'iron': 18};

int? dvPct(String key, num value) {
  final ref = kDvRef[key];
  if (ref == null) return null;
  return ((value / ref) * 100).round();
}
