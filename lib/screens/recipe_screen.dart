import 'package:flutter/material.dart' hide Step;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../theme.dart';
import '../responsive.dart';
import '../nav.dart';
import '../services/pdf_export.dart';
import '../widgets/cards.dart';
import '../widgets/chrome.dart';
import '../widgets/coach.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';
import '../widgets/nutrition.dart';
import '../widgets/reviews.dart';
import '../widgets/linked_controls.dart';
import 'settings_screen.dart' show Segmented;

class RecipeScreen extends StatefulWidget {
  final String id;
  final bool visiting; // browsing a friend's recipe (read-only, owner-only affordances hidden)
  final String? ownerName; // friend's @username, shown in the visiting band
  const RecipeScreen({super.key, required this.id, this.visiting = false, this.ownerName});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  int? _servings;
  bool _addedFlash = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    final recipe = app.getRecipe(widget.id);
    if (recipe == null) {
      // the recipe vanished from under us (e.g. a background auto-fork changed
      // its id) — return to the previous screen instead of a blank page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return Scaffold(backgroundColor: fb.canvas, body: const SizedBox());
    }
    final visiting = widget.visiting;
    final linkedMode = !visiting && recipe.isLinked; // a stolen, read-only copy in my library
    final owned = !visiting && !linkedMode && app.signedIn; // my own recipe
    final twoPane = context.layout.twoPane; // ingredients | steps side-by-side when wides

    final servings = _servings ??= recipe.servings;
    final ratio = servings / recipe.servings;
    final tag = primaryTag(recipe, app.tagsById);
    final group = recipe.variantGroupId != null ? app.getVariantGroup(recipe.variantGroupId) : null;
    final members = group != null ? group.memberIds.map(app.getRecipe).whereType<Recipe>().toList() : <Recipe>[];
    final linked = recipe.links.map(app.getRecipe).whereType<Recipe>().toList();
    final fav = app.isFav(recipe);
    final topInset = MediaQuery.of(context).padding.top;

    // one coach mark at a time, by priority among controls on this page
    final tipOrder = <String>[];
    if (members.length > 1) tipOrder.add('variantChips');
    tipOrder.addAll(['sousChef', 'shoppingAdd', 'variants', 'pdfExport']);
    final activeTip = tipOrder.firstWhere((f) => !app.tipsSeen.seen(f), orElse: () => '');

