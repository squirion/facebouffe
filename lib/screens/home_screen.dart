import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../nav.dart';
import '../widgets/avatar.dart';
import '../widgets/banners.dart';
import '../widgets/cards.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    final tagsById = app.tagsById;

    final favs = app.recipes.where(app.isFav).toList();
    final recent = app.recipes.where((r) => r.personal.lastCooked != null).toList()
      ..sort((a, b) => DateTime.parse(b.personal.lastCooked!).compareTo(DateTime.parse(a.personal.lastCooked!)));
    final all = app.baseRecipes;
    final browseTags = app.tags.where((t) => !t.isFavorite).toList();

    return Column(
      children: [
        FbHeader(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Bowl logo + heavy wordmark lockup
                      Image.asset(
                        'assets/logo_mark.png',
                        height: 44,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(app.t('home_title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.wordmark(size: 33, weight: FontWeight.w800, color: fb.accent, height: 0.94, letterSpacing: -0.6)),
                            const SizedBox(height: 5),
                            Text(app.t('home_greeting'), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12.5, weight: FontWeight.w600, color: fb.inkSoft, letterSpacing: 0.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // account circle: signed-in → avatar/initial → Compte; signed-out → person icon → sign-in
                GestureDetector(
                  onTap: () => app.signedIn ? Nav.openAccount(context) : Nav.openSignIn(context),
                  child: app.signedIn
                      ? Avatar(hash: app.account?.avatarHash, letter: app.account?.username ?? '?', size: 63)
                      : Container(
                          width: 63,
                          height: 63,
                          decoration: BoxDecoration(color: fb.card, shape: BoxShape.circle, border: Border.all(color: fb.line), boxShadow: fb.shadow),
                          alignment: Alignment.center,
                          child: FbIcon('user', size: fb.fs(30), color: fb.inkSoft),
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ScreenScroll(
            children: [
              // deployment banners (update available / install app) — self-hide
              const UpdateBanner(),
              const WebPromoBanner(),
              // social hub (signed-in only)
              if (app.signedIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: GestureDetector(
                    onTap: () => Nav.openFriends(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow),
                      child: Row(children: [
                        Container(width: 38, height: 38, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(11)), child: Center(child: FbIcon('users', size: 20, color: fb.accent))),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(app.t('social_friends'), style: fb.ui(size: 15.5, weight: FontWeight.w700)),
                            Text(app.t('social_hub_sub'), style: fb.ui(size: 12.5, color: fb.inkFaint)),
                          ]),
                        ),
                        if (app.incomingRequestCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(999)),
                            child: Text('${app.incomingRequestCount}', style: fb.ui(size: 12, weight: FontWeight.w700, color: Colors.white)),
                          ),
                        FbIcon('chevR', size: fb.fs(18), color: fb.inkFaint),
                      ]),
                    ),
                  ),
                ),
              // category browse hub
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.55,
                  children: [for (final tg in browseTags) _CategoryTile(tag: tg, lang: lang)],
                ),
              ),
              const SizedBox(height: 26),
              // favorites
              SectionLabel(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FbIcon('star', size: fb.fs(18), fill: true, color: fb.gold),
                  const SizedBox(width: 7),
                  Text(app.t('sec_favorites')),
                ]),
              ),
              if (favs.isNotEmpty)
                _HScroll(children: [for (final r in favs) MiniCard(recipe: r, tagsById: tagsById, lang: lang, isFav: true, onOpen: () => Nav.openRecipe(context, r.id))])
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: fb.lineStrong, style: BorderStyle.solid)),
                    child: Row(children: [
                      FbIcon('star', size: fb.fs(22), color: fb.gold),
                      const SizedBox(width: 12),
                      Expanded(child: Text(app.t('fav_empty'), style: fb.ui(size: 13.5, color: fb.inkSoft, height: 1.45))),
                    ]),
                  ),
                ),
              // recently cooked
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 28),
                SectionLabel(child: Text(app.t('sec_recent'))),
                _HScroll(children: [for (final r in recent) MiniCard(recipe: r, tagsById: tagsById, lang: lang, isFav: app.isFav(r), onOpen: () => Nav.openRecipe(context, r.id))]),
              ],
              // all recipes
              const SizedBox(height: 30),
              SectionLabel(
                action: '${app.t('filter_all')} →',
                onAction: () => context.read<ShellTab>().go(1),
                child: Text(app.t('sec_all')),
              ),
              if (app.homeLayout == 'grid')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                    children: [for (final r in all) MiniCard(recipe: r, tagsById: tagsById, lang: lang, isFav: app.isFav(r), width: null, onOpen: () => Nav.openRecipe(context, r.id))],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final r in all)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: FeatureCard(recipe: r, tagsById: tagsById, lang: lang, isFav: app.isFav(r), onOpen: () => Nav.openRecipe(context, r.id)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final dynamic tag;
  final String lang;
  const _CategoryTile({required this.tag, required this.lang});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final color = hexColor(tag.color);
    final lum = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    final ink = lum > 0.62 ? const Color(0xFF3A2A12) : Colors.white;
    final chipBg = lum > 0.62 ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: () => Nav.openFilter(context, tag.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: fb.dark ? null : [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
              child: Center(child: FbIcon(tag.icon, size: 19, color: ink)),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(tag.displayName(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w700, color: ink, height: 1.1, letterSpacing: 0.2))),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling carousel with 20px side padding and 14px gaps.
class _HScroll extends StatelessWidget {
  final List<Widget> children;
  const _HScroll({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++)
            Padding(padding: EdgeInsets.only(right: i < children.length - 1 ? 14 : 0), child: children[i]),
        ],
      ),
    );
  }
}
