import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/format.dart';
import '../data/i18n.dart';
import '../theme.dart';
import 'common.dart';
import 'fb_icon.dart';

Tag? primaryTag(Recipe recipe, Map<String, Tag> tagsById) {
  final id = recipe.tags.where((t) => t != 'tag-fav').firstOrNull;
  return tagsById[id] ?? (recipe.tags.isNotEmpty ? tagsById[recipe.tags.first] : null);
}

// Large feature card (hero image + title overlaid)
class FeatureCard extends StatelessWidget {
  final Recipe recipe;
  final Map<String, Tag> tagsById;
  final String lang;
  final VoidCallback onOpen;
  final bool isFav;
  const FeatureCard({super.key, required this.recipe, required this.tagsById, required this.lang, required this.onOpen, this.isFav = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final tag = primaryTag(recipe, tagsById);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(24), boxShadow: fb.shadow),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            HeroMedia(recipe: recipe, tag: tag, height: 210, radius: 0),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.05), Colors.transparent],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            if (isFav)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), shape: BoxShape.circle),
                  child: Center(child: FbIcon('heart', size: 17, fill: true, color: fb.favorite)),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tag != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FbIcon(tag.icon, size: 12, color: hexColor(tag.color)),
                          const SizedBox(width: 5),
                          Text(tag.displayName(lang), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF2B2620), letterSpacing: 0.2)),
                        ],
                      ),
                    ),
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: fb.display(size: 27, weight: FontWeight.w500, color: Colors.white, height: 1.05, letterSpacing: 0.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Horizontal scroll card (compact)
class MiniCard extends StatelessWidget {
  final Recipe recipe;
  final Map<String, Tag> tagsById;
  final String lang;
  final VoidCallback onOpen;
  final bool isFav;
  final double? width;
  const MiniCard({super.key, required this.recipe, required this.tagsById, required this.lang, required this.onOpen, this.isFav = false, this.width = 156});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final tag = primaryTag(recipe, tagsById);
    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                HeroMedia(recipe: recipe, tag: tag, height: 132, radius: 18),
                if (isFav)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                      child: Center(child: FbIcon('heart', size: 14, fill: true, color: fb.favorite)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: fb.display(size: 16.5, weight: FontWeight.w500, height: 1.12)),
            const SizedBox(height: 4),
            MetaPill(icon: 'clock', text: fmtDuration(recipe.totalTime, lang)),
          ],
        ),
      ),
    );
  }
}

// List row card (used in search / filtered list)
class ListCard extends StatelessWidget {
  final Recipe recipe;
  final Map<String, Tag> tagsById;
  final String lang;
  final VoidCallback onOpen;
  final bool isFav;
  final int variantCount;
  const ListCard({super.key, required this.recipe, required this.tagsById, required this.lang, required this.onOpen, this.isFav = false, this.variantCount = 0});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final tag = primaryTag(recipe, tagsById);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(20), boxShadow: fb.shadow),
        child: Row(
          children: [
            SizedBox(width: 86, height: 86, child: HeroMedia(recipe: recipe, tag: tag, height: 86, radius: 14)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (tag != null) ...[
                        FbIcon(tag.icon, size: 13, color: hexColor(tag.color)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(tag.displayName(lang).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 11.5, weight: FontWeight.w700, color: hexColor(tag.color), letterSpacing: 0.3))),
                      ],
                      if (isFav) ...[
                        const Spacer(),
                        FbIcon('heart', size: 13, fill: true, color: fb.favorite),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: fb.display(size: 18.5, weight: FontWeight.w500, height: 1.1)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MetaPill(icon: 'clock', text: fmtDuration(recipe.totalTime, lang)),
                      MetaPill(icon: 'users', text: '${recipe.servings}'),
                      if (variantCount > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)),
                          child: Text('$variantCount ${tr(lang, "variants").toLowerCase()}', style: fb.ui(size: 11, weight: FontWeight.w700, color: fb.accent)),
                        )
                      else if (recipe.personal.rating > 0)
                        Stars(value: recipe.personal.rating, size: fb.fs(12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
