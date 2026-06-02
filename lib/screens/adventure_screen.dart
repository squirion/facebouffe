import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/format.dart';
import '../theme.dart';
import '../nav.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import '../services/import/byok_client.dart';
import '../services/import/recipe_schema.dart';

// Curated, bilingual suggestion sets (fr, en). Cheap and always populated.
const List<(String, String, String)> _meals = [
  ('breakfast', 'Déjeuner', 'Breakfast'),
  ('lunch', 'Dîner', 'Lunch'),
  ('dinner', 'Souper', 'Dinner'),
  ('snack', 'Collation', 'Snack'),
  ('dessert', 'Dessert', 'Dessert'),
];
const List<(String, String)> _ingredients = [
  ('Poulet', 'Chicken'), ('Bœuf', 'Beef'), ('Œufs', 'Eggs'), ('Saumon', 'Salmon'),
  ('Tofu', 'Tofu'), ('Riz', 'Rice'), ('Pâtes', 'Pasta'), ('Tomates', 'Tomatoes'),
  ('Champignons', 'Mushrooms'), ('Épinards', 'Spinach'), ('Fromage', 'Cheese'),
  ('Chocolat', 'Chocolate'), ('Banane', 'Banana'), ('Pois chiches', 'Chickpeas'),
  ('Courgette', 'Zucchini'), ('Citron', 'Lemon'), ('Ail', 'Garlic'), ('Gingembre', 'Ginger'),
];
const List<(String, String)> _cuisines = [
  ('Italienne', 'Italian'), ('Française', 'French'), ('Mexicaine', 'Mexican'), ('Thaïe', 'Thai'),
  ('Japonaise', 'Japanese'), ('Indienne', 'Indian'), ('Chinoise', 'Chinese'), ('Grecque', 'Greek'),
  ('Libanaise', 'Lebanese'), ('Espagnole', 'Spanish'), ('Coréenne', 'Korean'), ('Marocaine', 'Moroccan'),
];

/// BYOK-only LLM recipe generator (easter egg). Two modes:
///  • adventurous — invent a recipe from a meal + ingredient/cuisine cues;
///  • mutation ([baseId] set) — twist an existing recipe into a new variant.
/// Either way the result is tagged "Hallucinations", saved and opened (no
/// review step).
class AdventureScreen extends StatefulWidget {
  final String? baseId; // non-null = mutation mode (variant of this recipe)
  const AdventureScreen({super.key, this.baseId});
  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  String? _meal;
  final Set<String> _ings = {};
  final Set<String> _styles = {};
  final _ingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  AppState get app => context.read<AppState>();

  bool get _mutation => widget.baseId != null;
  bool get _ready => (_mutation || _meal != null) && !_busy;