    void addAll() {
      app.shoppingAddMany(recipe.ingredients.map((ing) {
        final conv = ing.quantity != null && ing.unit != null
            ? convertIngredientUnit(ing.quantity! * ratio, ing.unit, app.prefs)
            : QtyUnit(ing.quantity == null ? null : ing.quantity! * ratio, ing.unit);
        return ShoppingItem(id: uuid(), name: ing.name, quantity: conv.quantity, unit: conv.unit, sourceRecipeId: recipe.id);
      }).toList());
      setState(() => _addedFlash = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _addedFlash = false);
      });
    }

    // Ingredients + steps as blocks so they can stack (narrow) or sit
    // side-by-side (wide / two-pane).
    final ingredientsBlock = <Widget>[
      Row(
        children: [
          Text(app.t('ingredients'), style: fb.display(size: 22, weight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: fb.line), boxShadow: fb.shadow),
            child: Row(
              children: [
                _StepperBtn(icon: 'minus', disabled: servings <= 1, onTap: () => setState(() => _servings = (servings - 1).clamp(1, 999))),
                SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$servings', style: fb.ui(size: 16, weight: FontWeight.w700, height: 1)),
                      Text(servings == 1 ? app.t('serving_one') : app.t('servings'), style: fb.ui(size: 10, weight: FontWeight.w600, color: fb.inkFaint)),
                    ],
                  ),
                ),
                _StepperBtn(icon: 'plus', onTap: () => setState(() => _servings = servings + 1)),
              ],
            ),
          ),
        ],
      ),
      if (servings != recipe.servings)
        GestureDetector(
          onTap: () => setState(() => _servings = recipe.servings),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('↺ ${app.t('scale_reset')}', style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.accent)),
          ),
        ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(20), boxShadow: fb.shadow),
        child: Column(
          children: [
            for (final (s, sec) in groupedSections(recipe.ingredients, (i) => i.group).indexed) ...[
              if (sec.hasHeader) _SectionHeader(name: sec.name!, first: s == 0),
              for (int k = 0; k < sec.items.length; k++)
                _IngredientRow(ing: sec.items[k], ratio: ratio, prefs: app.prefs, lang: lang, last: sec.indices[k] == recipe.ingredients.length - 1),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Coach(
        feature: 'shoppingAdd',
        active: activeTip == 'shoppingAdd',
        text: app.t('coach_shopping'),
        child: GestureDetector(
          onTap: addAll,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _addedFlash ? const Color(0xFF6BA368).withValues(alpha: 0.09) : fb.accentSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _addedFlash ? const Color(0xFF6BA368) : fb.accent, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FbIcon(_addedFlash ? 'check' : 'basket', size: fb.fs(19), color: _addedFlash ? const Color(0xFF4F7D4C) : fb.accent),
                const SizedBox(width: 8),
                Text(_addedFlash ? app.t('added') : app.t('add_to_list'), style: fb.ui(size: 15, weight: FontWeight.w700, color: _addedFlash ? const Color(0xFF4F7D4C) : fb.accent)),
              ],
            ),
          ),
        ),
      ),
    ];
    final stepsBlock = <Widget>[
      Text(app.t('steps'), style: fb.display(size: 22, weight: FontWeight.w600)),
      const SizedBox(height: 14),
      for (final (s, sec) in groupedSections(recipe.steps, (st) => st.group).indexed) ...[
        if (sec.hasHeader) _SectionHeader(name: sec.name!, first: s == 0, step: true),
        for (int k = 0; k < sec.items.length; k++)
          _StepRow(index: sec.indices[k], step: sec.items[k], onLink: (id) => Nav.openRecipe(context, id)),
      ],
    ];

    // Trailing sections — nutrition on one side, reviews + journal on the
    // other, so they sit in two columns (like ingredients|steps) on wide
    // screens instead of stretching the full width.
    final nutritionBlock = <Widget>[
      NutritionCard(recipe: recipe),
      // linked-recipe controls (update banner + lock/fork menu)
      if (linkedMode) ...[
        const SizedBox(height: 18),
        Coach(
          feature: 'stolenRecipe',
          active: activeTip.isEmpty,
          text: app.t('coach_stolen'),
          below: true,
          child: LinkedControls(recipeId: recipe.id),
        ),
      ],
      // steal action when visiting a friend's recipe
      if (visiting) ...[
        const SizedBox(height: 18),
        StealAction(recipeId: recipe.id, ownerName: widget.ownerName),
      ],
    ];
    final feedbackBlock = <Widget>[
      // reviews — your editor when visiting or on a linked recipe;
      // moderation list on your own shared recipe
      if (visiting || linkedMode)
        ReviewsSection(recipeId: recipe.id, canReview: true)
      else if (owned && recipe.visibility == 'friends')
        ReviewsSection(recipeId: recipe.id, canModerate: true),
      // personal journal (your overlay) — own + linked, not while visiting
      if (!visiting) ...[
        const SizedBox(height: 30),
        _Journal(recipe: recipe),
      ],
    ];
    // owner action row — owned recipes only
    final ownerActions = Row(
      children: [
        Expanded(
          child: Coach(
            feature: 'variants',
            active: activeTip == 'variants',
            text: app.t('coach_variants'),
            child: GestureDetector(
              // easter egg: long-press to generate an AI "mutation" (BYOK only)
              onLongPress: app.hasAnyImportKey ? () => Nav.openMutation(context, recipe.id) : null,
              child: _SecondaryAction(icon: 'plus', label: app.t('add_variant'), onTap: () async {
                final id = app.addVariant(recipe.id);
                if (context.mounted) Nav.editRecipe(context, id);
              }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Coach(
            feature: 'pdfExport',
            active: activeTip == 'pdfExport',
            text: app.t('coach_pdf'),
            child: _SecondaryAction(icon: 'note', label: app.t('export_pdf'), onTap: () => exportRecipesPdf(context, [recipe])),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _SecondaryAction(icon: 'pencil', label: app.t('edit'), onTap: () => Nav.editRecipe(context, recipe.id))),
      ],
    );

    return Scaffold(
      backgroundColor: fb.canvas,
      body: MaxW(
        max: context.layout.recipeMax,
        child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: 32 + MediaQuery.of(context).padding.bottom),
            children: [
              // hero
              HeroMedia(recipe: recipe, tag: tag, height: 300, radius: 0),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // description card
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(26), boxShadow: fb.shadow),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recipe.tags.any((t) => t != 'tag-fav'))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    for (final id in recipe.tags.where((t) => t != 'tag-fav'))
                                      if (app.tagsById[id] != null)
                                        TagChip(tag: app.tagsById[id]!, lang: lang, size: 'sm', onTap: () => Nav.openFilter(context, id)),
                                  ],
                                ),
                              ),
                            Text(recipe.title, style: fb.display(size: 30, weight: FontWeight.w600, height: 1.08, letterSpacing: 0.2)),
                            if (recipe.source != null && recipe.source!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(recipe.source!, style: fb.ui(size: 13.5, color: fb.inkSoft, fontStyle: FontStyle.italic)),
                              ),
                            if (linkedMode)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Align(alignment: Alignment.centerLeft, child: LinkedOwnerChip(recipe: recipe)),
                              ),
                            if (members.length > 1) ...[
                              const SizedBox(height: 16),
                              Coach(
                                feature: 'variantChips',
                                active: activeTip == 'variantChips',
                                text: app.t('coach_chips'),
                                below: true,
                                child: _VariantChips(members: members, current: recipe, group: group!, visiting: visiting, ownerName: widget.ownerName),
                              ),
                            ],
                            const SizedBox(height: 16),
                            RichRecipeText(text: recipe.description, onLink: (id) => Nav.openRecipe(context, id)),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: fb.line), bottom: BorderSide(color: fb.line))),
                              child: Row(
                                children: [
                                  _StatBlock(icon: 'clock', label: app.t('prep'), value: fmtDuration(recipe.prepTimeMinutes, lang)),
                                  Container(width: 1, height: 40, color: fb.line),
                                  _StatBlock(icon: 'flame', label: app.t('cook'), value: fmtDuration(recipe.cookTimeMinutes, lang)),
                                  Container(width: 1, height: 40, color: fb.line),
                                  _StatBlock(icon: 'users', label: app.t('servings'), value: '$servings'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (owned) ...[
                        const SizedBox(height: 16),
                        Coach(
                          feature: 'shareRecipe',
                          active: activeTip.isEmpty,
                          text: app.t('coach_share'),
                          below: true,
                          child: _VisibilityControl(recipe: recipe),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // cook mode CTA
                      Coach(
                        feature: 'sousChef',
                        active: activeTip == 'sousChef',
                        text: app.t('coach_souschef'),
                        below: true,
                        child: GestureDetector(
                          onTap: () => Nav.cook(context, recipe.id, servings),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: fb.accent.withValues(alpha: 0.33), blurRadius: 26, offset: const Offset(0, 10))]),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FbIcon('flame', size: fb.fs(21), fill: true, color: Colors.white),
                                const SizedBox(width: 9),
                                Text(app.t('cook_mode'), style: fb.ui(size: 17, weight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ingredients + steps — side-by-side on wide screens
                      const SizedBox(height: 22),
                      if (twoPane)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ingredientsBlock)),
                            const SizedBox(width: 28),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: stepsBlock)),
                          ],
                        )
                      else ...[
                        ...ingredientsBlock,
                        const SizedBox(height: 30),
                        ...stepsBlock,
                      ],
                      // gallery — user-added photos if any, else seed placeholders
                      if (app.galleryOf(recipe.id).isNotEmpty || recipe.gallery.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Text(app.t('gallery'), style: fb.display(size: 22, weight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: Builder(builder: (_) {
                            final g = app.galleryOf(recipe.id);
                            final useReal = g.isNotEmpty;
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: useReal ? g.length : recipe.gallery.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (_, i) => useReal
                                  ? GestureDetector(
                                      onTap: () => Nav.openGallery(context, g, i),
                                      child: SizedBox(width: 150, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: fileImage(g[i]))),
                                    )
                                  : _PhotoPlaceholder(label: recipe.gallery[i], size: 150),
                            );
                          }),
                        ),
                      ],
                      // see also
                      if (linked.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Text(app.t('see_also'), style: fb.display(size: 22, weight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        for (final r in linked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () => Nav.openRecipe(context, r.id),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line), boxShadow: fb.shadow),
                                child: Row(
                                  children: [
                                    Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon('link', size: 16, color: fb.accent))),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(r.title, style: fb.ui(size: 15, weight: FontWeight.w600))),
                                    FbIcon('chevR', size: fb.fs(17), color: fb.inkFaint),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                      // nutrition + reviews/journal — two columns on wide screens
                      const SizedBox(height: 4),
                      if (twoPane)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: nutritionBlock)),
                            const SizedBox(width: 28),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: feedbackBlock)),
                          ],
                        )
                      else ...[
                        ...nutritionBlock,
                        ...feedbackBlock,
                      ],
                      // owner action row — owned recipes only; capped so the
                      // three buttons don't stretch across a wide screen
                      if (owned) ...[
                        const SizedBox(height: 18),
                        if (twoPane)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: ownerActions),
                          )
                        else
                          ownerActions,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // hero top buttons
          Positioned(
            top: topInset + (visiting ? 44 : 6),
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RoundBtn(icon: 'back', onTap: () => Navigator.pop(context)),
                if (owned)
                  Row(children: [
                    _PopStar(active: fav, onTap: () => app.toggleFav(recipe.id)),
                    const SizedBox(width: 8),
                    RoundBtn(icon: 'pencil', onTap: () => Nav.editRecipe(context, recipe.id)),
                  ]),
              ],
            ),
          ),
          // visiting cue — "Carnet de @marie"
          if (visiting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: topInset + 6, bottom: 8),
                color: fb.accent,
                alignment: Alignment.center,
                child: Text('${app.t('visiting_band')} @${widget.ownerName ?? ''}', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// Owner-only Privé / Partagé control shown above the Sous-chef button (§4,
/// mode B). Matches the mockup: status icon + label, with a Segmented toggle.
class _VisibilityControl extends StatelessWidget {
  final Recipe recipe;
  const _VisibilityControl({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final shared = recipe.visibility == 'friends';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(16), boxShadow: fb.shadow),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: shared ? fb.accentSoft : fb.canvas2, borderRadius: BorderRadius.circular(10)),
            child: Center(child: FbIcon(shared ? 'users' : 'lock', size: fb.fs(18), color: shared ? fb.accent : fb.inkFaint)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(app.t('visibility'), style: fb.ui(size: 13.5, weight: FontWeight.w700)),
                Text(shared ? app.t('vis_friends') : app.t('vis_private'), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12, color: fb.inkFaint)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: Segmented(
              value: recipe.visibility,
              onChange: (v) => app.setVisibility(recipe.id, v),
              options: [('private', app.t('vis_private')), ('friends', app.lang == 'fr' ? 'Amis' : 'Friends')],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopStar extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  const _PopStar({required this.active, required this.onTap});

  @override
  State<_PopStar> createState() => _PopStarState();
}

class _PopStarState extends State<_PopStar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final reduce = context.read<AppState>().reduceMotion;
    return GestureDetector(
      onTap: () {
        widget.onTap();
        if (!reduce) _c.forward(from: 0);
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1).animate(_c).drive(_PopTween()),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), shape: BoxShape.circle),
          child: Center(child: FbIcon('star', size: 21, fill: widget.active, color: widget.active ? fb.gold : Colors.white)),
        ),
      ),
    );
  }
}

