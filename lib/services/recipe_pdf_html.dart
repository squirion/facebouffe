// Builds a complete, self-contained print-ready HTML document for one or more
// recipes — the "glorious" editorial cookbook page. Mirrors the Claude Design
// mockup (MockUp/Recipe PDF.html + recipe-pdf.js) exactly: same CSS, same
// measure-based paginator. The difference is the *source* of each block's HTML —
// here every block is pre-rendered in Dart using the app's own formatters
// (lib/data/format.dart), the single source of truth, so output matches the
// recipe screen and the mockup. Fonts (Newsreader + Hanken Grotesk) and images
// are embedded so rendering is fully offline and identical on web + Android.
//
// The returned string is loaded into a real browser engine (hidden iframe on
// web, headless WebView on Android — see recipe_pdf_print.dart) and printed to
// PDF. Only the irreducibly DOM-dependent paginator runs as JS in the engine.
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

import '../data/format.dart';
import '../data/i18n.dart';
import '../data/models.dart';
import '../theme.dart' show fallbackColorFor;
import 'cnf.dart' show dvPct;

/// Per-recipe images already resolved to `data:` URIs (or direct URLs on web).
/// A null entry means "no image" → the colored fallback panel is used.
class ResolvedImages {
  final String? hero;
  final List<String> gallery; // index-aligned with recipe.gallery (resolved only)
  final List<String?> steps; // index-aligned with recipe.steps
  const ResolvedImages({this.hero, this.gallery = const [], this.steps = const []});
}

/// Builds the full HTML document. [paper] is 'letter' or 'a4'. [images] maps a
/// recipe id to its resolved images. [resolveRecipe] resolves `{{link:id}}`
/// tokens and "see also" entries to their recipe (for the title).
Future<String> buildRecipePdfHtml({
  required List<Recipe> recipes,
  required String lang,
  required UnitPrefs prefs,
  required Map<String, Tag> tagsById,
  required String paper,
  required Map<String, ResolvedImages> images,
  required Recipe? Function(String? id) resolveRecipe,
}) async {
  final fontCss = await _fontFaceCss();

  final recipesJson = recipes.map((r) {
    final imgs = images[r.id];
    final items = <Map<String, dynamic>>[];

    items.add({'kind': 'atomic', 'html': _openerBlock(r, lang, tagsById, imgs)});
    items.add({'kind': 'atomic', 'html': _metaBlock(r, lang)});
    final hn = _headnoteBlock(r, prefs, lang, resolveRecipe);
    if (hn != null) items.add({'kind': 'atomic', 'html': hn});

    // Body flows through two newspaper columns: ingredients first (down the left
    // column, into the right, onto the next page), then a column break, then the
    // preparation steps. Section headers appear once — it reads as one journal flow.
    final ingTitle = tr(lang, 'ingredients');
    final stepTitle = tr(lang, 'steps');
    final flow = <Map<String, dynamic>>[];
    flow.add({'html': '<div class="block sec-head-block">${_sectionHeadHTML(ingTitle, '', false)}</div>'});
    for (final row in _ingredientRows(r, prefs, lang)) {
      flow.add({'html': row});
    }
    flow.add({'brk': true}); // column break before the steps
    flow.add({'html': '<div class="block sec-head-block">${_sectionHeadHTML(stepTitle, '', false)}</div>'});
    for (final row in _stepRows(r, imgs, prefs, lang, resolveRecipe)) {
      flow.add({'html': row});
    }
    // Nutrition Facts table — its own column after a forced break, no text summary.
    if (r.nutrition != null) {
      flow.add({'brk': true});
      flow.add({'html': '<div class="block b-nutrition">${_nutritionLabelHTML(r.nutrition!, lang, r.effectiveTotalWeightG)}</div>'});
    }
    items.add({'kind': 'flow', 'blocks': flow});

    if (r.personal.notes.trim().isNotEmpty) items.add({'kind': 'atomic', 'html': _noteBlock(r, lang)});
    final gal = _galleryBlock(r, lang, imgs?.gallery ?? const []);
    if (gal.isNotEmpty) items.add({'kind': 'atomic', 'html': gal});
    final see = _seeAlsoBlock(r, lang, resolveRecipe);
    if (see.isNotEmpty) items.add({'kind': 'atomic', 'html': see});

    return {
      'recipe': {
        'title': _esc(r.title),
        'category': _esc(_categoryLabel(r, lang, tagsById).toUpperCase()),
        'footLeft': _esc((r.source != null && r.source!.isNotEmpty)
            ? r.source!
            : (lang == 'fr' ? 'Carnet de recettes' : 'Recipe book')),
      },
      'items': items,
    };
  }).toList();

  // Guard against a literal "</script>" inside any recipe text breaking the tag.
  final dataJson = jsonEncode({'recipes': recipesJson}).replaceAll('</', '<\\/');
  final a4 = paper == 'a4';
  final pageSize = a4 ? 'A4' : 'Letter';
  // The print frameworks use the document title as the suggested PDF filename.
  final docTitle = recipes.length == 1 ? recipes.first.title : 'Facebouffe';

  return '<!DOCTYPE html>\n'
      '<html lang="${_esc(lang)}"${a4 ? ' class="a4"' : ''}>\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
      '<title>${_esc(docTitle)}</title>\n'
      '<style>\n$fontCss\n$_kCss\n</style>\n'
      '<style id="print-size">@page { size: $pageSize; margin: 0; }</style>\n'
      '</head>\n'
      '<body>\n'
      '<div id="doc"></div>\n'
      '<script id="fb-pages-data" type="application/json">$dataJson</script>\n'
      '<script>\n$_kPaginatorJs\n</script>\n'
      '</body>\n'
      '</html>';
}