  void _addCustomIng() {
    final v = _ingCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _ings.add(v);
      _ingCtrl.clear();
    });
  }

  Future<void> _go() async {
    if (!_ready) return;
    final lang = app.lang;
    final base = _mutation ? app.getRecipe(widget.baseId!) : null;
    if (_mutation && base == null) return;

    final req = StringBuffer()..writeln('Language: ${lang == 'fr' ? 'French' : 'English'}');
    if (_mutation) {
      req
        ..writeln('Original recipe to mutate:')
        ..writeln('Title: ${base!.title}')
        ..writeln('Servings: ${base.servings}')
        ..writeln('Ingredients:');
      for (final i in base.ingredients) {
        final qty = [if (i.quantity != null) i.quantity, if (i.unit != null) i.unit].join(' ');
        req.writeln('- ${[qty, i.name, if (i.note != null && i.note!.isNotEmpty) '(${i.note})'].where((s) => s.toString().isNotEmpty).join(' ')}');
      }
      req.writeln('Steps:');
      for (var k = 0; k < base.steps.length; k++) {
        req.writeln('${k + 1}. ${detokenizeTemps(base.steps[k].text)}');
      }
    } else {
      final mealLabel = _meals.firstWhere((m) => m.$1 == _meal);
      req.writeln('Meal: ${lang == 'fr' ? mealLabel.$2 : mealLabel.$3}');
    }
    final cueLabel = _mutation ? 'Ingredients to incorporate or swap in' : 'Ingredients to include';
    if (_ings.isNotEmpty) req.writeln('$cueLabel: ${_ings.join(', ')}');
    if (_styles.isNotEmpty) req.writeln('Cuisine styles: ${_styles.join(', ')}');
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) req.writeln('${_mutation ? 'Mutation instructions' : 'Extra notes'}: $notes');

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final provider = app.importProvider;
      final key = app.importKeys[provider] ?? '';
      final raw = await ByokClient.generate(
        provider: provider,
        apiKey: key,
        request: req.toString(),
        system: _mutation ? kMutatePrompt : kAdventurePrompt,
      );
      final res = draftFromModelJson(raw, source: _source(lang));
      final recipe = res.recipe;
      final hid = app.findTagByName('Hallucinations')?.id ?? app.addTag('Hallucinations').id;
      if (_mutation) {
        // base recipe's tags (minus favorite) + Hallucinations
        final tags = [...base!.tags.where((t) => t != 'tag-fav'), hid];
        recipe.tags = tags.toSet().toList();
        final id = app.addGeneratedVariant(widget.baseId!, recipe);
        if (!mounted) return;
        Nav.openRecipe(context, id, replace: true);
      } else {
        recipe.tags = [hid];
        final id = app.saveRecipe(recipe, null);
        if (!mounted) return;
        Nav.openRecipe(context, id, replace: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = app.t('adv_error');
        });
      }
    }
  }

  String _source(String lang) => _mutation
      ? (lang == 'fr' ? 'Muté par l\'IA · Je me sens aventureux' : 'AI mutation · Feeling adventurous')
      : (lang == 'fr' ? 'Inventé par l\'IA · Je me sens aventureux' : 'AI-invented · Feeling adventurous');

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    return Scaffold(
      backgroundColor: fb.canvas,
      body: Stack(
        children: [
          Column(
            children: [
              FbHeader(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
                  child: Row(children: [
                    GestureDetector(onTap: _busy ? null : () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_mutation ? app.t('adv_mut_title') : app.t('adv_title'), style: fb.display(size: 23, weight: FontWeight.w600))),
                    FbIcon('sparkles', size: 22, color: fb.accent),
                  ]),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: [
                    Text(_mutation ? app.t('adv_mut_intro') : app.t('adv_intro'), style: fb.ui(size: 13.5, color: fb.inkFaint, height: 1.5)),
                    const SizedBox(height: 18),
                    if (!_mutation) ...[
                      _label(fb, app.t('adv_meal')),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final m in _meals) _pill(fb, lang == 'fr' ? m.$2 : m.$3, _meal == m.$1, () => setState(() => _meal = m.$1)),
                      ]),
                      const SizedBox(height: 20),
                    ],
                    _label(fb, app.t('adv_ingredients')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final ing in _ingredients)
                        _pill(fb, lang == 'fr' ? ing.$1 : ing.$2, _ings.contains(lang == 'fr' ? ing.$1 : ing.$2), () {
                          final l = lang == 'fr' ? ing.$1 : ing.$2;
                          setState(() => _ings.contains(l) ? _ings.remove(l) : _ings.add(l));
                        }),
                      // custom-typed ingredients (those not in the curated set)
                      for (final c in _ings.where((x) => !_ingredients.any((p) => p.$1 == x || p.$2 == x)))
                        _pill(fb, c, true, () => setState(() => _ings.remove(c)), removable: true),
                    ]),
                    const SizedBox(height: 8),
                    _ingField(fb, app),
                    const SizedBox(height: 20),
                    _label(fb, app.t('adv_cuisines')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in _cuisines)
                        _pill(fb, lang == 'fr' ? c.$1 : c.$2, _styles.contains(lang == 'fr' ? c.$1 : c.$2), () {
                          final l = lang == 'fr' ? c.$1 : c.$2;
                          setState(() => _styles.contains(l) ? _styles.remove(l) : _styles.add(l));
                        }),
                    ]),
                    const SizedBox(height: 20),
                    _label(fb, app.t('adv_notes')),
                    Container(
                      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: TextField(controller: _notesCtrl, maxLines: 3, minLines: 2, style: fb.ui(size: 15, height: 1.4), decoration: InputDecoration.collapsed(hintText: app.t('adv_notes_ph'), hintStyle: fb.ui(size: 15, color: fb.inkFaint))),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          decoration: BoxDecoration(color: const Color(0xFFC0563B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const FbIcon('note', size: 15, color: Color(0xFFC0563B)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: fb.ui(size: 13, weight: FontWeight.w600, color: const Color(0xFF9C3F29), height: 1.4))),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: _ready ? _go : null,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(color: _ready ? fb.accent : fb.line, borderRadius: BorderRadius.circular(16)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          FbIcon('sparkles', size: 20, color: _ready ? Colors.white : fb.inkFaint),
                          const SizedBox(width: 9),
                          Text(_mutation ? app.t('adv_mut_go') : app.t('adv_go'), style: fb.ui(size: 16.5, weight: FontWeight.w700, color: _ready ? Colors.white : fb.inkFaint)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: fb.canvas.withValues(alpha: 0.88),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 52, height: 52, child: CircularProgressIndicator(strokeWidth: 3, color: fb.accent)),
                  const SizedBox(height: 20),
                  Text(app.t('adv_loading'), style: fb.ui(size: 16, weight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(FbTheme fb, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(t.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w800, color: fb.inkSoft, letterSpacing: 0.4)),
      );

  Widget _pill(FbTheme fb, String label, bool on, VoidCallback onTap, {bool removable = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(color: on ? fb.accent : fb.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: on ? fb.accent : fb.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: on ? Colors.white : fb.ink)),
            if (removable) ...[const SizedBox(width: 5), FbIcon('x', size: 13, color: Colors.white.withValues(alpha: 0.85))],
          ]),
        ),
      );

  Widget _ingField(FbTheme fb, AppState app) => Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
        child: Row(children: [
          FbIcon('plus', size: 16, color: fb.inkFaint),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _ingCtrl, textInputAction: TextInputAction.done, onSubmitted: (_) => _addCustomIng(), style: fb.ui(size: 14.5), decoration: InputDecoration.collapsed(hintText: app.t('adv_ing_ph'), hintStyle: fb.ui(size: 14.5, color: fb.inkFaint)))),
          GestureDetector(onTap: _addCustomIng, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon('check', size: 16, color: fb.accent)))),
        ]),
      );
}
