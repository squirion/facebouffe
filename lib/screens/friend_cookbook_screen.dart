import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../nav.dart';
import '../widgets/cards.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

/// Browse a friend's *shared* recipes (online-only). Recipes are loaded into the
/// transient visiting store; tapping one opens it in read-only visiting mode.
class FriendCookbookScreen extends StatefulWidget {
  final String friendId;
  final String username;
  const FriendCookbookScreen({super.key, required this.friendId, required this.username});

  @override
  State<FriendCookbookScreen> createState() => _FriendCookbookScreenState();
}

class _FriendCookbookScreenState extends State<FriendCookbookScreen> {
  bool _loading = true;
  bool _offline = false;
  List<Recipe> _recipes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    context.read<AppState>().clearVisiting();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _offline = false;
    });
    if (!app.online) {
      setState(() {
        _loading = false;
        _offline = true;
      });
      return;
    }
    try {
      final list = await app.loadFriendCookbook(widget.friendId);
      if (!mounted) return;
      setState(() {
        _recipes = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true; // treat any failure as "can't reach cookbook"
      });
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
          // visiting band
          Container(
            color: fb.accent,
            padding: EdgeInsets.only(top: topInset + 6, bottom: 10, left: 6, right: 16),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: Colors.white)))),
              const SizedBox(width: 2),
              Expanded(child: Text('${app.t('friend_cookbook')} @${widget.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.display(size: 21, weight: FontWeight.w600, color: Colors.white))),
            ]),
          ),
          Expanded(child: _body(app, fb)),
        ],
      ),
    );
  }

  Widget _body(AppState app, FbTheme fb) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: fb.accent));
    }
    if (_offline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FbIcon('users', size: 40, color: fb.inkFaint),
              const SizedBox(height: 14),
              Text('${app.t('cookbook_offline')} @${widget.username}', textAlign: TextAlign.center, style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(12)),
                  child: Text(app.t('retry'), style: fb.ui(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: fb.accentSoft, shape: BoxShape.circle), child: Center(child: FbIcon('bowl', size: 26, color: fb.accent))),
              const SizedBox(height: 14),
              Text('@${widget.username} ${app.t('cookbook_empty')}', textAlign: TextAlign.center, style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5)),
            ],
          ),
        ),
      );
    }
    // one card per variant group (show its base), like the home library
    final shown = _recipes.where((r) {
      final g = app.getVariantGroup(r.variantGroupId);
      return g == null || g.baseId == r.id;
    }).toList();
    return ScreenScroll(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        for (final r in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListCard(
              recipe: r,
              tagsById: app.tagsById,
              lang: app.lang,
              variantCount: app.getVariantGroup(r.variantGroupId)?.memberIds.length ?? 0,
              onOpen: () => Nav.openRecipe(context, r.id, visiting: true, ownerName: widget.username),
            ),
          ),
      ],
    );
  }
}
