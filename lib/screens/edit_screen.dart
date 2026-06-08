import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../nav.dart';
import '../theme.dart';
import '../services/image_pick.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';
import '../widgets/nutrition.dart';

// Derived from the canonical [kUnits] (format.dart) so the dropdowns can't drift.
const _units = [null, ...kUnits];
// Units offered for an embedded sub-recipe (weight + volume only — no count/pinch).
final _embedUnits = [for (final u in kUnits) if (u != 'pinch') u];
// Slate-blue (from the app palette) distinguishes embedded-recipe cards/chips
// from the terracotta accent used by section headers.
const _embedColor = Color(0xFF4A7BA6);
const _sections = [('infos', 'sec_infos'), ('ing', 'ingredients'), ('steps', 'steps'), ('desc', 'f_desc')];

class EditScreen extends StatefulWidget {
  final String? id;
  final Recipe? initial; // pre-fill a NEW (unsaved) recipe, e.g. from web import
  const EditScreen({super.key, this.id, this.initial});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late Recipe form;
  Recipe? existing;
  String section = 'infos';
  String? error;
  // Shared with the reorderable lists so dragging a card near a screen edge
  // auto-scrolls the page (the lists are shrink-wrapped, so they can't scroll
  // themselves).
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    existing = widget.id != null ? app.getRecipe(widget.id) : null;
    if (existing != null) {
      form = existing!.deepCopy();
    } else if (widget.initial != null) {
      // Imported draft — keep any hero photo already staged on "__draft".
      form = widget.initial!.deepCopy();
    } else {
      form = Recipe(
        id: '',
        title: '',
        servings: 4,
        prepTimeMinutes: 15,
        cookTimeMinutes: 20,
        ingredients: [Ingredient(name: '')],
        steps: [Step(text: '')],
      );
      app.setRecipePhoto('__draft', null);
    }
    // editor shows friendly temperature text; (de)tokenize on load/save
    form.description = detokenizeTemps(form.description);
    for (final s in form.steps) {
      s.text = detokenizeTemps(s.text);
    }
    // Section-aware editor rows (headers + item refs); group labels are derived
    // from header positions on save, so the flat form lists stay canonical.
    _ingRows = _rowsFrom<Ingredient>(form.ingredients, (i) => i.group);
    _stepRows = _rowsFrom<Step>(form.steps, (s) => s.group);
  }

  // Editor working rows for ingredients/steps. The flat form lists are rebuilt
  // from these (with group labels) on every structural change and on save.
  List<_EditRow> _ingRows = [];
  List<_EditRow> _stepRows = [];

  List<_EditRow> _rowsFrom<T>(List<T> items, String? Function(T) groupOf) {
    final rows = <_EditRow>[];
    String? cur;
    for (final it in items) {
      final g = groupOf(it);
      final key = (g == null || g.trim().isEmpty) ? null : g.trim();
      if (key != cur) {
        if (key != null) rows.add(_EditRow.header(key));
        cur = key;
      }
      rows.add(_EditRow.item(it));
    }
    return rows;
  }

  void _syncIng() {
    final out = <Ingredient>[];
    String? cur;
    for (final r in _ingRows) {
      if (r.isHeader) {
        cur = r.name.trim().isEmpty ? null : r.name.trim();
      } else {
        (r.item as Ingredient).group = cur;
        out.add(r.item as Ingredient);
      }
    }
    form.ingredients = out;
  }

  void _syncSteps() {
    final out = <Step>[];
    String? cur;
    for (final r in _stepRows) {
      if (r.isHeader) {
        cur = r.name.trim().isEmpty ? null : r.name.trim();
      } else {
        (r.item as Step).group = cur;
        out.add(r.item as Step);
      }
    }
    form.steps = out;
  }

  String get photoId => existing?.id ?? '__draft';

  void _save() {
    final app = context.read<AppState>();
    // Fold the section rows back into the flat lists (with group labels) first.
    _syncIng();
    _syncSteps();
    if (form.title.trim().isEmpty) {
      setState(() {
        error = app.t('validation_title');
        section = 'infos';
      });
      return;
    }
    if (!form.ingredients.any((x) => x.name.trim().isNotEmpty)) {
      setState(() {
        error = app.t('validation_ing');
        section = 'ing';
      });
      return;
    }
    final clean = form.deepCopy();
    clean.description = tokenizeTemps(form.description);
    clean.ingredients = form.ingredients.where((x) => x.name.trim().isNotEmpty).map((x) => x.copy()).toList();
    clean.steps = form.steps.where((x) => x.text.trim().isNotEmpty).map((x) {
      final s = x.copy();
      s.text = tokenizeTemps(x.text);
      return s;
    }).toList();
    if (existing != null) clean.id = existing!.id;
    app.saveRecipe(clean, existing);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('delete_confirm_title')),
        content: Text(app.t('delete_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('delete'), style: TextStyle(color: ctx.fb.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true && mounted && existing != null) {
      app.deleteRecipe(existing!.id);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          // header
          Container(
            padding: EdgeInsets.only(top: topInset),
            decoration: BoxDecoration(color: fb.glass, border: Border(bottom: BorderSide(color: fb.line))),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: Text(app.t('cancel'), style: fb.ui(size: 16, weight: FontWeight.w600, color: fb.inkSoft))),
                      Text(existing != null ? app.t('edit_title') : app.t('add_title'), style: fb.display(size: 18, weight: FontWeight.w600)),
                      GestureDetector(
                        onTap: _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(11)),
                          child: Text(app.t('save'), style: fb.ui(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                // section nav
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    children: [
                      for (int i = 0; i < _sections.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _SectionChip(
                            index: i,
                            label: app.t(_sections[i].$2),
                            active: section == _sections[i].$1,
                            onTap: () => setState(() => section = _sections[i].$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Ingredients/Steps render as their OWN reorderable scroller (so a card
          // dragged to a screen edge auto-scrolls); other tabs use a plain list.
          Expanded(
            child: section == 'ing'
                ? _ingredients(app, fb)
                : section == 'steps'
                    ? _steps(app, fb)
                    : ListView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(18, 18, 18, 30 + MediaQuery.of(context).padding.bottom),
                        children: [
                          ?_errorBanner(fb),
                          if (section == 'infos') ..._infos(app, fb),
                          if (section == 'desc') ..._desc(app, fb),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── INFOS ──
  List<Widget> _infos(AppState app, FbTheme fb) {
    final tag = form.tags.map((id) => app.tagsById[id]).whereType<Tag>().where((t) => !t.isFavorite).firstOrNull;
    return [
      _field(fb, app.t('sec_photo'), PhotoDrop(photoId: photoId, recipe: Recipe(id: photoId, title: form.title.isEmpty ? '?' : form.title), tag: tag, height: 190, radius: 16, removable: true)),
      _field(fb, app.t('f_tags'), TagSelector(value: form.tags, onChange: (t) => setState(() => form.tags = t))),
      _field(fb, app.t('f_title'), _input(fb, form.title, app.t('f_title_ph'), (v) => form.title = v)),
      _field(fb, app.t('f_source'), _input(fb, form.source ?? '', app.t('f_source_ph'), (v) => form.source = v)),
      Row(
        children: [
          for (final spec in [('f_servings', 'servings'), ('f_prep', 'prep'), ('f_cook', 'cook')])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: spec.$1 != 'f_cook' ? 10 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.t(spec.$1), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 10.5, weight: FontWeight.w700, color: fb.inkSoft, letterSpacing: 0.2)),
                    const SizedBox(height: 7),
                    _numInput(fb, _numFor(spec.$2), (v) => setState(() => _setNum(spec.$2, v))),
                  ],
                ),
              ),
            ),
        ],
      ),
      if (existing != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () => _confirmDelete(app),
            child: Container(
              height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: fb.line)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FbIcon('trash', size: 18, color: fb.danger),
                const SizedBox(width: 8),
                Text(app.t('delete'), style: fb.ui(size: 15, weight: FontWeight.w700, color: fb.danger)),
              ]),
            ),
          ),
        ),
    ];
  }

  int _numFor(String k) => k == 'servings' ? form.servings : (k == 'prep' ? form.prepTimeMinutes : form.cookTimeMinutes);
  void _setNum(String k, int v) {
    if (k == 'servings') {
      form.servings = v;
    } else if (k == 'prep') {
      form.prepTimeMinutes = v;
    } else {
      form.cookTimeMinutes = v;
    }
  }

  // Validation error banner (shown as the active list's header / first child).
  Widget? _errorBanner(FbTheme fb) {
    if (error == null) return null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: fb.danger.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.danger.withValues(alpha: 0.33))),
      child: Row(children: [
        FbIcon('x', size: 16, color: fb.dangerInk),
        const SizedBox(width: 8),
        Expanded(child: Text(error!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.dangerInk))),
      ]),
    );
  }

  // ── INGREDIENTS ── (its own scroller so drag-to-edge auto-scrolls)
  Widget _ingredients(AppState app, FbTheme fb) {
    return ReorderableListView(
      scrollController: _scroll,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 30 + MediaQuery.of(context).padding.bottom),
      buildDefaultDragHandles: false,
      proxyDecorator: _liftedCard,
      header: _errorBanner(fb),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              _addBtn(fb, app.t('f_add_ing'), () => setState(() { _ingRows.add(_EditRow.item(Ingredient(name: ''))); _syncIng(); })),
              _addBtn(fb, app.t('f_add_section'), () => setState(() => _ingRows.add(_EditRow.header(''))), icon: 'note'),
              _addBtn(fb, app.t('embed_recipe'), () => _openEmbedPicker(app), icon: 'link'),
            ]),
          ),
          Padding(padding: const EdgeInsets.only(top: 24), child: Divider(height: 1, color: fb.line)),
          Padding(padding: const EdgeInsets.only(top: 22), child: NutritionPanel(form: form, onChanged: () => setState(() {}))),
        ],
      ),
      onReorderItem: (o, n) => setState(() { _reorder(_ingRows, o, n); _syncIng(); }),
      children: _ingRowWidgets(app, fb),
    );
  }

  List<Widget> _ingRowWidgets(AppState app, FbTheme fb) {
    final widgets = <Widget>[];
    for (int i = 0; i < _ingRows.length; i++) {
      final row = _ingRows[i];
      if (row.isHeader) {
        widgets.add(_sectionHeaderCard(fb, app, row, i, () => setState(() { _ingRows.remove(row); _syncIng(); })));
      } else {
        widgets.add(_ingredientCard(app, fb, row, i));
      }
    }
    return widgets;
  }

  Widget _ingredientCard(AppState app, FbTheme fb, _EditRow row, int displayIndex) {
    final ing = row.item as Ingredient;
    if (ing.recipeRef != null) return _embedCard(app, fb, row, ing, displayIndex);
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line)),
        child: Column(
          children: [
            Row(
              children: [
                _dragHandle(displayIndex),
                const SizedBox(width: 4),
                SizedBox(width: 54, child: _input(fb, fmtQty(ing.quantity), app.t('f_qty'), (v) => ing.quantity = v.trim().isEmpty ? null : (parseQty(v) ?? ing.quantity), number: true, center: true, fractions: true)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 82,
                  child: _UnitDropdown(value: ing.unit, lang: app.lang, onChange: (u) => setState(() => ing.unit = u)),
                ),
                const SizedBox(width: 6),
                Expanded(child: _input(fb, ing.name, app.t('f_ing_name'), (v) => ing.name = v)),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _input(fb, ing.note ?? '', '${app.t('f_note')} · ${app.t('f_note_ph')}', (v) => ing.note = v, italic: true)),
                const SizedBox(width: 6),
                _miniBtn(fb, 'trash', false, () => setState(() { _ingRows.remove(row); _syncIng(); })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // An embedded sub-recipe ingredient: qty + unit + a tappable title chip
  // (opens B). Name isn't editable (it mirrors B's title) and there's no CNF
  // match — nutrition comes from B.
  Widget _embedCard(AppState app, FbTheme fb, _EditRow row, Ingredient ing, int displayIndex) {
    final rr = ing.recipeRef!;
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _embedColor.withValues(alpha: fb.dark ? 0.16 : 0.09), borderRadius: BorderRadius.circular(16), border: Border.all(color: _embedColor.withValues(alpha: 0.4))),
        child: Column(
          children: [
            Row(
              children: [
                _dragHandle(displayIndex),
                const SizedBox(width: 4),
                SizedBox(width: 54, child: _input(fb, fmtQty(ing.quantity), app.t('f_qty'), (v) => ing.quantity = v.trim().isEmpty ? null : (parseQty(v) ?? ing.quantity), number: true, center: true, fractions: true)),
                const SizedBox(width: 6),
                SizedBox(width: 82, child: _UnitDropdown(value: ing.unit, lang: app.lang, units: _embedUnits, onChange: (u) => setState(() => ing.unit = u))),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Nav.openRecipe(context, rr.recipeId),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: _embedColor.withValues(alpha: 0.45))),
                      child: Row(children: [
                        const FbIcon('link', size: 14, color: _embedColor),
                        const SizedBox(width: 7),
                        Expanded(child: Text(rr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w600, color: _embedColor))),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _input(fb, ing.note ?? '', '${app.t('f_note')} · ${app.t('f_note_ph')}', (v) => ing.note = v, italic: true)),
                const SizedBox(width: 6),
                _miniBtn(fb, 'trash', false, () => setState(() { _ingRows.remove(row); _syncIng(); })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Pick one of your own recipes to embed as an ingredient. Excludes the recipe
  // being edited, linked (stolen) recipes, and any candidate that would create a
  // cycle (B already embeds A, transitively).
  Future<void> _openEmbedPicker(AppState app) async {
    final fb = context.fb;
    final editingId = form.id;
    var q = '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: fb.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Align(alignment: Alignment.centerLeft, child: Text(app.t('embed_recipe'), style: fb.display(size: 18, weight: FontWeight.w600))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    FbIcon('search', size: 16, color: fb.inkFaint),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(autofocus: true, onChanged: (v) => setSheet(() => q = v), style: fb.ui(size: 14.5), decoration: InputDecoration.collapsed(hintText: app.lang == 'fr' ? 'Rechercher une recette' : 'Search a recipe', hintStyle: fb.ui(size: 14.5, color: fb.inkFaint)))),
                  ]),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: fb.line),
                _LinkResults(
                  query: q,
                  currentId: editingId,
                  exclude: (id) {
                    final r = app.getRecipe(id);
                    return r == null || r.isLinked || app.wouldCreateCycle(editingId, id);
                  },
                  onPick: (id) {
                    Navigator.pop(ctx);
                    _addEmbed(app, id);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addEmbed(AppState app, String id) {
    final b = app.getRecipe(id);
    if (b == null) return;
    setState(() {
      _ingRows.add(_EditRow.item(Ingredient(name: b.title, quantity: 100, unit: 'g', recipeRef: app.buildRecipeRefSnapshot(b))));
      _syncIng();
    });
  }

  /// A draggable section-header row (editable name) used in both editors.
  Widget _sectionHeaderCard(FbTheme fb, AppState app, _EditRow row, int displayIndex, VoidCallback onRemove) {
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 5, 8, 5),
        decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(13), border: Border.all(color: fb.accent.withValues(alpha: 0.45))),
        child: Row(children: [
          _dragHandle(displayIndex),
          const SizedBox(width: 2),
          Expanded(child: _input(fb, row.name, app.t('f_section_ph'), (v) => row.name = v)),
          const SizedBox(width: 6),
          _miniBtn(fb, 'trash', false, onRemove),
        ]),
      ),
    );
  }

  // Drag handle that initiates a reorder for the row at [index]. The haptic
  // fires on grab (pointer-down on the handle) so the user knows drag mode is
  // armed — not later when the card actually starts moving.
  Widget _dragHandle(int index) => ReorderableDragStartListener(
        index: index,
        child: Listener(
          onPointerDown: (_) => HapticFeedback.mediumImpact(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: FbIcon('drag', size: 22, color: const Color(0xFFA89E90)),
          ),
        ),
      );

  // onReorderItem already adjusts newIndex for the removed item, so no -1 here.
  void _reorder(List list, int oldIndex, int newIndex) {
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
  }

  // While dragging, float the actual rounded card (the default proxy wraps it in
  // a square Material) with a soft rounded shadow + slight lift.
  Widget _liftedCard(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.03 * t,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20 * t), blurRadius: 22 * t, offset: Offset(0, 8 * t))],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ── STEPS ── (its own scroller so drag-to-edge auto-scrolls)
  Widget _steps(AppState app, FbTheme fb) {
    return ReorderableListView(
      scrollController: _scroll,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 30 + MediaQuery.of(context).padding.bottom),
      buildDefaultDragHandles: false,
      proxyDecorator: _liftedCard,
      header: _errorBanner(fb),
      footer: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          _addBtn(fb, app.t('f_add_step'), () => setState(() { _stepRows.add(_EditRow.item(Step(text: ''))); _syncSteps(); })),
          _addBtn(fb, app.t('f_add_section'), () => setState(() => _stepRows.add(_EditRow.header(''))), icon: 'note'),
        ]),
      ),
      onReorderItem: (o, n) => setState(() { _reorder(_stepRows, o, n); _syncSteps(); }),
      children: _stepRowWidgets(app, fb),
    );
  }

  List<Widget> _stepRowWidgets(AppState app, FbTheme fb) {
    final widgets = <Widget>[];
    int stepNo = 0;
    for (int i = 0; i < _stepRows.length; i++) {
      final row = _stepRows[i];
      if (row.isHeader) {
        widgets.add(_sectionHeaderCard(fb, app, row, i, () => setState(() { _stepRows.remove(row); _syncSteps(); })));
      } else {
        widgets.add(_stepCard(app, fb, row, i, ++stepNo));
      }
    }
    return widgets;
  }

  Widget _stepCard(AppState app, FbTheme fb, _EditRow row, int displayIndex, int stepNo) {
    final step = row.item as Step;
    final watermark = fb.accent.withValues(alpha: fb.dark ? 0.20 : 0.12);
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line)),
        child: Stack(
          children: [
            // step number, filigrane top-right
            Positioned(
              top: -12,
              right: 8,
              child: IgnorePointer(child: Text('$stepNo', style: fb.display(size: 66, weight: FontWeight.w800, color: watermark, height: 1))),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 4), child: _dragHandle(displayIndex)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TempTextarea(
                          value: step.text,
                          onChange: (v) => setState(() => step.text = v),
                          placeholder: '${app.t('f_step')} $stepNo',
                          rows: 2,
                          maxRows: 5,
                          bare: true,
                          sidePills: false,
                          controlsBuilder: (insert) => _stepControls(app, fb, step, row, insert),
                        ),
                        if (step.image != null) Padding(padding: const EdgeInsets.only(top: 9), child: _stepPhoto(fb, step)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepControls(AppState app, FbTheme fb, Step step, _EditRow row, void Function(String) insert) {
    final hasImg = step.image != null;
    Widget cf(String label) => GestureDetector(
          onTap: () => insert(label),
          child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), alignment: Alignment.center, child: Text(label, style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.accent))),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(children: [
            cf('°C'),
            const SizedBox(width: 8),
            cf('°F'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pickStepPhoto(step),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(color: hasImg ? fb.accentSoft : fb.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: hasImg ? fb.accent : fb.line)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FbIcon('camera', size: 15, color: hasImg ? fb.accent : fb.inkSoft),
                  const SizedBox(width: 5),
                  Text(app.lang == 'fr' ? 'Photo' : 'Photo', style: fb.ui(size: 12.5, weight: FontWeight.w600, color: hasImg ? fb.accent : fb.inkSoft)),
                ]),
              ),
            ),
            const Spacer(),
            _miniBtn(fb, 'trash', false, () => setState(() { _stepRows.remove(row); _syncSteps(); })),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const FbIcon('timer', size: 16, color: Color(0xFFA89E90)),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              child: _input(fb, _minStr(step.timerSeconds), 'min', (v) {
                final sec = (step.timerSeconds ?? 0) % 60;
                final mn = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                final total = mn * 60 + sec;
                setState(() => step.timerSeconds = total == 0 ? null : total);
              }, number: true, small: true, center: true),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('min', style: fb.ui(size: 12.5, color: fb.inkFaint))),
            SizedBox(
              width: 46,
              child: _input(fb, _secStr(step.timerSeconds), 'sec', (v) {
                final mn = (step.timerSeconds ?? 0) ~/ 60;
                var sc = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                if (sc > 59) sc = 59;
                final total = mn * 60 + sc;
                setState(() => step.timerSeconds = total == 0 ? null : total);
              }, number: true, small: true, center: true),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('sec', style: fb.ui(size: 12.5, color: fb.inkFaint))),
          ]),
        ],
      ),
    );
  }

  Widget _stepPhoto(FbTheme fb, Step step) {
    final image = step.image!;
    final isFile = image.contains('/');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 120,
              child: isFile
                  ? fileImage(image)
                  : Container(color: fb.canvas2, alignment: Alignment.center, child: FbIcon('camera', size: 22, color: fb.inkFaint)),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => setState(() => step.image = null),
              child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Center(child: FbIcon('x', size: 14, color: Colors.white))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStepPhoto(Step step) async {
    final path = await ImagePick.pick(context);
    if (path != null && mounted) setState(() => step.image = path);
  }

  // ── DESCRIPTION ──
  List<Widget> _desc(AppState app, FbTheme fb) {
    return [
      _field(
        fb,
        app.t('f_desc'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TempTextarea(
              value: form.description,
              onChange: (v) => setState(() => form.description = v),
              placeholder: app.t('f_desc_ph'),
              rows: 5,
              extra: _LinkPickerButton(
                currentId: existing?.id,
                onInsert: (id) => setState(() => form.description = '${form.description.isNotEmpty ? '${form.description} ' : ''}{{link:$id}}'),
              ),
            ),
          ],
        ),
      ),
      _field(fb, app.t('gallery'), _galleryEditor(app, fb)),
      _field(fb, app.t('notes'), _input(fb, form.personal.notes, app.t('f_notes_ph'), (v) => form.personal.notes = v, rows: 2)),
    ];
  }

  // Gallery: existing photos (with remove) + an add tile (pick → crop → store).
  Widget _galleryEditor(AppState app, FbTheme fb) {
    final photos = app.galleryOf(photoId);
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: fileImage(photos[i])),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => app.removeGalleryPhoto(photoId, i),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                          child: const Center(child: FbIcon('x', size: 15, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (photos.length < AppState.maxGalleryPhotos)
            GestureDetector(
              onTap: () async {
                final path = await ImagePick.pick(context);
                if (path != null) app.addGalleryPhoto(photoId, path);
              },
              child: Container(
                width: 120,
                decoration: BoxDecoration(color: fb.canvas2, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.lineStrong, width: 1.5)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FbIcon('camera', size: 22, color: fb.accent),
                    const SizedBox(height: 6),
                    Text(app.lang == 'fr' ? 'Ajouter' : 'Add', style: fb.ui(size: 12.5, weight: FontWeight.w600, color: fb.accent)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── helpers ──
  // Split timerSeconds into editor field strings; blank out zero parts so a
  // 2:00 timer shows "2 min" (not "2 min 0 sec") and 0:30 shows "30 sec".
  String _minStr(int? s) => (s == null || s ~/ 60 == 0) ? '' : (s ~/ 60).toString();
  String _secStr(int? s) => (s == null || s % 60 == 0) ? '' : (s % 60).toString();


  Widget _field(FbTheme fb, String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: fb.ui(size: 12.5, weight: FontWeight.w700, color: fb.inkSoft, letterSpacing: 0.4)),
            const SizedBox(height: 7),
            child,
          ],
        ),
      );

  Widget _input(FbTheme fb, String value, String hint, ValueChanged<String> onChange, {bool number = false, bool center = false, bool italic = false, bool small = false, bool fractions = false, int rows = 1}) {
    return _TextField(value: value, hint: hint, onChange: onChange, number: number, center: center, italic: italic, small: small, fractions: fractions, rows: rows);
  }

  Widget _numInput(FbTheme fb, int value, ValueChanged<int> onChange) {
    return _TextField(value: value.toString(), hint: '', onChange: (v) => onChange(int.tryParse(v) ?? 0), number: true, center: true, bold: true);
  }

  Widget _miniBtn(FbTheme fb, String icon, bool disabled, VoidCallback onTap) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.35 : 1,
          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: fb.line)), child: Center(child: FbIcon(icon, size: 15, color: fb.inkSoft))),
        ),
      );

  // Inline "+ Add ingredient / step / section" button (sits in a Wrap so the
  // primary add and the add-section button share a row).
  Widget _addBtn(FbTheme fb, String label, VoidCallback onTap, {String icon = 'plus'}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.lineStrong, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            FbIcon(icon, size: fb.fs(17), color: fb.accent),
            const SizedBox(width: 7),
            Text(label, style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.accent)),
          ]),
        ),
      );
}

