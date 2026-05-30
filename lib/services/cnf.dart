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
  final List<String> _folded = []; // foods[i] name haystack, folded, for fuzzy match
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
    }
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

  /// Top fuzzy matches for the food picker (by folded name search).
  List<CnfFood> search(String query, {int limit = 12}) {
    final q = _fold(query.trim());
    if (q.isEmpty) return foods.take(limit).toList();
    final out = <CnfFood>[];
    for (var i = 0; i < foods.length && out.length < limit; i++) {
      if (_folded[i].contains(q)) out.add(foods[i]);
    }
    return out;
  }

  /// Crude fuzzy match: token overlap against the bilingual name. Returns
  /// (food, confidence 0–1) or null.
  ({CnfFood food, double confidence})? _bestMatch(String name) {
    final n = _fold(name.toLowerCase().trim());
    if (n.isEmpty) return null;
    final toks = n.split(RegExp(r'[\s,]+')).where((w) => w.length > 2).toList();
    if (toks.isEmpty) return null;
    CnfFood? best;
    var bestScore = 0;
    for (var i = 0; i < foods.length; i++) {
      final hay = _folded[i];
      var score = 0;
      for (final w in toks) {
        if (hay.contains(w)) score += w.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = foods[i];
      }
    }
    if (best == null) return null;
    return (food: best, confidence: (0.4 + bestScore / 16).clamp(0, 0.98));
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

  /// Resolve a per-ingredient match: learned alias first, then fuzzy match.
  NutritionRef resolveMatch(Ingredient ing, Map<String, String> aliases) {
    final key = ing.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final aliasCode = aliases[key];
    final excluded = defaultExcluded(ing);
    if (aliasCode != null && _byCode.containsKey(aliasCode)) {
      return NutritionRef(foodCode: aliasCode, matchedName: cnfName(aliasCode, 'fr'), confidence: 1, includeInCalc: !excluded, fromAlias: true);
    }
    final m = _bestMatch(ing.name);
    if (m == null) return NutritionRef(foodCode: null, matchedName: null, confidence: 0, includeInCalc: !excluded);
    return NutritionRef(foodCode: m.food.code, matchedName: m.food.fr, confidence: (m.confidence * 100).round() / 100, includeInCalc: !excluded);
  }

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
