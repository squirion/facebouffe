import 'package:flutter/material.dart' hide Step;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../theme.dart';
import '../services/image_pick.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';
import '../widgets/nutrition.dart';

const _units = [null, 'g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'oz', 'lb', 'pinch'];
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
  }

  String get photoId => existing?.id ?? '__draft';

  void _save() {
    final app = context.read<AppState>();
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 30 + MediaQuery.of(context).padding.bottom),
              children: [
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(color: const Color(0xFFC0563B).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC0563B).withValues(alpha: 0.33))),
                    child: Row(children: [
                      const FbIcon('x', size: 16, color: Color(0xFF9C3F29)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: const Color(0xFF9C3F29)))),
                    ]),
                  ),
                if (section == 'infos') ..._infos(app, fb),
                if (section == 'ing') ..._ingredients(app, fb),
                if (section == 'steps') ..._steps(app, fb),
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
            onTap: () {
              app.deleteRecipe(existing!.id);
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: fb.line)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const FbIcon('trash', size: 18, color: Color(0xFFC0563B)),
                const SizedBox(width: 8),
                Text(app.t('delete'), style: fb.ui(size: 15, weight: FontWeight.w700, color: const Color(0xFFC0563B))),
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

  // ── INGREDIENTS ──
  List<Widget> _ingredients(AppState app, FbTheme fb) {
    return [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) => setState(() => _reorder(form.ingredients, oldIndex, newIndex)),
        children: [
          for (int i = 0; i < form.ingredients.length; i++)
            Padding(
              key: ObjectKey(form.ingredients[i]),
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _dragHandle(i),
                        const SizedBox(width: 4),
                        SizedBox(width: 50, child: _input(fb, form.ingredients[i].quantity?.toString() ?? '', app.t('f_qty'), (v) => form.ingredients[i].quantity = v.isEmpty ? null : num.tryParse(v), number: true, center: true)),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 82,
                          child: _UnitDropdown(value: form.ingredients[i].unit, lang: app.lang, onChange: (u) => setState(() => form.ingredients[i].unit = u)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: _input(fb, form.ingredients[i].name, app.t('f_ing_name'), (v) => form.ingredients[i].name = v)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(child: _input(fb, form.ingredients[i].note ?? '', '${app.t('f_note')} · ${app.t('f_note_ph')}', (v) => form.ingredients[i].note = v, italic: true)),
                        const SizedBox(width: 6),
                        _miniBtn(fb, 'trash', false, () => setState(() => form.ingredients.removeAt(i))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      _addRowBtn(fb, app.t('f_add_ing'), () => setState(() => form.ingredients.add(Ingredient(name: '')))),
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Divider(height: 1, color: fb.line),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 22),
        child: NutritionPanel(form: form, onChanged: () => setState(() {})),
      ),
    ];
  }

  // Drag handle that initiates a reorder for the row at [index].
  Widget _dragHandle(int index) => ReorderableDragStartListener(
        index: index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: FbIcon('drag', size: 22, color: const Color(0xFFA89E90)),
        ),
      );

  void _reorder(List list, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
  }

  // ── STEPS ──
  List<Widget> _steps(AppState app, FbTheme fb) {
    return [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) => setState(() => _reorder(form.steps, oldIndex, newIndex)),
        children: [
          for (int i = 0; i < form.steps.length; i++)
            Padding(
              key: ObjectKey(form.steps[i]),
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 5), child: _dragHandle(i)),
                        const SizedBox(width: 2),
                        Container(width: 28, height: 28, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text('${i + 1}', style: fb.display(size: 15, weight: FontWeight.w600, color: Colors.white))),
                        const SizedBox(width: 9),
                        Expanded(child: TempTextarea(value: form.steps[i].text, onChange: (v) => setState(() => form.steps[i].text = v), placeholder: '${app.t('f_step')} ${i + 1}', rows: 2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 37),
                      child: Row(
                        children: [
                          const FbIcon('timer', size: 16, color: Color(0xFFA89E90)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 46,
                            child: _input(fb, _minStr(form.steps[i].timerSeconds), 'min', (v) {
                              final sec = (form.steps[i].timerSeconds ?? 0) % 60;
                              final mn = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                              final total = mn * 60 + sec;
                              setState(() => form.steps[i].timerSeconds = total == 0 ? null : total);
                            }, number: true, small: true, center: true),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('min', style: fb.ui(size: 12.5, color: fb.inkFaint))),
                          SizedBox(
                            width: 46,
                            child: _input(fb, _secStr(form.steps[i].timerSeconds), 'sec', (v) {
                              final mn = (form.steps[i].timerSeconds ?? 0) ~/ 60;
                              var sc = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                              if (sc > 59) sc = 59;
                              final total = mn * 60 + sc;
                              setState(() => form.steps[i].timerSeconds = total == 0 ? null : total);
                            }, number: true, small: true, center: true),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('sec', style: fb.ui(size: 12.5, color: fb.inkFaint))),
                          const Spacer(),
                          _miniBtn(fb, 'trash', false, () => setState(() => form.steps.removeAt(i))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      _addRowBtn(fb, app.t('f_add_step'), () => setState(() => form.steps.add(Step(text: '')))),
    ];
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

  Widget _input(FbTheme fb, String value, String hint, ValueChanged<String> onChange, {bool number = false, bool center = false, bool italic = false, bool small = false, int rows = 1}) {
    return _TextField(value: value, hint: hint, onChange: onChange, number: number, center: center, italic: italic, small: small, rows: rows);
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

  Widget _addRowBtn(FbTheme fb, String label, VoidCallback onTap) => Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.lineStrong, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              FbIcon('plus', size: fb.fs(17), color: fb.accent),
              const SizedBox(width: 7),
              Text(label, style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.accent)),
            ]),
          ),
        ),
      );
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
  final bool number, center, italic, small, bold;
  final int rows;
  const _TextField({required this.value, required this.hint, required this.onChange, this.number = false, this.center = false, this.italic = false, this.small = false, this.bold = false, this.rows = 1});

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value;
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
      keyboardType: widget.number ? TextInputType.number : (widget.rows > 1 ? TextInputType.multiline : TextInputType.text),
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
  const _UnitDropdown({required this.value, required this.lang, required this.onChange});

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
          items: [for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u == null ? '—' : unitLabel(u, lang), style: fb.ui(size: 14)))],
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
  final Widget? extra;
  const TempTextarea({super.key, required this.value, required this.onChange, required this.placeholder, this.rows = 2, this.extra});

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
                maxLines: widget.rows,
                minLines: widget.rows,
                keyboardType: TextInputType.multiline,
                style: fb.ui(size: 15.5, height: 1.5),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: fb.ui(size: 15.5, color: fb.inkFaint),
                  isDense: true,
                  filled: true,
                  fillColor: fb.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: fb.accent)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                GestureDetector(onTap: () => _insert('°C'), child: Container(width: 48, height: 34, decoration: pill, alignment: Alignment.center, child: Text('°C', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)))),
                const SizedBox(height: 6),
                GestureDetector(onTap: () => _insert('°F'), child: Container(width: 48, height: 34, decoration: pill, alignment: Alignment.center, child: Text('°F', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)))),
              ],
            ),
          ],
        ),
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
                  const FbIcon('check', size: 13, color: Color(0xFF6BA368)),
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
  const _LinkResults({required this.query, required this.currentId, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final qq = query.trim().toLowerCase();
    var matches = app.recipes.where((r) => r.id != currentId && r.title.toLowerCase().contains(qq)).toList();
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
