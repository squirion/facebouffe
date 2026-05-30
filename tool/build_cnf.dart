// Processes Health Canada's Canadian Nutrient File CSVs (tool/cnf_src/) into a
// compact assets/cnf.json: one entry per food with the 13 label nutrients per
// 100 g, plus grams-per-millilitre (density) and grams-per-piece derived from
// the food's household measures (Conversion Factor × 100 = grams for a measure).
//
// Run: dart run tool/build_cnf.dart
import 'dart:convert';
import 'dart:io';

const _src = 'tool/cnf_src';

// Output nutrient order (index-aligned in each food's "n" array).
const _nutrientOrder = ['kcal', 'protein', 'fat', 'satFat', 'transFat', 'carbs', 'fiber', 'sugars', 'cholesterol', 'sodium', 'potassium', 'calcium', 'iron'];
// CNF NutrientID → our key.
const _nutrientIds = {
  208: 'kcal', 203: 'protein', 204: 'fat', 606: 'satFat', 605: 'transFat',
  205: 'carbs', 291: 'fiber', 269: 'sugars', 601: 'cholesterol',
  307: 'sodium', 306: 'potassium', 301: 'calcium', 303: 'iron',
};

List<String> _csvLine(String line) {
  final out = <String>[];
  final sb = StringBuffer();
  bool inQ = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        sb.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == ',') {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(ch);
    }
  }
  out.add(sb.toString());
  return out;
}

Iterable<List<String>> _rows(String file) sync* {
  final text = latin1.decode(File('$_src/$file').readAsBytesSync());
  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    yield _csvLine(lines[i]);
  }
}

double? _num(String s) => double.tryParse(s.trim());

double? _median(List<double> xs) {
  if (xs.isEmpty) return null;
  xs.sort();
  return xs[xs.length ~/ 2];
}

void main() {
  // FOOD NAME: FoodID, FoodCode, FoodGroupID, FoodSourceID, FoodDescription(EN), FoodDescriptionF(FR)
  final foods = <String, Map<String, dynamic>>{}; // FoodID -> entry
  for (final r in _rows('FOOD NAME.csv')) {
    if (r.length < 6) continue;
    final id = r[0].trim();
    foods[id] = {
      'c': r[1].trim(),
      'en': r[4].trim(),
      'fr': r[5].trim(),
      '_n': <String, double>{},
      '_gml': <double>[],
      '_gpc': <double>[],
    };
  }

  // NUTRIENT AMOUNT: FoodID, NutrientID, NutrientValue
  for (final r in _rows('NUTRIENT AMOUNT.csv')) {
    if (r.length < 3) continue;
    final key = _nutrientIds[int.tryParse(r[1].trim())];
    if (key == null) continue;
    final f = foods[r[0].trim()];
    if (f == null) continue;
    final v = _num(r[2]);
    if (v != null) (f['_n'] as Map<String, double>)[key] = v;
  }

  // MEASURE NAME: MeasureID, MeasureDescription(EN), MeasureDescriptionF(FR)
  final measures = <String, String>{}; // MeasureID -> EN desc
  for (final r in _rows('MEASURE NAME.csv')) {
    if (r.length < 2) continue;
    measures[r[0].trim()] = r[1].trim();
  }

  // CONVERSION FACTOR: FoodID, MeasureID, ConversionFactorValue  (grams = CF*100)
  for (final r in _rows('CONVERSION FACTOR.csv')) {
    if (r.length < 3) continue;
    final f = foods[r[0].trim()];
    final desc = measures[r[1].trim()];
    final cf = _num(r[2]);
    if (f == null || desc == null || cf == null || cf <= 0) continue;
    final grams = cf * 100;
    final d = desc.toLowerCase();

    // Volume: prefer an explicit "… ml" anywhere (incl. parenthetical), else cup/tbsp/tsp/litre at start.
    double? ml;
    final mlM = RegExp(r'(\d+(?:\.\d+)?)\s*ml').firstMatch(d);
    if (mlM != null) {
      ml = double.tryParse(mlM.group(1)!);
    } else {
      final base = d.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final cup = RegExp(r'^(\d+(?:\.\d+)?)\s*cup').firstMatch(base);
      final tbsp = RegExp(r'^(\d+(?:\.\d+)?)\s*tbsp').firstMatch(base);
      final tsp = RegExp(r'^(\d+(?:\.\d+)?)\s*tsp').firstMatch(base);
      final litre = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:litre|liter)\b').firstMatch(base);
      if (cup != null) {
        ml = double.parse(cup.group(1)!) * 250;
      } else if (tbsp != null) {
        ml = double.parse(tbsp.group(1)!) * 15;
      } else if (tsp != null) {
        ml = double.parse(tsp.group(1)!) * 5;
      } else if (litre != null) {
        ml = double.parse(litre.group(1)!) * 1000;
      }
    }

    if (ml != null && ml > 0) {
      (f['_gml'] as List<double>).add(grams / ml);
    } else {
      // Count: "1 egg", "1 large", "1 medium", "1 slice"… (not a weight/volume unit)
      final base = d.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      final cm = RegExp(r'^(\d+(?:\.\d+)?)\s+([a-zà-ÿ].*)$').firstMatch(base);
      if (cm != null) {
        final word = cm.group(2)!;
        final isMeasureWord = RegExp(r'^(g|gram|kg|oz|ounce|lb|pound|ml|l|litre|liter|cup|tbsp|tsp|tablespoon|teaspoon|fl)\b').hasMatch(word);
        final count = double.tryParse(cm.group(1)!);
        if (!isMeasureWord && count != null && count > 0) {
          (f['_gpc'] as List<double>).add(grams / count);
        }
      }
    }
  }

  // Assemble compact output.
  final out = <Map<String, dynamic>>[];
  for (final f in foods.values) {
    if ((f['c'] as String).isEmpty) continue;
    final nm = f['_n'] as Map<String, double>;
    // Skip foods with no energy AND no macros (pure-water rows etc. keep; but drop totally empty).
    final n = _nutrientOrder.map((k) => (nm[k] ?? 0)).toList();
    final gml = _median(f['_gml'] as List<double>);
    final gpc = _median(f['_gpc'] as List<double>);
    final entry = <String, dynamic>{
      'c': f['c'],
      'fr': f['fr'],
      'en': f['en'],
      'n': n.map((v) => (v * 100).round() / 100).toList(),
    };
    if (gml != null) entry['gml'] = (gml * 1000).round() / 1000;
    if (gpc != null) entry['gpc'] = (gpc * 10).round() / 10;
    out.add(entry);
  }

  final json = jsonEncode({'nutrients': _nutrientOrder, 'foods': out});
  File('assets/cnf.json').writeAsStringSync(json);
  stdout.writeln('Wrote assets/cnf.json — ${out.length} foods, ${(json.length / 1024 / 1024).toStringAsFixed(2)} MB');
  final withGml = out.where((e) => e.containsKey('gml')).length;
  final withGpc = out.where((e) => e.containsKey('gpc')).length;
  stdout.writeln('  density (gml): $withGml · per-piece (gpc): $withGpc');
}
