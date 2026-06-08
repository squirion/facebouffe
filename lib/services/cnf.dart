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
  // normalized (diacritic-folded, punctuation stripped) when the table loads,
  // so accents and apostrophes in the recipe don't matter.
  static const Map<String, List<String>> _seedSpec = {
    // ── baking staples ──
    '4501': ['farine', 'farine tout usage', 'farine blanche', 'flour', 'all-purpose flour', 'all purpose flour', 'white flour'],
    '4500': ['farine de ble entier', 'farine de ble complete', 'farine integrale', 'whole wheat flour', 'wholemeal flour'],
    '4446': ['farine a gateau', 'farine a patisserie', 'cake flour', 'pastry flour'],
    '4429': ['farine de riz', 'rice flour'],
    '4419': ['fecule de mais', 'corn starch', 'cornstarch'],
    '4318': ['sucre', 'sucre blanc', 'sucre granule', 'sugar', 'white sugar', 'granulated sugar'],
    '4317': ['cassonade', 'sucre brun', 'brown sugar'],
    '4319': ['sucre a glacer', 'sucre glace', 'sucre en poudre', 'icing sugar', 'powdered sugar', 'confectioners sugar'],
    '214': ['sel', 'salt', 'table salt', 'sel de table'],
    '118': ['beurre', 'beurre sale', 'butter', 'salted butter'],
    '92': ['beurre non sale', 'beurre doux', 'unsalted butter'],
    '7458': ['margarine'],
    '552': ['shortening', 'graisse vegetale', 'graisse a cuisson'],
    '125': ['oeuf', 'oeufs', 'oeuf entier', 'egg', 'eggs', 'whole egg'],
    '126': ['blanc d oeuf', 'blancs d oeufs', 'egg white', 'egg whites'],
    '127': ['jaune d oeuf', 'jaunes d oeufs', 'egg yolk', 'egg yolks'],
    '113': ['lait', 'lait entier', 'milk', 'whole milk'],
    '124': ['babeurre', 'buttermilk'],
    '140': ['lait evapore', 'lait concentre', 'evaporated milk'],
    '68': ['lait condense', 'lait condense sucre', 'sweetened condensed milk', 'condensed milk'],
    '4003': ['poudre a pate', 'levure chimique', 'baking powder'],
    '4005': ['bicarbonate', 'bicarbonate de soude', 'baking soda'],
    '216': ['vanille', 'extrait de vanille', 'vanilla', 'vanilla extract'],
    '4294': ['miel', 'honey'],
    '4326': ['sirop d erable', 'maple syrup'],
    '4323': ['sirop de mais', 'corn syrup'],
    '4299': ['melasse', 'molasses'],
    '4223': ['cacao', 'poudre de cacao', 'cacao en poudre', 'cocoa', 'cocoa powder', 'unsweetened cocoa'],
    '4148': ['brisures de chocolat', 'pepites de chocolat', 'grains de chocolat', 'chocolate chips', 'chocolat mi-sucre'],
    '4147': ['chocolat a cuire', 'chocolat non sucre', 'baking chocolate', 'unsweetened chocolate'],
    '6670': ['chocolat noir', 'dark chocolate'],
    '1462': ['flocons d avoine', 'gruau', 'avoine', 'rolled oats', 'oats', 'oatmeal'],
    '4069': ['chapelure', 'bread crumbs', 'breadcrumbs', 'panko'],
    '5917': ['quinoa'],
    '4490': ['couscous'],
    // ── oils & fats ──
    '451': ['huile', 'huile vegetale', 'huile de canola', 'vegetable oil', 'canola oil', 'oil', 'cooking oil'],
    '422': ['huile d olive', 'olive oil'],
    '420': ['huile de coco', 'huile de noix de coco', 'coconut oil'],
    '424': ['huile de sesame', 'sesame oil'],
    '464': ['saindoux', 'lard', 'gras de porc'],
    '17': ['ghee', 'beurre clarifie', 'clarified butter'],
    // ── dairy & cheese ──
    '119': ['cheddar', 'fromage cheddar', 'cheddar cheese'],
    '35': ['mozzarella', 'fromage mozzarella', 'mozzarella cheese'],
    '40': ['parmesan', 'fromage parmesan', 'parmesan cheese', 'parmigiano'],
    '47': ['suisse', 'emmental', 'fromage suisse', 'swiss cheese'],
    '32': ['gruyere', 'fromage gruyere'],
    '28': ['fromage a la creme', 'cream cheese'],
    '108': ['feta', 'fromage feta', 'feta cheese'],
    '43': ['ricotta', 'fromage ricotta', 'ricotta cheese'],
    '107': ['cottage', 'fromage cottage', 'cottage cheese'],
    '20': ['brie', 'fromage brie'],
    '18': ['fromage bleu', 'blue cheese'],
    '98': ['chevre', 'fromage de chevre', 'fromage chevre', 'goat cheese'],
    '6961': ['yogourt', 'yogourt nature', 'yaourt', 'yogurt', 'plain yogurt'],
    '7469': ['yogourt grec', 'greek yogurt', 'yogourt grec nature'],
    '139': ['creme sure', 'sour cream'],
    '138': ['creme a fouetter', 'creme 35', 'creme epaisse', 'whipping cream', 'heavy cream'],
    '150': ['creme a cafe', 'creme 10', 'creme legere', 'half and half'],
    // ── herbs & spices ──
    '198': ['poivre', 'poivre noir', 'black pepper', 'pepper'],
    '178': ['cannelle', 'cinnamon'],
    '193': ['muscade', 'nutmeg'],
    '196': ['paprika'],
    '195': ['origan', 'oregano'],
    '171': ['basilic', 'basilic seche', 'basil', 'dried basil'],
    '210': ['thym', 'thyme'],
    '197': ['persil', 'parsley'],
    '204': ['romarin', 'rosemary'],
    '172': ['laurier', 'feuille de laurier', 'feuilles de laurier', 'bay leaf', 'bay leaves'],
    '194': ['poudre d oignon', 'onion powder'],
    '188': ['poudre d ail', 'ail en poudre', 'garlic powder'],
    '177': ['poudre de chili', 'chili powder', 'poudre de piment'],
    '183': ['poudre de cari', 'cari', 'curry', 'curry powder'],
    '211': ['curcuma', 'turmeric'],
    '174': ['cardamome', 'cardamom'],
    '181': ['graines de coriandre', 'coriandre moulue', 'coriander seed', 'ground coriander'],
    // ── produce ──
    '2401': ['oignon', 'oignons', 'onion'],
    '2144': ['oignon vert', 'oignons verts', 'echalote verte', 'green onion', 'scallion', 'scallions'],
    '2394': ['ail', 'gousse d ail', 'gousses d ail', 'garlic', 'garlic clove'],
    '2380': ['carotte', 'carottes', 'carrot', 'carrots'],
    '2417': ['pomme de terre', 'pommes de terre', 'patate', 'patates', 'potato', 'potatoes'],
    '2240': ['patate douce', 'sweet potato'],
    '2460': ['tomate', 'tomates', 'tomato', 'tomatoes'],
    '2386': ['celeri', 'celery'],
    '2484': ['poivron', 'poivron rouge', 'red pepper', 'red bell pepper', 'bell pepper'],
    '2413': ['poivron vert', 'green pepper', 'green bell pepper'],
    '2399': ['champignon', 'champignons', 'champignon de paris', 'mushroom', 'mushrooms'],
    '2213': ['epinard', 'epinards', 'spinach'],
    '2374': ['brocoli', 'broccoli'],
    '2385': ['chou-fleur', 'chou fleur', 'cauliflower'],
    '2225': ['courgette', 'courgettes', 'zucchini'],
    '2363': ['concombre', 'cucumber'],
    '2361': ['chou', 'cabbage'],
    '2409': ['pois verts', 'petits pois', 'pois', 'green peas', 'peas'],
    '2370': ['haricots verts', 'green beans', 'snap beans'],
    '1587': ['citron', 'lemon'],
    '1593': ['lime', 'citron vert'],
    '1696': ['pomme', 'pommes', 'apple', 'apples'],
    '1704': ['banane', 'banana'],
    '1749': ['fraise', 'fraises', 'strawberry', 'strawberries'],
    '1705': ['bleuet', 'bleuets', 'myrtille', 'blueberry', 'blueberries'],
    '1745': ['raisins secs', 'raisin sec', 'raisins', 'sultanas'],
    '2091': ['gingembre', 'ginger', 'racine de gingembre', 'fresh ginger'],
    '1511': ['avocat', 'avocado'],
    '2067': ['coriandre', 'cilantro', 'coriandre fraiche', 'fresh coriander'],
    '4860': ['jalapeno', 'piment jalapeno', 'jalapeno pepper'],
    // ── proteins ──
    '2786': ['boeuf hache', 'viande hachee', 'ground beef'],
    '6143': ['bifteck', 'steak', 'bifteck de surlonge', 'sirloin steak'],
    '6119': ['porc hache', 'ground pork'],
    '815': ['dinde hachee', 'ground turkey'],
    '841': ['poitrine de poulet', 'poulet', 'chicken breast', 'chicken'],
    '853': ['haut de cuisse de poulet', 'cuisse de poulet', 'chicken thigh'],
    '1801': ['cotelette de porc', 'porc', 'pork chop', 'pork loin', 'pork'],
    '1936': ['bacon', 'lard fume'],
    '1148': ['jambon', 'ham', 'deli ham'],
    '3182': ['saumon', 'salmon', 'filet de saumon'],
    '3211': ['crevette', 'crevettes', 'shrimp', 'prawns'],
    '3084': ['thon', 'thon en conserve', 'tuna', 'canned tuna'],
    // ── legumes ──
    '3392': ['lentilles', 'lentils', 'dal', 'daal'],
    '3389': ['pois chiches', 'pois chiche', 'chickpeas', 'garbanzo', 'channa'],
    '3376': ['haricots noirs', 'black beans'],
    '3269': ['haricots pinto', 'pinto beans'],
    '6366': ['haricots rouges', 'kidney beans', 'red kidney beans'],
    '7449': ['haricots refrits', 'refried beans', 'frijoles refritos'],
    // ── nuts & seeds ──
    '2534': ['amandes', 'amande', 'almonds', 'almond', 'ground almonds', 'almond flour', 'almond meal', 'farine d amande'],
    '2590': ['noix', 'noix de grenoble', 'walnuts', 'walnut'],
    '2582': ['pacanes', 'pecans', 'pecan', 'noix de pecan'],
    '5709': ['noix de cajou', 'cajou', 'cashews', 'cashew'],
    '3303': ['arachides', 'arachide', 'cacahuetes', 'peanuts', 'peanut'],
    '6289': ['beurre d arachide', 'beurre d arachides', 'peanut butter'],
    '2611': ['graines de sesame', 'sesame', 'sesame seeds'],
    '2511': ['graines de chia', 'chia', 'chia seeds'],
    '4528': ['graines de lin', 'lin', 'flax', 'flaxseed', 'flax seeds'],
    // ── Asian pantry ──
    '3403': ['sauce soya', 'sauce soja', 'soy sauce', 'tamari'],
    '2565': ['lait de coco', 'coconut milk'],
    '4911': ['tofu', 'tofu ferme', 'firm tofu'],
    '4731': ['sauce de poisson', 'sauce poisson', 'fish sauce', 'nuoc mam'],
    '4874': ['nouilles de riz', 'rice noodles', 'vermicelle de riz'],
    '3319': ['miso', 'pate miso'],
    '2008': ['germes de haricot', 'feves germees', 'germes de soja', 'bean sprouts'],
    // ── rice, pasta, grains ──
    '4471': ['riz', 'riz blanc', 'riz basmati', 'basmati', 'rice', 'white rice', 'basmati rice'],
    // ── Mexican ──
    '3997': ['tortilla de mais', 'corn tortilla'],
    '4049': ['tortilla', 'tortilla de farine', 'flour tortilla'],
    '2388': ['mais', 'mais sucre', 'corn', 'sweet corn', 'grains de mais'],
    '1025': ['salsa', 'sauce salsa'],
    // ── condiments & canned ──
    '2494': ['ketchup', 'catsup'],
    '4970': ['moutarde', 'mustard', 'moutarde de dijon', 'dijon'],
    '531': ['mayonnaise', 'mayo'],
    '14': ['vinaigre', 'vinaigre blanc', 'white vinegar', 'vinaigre distille'],
    '6196': ['vinaigre balsamique', 'balsamic vinegar', 'balsamique'],
    '13': ['vinaigre de cidre', 'apple cider vinegar'],
    '2258': ['pate de tomate', 'pate de tomates', 'tomato paste'],
    '2465': ['sauce tomate', 'sauce aux tomates', 'tomato sauce'],
    '4736': ['tomates en conserve', 'tomates broyees', 'canned tomatoes', 'diced tomatoes', 'crushed tomatoes'],
    '6541': ['bouillon de poulet', 'chicken broth', 'chicken stock'],
    '927': ['bouillon de boeuf', 'beef broth', 'beef stock'],
    '7374': ['bouillon de legumes', 'vegetable broth', 'vegetable stock'],
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

  /// Grams for an embedded sub-recipe amount, using the sub-recipe's overall
  /// density (its total weight / total volume) for volume units. Returns null
  /// for countable/unknown units (not supported for sub-recipes).
  double? embedGramsFor(num? quantity, String? unit, num subWeightG, num? subVolumeMl) {
    if (quantity == null || unit == null) return null;
    final q = quantity.toDouble();
    if (_gPer.containsKey(unit)) return q * _gPer[unit]!;
    if (_mlPer.containsKey(unit)) {
      final gml = (subVolumeMl != null && subVolumeMl > 0) ? subWeightG / subVolumeMl : 1.0;
      return q * _mlPer[unit]! * gml;
    }
    return null;
  }

  /// Total physical weight (grams) of a recipe's ingredients — the basis for
  /// portion weight. Only counts ingredients meant to be eaten (matched &
  /// included, or an embedded sub-recipe); [complete] is false when something
  /// couldn't be resolved. Used as a fallback where [Nutrition.autoTotalWeightG]
  /// isn't available.
  ({double grams, bool complete}) totalWeight(List<Ingredient> ings, {Recipe? Function(String id)? resolve}) {
    double g = 0;
    var complete = true;
    for (final ing in ings) {
      if (ing.recipeRef != null) {
        final rr = ing.recipeRef!;
        num? subW = rr.totalWeightG;
        num? subV = rr.totalVolumeMl;
        final liveB = resolve?.call(rr.recipeId);
        final liveW = liveB?.effectiveTotalWeightG;
        if (liveB != null && liveW != null && liveW > 0) {
          subW = liveW;
          subV = totalVolume(liveB.ingredients).ml;
        }
        if (subW == null || subW <= 0) {
          complete = false;
          continue;
        }
        final used = embedGramsFor(ing.quantity, ing.unit, subW, subV);
        if (used != null) {
          g += used;
        } else {
          complete = false;
        }
        continue;
      }
      if (ing.name.trim().isEmpty) continue;
      final ref = ing.nutritionRef;
      if (ref != null && !ref.includeInCalc) continue; // intentionally excluded
      if (ref != null && ref.matched) {
        final food = byCode(ref.foodCode);
        final grams = food != null ? gramsFor(ing.quantity, ing.unit, food) : null;
        if (grams != null) {
          g += grams;
          continue;
        }
      }
      complete = false;
    }
    return (grams: g, complete: complete);
  }

  /// Total volume (ml) summed from volume-unit ingredients only — advisory, used
  /// to derive a sub-recipe's density for volume-specified embeds.
  ({double ml, bool complete}) totalVolume(List<Ingredient> ings) {
    double ml = 0;
    var complete = true;
    for (final ing in ings) {
      if (ing.recipeRef != null) {
        complete = false;
        continue;
      }
      if (ing.name.trim().isEmpty) continue;
      final u = ing.unit;
      if (u != null && _mlPer.containsKey(u) && ing.quantity != null) {
        ml += ing.quantity!.toDouble() * _mlPer[u]!;
      } else {
        complete = false;
      }
    }
    return (ml: ml, complete: complete);
  }

  /// Estimate nutrition for a recipe's ingredients at [servings]. Also sums the
  /// total weight (grams) and includes embedded sub-recipe contributions:
  /// fraction = gramsUsed / subTotalWeight, added as fraction × the sub-recipe's
  /// total nutrients. [resolveRecipe] resolves an embedded recipe by id to its
  /// live values; when absent or the sub-recipe has no computed nutrition, the
  /// embed's stored snapshot is used (and a missing one flags hasUnmatched).
  Nutrition compute(List<Ingredient> ingredients, int servings, {required String computedAt, Recipe? Function(String id)? resolveRecipe}) {
    final total = {for (final k in nutrientOrder) k: 0.0};
    var hasUnmatched = false;
    double totalGrams = 0;
    var weightComplete = true;
    for (final ing in ingredients) {
      // ── embedded sub-recipe ──
      if (ing.recipeRef != null) {
        final rr = ing.recipeRef!;
        Map<String, num>? subTotal;
        num? subW;
        num? subV;
        final liveB = resolveRecipe?.call(rr.recipeId);
        final liveW = liveB?.effectiveTotalWeightG;
        if (liveB?.nutrition != null && liveW != null && liveW > 0 && liveB!.nutrition!.total.isNotEmpty) {
          subTotal = liveB.nutrition!.total;
          subW = liveW;
          subV = totalVolume(liveB.ingredients).ml;
        } else if (rr.totalWeightG != null && rr.totalWeightG! > 0 && rr.total.isNotEmpty) {
          subTotal = rr.total;
          subW = rr.totalWeightG;
          subV = rr.totalVolumeMl;
        }
        if (subTotal == null || subW == null || subW <= 0) {
          hasUnmatched = true;
          weightComplete = false;
          continue;
        }
        final used = embedGramsFor(ing.quantity, ing.unit, subW, subV);
        if (used == null) {
          hasUnmatched = true;
          weightComplete = false;
          continue;
        }
        final fraction = used / subW;
        for (final k in nutrientOrder) {
          total[k] = total[k]! + (subTotal[k] ?? 0) * fraction;
        }
        totalGrams += used;
        continue;
      }
      // ── plain ingredient ──
      if (ing.name.trim().isEmpty) continue;
      final ref = ing.nutritionRef;
      final excluded = ref != null && !ref.includeInCalc;
      double? grams;
      if (ref != null && ref.matched && ref.includeInCalc) {
        final food = byCode(ref.foodCode);
        if (food != null) {
          grams = gramsFor(ing.quantity, ing.unit, food);
          if (grams != null) {
            final factor = grams / 100.0;
            for (final k in nutrientOrder) {
              total[k] = total[k]! + _nutrient(food, k) * factor;
            }
          } else {
            hasUnmatched = true;
          }
        } else {
          hasUnmatched = true;
        }
      } else {
        hasUnmatched = true;
      }
      if (!excluded) {
        if (grams != null) {
          totalGrams += grams;
        } else {
          weightComplete = false;
        }
      }
    }
    final basis = servings < 1 ? 1 : servings;
    num r2(num v) => (v * 100).round() / 100;
    final per = {for (final k in nutrientOrder) k: r2(total[k]! / basis)};
    final tot = {for (final k in nutrientOrder) k: r2(total[k]!)};
    return Nutrition(perServing: per, total: tot, isEstimate: true, hasUnmatched: hasUnmatched, computedAt: computedAt, servingsBasis: basis, autoTotalWeightG: r2(totalGrams), weightComplete: weightComplete);
  }
}

// ── Daily Values (Canada, 2016) for the % DV column ──
const Map<String, num> kDvRef = {'fat': 75, 'satTrans': 20, 'sodium': 2300, 'fiber': 28, 'sugars': 100, 'potassium': 3400, 'calcium': 1300, 'iron': 18};

int? dvPct(String key, num value) {
  final ref = kDvRef[key];
  if (ref == null) return null;
  return ((value / ref) * 100).round();
}
