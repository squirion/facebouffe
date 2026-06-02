import 'dart:convert';

import '../../data/models.dart';
import '../recipe_import.dart' show ImportResult, ImportException;

/// The unit enum the editor accepts; the model must emit one of these or null.
const List<String> kImportUnits = ['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'oz', 'lb', 'pinch'];

/// Strict instruction handed to any AI tier (BYOK or on-device). Keeps the
/// recipe in its original language, constrains units to the editor's enum, and
/// demands JSON only — we still validate and the user still reviews. The
/// one-shot example + "no quotes inside strings" rule keep small on-device
/// models from emitting the malformed JSON they otherwise tend to.
const String kImportPrompt = '''
You convert a recipe into strict JSON for a recipe app.
Output ONLY one JSON object — no markdown, no ``` fences, no text before or after.
NEVER put a double-quote (") inside a string value.

Rules:
- Keep all text in the recipe's ORIGINAL language (usually French). Do not translate.
- "unit" must be EXACTLY one of: "g","kg","ml","l","tsp","tbsp","cup","oz","lb","pinch" — or null for countable items (e.g. eggs) or when unknown. The unit is the measure only, NEVER an ingredient name.
- "quantity" is a number (decimals allowed, e.g. 0.5) or null.
- "servings","prepTimeMinutes","cookTimeMinutes" are numbers (0 if unknown).
- Each cooking step is one sentence in "steps"; write temperatures inline like "180 °C".
- "group" is OPTIONAL on an ingredient or step: a short section name (e.g. "Pâte", "Garniture", "Glaçage") when the recipe has labelled parts. Use the SAME wording for items in the same part. Omit it or use null when the recipe has no sections.
- "tags": short lowercase keywords (e.g. "dessert"); may be empty [].

Example of a valid answer:
{"title":"Crêpes","description":"Recette simple.","source":"","servings":4,"prepTimeMinutes":10,"cookTimeMinutes":15,"tags":["dejeuner"],"ingredients":[{"quantity":250,"unit":"g","name":"farine tout usage","note":""},{"quantity":2,"unit":null,"name":"oeufs","note":"gros"},{"quantity":500,"unit":"ml","name":"lait","note":""}],"steps":[{"text":"Mélanger la farine, les oeufs et le lait.","timerSeconds":null},{"text":"Cuire chaque crêpe à feu moyen.","timerSeconds":null}]}''';

/// Region-guided import uses TWO single-purpose calls (one per region) so a
/// small model can't bleed step text into ingredient notes or vice-versa.
const String kPromptIngredients = '''
Extract ONLY the ingredients from the text below into JSON.
Output ONLY one JSON object: {"ingredients":[{"quantity":number|null,"unit":string|null,"name":string,"note":string}]}
Rules:
- One entry per ingredient. Keep the ORIGINAL language. No markdown, nothing outside the JSON.
- "unit" must be EXACTLY one of "g","kg","ml","l","tsp","tbsp","cup","oz","lb","pinch" — or null for countable items / when unknown.
- "quantity" is a number or null.
- "name" is the ingredient only; "note" is a SHORT qualifier (e.g. "fondu", "haché", "à température pièce") or "". NEVER put cooking steps, sentences, or instructions in "name" or "note".''';

const String kPromptSteps = '''
Extract ONLY the cooking steps from the text below into JSON.
Output ONLY one JSON object: {"steps":[{"text":string,"timerSeconds":number|null}]}
Rules:
- One entry per step; "text" is a single instruction sentence. Write temperatures inline like "180 °C".
- Keep the ORIGINAL language. No markdown, nothing outside the JSON. Do NOT include the ingredient list.''';

/// Parse a (possibly messy) model response into a loose JSON map — used to pull
/// a single field (ingredients[] or steps[]) out of a per-region call.
Map<String, dynamic> parseModelJsonLoose(String raw) => _parseModelJson(raw);

String _stripFences(String raw) => raw
    .trim()
    .replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '')
    .replaceAll(RegExp(r'\s*```$'), '')
    .replaceAll('<end_of_turn>', '') // Gemma
    .replaceAll('<eos>', '')
    .replaceAll('<|im_end|>', '') // Qwen / ChatML
    .replaceAll('<|endoftext|>', '')
    .replaceAll('<|end|>', '') // Phi
    .replaceAll('<|assistant|>', '')
    .trim();

Map<String, dynamic>? _tryDecode(String s) {
  try {
    final v = jsonDecode(s);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

// Small LLMs routinely drop the comma between a value and the next "key" (e.g.
// `"unit": "g"\n  "name"`). Insert it.
String _insertMissingCommas(String s) =>
    s.replaceAllMapped(RegExp(r'([}\]"]|\d|true|false|null)(\s*\r?\n\s*)(")'), (m) => '${m[1]},${m[2]}${m[3]}');

// Close a truncated JSON: track bracket depth (ignoring string contents) and
// append the missing closers so a cut-off response still parses.
String _balance(String s) {
  final stack = <String>[];
  var inStr = false, esc = false;
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == '\\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == '{') {
      stack.add('}');
    } else if (c == '[') {
      stack.add(']');
    } else if ((c == '}' || c == ']') && stack.isNotEmpty) {
      stack.removeLast();
    }
  }
  final buf = StringBuffer(s);
  if (inStr) buf.write('"');
  for (var i = stack.length - 1; i >= 0; i--) {
    buf.write(stack[i]);
  }
  return buf.toString();
}

/// Best-effort parse of a model response: strip fences/turn tokens, then try the
/// raw object, a comma-repaired version, and a bracket-balanced (de-truncated)
/// version in turn. Throws bad_json (with the raw output) if none parse.
Map<String, dynamic> _parseModelJson(String raw) {
  final s = _stripFences(raw);
  final start = s.indexOf('{');
  if (start >= 0) {
    final end = s.lastIndexOf('}');
    final clipped = end > start ? s.substring(start, end + 1) : s.substring(start);
    final fromStart = s.substring(start);
    for (final candidate in [clipped, _insertMissingCommas(clipped), _balance(_insertMissingCommas(fromStart))]) {
      final m = _tryDecode(candidate);
      if (m != null) return m;
    }
  }
  final snip = raw.trim();
  throw ImportException('bad_json', 'Model output was not valid JSON.\n--- raw (${raw.length} chars) ---\n${snip.length > 800 ? snip.substring(0, 800) : snip}');
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

/// Optional section label on an imported item; null/blank/"null" → ungrouped.
String? _group(dynamic v) {
  if (v == null) return null;
  final g = v.toString().trim();
  return (g.isEmpty || g.toLowerCase() == 'null') ? null : g;
}

/// Validate model JSON and map it to a reviewable draft [ImportResult].
/// Throws [ImportException] when the payload isn't a usable recipe.
ImportResult draftFromModelJson(String raw, {String? source}) {
  final j = _parseModelJson(raw);

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
      group: _group(e['group']),
    ));
  }

  final steps = <Step>[];
  for (final e in rawSteps) {
    final text = (e is Map ? (e['text'] as String? ?? '') : e.toString()).trim();
    if (text.isEmpty) continue;
    final secs = e is Map ? _numOrNull(e['timerSeconds'])?.round() : null;
    steps.add(Step(text: text, timerSeconds: (secs != null && secs > 0) ? secs : null, group: e is Map ? _group(e['group']) : null));
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
