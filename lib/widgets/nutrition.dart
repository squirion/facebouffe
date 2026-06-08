import 'package:flutter/material.dart' hide Step;
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/format.dart' show fmtQty, parseQty;
import '../state/app_state.dart';
import '../services/cnf.dart';
import '../nav.dart';
import '../theme.dart';
import 'common.dart' show WarningBanner;
import 'fb_icon.dart';

// The regulated Canadian label uses a neutral sans (not the app's display face)
// so it reads as an authentic artifact rather than app chrome.
const _nfFont = 'Helvetica';

String _trim(num n) {
  final r = (n * 10).round() / 10;
  return r == r.roundToDouble() ? r.round().toString() : r.toString();
}

String nfNum(num? v, String unit) {
  final suffix = unit.isNotEmpty ? ' $unit' : '';
  if (v == null) return '0$suffix';
  String s;
  if (unit == 'mg') {
    s = (v.abs() < 10 && v % 1 != 0) ? _trim(v) : v.round().toString();
  } else if (v.abs() < 10) {
    s = _trim(v);
  } else {
    s = v.round().toString();
  }
  return '$s$suffix';
}

class _NFRow extends StatelessWidget {
  final String en, fr, amount;
  final int? dv;
  final bool bold, indent, plus, last;
  const _NFRow({required this.en, required this.fr, required this.amount, this.dv, this.bold = false, this.indent = false, this.plus = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontFamily: _nfFont, fontSize: 12.5, color: Colors.black, height: 1.2);
    return Container(
      padding: EdgeInsets.fromLTRB(indent && !plus ? 12 : 0, 1.5, 0, 1.5),
      decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: en, style: base.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
              TextSpan(text: ' / $fr', style: base.copyWith(fontStyle: FontStyle.italic)),
              TextSpan(text: ' $amount', style: base.copyWith(fontWeight: FontWeight.w700)),
            ])),
          ),
          if (dv != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text('$dv %', style: base.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Authentic bilingual "Nutrition Facts / Valeur nutritive" table (estimate).
class NutritionFactsLabel extends StatelessWidget {
  final Nutrition nutrition;
  final String lang;
  final String mode; // perServing | total
  final num? totalWeightG; // finished/auto total weight, for the serving line
  const NutritionFactsLabel({super.key, required this.nutrition, required this.lang, this.mode = 'perServing', this.totalWeightG});

  @override
  Widget build(BuildContext context) {
    final d = mode == 'total' ? nutrition.total : nutrition.perServing;
    num v(String k) => d[k] ?? 0;
    final basis = nutrition.servingsBasis < 1 ? 1 : nutrition.servingsBasis;
    final w = totalWeightG;
    final hasW = w != null && w > 0;
    final totalW = hasW ? ' · ${w.round()} g' : '';
    final perW = hasW ? ' (${(w / basis).round()} g)' : '';
    final perLine = mode == 'total'
        ? (lang == 'fr' ? 'Recette entière ($basis portions)$totalW' : 'Whole recipe ($basis servings)$totalW')
        : (lang == 'fr' ? 'Par 1 portion$perW' : 'Per 1 serving$perW');
    final satTransDv = dvPct('satTrans', v('satFat') + v('transFat'));
    const base = TextStyle(fontFamily: _nfFont, fontSize: 12.5, color: Colors.black, height: 1.25);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nutrition Facts', style: TextStyle(fontFamily: _nfFont, fontSize: 23, fontWeight: FontWeight.w800, height: 0.98, letterSpacing: -0.4, color: Colors.black)),
          const Text('Valeur nutritive', style: TextStyle(fontFamily: _nfFont, fontSize: 19, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, height: 1.0, letterSpacing: -0.3, color: Colors.black)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Text(perLine, style: base),
          ),
          // Calories
          Container(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 1),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 8))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Calories', style: TextStyle(fontFamily: _nfFont, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
              Text('${v('kcal').round()}', style: const TextStyle(fontFamily: _nfFont, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Text('% ${lang == 'fr' ? 'valeur quotidienne' : 'Daily Value'}*', textAlign: TextAlign.right, style: base.copyWith(fontWeight: FontWeight.w700)),
          ),
          _NFRow(en: 'Fat', fr: 'Lipides', amount: nfNum(v('fat'), 'g'), dv: dvPct('fat', v('fat')), bold: true),
          _NFRow(en: 'Saturated', fr: 'saturés', amount: nfNum(v('satFat'), 'g'), dv: satTransDv, indent: true),
          _NFRow(en: '+ Trans', fr: 'trans', amount: nfNum(v('transFat'), 'g'), indent: true, plus: true),
          _NFRow(en: 'Carbohydrate', fr: 'Glucides', amount: nfNum(v('carbs'), 'g'), bold: true),
          _NFRow(en: 'Fibre', fr: 'Fibres', amount: nfNum(v('fiber'), 'g'), dv: dvPct('fiber', v('fiber')), indent: true),
          _NFRow(en: 'Sugars', fr: 'Sucres', amount: nfNum(v('sugars'), 'g'), dv: dvPct('sugars', v('sugars')), indent: true),
          _NFRow(en: 'Protein', fr: 'Protéines', amount: nfNum(v('protein'), 'g'), bold: true),
          _NFRow(en: 'Cholesterol', fr: 'Cholestérol', amount: nfNum(v('cholesterol'), 'mg'), bold: true),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 8))),
            child: _NFRow(en: 'Sodium', fr: 'Sodium', amount: nfNum(v('sodium'), 'mg'), dv: dvPct('sodium', v('sodium')), bold: true, last: true),
          ),
          _NFRow(en: 'Potassium', fr: 'Potassium', amount: nfNum(v('potassium'), 'mg'), dv: dvPct('potassium', v('potassium'))),
          _NFRow(en: 'Calcium', fr: 'Calcium', amount: nfNum(v('calcium'), 'mg'), dv: dvPct('calcium', v('calcium'))),
          _NFRow(en: 'Iron', fr: 'Fer', amount: nfNum(v('iron'), 'mg'), dv: dvPct('iron', v('iron')), last: true),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.only(top: 3),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 4))),
            child: Text(
              lang == 'fr' ? '*5 % ou moins c\'est peu, 15 % ou plus c\'est beaucoup' : '*5% or less is a little, 15% or more is a lot',
              style: const TextStyle(fontFamily: _nfFont, fontSize: 10.5, height: 1.3, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

/// Searchable CNF food picker (same pattern as tag/link pickers) with an
/// optional "set as default for this ingredient" toggle (writes an alias).
class CnfPicker extends StatefulWidget {
  final void Function(CnfFood) onPick;
  final VoidCallback onClose;
  final bool remember;
  final ValueChanged<bool> setRemember;
  final String? ingredientName;
  final String? currentCode;
  const CnfPicker({super.key, required this.onPick, required this.onClose, required this.remember, required this.setRemember, this.ingredientName, this.currentCode});

  @override
  State<CnfPicker> createState() => _CnfPickerState();
}

class _CnfPickerState extends State<CnfPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final list = Cnf.instance.search(q);
    // Always keep the current match pinned as the first option.
    final current = Cnf.instance.byCode(widget.currentCode);
    if (current != null) {
      list.removeWhere((f) => f.code == current.code);
      list.insert(0, current);
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              FbIcon('search', size: 16, color: fb.inkFaint),
              const SizedBox(width: 8),
              Expanded(child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), style: fb.ui(size: 14.5), decoration: InputDecoration.collapsed(hintText: app.t('match_search'), hintStyle: fb.ui(size: 14.5, color: fb.inkFaint)))),
              GestureDetector(onTap: widget.onClose, child: FbIcon('x', size: 16, color: fb.inkFaint)),
            ]),
          ),
          Divider(height: 1, color: fb.line),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: list.isEmpty
                ? Padding(padding: const EdgeInsets.all(14), child: Align(alignment: Alignment.centerLeft, child: Text(app.t('no_results'), style: fb.ui(size: 13.5, color: fb.inkFaint))))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: fb.line),
                    itemBuilder: (_, i) {
                      final f = list[i];
                      return GestureDetector(
                        onTap: () => widget.onPick(f),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.name(app.lang), style: fb.ui(size: 14.5, weight: FontWeight.w500)),
                            const SizedBox(height: 1),
                            Text('${app.t('cnf_label')} ${f.code} · ${f.n.isNotEmpty ? f.n[0].round() : 0} kcal ${app.t('per_100')}', style: TextStyle(fontFamily: 'monospace', fontSize: fb.fs(11), color: fb.inkFaint)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          GestureDetector(
            onTap: () => widget.setRemember(!widget.remember),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: fb.line))),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(color: widget.remember ? fb.accent : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: widget.remember ? fb.accent : fb.lineStrong, width: 2)), child: widget.remember ? const Center(child: FbIcon('check', size: 12, color: Colors.white)) : null),
                const SizedBox(width: 9),
                Expanded(child: Text('${app.t('match_set_default')}${widget.ingredientName != null ? ' · « ${widget.ingredientName} »' : ''}', style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkSoft))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color, bg;
  final String label, icon;
  const _Badge({required this.color, required this.bg, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FbIcon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: fb.ui(size: 11, weight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Editor control (Ingredients section): generate + per-ingredient matching +
/// include toggle + correction + label preview. Mutates [form] and calls [onChanged].
class NutritionPanel extends StatefulWidget {
  final Recipe form;
  final VoidCallback onChanged;
  const NutritionPanel({super.key, required this.form, required this.onChanged});

  @override
  State<NutritionPanel> createState() => _NutritionPanelState();
}

class _NutritionPanelState extends State<NutritionPanel> {
  int? editingIdx;
  bool remember = true;
  String mode = 'perServing';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Cnf.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _loading = false);
    }).catchError((_) {
      // load failed — stop the spinner so the panel falls back to its normal UI
      if (mounted) setState(() => _loading = false);
    });
  }

  Recipe get form => widget.form;

  void _recompute() {
    final app = context.read<AppState>();
    form.nutrition = Cnf.instance.compute(form.ingredients, form.servings, computedAt: DateTime.now().toIso8601String(), resolveRecipe: app.getRecipe);
  }

  void _generate() {
    final app = context.read<AppState>();
    for (final ing in form.ingredients) {
      if (ing.recipeRef != null) continue; // embedded sub-recipe — nutrition comes from B
      if (ing.name.trim().isEmpty) continue;
      final old = ing.nutritionRef;
      // Preserve manual corrections (picker pick → confidence 1, or a learned
      // alias); re-match everything else so Recalculate picks up better matches.
      if (old != null && (old.fromAlias || old.confidence >= 1)) continue;
      final fresh = Cnf.instance.resolveMatch(ing, app.aliases);
      if (old != null) fresh.includeInCalc = old.includeInCalc; // keep the user's include toggle
      ing.nutritionRef = fresh;
    }
    _recompute();
    widget.onChanged();
    setState(() {});
  }

  void _setRef(int i, {bool? include}) {
    final ref = form.ingredients[i].nutritionRef ??= NutritionRef();
    if (include != null) ref.includeInCalc = include;
    _recompute();
    widget.onChanged();
    setState(() {});
  }

  void _pickFood(int i, CnfFood food) {
    final app = context.read<AppState>();
    final ing = form.ingredients[i];
    final ref = ing.nutritionRef ??= NutritionRef(includeInCalc: !Cnf.instance.defaultExcluded(ing));
    ref.foodCode = food.code;
    ref.matchedName = food.fr;
    ref.confidence = 1;
    ref.fromAlias = false;
    if (remember && ing.name.trim().isNotEmpty) app.addAlias(ing.name, food.code);
    _recompute();
    widget.onChanged();
    setState(() => editingIdx = null);
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final named = form.ingredients.where((x) => x.name.trim().isNotEmpty).toList();

    if (named.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.lineStrong)),
        child: Text(app.lang == 'fr' ? 'Ajoutez des ingrédients ci-dessus, puis générez l\'étiquette nutritionnelle.' : 'Add ingredients above, then generate the nutrition label.', style: fb.ui(size: 13.5, color: fb.inkFaint, height: 1.5)),
      );
    }
    if (_loading) {
      return Padding(padding: const EdgeInsets.all(16), child: Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fb.accent)), const SizedBox(width: 12), Text(app.t('nutrition_section'), style: fb.ui(size: 14, color: fb.inkSoft))]));
    }

    final generated = form.nutrition != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(8)), child: Center(child: FbIcon('note', size: 16, color: fb.accent))),
          const SizedBox(width: 8),
          Text(app.t('nutrition_section'), style: fb.display(size: 18, weight: FontWeight.w600)),
          const SizedBox(width: 8),
          _estimatePill(fb, app),
        ]),
        const SizedBox(height: 6),
        Text(app.t('nutrition_intro'), style: fb.ui(size: 13, color: fb.inkSoft, height: 1.5)),
        const SizedBox(height: 12),
        if (!generated)
          GestureDetector(
            onTap: _generate,
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const FbIcon('note', size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(app.t('nutrition_gen'), style: fb.ui(size: 15, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          )
        else ...[
          Text(app.t('match_title').toUpperCase(), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          for (int i = 0; i < form.ingredients.length; i++)
            if (form.ingredients[i].name.trim().isNotEmpty) _matchRow(i, fb, app),
          if (form.nutrition!.hasUnmatched)
            Padding(padding: const EdgeInsets.only(top: 12), child: WarningBanner(text: app.t('nutrition_unmatched'))),
          const SizedBox(height: 16),
          _modeToggle(fb, app),
          const SizedBox(height: 10),
          NutritionFactsLabel(nutrition: form.nutrition!, lang: app.lang, mode: mode, totalWeightG: form.effectiveTotalWeightG),
          const SizedBox(height: 12),
          _weightRow(fb, app),
          const SizedBox(height: 9),
          Text(app.t('nutrition_disclaimer'), style: fb.ui(size: 11.5, color: fb.inkFaint, height: 1.45)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _generate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(11), border: Border.all(color: fb.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                FbIcon('refresh', size: 15, color: fb.accent),
                const SizedBox(width: 7),
                Text(app.t('nutrition_regen'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _matchRow(int i, FbTheme fb, AppState app) {
    final ing = form.ingredients[i];
    if (ing.recipeRef != null) return _subRecipeRow(ing, fb, app);
    final ref = ing.nutritionRef;
    final matched = ref != null && ref.matched;
    final on = ref != null && ref.includeInCalc;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line)),
      child: Column(
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => _setRef(i, include: !on),
              child: Container(width: 24, height: 24, decoration: BoxDecoration(color: on ? fb.accent : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: on ? fb.accent : fb.lineStrong, width: 2)), child: on ? const Center(child: FbIcon('check', size: 14, color: Colors.white)) : null),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(child: Text(matched ? '→ ${Cnf.instance.cnfName(ref.foodCode, app.lang)}' : app.t('match_unmatched'), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12.5, color: matched ? fb.inkSoft : fb.inkFaint, fontStyle: matched ? FontStyle.normal : FontStyle.italic))),
                    if (ref != null && ref.fromAlias) ...[const SizedBox(width: 6), FbIcon('check', size: 12, color: fb.accent)],
                    if (ref != null && ref.matched && !ref.includeInCalc) ...[const SizedBox(width: 6), _Badge(color: fb.inkFaint, bg: fb.line, label: app.t('match_excluded'), icon: 'minus')],
                    if (ref != null && ref.matched && ref.includeInCalc && ref.confidence < 0.6) ...[const SizedBox(width: 6), _Badge(color: const Color(0xFFC58A2E), bg: const Color(0x1FC58A2E), label: app.t('match_check'), icon: 'note')],
                  ]),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { editingIdx = editingIdx == i ? null : i; remember = true; }),
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('pencil', size: 15, color: fb.inkSoft))),
            ),
          ]),
          if (editingIdx == i)
            CnfPicker(
              ingredientName: ing.name,
              currentCode: ing.nutritionRef?.foodCode,
              remember: remember,
              setRemember: (v) => setState(() => remember = v),
              onPick: (food) => _pickFood(i, food),
              onClose: () => setState(() => editingIdx = null),
            ),
        ],
      ),
    );
  }

  // An embedded sub-recipe ingredient: link chip + amount, plus a prompt to
  // generate B's nutrition when it (and its snapshot) can't propagate yet.
  Widget _subRecipeRow(Ingredient ing, FbTheme fb, AppState app) {
    final rr = ing.recipeRef!;
    final b = app.getRecipe(rr.recipeId);
    final liveW = b?.effectiveTotalWeightG;
    final usable = (b?.nutrition != null && liveW != null && liveW > 0 && b!.nutrition!.total.isNotEmpty) || (rr.totalWeightG != null && rr.totalWeightG! > 0 && rr.total.isNotEmpty);
    final amount = '${fmtQty(ing.quantity)} ${ing.unit ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(7)), child: Center(child: FbIcon('link', size: 14, color: fb.accent))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${app.t('embed_subrecipe')}${amount.isNotEmpty ? ' · $amount' : ''}', style: fb.ui(size: 12.5, color: fb.inkSoft)),
              ]),
            ),
          ]),
          if (!usable) ...[
            const SizedBox(height: 8),
            WarningBanner(
              text: app.t('embed_needs_nutrition').replaceAll('{title}', rr.title),
              onTap: () => Nav.editRecipe(context, rr.recipeId),
            ),
          ],
        ],
      ),
    );
  }

  // Editable finished-total-weight override (the per-portion weight itself shows
  // on the Nutrition Facts label above).
  Widget _weightRow(FbTheme fb, AppState app) {
    final n = form.nutrition;
    if (n == null) return const SizedBox.shrink();
    return Row(children: [
      Expanded(child: Text(app.t('finished_weight'), style: fb.ui(size: 12.5, color: fb.inkSoft))),
      SizedBox(
        width: 88,
        child: _WeightInput(
          value: form.finishedWeightG,
          hint: n.autoTotalWeightG > 0 ? '${n.autoTotalWeightG.round()}' : '—',
          onChange: (v) => setState(() {
            form.finishedWeightG = v;
            widget.onChanged();
          }),
        ),
      ),
      const SizedBox(width: 6),
      Text('g', style: fb.ui(size: 12.5, color: fb.inkFaint)),
    ]);
  }

  Widget _modeToggle(FbTheme fb, AppState app) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: fb.dark ? Colors.white.withValues(alpha: 0.06) : fb.canvas2, borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        for (final m in [('perServing', app.t('nutrition_per_serving')), ('total', app.t('nutrition_amount_total'))])
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => mode = m.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: mode == m.$1 ? fb.card : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: mode == m.$1 ? fb.shadow : null),
                alignment: Alignment.center,
                child: Text(m.$2, style: fb.ui(size: 13, weight: mode == m.$1 ? FontWeight.w700 : FontWeight.w600, color: mode == m.$1 ? fb.ink : fb.inkSoft)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Small numeric field for the finished-weight override (text → parseQty).
class _WeightInput extends StatefulWidget {
  final num? value;
  final String hint;
  final ValueChanged<num?> onChange;
  const _WeightInput({required this.value, required this.hint, required this.onChange});
  @override
  State<_WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends State<_WeightInput> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value != null ? fmtQty(widget.value) : '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: fb.line)),
      alignment: Alignment.center,
      child: TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: fb.ui(size: 14),
        decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: fb.ui(size: 14, color: fb.inkFaint)),
        onChanged: (v) => widget.onChange(v.trim().isEmpty ? null : parseQty(v)),
      ),
    );
  }
}