// ── fonts ────────────────────────────────────────────────────────
String? _fontCssCache;
Future<String> _fontFaceCss() async {
  if (_fontCssCache != null) return _fontCssCache!;
  Future<String> face(String family, String style, String weights, String asset) async {
    final data = await rootBundle.load('assets/fonts/$asset');
    final b64 = base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return "@font-face{font-family:'$family';font-style:$style;font-weight:$weights;font-display:block;"
        "src:url(data:font/ttf;base64,$b64) format('truetype');}";
  }

  final parts = await Future.wait([
    face('Newsreader', 'normal', '200 800', 'Newsreader.ttf'),
    face('Newsreader', 'italic', '200 800', 'Newsreader-Italic.ttf'),
    face('Hanken Grotesk', 'normal', '100 900', 'HankenGrotesk.ttf'),
    face('Hanken Grotesk', 'italic', '100 900', 'HankenGrotesk-Italic.ttf'),
  ]);
  return _fontCssCache = parts.join('\n');
}

// ── tiny helpers ─────────────────────────────────────────────────
String _esc(Object? s) => (s == null ? '' : s.toString())
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _colorHex(Color c) {
  String h(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

List<Tag> _nonFavTags(Recipe r, Map<String, Tag> tagsById) =>
    r.tags.where((id) => id != 'tag-fav').map((id) => tagsById[id]).whereType<Tag>().toList();

String _categoryLabel(Recipe r, String lang, Map<String, Tag> tagsById) {
  final t = _nonFavTags(r, tagsById);
  if (t.isNotEmpty) return t.first.displayName(lang);
  return lang == 'fr' ? 'Recette' : 'Recipe';
}

// ── rich text: {{temp:v:u}} → converted, {{link:id}} → recipe title ──
final RegExp _richTok = RegExp(r'\{\{(temp:[0-9.]+:[cfCF]|link:[^}]+)\}\}');

String _renderRich(String? text, UnitPrefs prefs, String lang, Recipe? Function(String?) resolveRecipe) {
  final prefU = prefTempUnit(prefs);
  final src = text ?? '';
  final sb = StringBuffer();
  var last = 0;
  for (final m in _richTok.allMatches(src)) {
    if (m.start > last) sb.write(_esc(src.substring(last, m.start)));
    final tok = m.group(1)!;
    if (tok.startsWith('temp:')) {
      final p = tok.split(':'); // [temp, value, unit]
      sb.write('<span class="rich-temp">${_esc(fmtTemp(num.parse(p[1]), p[2], prefU))}</span>');
    } else {
      final r = resolveRecipe(tok.substring('link:'.length));
      sb.write('<span class="rich-link">${_esc(r?.title ?? '—')}</span>');
    }
    last = m.end;
  }
  if (last < src.length) sb.write(_esc(src.substring(last)));
  return sb.toString();
}

// ── photo frame: <img> when resolved, else color panel + monogram ──
String _heroFrameHTML(Recipe r, String lang, Map<String, Tag> tagsById, ResolvedImages? imgs) {
  final cat = _esc(_categoryLabel(r, lang, tagsById).toUpperCase());
  final hero = imgs?.hero;
  if (hero != null && hero.isNotEmpty) {
    return '<div class="hero hero-photo"><img src="${_esc(hero)}" alt="" '
        'style="display:block;width:100%;height:100%;object-fit:cover;"></div>';
  }
  final pal = fallbackColorFor(r.id.isNotEmpty ? r.id : r.title);
  final t = r.title.trim();
  final initial = _esc((t.isEmpty ? '?' : t[0]).toUpperCase());
  return '<div class="hero hero-fallback" style="background:${_colorHex(pal.bg)};color:${_colorHex(pal.ink)};">'
      '<div class="hero-monogram">$initial</div>'
      '<div class="hero-kicker">$cat</div>'
      '</div>';
}

// ── blocks ────────────────────────────────────────────────────────
String _openerBlock(Recipe r, String lang, Map<String, Tag> tagsById, ResolvedImages? imgs) {
  final chips = _nonFavTags(r, tagsById)
      .map((t) => '<span class="chip"><span class="chip-dot" style="background:${_esc(t.color)}"></span>'
          '${_esc(t.displayName(lang))}</span>')
      .join('');
  final src = (r.source != null && r.source!.isNotEmpty) ? '<div class="opener-source">${_esc(r.source)}</div>' : '';
  return '<div class="block b-opener">'
      '${_heroFrameHTML(r, lang, tagsById, imgs)}'
      '<div class="opener-head">'
      '${chips.isNotEmpty ? '<div class="chips">$chips</div>' : ''}'
      '<h1 class="opener-title">${_esc(r.title)}</h1>'
      '$src'
      '</div>'
      '</div>';
}

String _metaCells(List<List<String>> cells) {
  final sb = StringBuffer();
  for (var i = 0; i < cells.length; i++) {
    if (i > 0) sb.write('<div class="meta-div"></div>');
    sb.write('<div class="meta-cell"><div class="meta-val">${_esc(cells[i][0])}</div>'
        '<div class="meta-lbl">${_esc(cells[i][1])}</div></div>');
  }
  return sb.toString();
}

String _metaBlock(Recipe r, String lang) {
  final cells = [
    [fmtDuration(r.prepTimeMinutes, lang), lang == 'fr' ? 'Préparation' : 'Prep'],
    [fmtDuration(r.cookTimeMinutes, lang), lang == 'fr' ? 'Cuisson' : 'Cook'],
    [fmtDuration(r.totalTime, lang), 'Total'],
    [r.servings.toString(), lang == 'fr' ? 'Portions' : 'Servings'],
  ];
  return '<div class="block b-meta"><div class="meta-strip">${_metaCells(cells)}</div></div>';
}

String? _headnoteBlock(Recipe r, UnitPrefs prefs, String lang, Recipe? Function(String?) resolve) {
  if (r.description.isEmpty) return null;
  final raw = r.description.replaceFirst(RegExp(r'^\s+'), '');
  if (raw.isEmpty) return null;
  final first = raw[0];
  final rest = raw.substring(1);
  final html = '<span class="dropcap">${_esc(first)}</span>${_renderRich(rest, prefs, lang, resolve)}';
  return '<div class="block b-headnote"><p class="headnote">$html</p></div>';
}

String _sectionHeadHTML(String title, String right, bool suite) {
  return '<div class="sec-head">'
      '<span class="sec-rule"></span>'
      '<span class="sec-title">${_esc(title)}${suite ? ' <span class="sec-suite">(suite)</span>' : ''}</span>'
      '${right.isNotEmpty ? '<span class="sec-right">${_esc(right)}</span>' : ''}'
      '</div>';
}

String _ingredientRowHTML(Ingredient ing, UnitPrefs prefs, String lang) {
  final d = displayIngredient(ing.quantity, ing.unit, ing.name, ing.note, 1, prefs, lang);
  final qty = d.qtyText + (d.unitText.isNotEmpty ? ' ${d.unitText}' : '');
  final note = (d.note != null && d.note!.isNotEmpty) ? '<span class="ing-note">${_esc(d.note)}</span>' : '';
  return '<div class="ing-row">'
      '<span class="ing-qty">${_esc(qty.isEmpty ? '—' : qty)}</span>'
      '<span class="ing-main"><span class="ing-name">${_esc(d.name)}</span>$note</span></div>';
}

List<String> _ingredientRows(Recipe r, UnitPrefs prefs, String lang) {
  final rows = <String>[];
  for (final sec in groupedSections<Ingredient>(r.ingredients, (i) => i.group)) {
    if (sec.hasHeader) {
      rows.add('<div class="ing-row-block ing-sub-block"><div class="ing-sub">${_esc(sec.name)}</div></div>');
    }
    for (final ing in sec.items) {
      rows.add('<div class="ing-row-block">${_ingredientRowHTML(ing, prefs, lang)}</div>');
    }
  }
  return rows;
}

String _stepRowHTML(Step step, int idx, String? imgSrc, UnitPrefs prefs, String lang, Recipe? Function(String?) resolve) {
  final img = (imgSrc != null && imgSrc.isNotEmpty)
      ? '<div class="step-photo"><img src="${_esc(imgSrc)}" alt="" '
          'style="display:block;width:100%;height:100%;object-fit:cover;"></div>'
      : '';
  final timer = step.timerSeconds != null
      ? '<span class="step-timer">&#9719; ${_esc(fmtTimer(step.timerSeconds))}</span>'
      : '';
  return '<div class="step-row">'
      '<div class="step-num">${idx + 1}</div>'
      '<div class="step-body"><div class="step-text">${_renderRich(step.text, prefs, lang, resolve)}</div>'
      '${timer.isNotEmpty ? '<div class="step-meta">$timer</div>' : ''}$img</div></div>';
}

List<String> _stepRows(Recipe r, ResolvedImages? imgs, UnitPrefs prefs, String lang, Recipe? Function(String?) resolve) {
  final rows = <String>[];
  for (final sec in groupedSections<Step>(r.steps, (s) => s.group)) {
    if (sec.hasHeader) {
      rows.add('<div class="step-block step-sub-block"><div class="step-sub">${_esc(sec.name)}</div></div>');
    }
    for (var k = 0; k < sec.items.length; k++) {
      final origIdx = sec.indices[k];
      final imgSrc = (imgs != null && origIdx < imgs.steps.length) ? imgs.steps[origIdx] : null;
      rows.add('<div class="step-block">${_stepRowHTML(sec.items[k], origIdx, imgSrc, prefs, lang, resolve)}</div>');
    }
  }
  return rows;
}

// ── nutrition facts label (port of the app's bilingual panel) ──────
String _numStr(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

String _nfNum(num? v, [String? unit]) {
  if (v == null || v.isNaN) return '0${unit != null ? ' $unit' : ''}';
  String s;
  if (unit == 'mg') {
    s = (v.abs() < 10 && v % 1 != 0) ? _numStr((v * 10).round() / 10) : v.round().toString();
  } else if (v.abs() < 10) {
    s = _numStr((v * 10).round() / 10);
  } else {
    s = v.round().toString();
  }
  return s + (unit != null ? ' $unit' : '');
}

String _nfRow(String en, String fr, String amount, int? dv,
    {bool bold = false, bool indent = false, bool plus = false, bool last = false}) {
  final cls = 'nf-row${bold ? ' nf-bold' : ''}${indent ? ' nf-indent' : ''}${plus ? ' nf-plus' : ''}${last ? ' nf-last' : ''}';
  return '<div class="$cls"><div class="nf-name">'
      '<span class="${bold ? 'nf-b' : ''}">$en</span>'
      '<span class="nf-fr"> / $fr</span>'
      '<span class="nf-amt"> $amount</span></div>'
      '${dv != null ? '<div class="nf-dv">$dv %</div>' : ''}</div>';
}

String _nutritionLabelHTML(Nutrition n, String lang, num? totalWeightG) {
  final d = n.perServing;
  num g(String k) => d[k] ?? 0;
  final cal = d['kcal'] ?? d['calories'] ?? 0;
  final basis = n.servingsBasis < 1 ? 1 : n.servingsBasis;
  final hasW = totalWeightG != null && totalWeightG > 0;
  final perW = hasW ? ' (${(totalWeightG / basis).round()} g)' : '';
  final per = (lang == 'fr' ? 'Par 1 portion' : 'Per 1 serving') + perW;
  final satTransDv = dvPct('satTrans', g('satFat') + g('transFat'));
  final foot = lang == 'fr'
      ? "*5 % ou moins c'est peu, 15 % ou plus c'est beaucoup"
      : '*5% or less is a little, 15% or more is a lot';
  return '<div class="nf">'
      '<div class="nf-t1">Nutrition Facts</div>'
      '<div class="nf-t2">Valeur nutritive</div>'
      '<div class="nf-per">$per</div>'
      '<div class="nf-cal"><span>Calories</span><span>${cal.round()}</span></div>'
      '<div class="nf-dvhead">% ${lang == 'fr' ? 'valeur quotidienne' : 'Daily Value'}*</div>'
      '${_nfRow('Fat', 'Lipides', _nfNum(g('fat'), 'g'), dvPct('fat', g('fat')), bold: true)}'
      '${_nfRow('Saturated', 'saturés', _nfNum(g('satFat'), 'g'), satTransDv, indent: true)}'
      '${_nfRow('+ Trans', 'trans', _nfNum(g('transFat'), 'g'), null, indent: true, plus: true)}'
      '${_nfRow('Carbohydrate', 'Glucides', _nfNum(g('carbs'), 'g'), null, bold: true)}'
      '${_nfRow('Fibre', 'Fibres', _nfNum(g('fiber'), 'g'), dvPct('fiber', g('fiber')), indent: true)}'
      '${_nfRow('Sugars', 'Sucres', _nfNum(g('sugars'), 'g'), dvPct('sugars', g('sugars')), indent: true)}'
      '${_nfRow('Protein', 'Protéines', _nfNum(g('protein'), 'g'), null, bold: true)}'
      '${_nfRow('Cholesterol', 'Cholestérol', _nfNum(g('cholesterol'), 'mg'), null, bold: true)}'
      '<div class="nf-thick">${_nfRow('Sodium', 'Sodium', _nfNum(g('sodium'), 'mg'), dvPct('sodium', g('sodium')), bold: true, last: true)}</div>'
      '${_nfRow('Potassium', 'Potassium', _nfNum(g('potassium'), 'mg'), dvPct('potassium', g('potassium')))}'
      '${_nfRow('Calcium', 'Calcium', _nfNum(g('calcium'), 'mg'), dvPct('calcium', g('calcium')))}'
      '${_nfRow('Iron', 'Fer', _nfNum(g('iron'), 'mg'), dvPct('iron', g('iron')), last: true)}'
      '<div class="nf-foot">$foot</div>'
      '</div>';
}

String _noteBlock(Recipe r, String lang) {
  return '<div class="block b-note">'
      '<div class="note-label">${lang == 'fr' ? 'Note du cuisinier' : "Cook's note"}</div>'
      '<p class="note-text">${_esc(r.personal.notes)}</p>'
      '</div>';
}

String _galleryBlock(Recipe r, String lang, List<String> gallerySrcs) {
  final items = gallerySrcs
      .where((s) => s.isNotEmpty)
      .map((s) => '<div class="gal-item"><div class="gal-frame"><img src="${_esc(s)}" alt="" '
          'style="display:block;width:100%;height:100%;object-fit:cover;"></div></div>')
      .join('');
  if (items.isEmpty) return '';
  return '<div class="block b-gallery">${_sectionHeadHTML(tr(lang, 'gallery'), '', false)}'
      '<div class="gal-row">$items</div></div>';
}

String _seeAlsoBlock(Recipe r, String lang, Recipe? Function(String?) resolve) {
  final linked = r.links.map(resolve).whereType<Recipe>().toList();
  if (linked.isEmpty) return '';
  final ls = linked
      .map((lr) => '<div class="see-row"><span class="see-mark">&#10022;</span>'
          '<span class="see-title">${_esc(lr.title)}</span></div>')
      .join('');
  return '<div class="block b-see">${_sectionHeadHTML(tr(lang, 'see_also'), '', false)}$ls</div>';
}

// ── CSS — copied verbatim from MockUp/Recipe PDF.html (toolbar + image-slot
//    rules dropped; two sub-group label rules added). Google-Fonts <link>
//    replaced by the embedded @font-face block (see _fontFaceCss). ─────────────
const String _kCss = r'''
:root {
  --paper: #FFFFFF;
  --paper-edge: #F1E7D6;
  --ink: #2B2620;
  --ink-soft: #736A5E;
  --ink-faint: #A89E90;
  --line: rgba(43,38,32,0.13);
  --line-soft: rgba(43,38,32,0.08);
  --rule: rgba(43,38,32,0.30);
  --accent: #C0563B;
  --accent-soft: rgba(192,86,59,0.10);
  --gold: #C58A2E;
  --serif: "Newsreader", Georgia, "Times New Roman", serif;
  --sans: "Hanken Grotesk", -apple-system, system-ui, sans-serif;
  --page-w: 8.5in;
  --page-h: 11in;
}
html.a4 { --page-w: 8.27in; --page-h: 11.69in; }

* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  background: #cdbfa8;
  background-image:
    radial-gradient(120% 80% at 50% -10%, #d8cbb4 0%, #c4b59c 70%);
  font-family: var(--sans);
  color: var(--ink);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  font-optical-sizing: auto;
  min-height: 100vh;
}

/* Document / sheets */
#doc {
  display: flex; flex-direction: column; align-items: center;
  gap: 26px; padding: 34px 16px 70px;
}
.page {
  position: relative;
  width: var(--page-w); height: var(--page-h);
  background: var(--paper);
  box-shadow: 0 20px 50px rgba(40,28,16,0.34), 0 2px 6px rgba(40,28,16,0.2);
  overflow: hidden;
  flex-shrink: 0;
}
.page::after {
  content: ""; position: absolute; inset: 0; pointer-events: none;
  box-shadow: inset 0 0 0 1px rgba(43,38,32,0.05),
              inset 0 0 90px rgba(120,90,55,0.06);
}
.page-frame {
  position: absolute; inset: 0.30in;
  border: 1px solid var(--rule);
  pointer-events: none;
}
.page-frame::before {
  content: ""; position: absolute; inset: 4px;
  border: 1px solid var(--line-soft);
}
.page-corner {
  position: absolute; width: 13px; height: 13px; pointer-events: none;
  border: 1.5px solid var(--accent);
}
.page-corner.tl { top: calc(0.30in - 4px); left: calc(0.30in - 4px); border-right: none; border-bottom: none; }
.page-corner.tr { top: calc(0.30in - 4px); right: calc(0.30in - 4px); border-left: none; border-bottom: none; }
.page-corner.bl { bottom: calc(0.30in - 4px); left: calc(0.30in - 4px); border-right: none; border-top: none; }
.page-corner.br { bottom: calc(0.30in - 4px); right: calc(0.30in - 4px); border-left: none; border-top: none; }

.page-inner {
  position: absolute; inset: 0.30in;
  padding: 30px 38px 26px;
  display: block;
}

/* Running head / foot */
.runhead {
  display: flex; align-items: baseline; gap: 12px;
  padding-bottom: 9px; border-bottom: 1px solid var(--line);
}
.rh-mark {
  font-family: var(--serif); font-style: italic; font-weight: 600;
  font-size: 14px; color: var(--accent); white-space: nowrap;
}
.rh-title {
  flex: 1; min-width: 0;
  font-family: var(--sans); font-size: 10.5px; font-weight: 600;
  color: var(--ink-faint); letter-spacing: 0.3px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  text-align: center;
}
.rh-cat {
  font-family: var(--sans); font-size: 9.5px; font-weight: 700;
  letter-spacing: 1.4px; color: var(--ink-faint); white-space: nowrap;
}
.content { margin-top: 20px; }
.runfoot {
  position: absolute; left: 38px; right: 38px; bottom: 16px;
  display: flex; align-items: center; gap: 12px;
  padding-top: 8px; border-top: 1px solid var(--line);
}
.rf-left {
  flex: 1; font-family: var(--serif); font-style: italic;
  font-size: 11px; color: var(--ink-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.rf-mark { color: var(--accent); font-size: 11px; }
.rf-page {
  flex: 1; text-align: right; font-family: var(--sans);
  font-size: 10px; font-weight: 700; letter-spacing: 0.8px;
  color: var(--ink-faint); text-transform: uppercase;
}

/* Block spacing */
.block { margin-bottom: 24px; }
.sec-head-block { margin-bottom: 12px; }
.ing-row-block { margin-bottom: 0; }
.step-block { margin-bottom: 17px; }

/* Opener */
.b-opener { margin-bottom: 20px; }
.hero {
  position: relative; width: 100%; height: 2.95in; overflow: hidden;
  border: 1px solid var(--line); background: var(--paper-edge);
}
.hero::after {
  content: ""; position: absolute; inset: 0; pointer-events: none;
  box-shadow: inset 0 0 0 5px var(--paper), inset 0 0 0 6px var(--line);
}
.hero-fallback { display: flex; align-items: center; justify-content: center; }
.hero-fallback::before {
  content: ""; position: absolute; inset: 0;
  background-image: radial-gradient(currentColor 1.1px, transparent 1.1px);
  background-size: 17px 17px; opacity: 0.16;
}
.hero-monogram {
  font-family: var(--serif); font-weight: 500; font-size: 150px;
  line-height: 1; opacity: 0.92; position: relative;
}
.hero-kicker {
  position: absolute; bottom: 16px; left: 0; right: 0; text-align: center;
  font-family: var(--sans); font-size: 11px; font-weight: 700;
  letter-spacing: 3px; opacity: 0.8;
}

.opener-head { margin-top: 18px; }
.chips { display: flex; flex-wrap: wrap; gap: 7px; margin-bottom: 13px; }
.chip {
  display: inline-flex; align-items: center; gap: 6px;
  font-family: var(--sans); font-size: 11px; font-weight: 600;
  color: var(--ink-soft); padding: 3px 11px 3px 8px;
  border: 1px solid var(--line); border-radius: 999px; background: #fff;
}
.chip-dot { width: 8px; height: 8px; border-radius: 999px; flex-shrink: 0; }
.opener-title {
  margin: 0; font-family: var(--serif); font-weight: 600;
  font-size: 44px; line-height: 1.04; letter-spacing: -0.3px;
  color: var(--ink); text-wrap: balance;
}
.opener-source {
  margin-top: 9px; font-family: var(--serif); font-style: italic;
  font-size: 16px; color: var(--ink-soft);
}

/* Meta strip */
.meta-strip {
  display: flex; align-items: stretch;
  padding: 13px 4px; border-top: 1.5px solid var(--ink);
  border-bottom: 1px solid var(--line);
}
.meta-cell { flex: 1; text-align: center; padding: 0 6px; }
.meta-val {
  font-family: var(--serif); font-weight: 600; font-size: 20px;
  color: var(--ink); line-height: 1.1;
}
.meta-lbl {
  font-family: var(--sans); font-size: 9.5px; font-weight: 700;
  letter-spacing: 1.4px; text-transform: uppercase;
  color: var(--ink-faint); margin-top: 5px;
}
.meta-div { width: 1px; background: var(--line); flex-shrink: 0; }

/* Headnote */
.headnote {
  margin: 0; font-family: var(--serif); font-size: 16.5px;
  line-height: 1.62; color: var(--ink-soft); text-wrap: pretty;
}
.dropcap {
  float: left; font-family: var(--serif); font-weight: 600;
  color: var(--accent); font-size: 60px; line-height: 0.78;
  margin: 6px 10px 0 0;
}
.rich-temp {
  font-family: var(--sans); font-weight: 700; font-size: 0.86em;
  color: var(--accent); white-space: nowrap;
}
.rich-link {
  font-style: italic; color: var(--accent); font-weight: 500;
}

/* Section headings */
.sec-head { display: flex; align-items: center; gap: 12px; }
.sec-rule {
  width: 22px; height: 2px; background: var(--accent); flex-shrink: 0;
}
.sec-title {
  font-family: var(--serif); font-weight: 600; font-size: 23px;
  color: var(--ink); letter-spacing: -0.2px; white-space: nowrap;
}
.sec-suite {
  font-family: var(--sans); font-size: 11px; font-weight: 600;
  font-style: italic; color: var(--ink-faint); letter-spacing: 0;
}
.sec-right {
  margin-left: auto; font-family: var(--sans); font-size: 10.5px;
  font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase;
  color: var(--ink-faint); white-space: nowrap;
}

/* Two-column body — newspaper flow: ingredients fill the left column, overflow
   into the right, then onto the next page; a column break starts the steps. */
.body-cols { display: flex; gap: 30px; align-items: flex-start; }
.col { flex: 1; min-width: 0; display: flow-root; }

/* Ingredients */
.ing-row {
  display: flex; align-items: baseline; gap: 9px;
  padding: 7px 0; border-bottom: 1px solid var(--line-soft);
}
.ing-qty {
  flex-shrink: 0; min-width: 56px;
  font-family: var(--sans); font-weight: 700; font-size: 12.5px;
  color: var(--accent); font-variant-numeric: tabular-nums;
  letter-spacing: 0.2px; line-height: 1.35;
}
.ing-main { flex: 1; min-width: 0; }
.ing-name {
  display: block; font-family: var(--sans); font-size: 13.5px;
  color: var(--ink); line-height: 1.35;
}
.ing-note {
  display: block; font-family: var(--sans); font-style: italic;
  font-size: 11.5px; line-height: 1.3; color: var(--ink-faint); margin-top: 1px;
}

/* Sub-group labels (e.g. "Pâte", "Glaçage") — Facebouffe sections */
.ing-sub {
  font-family: var(--serif); font-weight: 600; font-size: 15px;
  color: var(--accent); padding: 9px 0 2px;
}
.ing-row-block:first-child .ing-sub { padding-top: 0; }
.step-sub {
  font-family: var(--serif); font-weight: 600; font-size: 16px;
  color: var(--accent); margin: 2px 0;
}

/* Nutrition Facts label */
.nf {
  font-family: Helvetica, "Helvetica Neue", Arial, sans-serif;
  color: #000; background: #fff; border: 1.5px solid #000;
  border-radius: 2px; padding: 6px 9px 8px; font-size: 11.5px;
  line-height: 1.25; width: 100%;
}
.nf-t1 { font-size: 22px; font-weight: 800; letter-spacing: -0.4px; line-height: 0.98; }
.nf-t2 { font-size: 17px; font-weight: 800; font-style: italic; letter-spacing: -0.3px; line-height: 1; margin-bottom: 2px; }
.nf-per { border-bottom: 1px solid #000; padding-bottom: 2px; }
.nf-cal {
  display: flex; justify-content: space-between; align-items: flex-end;
  border-bottom: 8px solid #000; padding: 2px 0 1px;
  font-weight: 800; font-size: 16px;
}
.nf-dvhead { text-align: right; font-weight: 700; padding: 1.5px 0; border-bottom: 1px solid #000; }
.nf-row {
  display: flex; justify-content: space-between; align-items: baseline;
  padding: 1.5px 0; border-bottom: 1px solid #000;
}
.nf-row.nf-last { border-bottom: none; }
.nf-indent { padding-left: 12px; }
.nf-plus { padding-left: 0; }
.nf-name { line-height: 1.2; }
.nf-b, .nf-bold .nf-name > span:first-child { font-weight: 700; }
.nf-bold .nf-name { font-weight: 700; }
.nf-fr { font-weight: 400; font-style: italic; }
.nf-amt { font-weight: 700; }
.nf-dv { font-weight: 700; white-space: nowrap; padding-left: 8px; }
.nf-thick { border-bottom: 8px solid #000; }
.nf-foot { border-top: 4px solid #000; margin-top: 2px; padding-top: 3px; font-size: 9.5px; line-height: 1.3; }

/* Steps */
.step-row { display: flex; gap: 16px; }
.step-num {
  flex-shrink: 0; width: 34px; text-align: center;
  font-family: var(--serif); font-weight: 600; font-size: 27px;
  color: var(--accent); line-height: 1; padding-top: 1px;
}
.step-body { flex: 1; min-width: 0; }
.step-text {
  font-family: var(--sans); font-size: 14px; line-height: 1.58;
  color: var(--ink); text-wrap: pretty;
}
.step-meta { margin-top: 8px; }
.step-timer {
  display: inline-flex; align-items: center; gap: 6px;
  font-family: var(--sans); font-size: 11.5px; font-weight: 700;
  color: var(--accent); background: var(--accent-soft);
  border-radius: 999px; padding: 4px 11px;
}
.step-photo {
  margin-top: 11px; width: 2.5in; height: 1.55in; overflow: hidden;
  border: 1px solid var(--line);
}

/* Cook's note */
.b-note {
  background: var(--accent-soft); border-left: 3px solid var(--accent);
  padding: 13px 18px 15px; border-radius: 2px;
}
.note-label {
  font-family: var(--sans); font-size: 9.5px; font-weight: 700;
  letter-spacing: 1.6px; text-transform: uppercase;
  color: var(--accent); margin-bottom: 5px;
}
.note-text {
  margin: 0; font-family: var(--serif); font-style: italic;
  font-size: 14.5px; line-height: 1.5; color: var(--ink-soft);
  white-space: pre-line;
}

/* Gallery */
.b-gallery .sec-head { margin-bottom: 12px; }
.gal-row { display: flex; gap: 12px; }
.gal-item { flex: 1; }
.gal-frame {
  position: relative; width: 100%; height: 1.5in; overflow: hidden;
  border: 1px solid var(--line); background: var(--paper-edge);
}
.gal-frame::after {
  content: ""; position: absolute; inset: 0; pointer-events: none;
  box-shadow: inset 0 0 0 4px var(--paper), inset 0 0 0 5px var(--line);
}

/* See also */
.b-see .sec-head { margin-bottom: 10px; }
.see-row {
  display: flex; align-items: center; gap: 10px;
  padding: 7px 0; border-bottom: 1px solid var(--line-soft);
}
.see-mark { color: var(--accent); font-size: 12px; flex-shrink: 0; }
.see-title {
  flex: 1; min-width: 0;
  font-family: var(--serif); font-size: 15px; color: var(--ink);
}

/* Print */
@page { size: Letter; margin: 0; }
@media print {
  body {
    background: #fff !important;
    -webkit-print-color-adjust: exact; print-color-adjust: exact;
  }
  #doc { padding: 0; gap: 0; display: block; }
  .page {
    box-shadow: none !important;
    width: var(--page-w); height: var(--page-h);
    break-after: page; page-break-after: always;
    margin: 0;
  }
  .page:last-child { break-after: auto; page-break-after: auto; }
  .page::after { box-shadow: none; }
}
''';

// ── paginator — adapted from MockUp/recipe-pdf.js. Same measure-based flow;
//    consumes the pre-rendered block HTML from #fb-pages-data instead of
//    building it from a seed. Signals readiness (Android handler + web
//    postMessage) once layout + fonts + images have settled. ──────────────────
const String _kPaginatorJs = r'''
(function () {
  "use strict";
  var DATA = JSON.parse(document.getElementById("fb-pages-data").textContent);
  var root = document.getElementById("doc");
  var FOOTER_ZONE = 46;
  var pages = [];

  function node(html) {
    var d = document.createElement("div");
    d.innerHTML = String(html).trim();
    return d.firstElementChild;
  }

  function makePage(meta) {
    var p = node(
      '<div class="page">' +
        '<div class="page-frame"></div>' +
        '<div class="page-corner tl"></div><div class="page-corner tr"></div>' +
        '<div class="page-corner bl"></div><div class="page-corner br"></div>' +
        '<div class="page-inner">' +
          '<div class="runhead">' +
            '<span class="rh-mark">Facebouffe</span>' +
            '<span class="rh-title">' + meta.title + '</span>' +
            '<span class="rh-cat">' + meta.category + '</span>' +
          '</div>' +
          '<div class="content"></div>' +
          '<div class="runfoot">' +
            '<span class="rf-left">' + meta.footLeft + '</span>' +
            '<span class="rf-mark">&#10022;</span>' +
            '<span class="rf-page"></span>' +
          '</div>' +
        '</div>' +
      '</div>'
    );
    root.appendChild(p);
    pages.push(p);
    return p;
  }

  function isHeaderBlock(el) {
    var c = el.className || "";
    return c.indexOf("sec-head-block") >= 0 || c.indexOf("ing-sub-block") >= 0 || c.indexOf("step-sub-block") >= 0;
  }

  function layoutRecipe(rec) {
    var page, content, budget;
    function fresh() {
      page = makePage(rec.recipe);
      content = page.querySelector(".content");
      var inner = page.querySelector(".page-inner");
      var rh = page.querySelector(".runhead");
      var pad = parseFloat(getComputedStyle(content).marginTop) || 0;
      budget = inner.clientHeight - rh.offsetHeight - pad - FOOTER_ZONE;
    }
    function fits() { return content.scrollHeight <= budget + 0.5; }
    function placeAtomic(html) {
      var el = node(html);
      content.appendChild(el);
      if (!fits() && content.childElementCount > 1) {
        content.removeChild(el);
        fresh();
        content.appendChild(el);
      }
    }
    // Newspaper column flow: blocks fill the left column top-to-bottom, overflow
    // into the right column, then continue on the next page's left column. A
    // { brk:true } block forces a jump to the next column (used before the steps).
    function placeFlow(blocks) {
      var cols, col, colBudget, side, guard = 0;
      function makeCols(b) {
        cols = node('<div class="body-cols"><div class="col"></div><div class="col"></div></div>');
        content.appendChild(cols);
        colBudget = b;
        side = 0;
        col = cols.children[0];
      }
      function startInitial() {
        // first columns share the page with the full-width header above them
        var avail = budget - content.scrollHeight;
        if (avail < 150) { fresh(); avail = budget; }
        makeCols(avail);
      }
      function nextColumn() {
        if (side === 0) { side = 1; col = cols.children[1]; }
        else { fresh(); makeCols(budget); }
      }
      startInitial();
      for (var i = 0; i < blocks.length; i++) {
        if (++guard > 400) break; // runaway safety
        var b = blocks[i];
        if (b.brk) { nextColumn(); continue; }
        var el = node(b.html);
        col.appendChild(el);
        if (col.scrollHeight > colBudget && col.childElementCount > 1) {
          col.removeChild(el);
          // keep a section/sub-group header with its first row across the break
          var prev = col.lastElementChild;
          var moveHead = prev && isHeaderBlock(prev) && col.childElementCount > 1;
          if (moveHead) col.removeChild(prev);
          nextColumn();
          if (moveHead) col.appendChild(prev);
          col.appendChild(el);
        }
      }
    }
    fresh();
    rec.items.forEach(function (it) {
      if (it.kind === "atomic") placeAtomic(it.html);
      else if (it.kind === "flow") placeFlow(it.blocks);
    });
  }

  function build() {
    root.innerHTML = "";
    pages = [];
    DATA.recipes.forEach(layoutRecipe);
    var n = pages.length;
    pages.forEach(function (pg, i) {
      pg.querySelector(".rf-page").textContent = "p. " + (i + 1) + " / " + n;
    });
  }

  function waitImages() {
    var imgs = Array.prototype.slice.call(document.images || []);
    return Promise.all(imgs.map(function (img) {
      if (img.complete) return null;
      return new Promise(function (res) { img.onload = img.onerror = res; });
    }));
  }

  function signalReady() {
    try { if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler("layoutDone"); } catch (e) {}
    try { if (window.parent && window.parent !== window) window.parent.postMessage("fb-pdf-ready", "*"); } catch (e) {}
  }

  function settle() {
    build(); // re-layout with fonts settled (metrics now final)
    waitImages().then(signalReady, signalReady);
  }

  build(); // initial layout — also kicks off font + image loading
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(settle, settle);
  } else {
    settle();
  }
})();
''';