/// One row in the section-aware ingredient/step editor: either a group header
/// (editable [name]) or an item (an Ingredient/Step held by reference, so the
/// flat form lists remain the source of truth for nutrition and save).
class _EditRow {
  final bool isHeader;
  String name;
  final Object? item;
  _EditRow.header(this.name)
      : isHeader = true,
        item = null;
  _EditRow.item(this.item)
      : isHeader = false,
        name = '';
}

class _SectionChip extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SectionChip({required this.index, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 13, 7),
        decoration: BoxDecoration(color: active ? fb.accent : fb.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? fb.accent : fb.line, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.25) : fb.accentSoft, shape: BoxShape.circle), alignment: Alignment.center, child: Text('${index + 1}', style: fb.ui(size: 11.5, weight: FontWeight.w700, color: active ? Colors.white : fb.accent))),
            const SizedBox(width: 7),
            Text(label, style: fb.ui(size: 13.5, weight: FontWeight.w700, color: active ? Colors.white : fb.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// Plain styled text field (uncontrolled, syncs value on change).
class _TextField extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChange;
  final bool number, center, italic, small, bold, fractions;
  final int rows;
  const _TextField({required this.value, required this.hint, required this.onChange, this.number = false, this.center = false, this.italic = false, this.small = false, this.bold = false, this.fractions = false, this.rows = 1});

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      // Preserve the caret/selection when syncing an external value, rather than
      // resetting it (the plain `text=` setter collapses selection to offset -1,
      // which can make the next tap behave oddly).
      final sel = _c.selection;
      final keep = sel.isValid && sel.start <= widget.value.length && sel.end <= widget.value.length;
      _c.value = TextEditingValue(
        text: widget.value,
        selection: keep ? sel : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return TextField(
      controller: _c,
      onChanged: widget.onChange,
      keyboardType: widget.fractions ? TextInputType.text : (widget.number ? TextInputType.number : (widget.rows > 1 ? TextInputType.multiline : TextInputType.text)),
      maxLines: widget.rows,
      minLines: widget.rows > 1 ? widget.rows : 1,
      textAlign: widget.center ? TextAlign.center : TextAlign.start,
      style: fb.ui(size: widget.small ? 13.5 : 15.5, weight: widget.bold ? FontWeight.w700 : FontWeight.w500, fontStyle: widget.italic ? FontStyle.italic : null),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: fb.ui(size: widget.small ? 13.5 : 15.5, color: fb.inkFaint, fontStyle: widget.italic ? FontStyle.italic : null),
        isDense: true,
        filled: true,
        fillColor: fb.card,
        contentPadding: EdgeInsets.symmetric(horizontal: widget.center ? 6 : 14, vertical: widget.small ? 8 : 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.accent)),
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final String? value;
  final String lang;
  final ValueChanged<String?> onChange;
  final List<String?> units;
  const _UnitDropdown({required this.value, required this.lang, required this.onChange, this.units = _units});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: fb.line)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: fb.card,
          style: fb.ui(size: 14),
          items: [for (final u in units) DropdownMenuItem<String?>(value: u, child: Text(u == null ? '—' : unitLabel(u, lang), style: fb.ui(size: 14)))],
          onChanged: onChange,
        ),
      ),
    );
  }
}

