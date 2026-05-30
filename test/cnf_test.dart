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

  test('alias resolution wins over fuzzy match', () {
    // pick any food code and alias "beurre" to it
    final code = cnf.foods.first.code;
    final ref = cnf.resolveMatch(Ingredient(name: 'Beurre', quantity: 30, unit: 'g'), {'beurre': code});
    expect(ref.foodCode, code);
    expect(ref.fromAlias, true);
    expect(ref.confidence, 1);
  });
}
