// Formatting & conversion utilities — ported from fb-core.js.
// Friendly fractions, same-dimension unit conversion, inline temperature
// tokens, and friendly dates. All display-time only; storage keeps authored
// values to avoid accumulating rounding error.
import 'i18n.dart';

class UnitPrefs {
  final String temperature; // celsius | fahrenheit
  final String volume; // metric | imperial
  final String weight; // metric | imperial
  const UnitPrefs({required this.temperature, required this.volume, required this.weight});
}

// ── Friendly fractions ──────────────────────────────────────────
const List<List<dynamic>> _fractions = [
  [1 / 8, '⅛'], [1 / 4, '¼'], [1 / 3, '⅓'], [3 / 8, '⅜'], [1 / 2, '½'],
  [5 / 8, '⅝'], [2 / 3, '⅔'], [3 / 4, '¾'], [7 / 8, '⅞'],
];

String fmtQty(num? n) {
  if (n == null || n.isNaN) return '';
  if (n == 0) return '0';
  final sign = n < 0 ? '-' : '';
  n = n.abs();
  final whole = n.floor();
  final frac = n - whole;
  String? best;
  double bestErr = 0.04;
  for (final f in _fractions) {
    final err = (frac - (f[0] as double)).abs();
    if (err < bestErr) {
      best = f[1] as String;
      bestErr = err;
    }
  }
  if (frac < 0.02) return '$sign$whole';
  if (best != null) return sign + (whole > 0 ? '$whole $best' : best);
  num rounded = (n * 100).round() / 100;
  if (rounded >= 10) rounded = (n * 10).round() / 10;
  return sign + _trimNum(rounded);
}

String _trimNum(num n) {
  var s = n.toString();
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// ── Units ───────────────────────────────────────────────────────
const Map<String, Map<String, String>> _unitLabel = {
  'fr': {'g': 'g', 'kg': 'kg', 'ml': 'ml', 'l': 'l', 'tsp': 'c. à thé', 'tbsp': 'c. à soupe', 'cup': 'tasse', 'oz': 'oz', 'lb': 'lb', 'pinch': 'pincée', 'floz': 'oz liq.'},
  'en': {'g': 'g', 'kg': 'kg', 'ml': 'ml', 'l': 'l', 'tsp': 'tsp', 'tbsp': 'tbsp', 'cup': 'cup', 'oz': 'oz', 'lb': 'lb', 'pinch': 'pinch', 'floz': 'fl oz'},
};

String unitLabel(String? unit, String lang, [num? qty]) {
  if (unit == null) return '';
  final l = _unitLabel[lang]?[unit] ?? unit;
  if (qty != null && qty > 1) {
    if (unit == 'cup' && lang == 'en') return 'cups';
    if (unit == 'cup' && lang == 'fr') return 'tasses';
    if (unit == 'pinch' && lang == 'en') return 'pinches';
  }
  return l;
}

const Map<String, double> _toBase = {
  'g': 1, 'kg': 1000, 'ml': 1, 'l': 1000, 'tsp': 4.92892, 'tbsp': 14.7868,
  'cup': 236.588, 'floz': 29.5735, 'oz': 28.3495, 'lb': 453.592,
};
const _weightUnits = ['g', 'kg', 'oz', 'lb'];
const _volumeUnits = ['ml', 'l', 'tsp', 'tbsp', 'cup', 'floz'];
const _smallPass = ['tsp', 'tbsp', 'pinch'];

String? dimensionOf(String? unit) {
  if (_weightUnits.contains(unit)) return 'weight';
  if (_volumeUnits.contains(unit)) return 'volume';
  return null;
}

class QtyUnit {
  final num? quantity;
  final String? unit;
  const QtyUnit(this.quantity, this.unit);
}

QtyUnit convertIngredientUnit(num? qty, String? unit, UnitPrefs prefs) {
  if (qty == null || unit == null) return QtyUnit(qty, unit);
  if (_smallPass.contains(unit)) return QtyUnit(qty, unit);
  final dim = dimensionOf(unit);
  if (dim == null) return QtyUnit(qty, unit);
  final base = qty * _toBase[unit]!;
  if (dim == 'weight') {
    if (prefs.weight == 'imperial') {
      if (base >= _toBase['lb']! * 0.9) return QtyUnit(base / _toBase['lb']!, 'lb');
      return QtyUnit(base / _toBase['oz']!, 'oz');
    }
    if (base >= 1000) return QtyUnit(base / 1000, 'kg');
    return QtyUnit(base, 'g');
  }
  // volume
  if (prefs.volume == 'imperial') {
    if (base >= _toBase['cup']! * 0.95) return QtyUnit(base / _toBase['cup']!, 'cup');
    return QtyUnit(base / _toBase['floz']!, 'floz');
  }
  if (base >= 1000) return QtyUnit(base / 1000, 'l');
  return QtyUnit(base, 'ml');
}

String fmtQtyForUnit(num? qty, String? unit) {
  if (qty == null || qty.isNaN) return '';
  if (unit == 'g' || unit == 'ml') {
    if (qty >= 20) return qty.round().toString();
    return fmtQty((qty * 10).round() / 10);
  }
  if (unit == 'kg' || unit == 'l') {
    return _trimNum((qty * 100).round() / 100);
  }
  return fmtQty(qty);
}

class DisplayIngredient {
  final String qtyText;
  final String unitText;
  final String name;
  final String? note;
  const DisplayIngredient(this.qtyText, this.unitText, this.name, this.note);
}

DisplayIngredient displayIngredient(num? quantity, String? unit, String name, String? note, double ratio, UnitPrefs prefs, String lang) {
  num? qty = quantity == null ? null : quantity * ratio;
  String? u = unit;
  if (qty != null && u != null) {
    final conv = convertIngredientUnit(qty, u, prefs);
    qty = conv.quantity;
    u = conv.unit;
  }
  return DisplayIngredient(fmtQtyForUnit(qty, u), unitLabel(u, lang, qty), name, (note != null && note.isEmpty) ? null : note);
}

// ── Time ────────────────────────────────────────────────────────
String fmtDuration(int? min, String lang) {
  if (min == null) return '—';
  if (min < 60) return '$min ${tr(lang, "min")}';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '$h ${tr(lang, "hours")}' : '$h ${tr(lang, "hours")} ${m < 10 ? "0" : ""}$m';
}

String fmtTimer(int? sec) {
  if (sec == null) return '';
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s < 10 ? "0" : ""}$s';
}