Widget _estimatePill(FbTheme fb, AppState app) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fb.line, borderRadius: BorderRadius.circular(999)),
      child: Text(app.t('nutrition_estimate').toUpperCase(), style: fb.ui(size: 10.5, weight: FontWeight.w700, color: fb.inkSoft, letterSpacing: 0.4)),
    );

/// Recipe-page display of a saved label (collapsible).
class NutritionCard extends StatefulWidget {
  final Recipe recipe;
  const NutritionCard({super.key, required this.recipe});
  @override
  State<NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<NutritionCard> {
  bool open = false;
  String mode = 'perServing';

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final n = widget.recipe.nutrition;
    if (n == null) return const SizedBox.shrink();
    final per = n.perServing;
    num pv(String k) => per[k] ?? 0;
    final quick = [
      ('${pv('kcal').round()}', 'Cal'),
      (nfNum(pv('protein'), 'g'), app.lang == 'fr' ? 'Prot.' : 'Protein'),
      (nfNum(pv('fat'), 'g'), app.lang == 'fr' ? 'Lip.' : 'Fat'),
      (nfNum(pv('carbs'), 'g'), app.lang == 'fr' ? 'Gluc.' : 'Carbs'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(app.t('nutrition_section'), style: fb.display(size: 22, weight: FontWeight.w600)),
            const SizedBox(width: 9),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)), child: Text(app.t('nutrition_estimate').toUpperCase(), style: fb.ui(size: 10.5, weight: FontWeight.w700, color: fb.accent, letterSpacing: 0.4))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(20), boxShadow: fb.shadow),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final q in quick)
                      Expanded(
                        child: Column(children: [
                          Text(q.$1, style: fb.display(size: 22, weight: FontWeight.w600, height: 1)),
                          const SizedBox(height: 4),
                          Text(q.$2.toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w600, color: fb.inkFaint, letterSpacing: 0.3)),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final basis = n.servingsBasis < 1 ? 1 : n.servingsBasis;
                  final totalW = widget.recipe.effectiveTotalWeightG ?? 0;
                  final perPortion = totalW > 0 ? (totalW / basis).round() : null;
                  final label = '${app.t('nutrition_per_serving')} · ${n.servingsBasis} ${n.servingsBasis == 1 ? app.t('serving_one') : app.t('servings')}'
                      '${perPortion != null ? ' · ≈ $perPortion g' : ''}';
                  return Text(label, style: fb.ui(size: 11.5, color: fb.inkFaint));
                }),
                if (n.hasUnmatched)
                  Padding(padding: const EdgeInsets.only(top: 12), child: WarningBanner(text: app.t('nutrition_unmatched'))),
                GestureDetector(
                  onTap: () => setState(() => open = !open),
                  child: Container(
                    margin: const EdgeInsets.only(top: 14),
                    height: 44,
                    decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.accent, width: 1.5)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      FbIcon(open ? 'chevD' : 'note', size: fb.fs(17), color: fb.accent),
                      const SizedBox(width: 8),
                      Text(open ? app.t('nutrition_hide') : app.t('nutrition_view'), style: fb.ui(size: 14.5, weight: FontWeight.w700, color: fb.accent)),
                    ]),
                  ),
                ),
                if (open) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: fb.dark ? Colors.white.withValues(alpha: 0.06) : fb.canvas2, borderRadius: BorderRadius.circular(11)),
                    child: Row(children: [
                      for (final m in [('perServing', app.t('nutrition_per_serving')), ('total', app.t('nutrition_amount_total'))])
                        Expanded(child: GestureDetector(onTap: () => setState(() => mode = m.$1), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: mode == m.$1 ? fb.card : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: mode == m.$1 ? fb.shadow : null), alignment: Alignment.center, child: Text(m.$2, style: fb.ui(size: 13, weight: mode == m.$1 ? FontWeight.w700 : FontWeight.w600, color: mode == m.$1 ? fb.ink : fb.inkSoft))))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  NutritionFactsLabel(nutrition: n, lang: app.lang, mode: mode, totalWeightG: widget.recipe.effectiveTotalWeightG),
                  const SizedBox(height: 9),
                  Text(app.t('nutrition_disclaimer'), style: fb.ui(size: 11.5, color: fb.inkFaint, height: 1.45)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
