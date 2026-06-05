import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/i18n.dart';
import '../theme.dart';
import '../responsive.dart';
import '../nav.dart';
import '../widgets/cards.dart';
import '../widgets/chrome.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';

const _presetIngredients = ['farine', 'oeufs', 'lait', 'beurre', 'sucre', 'oignon', 'boeuf haché'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  String q = '';
  String? activeTag;
  final Set<String> ingFilter = {};

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;

    final matches = app.recipes.where((r) {
      if (r.variantGroupId != null) {
        final g = app.getVariantGroup(r.variantGroupId);
        if (g != null && g.baseId != r.id) return false;
      }
      if (activeTag == 'tag-fav' && !app.isFav(r)) return false;
      if (activeTag != null && activeTag != 'tag-fav' && !r.tags.contains(activeTag)) return false;
      for (final ing in ingFilter) {
        if (!r.ingredients.any((x) => x.name.toLowerCase().contains(ing))) return false;
      }
      if (q.trim().isEmpty) return true;
      final hay = '${r.title} ${r.description} ${r.ingredients.map((i) => i.name).join(' ')}'.toLowerCase();
      return hay.contains(q.trim().toLowerCase());
    }).toList();

    int vcount(r) => app.liveVariantCount(r.variantGroupId);

    return Column(
      children: [
        FbHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(app.t('tab_search'), style: fb.display(size: 28, weight: FontWeight.w600))),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line), boxShadow: fb.shadow),
                      child: Row(children: [
                        FbIcon('search', size: fb.fs(19), color: fb.inkFaint),
                        const SizedBox(width: 9),
                        Expanded(child: TextField(controller: _ctl, onChanged: (v) => setState(() => q = v), style: fb.ui(size: 16), decoration: InputDecoration.collapsed(hintText: app.t('search_placeholder'), hintStyle: fb.ui(size: 16, color: fb.inkFaint)))),
                        if (q.isNotEmpty)
                          GestureDetector(onTap: () { _ctl.clear(); setState(() => q = ''); }, child: FbIcon('x', size: fb.fs(17), color: fb.inkFaint)),
                      ]),
                    ),
                  ],
                ),
              ),
              // tag chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  children: [
                    for (final tg in app.tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TagChip(tag: tg, lang: lang, active: activeTag == tg.id, onTap: () => setState(() => activeTag = activeTag == tg.id ? null : tg.id)),
                      ),
                  ],
                ),
              ),
              // preset ingredient filters
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(app.t('presets').toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final ing in _presetIngredients)
                              Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: GestureDetector(
                                  onTap: () => setState(() => ingFilter.contains(ing) ? ingFilter.remove(ing) : ingFilter.add(ing)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: ingFilter.contains(ing) ? fb.accent : fb.card,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: ingFilter.contains(ing) ? fb.accent : fb.line),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(ing, style: fb.ui(size: 13, weight: FontWeight.w600, color: ingFilter.contains(ing) ? Colors.white : fb.inkSoft)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? ListView(children: [EmptyState(icon: 'search', title: app.t('no_results'), hint: app.t('search_hint'))])
              : ScreenScroll(
                  wide: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text('${matches.length} ${matches.length == 1 ? tr(lang, "result") : tr(lang, "results")}', style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkSoft)),
                    ),
                    CardColumns(
                      columns: context.layout.gridCols,
                      padding: EdgeInsets.zero,
                      spacing: 12,
                      children: [
                        for (final r in matches)
                          ListCard(recipe: r, tagsById: app.tagsById, lang: lang, isFav: app.isFav(r), variantCount: vcount(r), onOpen: () => Nav.openRecipe(context, r.id)),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