class _PopTween extends Animatable<double> {
  @override
  double transform(double t) {
    // pop: 1 -> 1.32 -> 0.92 -> 1
    if (t < 0.38) return 1 + (0.32) * (t / 0.38);
    if (t < 0.70) return 1.32 - 0.40 * ((t - 0.38) / 0.32);
    return 0.92 + 0.08 * ((t - 0.70) / 0.30);
  }
}

class _VariantChips extends StatelessWidget {
  final List<Recipe> members;
  final Recipe current;
  final VariantGroup group;
  final bool visiting;
  final String? ownerName;
  const _VariantChips({required this.members, required this.current, required this.group, this.visiting = false, this.ownerName});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(app.t('variants').toUpperCase(), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final m = members[i];
              final active = m.id == current.id;
              return GestureDetector(
                onTap: active ? null : () => Nav.openRecipe(context, m.id, replace: true, visiting: visiting, ownerName: ownerName),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? fb.accent : fb.card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: active ? fb.accent : fb.line, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: active ? Colors.white : fb.ink)),
                      if (group.baseId == m.id)
                        Text(app.t('base_variant'), style: fb.ui(size: 10.5, weight: FontWeight.w600, color: active ? Colors.white.withValues(alpha: 0.8) : fb.inkSoft)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String icon, label, value;
  const _StatBlock({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Expanded(
      child: Column(
        children: [
          FbIcon(icon, size: fb.fs(19), color: fb.accent),
          const SizedBox(height: 4),
          Text(value, style: fb.ui(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w600, color: fb.inkFaint, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final String icon;
  final bool disabled;
  final VoidCallback onTap;
  const _StepperBtn({required this.icon, this.disabled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: disabled ? Colors.transparent : fb.accentSoft, shape: BoxShape.circle),
          child: Center(child: FbIcon(icon, size: fb.fs(19), color: fb.accent)),
        ),
      ),
    );
  }
}

/// Group heading for a run of ingredients/steps (e.g. "Pâte", "Glaçage").
/// [step] gives a touch more breathing room for the larger step list.
class _SectionHeader extends StatelessWidget {
  final String name;
  final bool first;
  final bool step;
  const _SectionHeader({required this.name, this.first = false, this.step = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: EdgeInsets.only(top: first ? (step ? 0 : 6) : (step ? 8 : 16), bottom: step ? 12 : 8),
      child: Row(children: [
        Container(width: 3, height: 15, decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(name.toUpperCase(), style: fb.ui(size: step ? 13.5 : 12.5, weight: FontWeight.w800, color: fb.accent, letterSpacing: 0.4))),
      ]),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final Ingredient ing;
  final double ratio;
  final UnitPrefs prefs;
  final String lang;
  final bool last;
  const _IngredientRow({required this.ing, required this.ratio, required this.prefs, required this.lang, required this.last});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final d = displayIngredient(ing.quantity, ing.unit, ing.name, ing.note, ratio, prefs, lang);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text('${d.qtyText}${d.unitText.isNotEmpty ? ' ${d.unitText}' : ''}', style: fb.ui(size: 14.5, weight: FontWeight.w700, color: fb.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: d.name, style: fb.ui(size: 15.5, color: fb.ink)),
              if (d.note != null) TextSpan(text: ' · ${d.note}', style: fb.ui(size: 13.5, color: fb.inkFaint, fontStyle: FontStyle.italic)),
            ])),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final Step step;
  final void Function(String) onLink;
  const _StepRow({required this.index, required this.step, required this.onLink});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: fb.display(size: 16, weight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichRecipeText(text: step.text, onLink: onLink, color: fb.ink, fontSize: 15.5, height: 1.55),
                ),
                if (step.image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: step.image!.contains('/')
                          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 150, width: double.infinity, child: fileImage(step.image!)))
                          : _PhotoPlaceholder(label: step.image!, size: 150, height: 150),
                    ),
                  ),
                if (step.timerSeconds != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        FbIcon('timer', size: fb.fs(15), color: fb.accent),
                        const SizedBox(width: 6),
                        Text(fmtTimer(step.timerSeconds), style: fb.ui(size: 13, weight: FontWeight.w700, color: fb.accent)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String label;
  final double size;
  final double? height;
  const _PhotoPlaceholder({required this.label, required this.size, this.height});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      width: size,
      height: height ?? size,
      decoration: BoxDecoration(color: fb.canvas2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FbIcon('camera', size: 22, color: fb.inkFaint),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: fb.ui(size: 10.5, color: fb.inkFaint)),
          ),
        ],
      ),
    );
  }
}