/// Step/description editor with °C / °F insert pills and a live recognized-
/// temperature preview. An optional [extra] widget (e.g. link button) sits in
/// the toolbar row.
class TempTextarea extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final String placeholder;
  final int rows;
  final int? maxRows; // auto-grows from [rows] up to this, then scrolls
  final bool sidePills; // °C/°F pills to the right of the field
  final bool bare; // transparent/borderless (blends into a card, e.g. step watermark)
  final Widget Function(void Function(String) insert)? controlsBuilder; // controls rendered below the field
  final Widget? extra;
  const TempTextarea({super.key, required this.value, required this.onChange, required this.placeholder, this.rows = 2, this.maxRows, this.sidePills = true, this.bare = false, this.controlsBuilder, this.extra});

  @override
  State<TempTextarea> createState() => _TempTextareaState();
}

class _TempTextareaState extends State<TempTextarea> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant TempTextarea old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      final sel = _c.selection;
      _c.text = widget.value;
      if (sel.start <= widget.value.length) _c.selection = sel;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _insert(String s) {
    final sel = _c.selection;
    final text = _c.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final next = text.substring(0, start) + s + text.substring(end);
    _c.text = next;
    _c.selection = TextSelection.collapsed(offset: start + s.length);
    widget.onChange(next);
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final detected = findTemps(widget.value);
    final pref = prefTempUnit(app.prefs);
    final pill = BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line));
    final InputDecoration decoration = widget.bare
        ? InputDecoration(
            hintText: widget.placeholder,
            hintStyle: fb.ui(size: 15.5, color: fb.inkFaint),
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          )
        : InputDecoration(
            hintText: widget.placeholder,
            hintStyle: fb.ui(size: 15.5, color: fb.inkFaint),
            isDense: true,
            filled: true,
            fillColor: fb.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.accent)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                onChanged: widget.onChange,
                maxLines: widget.maxRows ?? widget.rows,
                minLines: widget.rows,
                keyboardType: TextInputType.multiline,
                style: fb.ui(size: 15.5, height: 1.5),
                decoration: decoration,
              ),
            ),
            if (widget.sidePills) ...[
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(onTap: () => _insert('°C'), child: Container(width: 48, height: 34, decoration: pill, alignment: Alignment.center, child: Text('°C', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)))),
                  const SizedBox(height: 6),
                  GestureDetector(onTap: () => _insert('°F'), child: Container(width: 48, height: 34, decoration: pill, alignment: Alignment.center, child: Text('°F', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)))),
                ],
              ),
            ],
          ],
        ),
        if (widget.controlsBuilder != null) widget.controlsBuilder!(_insert),
        if (widget.extra != null || detected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.extra != null) widget.extra!,
                if (detected.isNotEmpty) ...[
                  FbIcon('check', size: 13, color: fb.success),
                  for (final d in detected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: fb.accent.withValues(alpha: 0.33))),
                      child: Text(fmtTemp(d.value, d.unit, pref), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.accent)),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkPickerButton extends StatefulWidget {
  final String? currentId;
  final ValueChanged<String> onInsert;
  const _LinkPickerButton({required this.currentId, required this.onInsert});

  @override
  State<_LinkPickerButton> createState() => _LinkPickerButtonState();
}

