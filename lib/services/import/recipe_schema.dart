import 'dart:convert';

import '../../data/models.dart';
import '../recipe_import.dart' show ImportResult, ImportException;

/// The unit enum the editor accepts; the model must emit one of these or null.
const List<String> kImportUnits = ['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'oz', 'lb', 'pinch'];

/// Strict instruction handed to any AI tier (BYOK or on-device). Keeps the
/// recipe in its original language, constrains units to the editor's enum, and
/// demands JSON only — we still validate and the user still reviews.
const String kImportPrompt = '''
You convert a recipe (given as text, HTML, or an image) into strict JSON for a recipe app.
Return ONLY a single JSON object — no markdown, no code fences, no commentary.

Rules:
- Keep all text in the recipe's ORIGINAL language (usually French or English). Do not translate.
- "unit" must be one of: "g","kg","ml","l","tsp","tbsp","cup","oz","lb","pinch" — or null for countable items (e.g. eggs) or when unknown.
- "quantity" is a number (use decimals, e.g. 0.5) or null.
- Put each cooking step in "steps" as a sentence. Write temperatures inline as text like "180 °C" or "350 °F".
- "tags" is an array of short lowercase keyword strings (e.g. "dessert","souper") — best-effort, may be empty.
- Numbers for servings/prepTimeMinutes/cookTimeMinutes; use 0 if unknown.

JSON shape:
{
  "title": string,
  "description": string,
  "source": string,
  "servings": number,
  "prepTimeMinutes": number,
  "cookTimeMinutes": number,
  "tags": [string],
  "ingredients": [ { "quantity": number|null, "unit": string|null, "name": string, "note": string } ],
  "steps": [ { "text": string, "timerSeconds": number|null } ]
}
''';

/// Pull the first balanced JSON object out of a model response that may be
/// wrapped in prose or ```json fences.
String _extractJson(String raw) {
  var s = raw.trim();
  // strip a leading ```json / ``` fence and trailing ```
  s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) throw ImportException('bad_json');
  return s.substring(start, end + 1);
}

num? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

int _intOr(dynamic v, int fallback) => _numOrNull(v)?.round() ?? fallback;

String? _unit(dynamic v) {
  if (v == null) return null;
  final u = v.toString().trim().toLowerCase();
  if (u.isEmpty || u == 'null' || u == 'none') return null;
  return kImportUnits.contains(u) ? u : null; // out-of-enum → treat as unitless
}

/// Validate model JSON and map it to a reviewable draft [ImportResult].
/// Throws [ImportException] when the payload isn't a usable recipe.
ImportResult draftFromModelJson(String raw, {String? source}) {
  final Map<String, dynamic> j;
  try {
    j = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
  } catch (_) {
    final snip = raw.trim();
    throw ImportException('bad_json', 'Model output was not valid JSON.\n--- raw (${raw.length} chars) ---\n${snip.length > 800 ? snip.substring(0, 800) : snip}');
  }

  final title = (j['title'] as String? ?? '').trim();
  final rawIngredients = (j['ingredients'] as List?) ?? const [];
  final rawSteps = (j['steps'] as List?) ?? const [];
  if (title.isEmpty && rawIngredients.isEmpty && rawSteps.isEmpty) {
    throw ImportException('no_recipe');
  }

  final ingredients = <Ingredient>[];
  for (final e in rawIngredients) {
    if (e is! Map) continue;
    final name = (e['name'] as String? ?? '').trim();
    if (name.isEmpty) continue;
    final note = (e['note'] as String? ?? '').trim();
    ingredients.add(Ingredient(
      quantity: _numOrNull(e['quantity']),
      unit: _unit(e['unit']),
      name: name,
      note: note.isEmpty ? null : note,
    ));
  }

  final steps = <Step>[];
  for (final e in rawSteps) {
    final text = (e is Map ? (e['text'] as String? ?? '') : e.toString()).trim();
    if (text.isEmpty) continue;
    final secs = e is Map ? _numOrNull(e['timerSeconds'])?.round() : null;
    steps.add(Step(text: text, timerSeconds: (secs != null && secs > 0) ? secs : null));
  }

  final tags = <String>[];
  for (final t in (j['tags'] as List? ?? const [])) {
    final s = t.toString().trim();
    if (s.isNotEmpty) tags.add(s);
  }

  final recipe = Recipe(
    id: '',
    title: title.isEmpty ? '' : title,
    description: (j['description'] as String? ?? '').trim(),
    source: source ?? ((j['source'] as String?)?.trim().isNotEmpty == true ? (j['source'] as String).trim() : null),
    servings: _intOr(j['servings'], 4).clamp(1, 999),
    prepTimeMinutes: _intOr(j['prepTimeMinutes'], 0).clamp(0, 100000),
    cookTimeMinutes: _intOr(j['cookTimeMinutes'], 0).clamp(0, 100000),
    ingredients: ingredients.isEmpty ? [Ingredient(name: '')] : ingredients,
    steps: steps.isEmpty ? [Step(text: '')] : steps,
  );

  return ImportResult(recipe, tags, null);
}