String? fmtDate(String? iso, String lang) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final u = d.toUtc();
  final m = kMonths[lang]![u.month - 1];
  return lang == 'fr' ? '${u.day} $m ${u.year}' : '$m ${u.day}, ${u.year}';
}

String fmtRelDate(String? iso, String lang) {
  if (iso == null) return tr(lang, 'never_cooked');
  final d = DateTime.tryParse(iso);
  if (d == null) return tr(lang, 'never_cooked');
  final now = DateTime.parse('2026-05-28T00:00:00Z');
  final days = (now.difference(d).inMilliseconds / 86400000).round();
  if (days <= 0) return lang == 'fr' ? 'aujourd\'hui' : 'today';
  if (days == 1) return lang == 'fr' ? 'hier' : 'yesterday';
  if (days < 7) return lang == 'fr' ? 'il y a $days jours' : '$days days ago';
  if (days < 14) return lang == 'fr' ? 'la semaine dernière' : 'last week';
  if (days < 60) return lang == 'fr' ? 'il y a ${(days / 7).round()} semaines' : '${(days / 7).round()} weeks ago';
  return fmtDate(iso, lang) ?? '';
}

// ── Temperatures — inline {{temp:value:unit}} tokens ────────────
String prefTempUnit(UnitPrefs prefs) => prefs.temperature == 'fahrenheit' ? 'f' : 'c';

String fmtTemp(num value, String unit, String prefUnit) {
  unit = unit.toLowerCase();
  if (unit == prefUnit) {
    final n = (value % 1).abs() < 0.01 ? value.round() : value;
    return '$n °${unit.toUpperCase()}';
  }
  num conv = unit == 'c' ? value * 9 / 5 + 32 : (value - 32) * 5 / 9;
  conv = (conv / 5).round() * 5; // nearest 5° in target unit (intentional)
  return '$conv °${prefUnit.toUpperCase()}';
}

// number immediately followed by an explicit C/F marker
final RegExp tempRe = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:°\s*([cCfF])|([℃℉]))');

String _unitFrom(String? letter, String? glyph) {
  if (glyph == '℃') return 'c';
  if (glyph == '℉') return 'f';
  return (letter ?? '').toLowerCase();
}

class TempMatch {
  final num value;
  final String unit;
  const TempMatch(this.value, this.unit);
}

List<TempMatch> findTemps(String? text) {
  final out = <TempMatch>[];
  for (final m in tempRe.allMatches(text ?? '')) {
    out.add(TempMatch(num.parse(m.group(1)!.replaceAll(',', '.')), _unitFrom(m.group(2), m.group(3))));
  }
  return out;
}

String tokenizeTemps(String? text) {
  return (text ?? '').replaceAllMapped(tempRe, (m) =>
      '{{temp:${m.group(1)!.replaceAll(',', '.')}:${_unitFrom(m.group(2), m.group(3))}}}');
}

final RegExp _detokRe = RegExp(r'\{\{temp:([0-9.]+):([cfCF])\}\}');
String detokenizeTemps(String? text) {
  return (text ?? '').replaceAllMapped(_detokRe, (m) => '${m.group(1)} °${m.group(2)!.toUpperCase()}');
}