class _LinkPickerButtonState extends State<_LinkPickerButton> {
  bool open = false;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => setState(() => open = !open),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                FbIcon('link', size: 14, color: fb.accent),
                const SizedBox(width: 6),
                Text(app.t('insert_link'), style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.accent)),
              ]),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    FbIcon('search', size: 16, color: fb.inkFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => q = v),
                        style: fb.ui(size: 14.5),
                        decoration: InputDecoration.collapsed(hintText: app.lang == 'fr' ? 'Rechercher une recette' : 'Search a recipe', hintStyle: fb.ui(size: 14.5, color: fb.inkFaint)),
                      ),
                    ),
                  ]),
                ),
                Divider(height: 1, color: fb.line),
                _LinkResults(query: q, currentId: widget.currentId, onPick: (id) {
                  widget.onInsert(id);
                  setState(() { open = false; q = ''; });
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LinkResults extends StatelessWidget {
  final String query;
  final String? currentId;
  final ValueChanged<String> onPick;
  final bool Function(String id)? exclude;
  const _LinkResults({required this.query, required this.currentId, required this.onPick, this.exclude});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final qq = query.trim().toLowerCase();
    var matches = app.recipes.where((r) => r.id != currentId && !(exclude?.call(r.id) ?? false) && r.title.toLowerCase().contains(qq)).toList();
    if (qq.isEmpty) {
      matches.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    }
    matches = matches.take(10).toList();
    if (matches.isEmpty) {
      return Padding(padding: const EdgeInsets.all(14), child: Align(alignment: Alignment.centerLeft, child: Text(app.t('no_results'), style: fb.ui(size: 13.5, color: fb.inkFaint))));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 264),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: matches.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: fb.line),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onPick(matches[i].id),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(children: [
              FbIcon('link', size: 14, color: fb.accent),
              const SizedBox(width: 9),
              Expanded(child: Text(matches[i].title, style: fb.ui(size: 14.5))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Editor tag row: colored selected pills + grayed unselected pills (tap to
/// toggle) + a "+ tag" button that opens a searchable picker with inline create.
class TagSelector extends StatefulWidget {
  final List<String> value;
  final ValueChanged<List<String>> onChange;
  const TagSelector({super.key, required this.value, required this.onChange});

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  bool picker = false;
  String q = '';

  void _toggle(String id) {
    final v = List<String>.from(widget.value);
    v.contains(id) ? v.remove(id) : v.add(id);
    widget.onChange(v);
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final lang = app.lang;
    final all = app.tags.where((t) => !t.isFavorite).toList();
    final selected = widget.value.map((id) => app.tagsById[id]).whereType<Tag>().where((t) => !t.isFavorite).toList();
    final unselected = all.where((t) => !widget.value.contains(t.id)).toList();
    final qq = q.trim().toLowerCase();
    final pickList = unselected.where((t) => t.displayName(lang).toLowerCase().contains(qq)).toList();
    final exactExists = app.findTagByName(q) != null;

    Widget pill(Tag tg, bool on) => GestureDetector(
          onTap: () => _toggle(tg.id),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
            decoration: BoxDecoration(color: on ? hexColor(tg.color) : Colors.transparent, borderRadius: BorderRadius.circular(999), border: Border.all(color: on ? hexColor(tg.color) : fb.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 17, height: 17, decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.25) : fb.line, shape: BoxShape.circle), child: Center(child: FbIcon(tg.icon, size: 11, color: on ? Colors.white : fb.inkFaint))),
              const SizedBox(width: 6),
              Text(tg.displayName(lang), style: fb.ui(size: 13.5, weight: FontWeight.w600, color: on ? Colors.white : fb.inkFaint)),
            ]),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tg in selected) pill(tg, true),
            for (final tg in unselected) pill(tg, false),
            GestureDetector(
              onTap: () => setState(() { picker = !picker; q = ''; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: fb.lineStrong, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FbIcon('plus', size: 14, color: fb.accent),
                  const SizedBox(width: 5),
                  Text('tag', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)),
                ]),
              ),
            ),
          ],
        ),
        if (picker) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    FbIcon('search', size: 16, color: fb.inkFaint),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(onChanged: (v) => setState(() => q = v), style: fb.ui(size: 14.5), decoration: InputDecoration.collapsed(hintText: app.t('search_tag'), hintStyle: fb.ui(size: 14.5, color: fb.inkFaint)))),
                  ]),
                ),
                Divider(height: 1, color: fb.line),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 230),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tg in pickList)
                        GestureDetector(
                          onTap: () { _toggle(tg.id); setState(() { picker = false; q = ''; }); },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
                            child: Row(children: [
                              Container(width: 18, height: 18, decoration: BoxDecoration(color: hexColor(tg.color).withValues(alpha: 0.13), shape: BoxShape.circle), child: Center(child: FbIcon(tg.icon, size: 12, color: hexColor(tg.color)))),
                              const SizedBox(width: 9),
                              Text(tg.displayName(lang), style: fb.ui(size: 14.5)),
                            ]),
                          ),
                        ),
                      if (q.trim().isNotEmpty && !exactExists)
                        GestureDetector(
                          onTap: () {
                            final r = app.addTag(q.trim());
                            final v = List<String>.from(widget.value);
                            if (!v.contains(r.id)) v.add(r.id);
                            widget.onChange(v);
                            setState(() { q = ''; picker = false; });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                            child: Row(children: [
                              FbIcon('plus', size: 15, color: fb.accent),
                              const SizedBox(width: 9),
                              Expanded(child: Text(lang == 'fr' ? 'Aucun résultat — créer « ${q.trim()} » ?' : 'No match — create "${q.trim()}"?', style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.accent))),
                            ]),
                          ),
                        ),
                      if (q.trim().isNotEmpty && exactExists && pickList.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), child: Align(alignment: Alignment.centerLeft, child: Text(app.t('tag_exists'), style: fb.ui(size: 13.5, color: fb.inkFaint)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
