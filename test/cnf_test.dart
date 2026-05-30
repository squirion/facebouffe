import 'package:flutter_test/flutter_test.dart';
import 'package:facebouffe/data/models.dart';
import 'package:facebouffe/services/cnf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cnf = Cnf.instance;

  setUpAll(() async => cnf.ensureLoaded());

  test('CNF asset loads with 13 nutrients and many foods', () {
    expect(cnf.nutrientOrder.length, 13);
    expect(cnf.foods.length, greaterThan(4000));
    expect(cnf.nutrientOrder.first, 'kcal');
  });

  test('search and fuzzy-match find flour', () {
    expect(cnf.search('farine').isNotEmpty, true);
    final ref = cnf.resolveMatch(Ingredient(name: 'farine tout usage', quantity: 250, unit: 'ml'), {});
    expect(ref.matched, true);
    final food = cnf.byCode(ref.foodCode)!;
    expect('${food.fr} ${food.en}'.toLowerCase(), contains('farine'));
  });

  test('weight → grams is exact; per-serving math is correct', () {
    final ref = cnf.resolveMatch(Ingredient(name: 'farine tout usage', quantity: 100, unit: 'g'), {});
    final food = cnf.byCode(ref.foodCode)!;
    final ing = Ingredient(name: 'farine', quantity: 100, unit: 'g', nutritionRef: ref);
    final n = cnf.compute([ing], 1, computedAt: 'now');
    // 100 g of flour at 1 serving → per-serving kcal ≈ the food's per-100g kcal.
    expect((n.perServing['kcal']! - food.n[0]).abs() < 0.5, true);
    expect(n.isEstimate, true);
  });

  test('default-excluded: frying oil and salt', () {
    expect(cnf.defaultExcluded(Ingredient(name: 'huile végétale', quantity: 1.5, unit: 'l', note: 'pour la friture')), true);
    expect(cnf.defaultExcluded(Ingredient(name: 'sel', quantity: 1, unit: 'tsp')), true);
    expect(cnf.defaultExcluded(Ingredient(name: 'farine', quantity: 500, unit: 'g')), false);
  });

  test('curated seed pins the donut recipe staples', () {
    final expected = {
      'farine tout usage': '4501',
      'sucre': '4318',
      'poudre à pâte': '4003',
      'sel': '214',
      'oeufs': '125',
      'lait': '113',
      'beurre': '118',
      'huile végétale': '451',
    };
    expected.forEach((name, code) {
      final ref = cnf.resolveMatch(Ingredient(name: name), {});
      expect(ref.foodCode, code, reason: '"$name" should seed-match $code (${cnf.cnfName(code, 'fr')})');
      expect(ref.matched, true);
    });
  });

  test('seed handles common English + accent/punctuation variants', () {
    expect(cnf.resolveMatch(Ingredient(name: 'All-Purpose Flour'), {}).foodCode, '4501');
    expect(cnf.resolveMatch(Ingredient(name: "huile d'olive"), {}).foodCode, '422');
    expect(cnf.resolveMatch(Ingredient(name: 'Cassonade'), {}).foodCode, '4317');
    expect(cnf.resolveMatch(Ingredient(name: 'baking soda'), {}).foodCode, '4005');
  });

  test('expanded seed covers cheeses, cuisine staples, produce, proteins', () {
    final cases = {
      'parmesan': '40', 'mozzarella': '35', 'fromage à la crème': '28', 'féta': '108',
      "blanc d'oeuf": '126', "jaune d'oeuf": '127', 'farine de blé entier': '4500',
      'sauce soya': '3403', 'lait de coco': '2565', 'tofu': '4911', 'gingembre': '2091',
      'haricots noirs': '3376', 'avocat': '1511', 'coriandre': '2067', 'jalapeño': '4860',
      'pois chiches': '3389', 'lentilles': '3392', 'curcuma': '211', 'curry': '183',
      'épinard': '2213', 'champignon': '2399', 'citron': '1587', 'pomme': '1696',
      'saumon': '3182', 'crevettes': '3211', 'bacon': '1936', 'beurre d\'arachide': '6289',
      'cacao': '4223', 'brisures de chocolat': '4148', 'mayonnaise': '531', 'pâte de tomate': '2258',
      'bouillon de poulet': '6541', 'cassonade': '4317', 'riz basmati': '4471',
    };
    cases.forEach((name, code) {
      final ref = cnf.resolveMatch(Ingredient(name: name), {});
      expect(ref.foodCode, code, reason: '"$name" should seed-match $code (${cnf.cnfName(code, 'fr')})');
    });
  });

  test('alias resolution wins over fuzzy match', () {
    // pick any food code and alias "beurre" to it
    final code = cnf.foods.first.code;
    final ref = cnf.resolveMatch(Ingredient(name: 'Beurre', quantity: 30, unit: 'g'), {'beurre': code});
    expect(ref.foodCode, code);
    expect(ref.fromAlias, true);
    expect(ref.confidence, 1);
  });
}
