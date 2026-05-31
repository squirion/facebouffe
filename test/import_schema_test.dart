import 'package:flutter_test/flutter_test.dart';
import 'package:facebouffe/services/import/recipe_schema.dart';
import 'package:facebouffe/services/recipe_import.dart' show ImportException;

void main() {
  test('maps clean model JSON to a draft', () {
    const raw = '''
{
  "title": "Tarte au sucre",
  "description": "Un classique.",
  "servings": 8, "prepTimeMinutes": 15, "cookTimeMinutes": 35,
  "tags": ["dessert"],
  "ingredients": [
    {"quantity": 250, "unit": "g", "name": "cassonade", "note": ""},
    {"quantity": 1, "unit": null, "name": "oeuf", "note": "gros"}
  ],
  "steps": [ {"text": "Préchauffer le four à 180 °C.", "timerSeconds": null},
             {"text": "Cuire.", "timerSeconds": 2100} ]
}''';
    final res = draftFromModelJson(raw, source: 'Importé d\'un texte');
    expect(res.recipe.title, 'Tarte au sucre');
    expect(res.recipe.servings, 8);
    expect(res.recipe.ingredients.length, 2);
    expect(res.recipe.ingredients[1].unit, isNull); // countable egg
    expect(res.recipe.steps[1].timerSeconds, 2100);
    expect(res.suggestedTags, contains('dessert'));
    expect(res.recipe.source, 'Importé d\'un texte');
  });

  test('strips code fences and clamps out-of-enum units to null', () {
    const raw = '```json\n{"title":"X","ingredients":[{"quantity":"2","unit":"cloves","name":"ail"}],"steps":[{"text":"Go"}]}\n```';
    final res = draftFromModelJson(raw);
    expect(res.recipe.title, 'X');
    expect(res.recipe.ingredients.first.unit, isNull); // "cloves" not in enum
    expect(res.recipe.ingredients.first.quantity, 2); // string number parsed
  });

  test('repairs missing commas from small-model output', () {
    const raw = '{"title":"X","ingredients":[{"quantity":250,"unit":"g"\n"name":"cassonade"}],"steps":[{"text":"Go"}]}';
    final res = draftFromModelJson(raw);
    expect(res.recipe.title, 'X');
    expect(res.recipe.ingredients.first.name, 'cassonade');
    expect(res.recipe.ingredients.first.unit, 'g');
  });

  test('salvages a truncated response by balancing brackets', () {
    const raw = '{"title":"Tarte","ingredients":[{"quantity":1,"unit":null,"name":"oeuf"}],"steps":[{"text":"Préc';
    final res = draftFromModelJson(raw);
    expect(res.recipe.title, 'Tarte');
    expect(res.recipe.ingredients.first.name, 'oeuf');
  });

  test('throws on non-JSON and on empty recipe', () {
    expect(() => draftFromModelJson('sorry, I cannot help'), throwsA(isA<ImportException>()));
    expect(() => draftFromModelJson('{"title":"","ingredients":[],"steps":[]}'), throwsA(isA<ImportException>()));
  });
}
