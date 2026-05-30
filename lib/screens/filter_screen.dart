import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/i18n.dart';
import '../theme.dart';
import '../nav.dart';
import '../widgets/cards.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import 'import_dialog.dart';

class FilterScreen extends StatelessWidget {
  final String tagId;
  const FilterScreen({super.key, required this.tagId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    final tag = app.tagsById[tagId];
    final matches = app.recipes.where((r) => tagId == 'tag-fav' ? app.isFav(r) : r.tags.contains(tagId)).toList();

    return Scaffold(
      backgroundColor: fb.canvas,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 2),
        child: GestureDetector(
          onTap: () => Nav.addRecipe(context),
          onLongPress: () => showImportDialog(context),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: fb.accent.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 10))]),
            child: const Center(child: FbIcon('plus', size: 28, color: Colors.white)),
          ),
        ),
      ),
      body: Column(
        children: [
          FbHeader(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink))),
                  ),
                  const SizedBox(width: 4),
                  if (tag != null) ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: hexColor(tag.color).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
                      child: Center(child: FbIcon(tag.icon, size: 17, color: hexColor(tag.color))),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Text(tag?.displayName(lang) ?? '', style: fb.display(size: 25, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ScreenScroll(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Text('${matches.length} ${matches.length == 1 ? tr(lang, "result") : tr(lang, "results")}', style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkSoft)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final r in matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListCard(recipe: r, tagsById: app.tagsById, lang: lang, isFav: app.isFav(r), onOpen: () => Nav.openRecipe(context, r.id)),
                        ),
                    ],
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