class _Journal extends StatefulWidget {
  final Recipe recipe;
  const _Journal({required this.recipe});

  @override
  State<_Journal> createState() => _JournalState();
}

class _JournalState extends State<_Journal> {
  late final TextEditingController _notes = TextEditingController(text: widget.recipe.personal.notes);
  final FocusNode _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Flush the edited note to disk when the field loses focus.
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) context.read<AppState>().saveDb(widget.recipe.id);
    });
  }

  @override
  void dispose() {
    context.read<AppState>().saveDb(widget.recipe.id); // flush any last edit on leaving the page
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final recipe = widget.recipe;
    final lang = app.lang;
    final p = recipe.personal;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: fb.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.t('personal').toUpperCase(), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Stars(value: p.rating, size: fb.fs(24), gap: 4, interactive: true, onChange: (v) => app.setRating(recipe.id, v)),
              const Spacer(),
              Text(p.rating > 0 ? '${p.rating}/5' : app.t('unrated'), style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkSoft)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.t('made_count').toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w600, color: fb.inkFaint, letterSpacing: 0.3)),
                  Text('${p.madeCount} ${p.madeCount == 1 ? app.t('time_once') : app.t('times')}', style: fb.display(size: 18, weight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.t('last_cooked').toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w600, color: fb.inkFaint, letterSpacing: 0.3)),
                  Text(fmtRelDate(p.lastCooked, lang), style: fb.display(size: 18, weight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          // Editable notes — tap to add or change.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 10), child: FbIcon('note', size: fb.fs(17), color: fb.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _notes,
                      focusNode: _notesFocus,
                      onChanged: (v) => p.notes = v, // in-memory; flushed on blur/leave
                      // tapping anywhere outside drops focus → cursor/keyboard
                      // disappear, signalling the edit was recorded (blur saves)
                      onTapOutside: (_) => _notesFocus.unfocus(),
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5, fontStyle: FontStyle.italic),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: app.t('f_notes_ph'),
                        hintStyle: fb.ui(size: 14.5, color: fb.inkFaint, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _SecondaryAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line), boxShadow: fb.shadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FbIcon(icon, size: fb.fs(19), color: fb.accent),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: fb.ui(size: 11.5, weight: FontWeight.w600, height: 1.2)),
          ],
        ),
      ),
    );
  }
}
