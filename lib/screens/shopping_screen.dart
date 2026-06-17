import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../services/sync/sync_backend.dart' show FriendEdge;
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import '../widgets/avatar.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _addDraft(AppState app) {
    final v = _ctl.text.trim();
    if (v.isEmpty) return;
    app.shoppingAdd(ShoppingItem(id: uuid(), name: v));
    _ctl.clear();
    setState(() {});
  }

  Future<void> _confirmClearAll(BuildContext context, AppState app) async {
    final fb = context.fb;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fb.card,
        title: Text(app.t('clear_list_confirm'), style: fb.display(size: 19, weight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('clear_list'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.danger))),
        ],
      ),
    );
    if (go == true) app.shoppingClearAll();
  }

  Future<void> _confirmDeleteList(BuildContext context, AppState app, ShoppingList list) async {
    final fb = context.fb;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fb.card,
        title: Text(app.t('delete_list_confirm'), style: fb.display(size: 19, weight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('delete_list'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.danger))),
        ],
      ),
    );
    if (go == true) app.deleteShoppingList(list.id);
  }

  // ── send the main list to a friend ──
  Future<void> _startSend(BuildContext context, AppState app) async {
    if (app.mainShoppingList.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('send_empty'))));
      return;
    }
    final friend = await _pickFriend(context, app);
    if (friend == null || !context.mounted) return;
    final go = await _confirmSend(context, app, friend);
    if (go != true || !context.mounted) return;
    final ok = await app.sendShoppingList(friend);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? app.t('list_sent').replaceAll('@name', '@${friend.username ?? ''}') : app.t('send_offline')),
    ));
  }

  Future<FriendEdge?> _pickFriend(BuildContext context, AppState app) {
    final fb = context.fb;
    final friends = app.acceptedFriends;
    return showModalBottomSheet<FriendEdge>(
      context: context,
      backgroundColor: fb.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              FbIcon('send', size: fb.fs(20), color: fb.accent),
              const SizedBox(width: 10),
              Text(app.t('send_to_friend'), style: fb.display(size: 19, weight: FontWeight.w600)),
            ]),
          ),
          if (friends.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Text(app.t('no_friends_yet'), style: fb.ui(size: 15, color: fb.inkSoft)))
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in friends)
                    ListTile(
                      leading: Avatar(hash: f.avatarHash, letter: f.username ?? '?', size: 40),
                      title: Text('@${f.username ?? ''}', style: fb.ui(size: 16, weight: FontWeight.w600)),
                      onTap: () => Navigator.pop(ctx, f),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<bool?> _confirmSend(BuildContext context, AppState app, FriendEdge friend) {
    final fb = context.fb;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fb.card,
        title: Text(app.t('send_confirm_title'), style: fb.display(size: 19, weight: FontWeight.w600)),
        content: Text(app.t('send_confirm_body').replaceAll('@name', '@${friend.username ?? ''}'), style: fb.ui(size: 15, color: fb.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('send_list'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.accent))),
        ],
      ),
    );
  }

  // Display title for a list tab. Disambiguates same-friend tabs with a date.
  String _listTitle(AppState app, ShoppingList list) {
    if (list.isMain) return app.t('my_list');
    final name = '@${list.otherUser ?? ''}';
    final base = list.kind == 'sent' ? '${app.t('sent_to')} $name' : name;
    final sameUser = app.shoppingLists.where((l) => l.kind == list.kind && l.otherUser == list.otherUser).length;
    if (sameUser > 1 && list.createdAt > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(list.createdAt);
      return '$base · ${d.day}/${d.month}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final active = app.activeShoppingList;
    final frozen = active.frozen;
    final items = active.items;
    final toBuy = items.where((i) => !i.checked).toList();
    final inCart = items.where((i) => i.checked).toList();
    final showTabs = app.shoppingLists.length > 1;

    return Column(
      children: [
        FbHeader(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(_listTitle(app, active), maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.display(size: 28, weight: FontWeight.w600))),
                const SizedBox(width: 8),
                // Send (main list only, signed in)
                if (active.isMain && app.signedIn)
                  GestureDetector(
                    onTap: items.isEmpty ? null : () => _startSend(context, app),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 6),
                      child: FbIcon('send', size: fb.fs(21), color: items.isEmpty ? fb.inkFaint : fb.accent),
                    ),
                  ),
                if (!frozen && inCart.isNotEmpty)
                  GestureDetector(onTap: () => app.shoppingClearChecked(), child: Text(app.t('clear_checked'), style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.accent))),
                if (!frozen && active.isMain && items.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  GestureDetector(onTap: () => _confirmClearAll(context, app), child: FbIcon('trash', size: fb.fs(20), color: fb.inkSoft)),
                ],
                // Delete a received/sent list
                if (!active.isMain) ...[
                  const SizedBox(width: 14),
                  GestureDetector(onTap: () => _confirmDeleteList(context, app, active), child: FbIcon('trash', size: fb.fs(20), color: fb.inkSoft)),
                ],
              ],
            ),
          ),
        ),
        if (frozen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              FbIcon('lock', size: fb.fs(14), color: fb.inkFaint),
              const SizedBox(width: 6),
              Text(app.t('list_frozen_note'), style: fb.ui(size: 13, color: fb.inkFaint)),
            ]),
          ),
        // add bar (editable lists only)
        if (!frozen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line), boxShadow: fb.shadow),
              child: Row(children: [
                FbIcon('plus', size: fb.fs(19), color: fb.inkFaint),
                const SizedBox(width: 9),
                Expanded(child: TextField(controller: _ctl, onChanged: (_) => setState(() {}), onSubmitted: (_) => _addDraft(app), style: fb.ui(size: 16), decoration: InputDecoration.collapsed(hintText: app.t('add_item'), hintStyle: fb.ui(size: 16, color: fb.inkFaint)))),
                if (_ctl.text.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => _addDraft(app),
                    child: Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(app.t('done'), style: fb.ui(size: 14, weight: FontWeight.w700, color: Colors.white))),
                  ),
              ]),
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 30),
                  EmptyState(icon: 'basket', title: app.t('list_empty'), hint: app.t('list_empty_hint')),
                ])
              : ScreenScroll(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  children: [
                    if (toBuy.isNotEmpty) ...[
                      _groupLabel(fb, '${app.t('to_buy')} · ${toBuy.length}'),
                      _itemGroup(context, app, fb, toBuy, frozen),
                    ],
                    if (inCart.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.only(top: 12), child: _groupLabel(fb, '${app.t('in_cart')} · ${inCart.length}')),
                      Opacity(opacity: 0.75, child: _itemGroup(context, app, fb, inCart, frozen)),
                    ],
                  ],
                ),
        ),
        if (showTabs) _tabBar(context, app, fb),
      ],
    );
  }

  // ── bottom tab bar (shown when ≥2 lists exist) ──
  Widget _tabBar(BuildContext context, AppState app, FbTheme fb) {
    final lists = app.shoppingLists;
    final activeId = app.activeShoppingList.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: fb.card, border: Border(top: BorderSide(color: fb.line))),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [for (final l in lists) _tabTile(app, fb, l, l.id == activeId)],
        ),
      ),
    );
  }

  Widget _tabTile(AppState app, FbTheme fb, ShoppingList list, bool active) {
    final sent = list.kind == 'sent';
    final fg = sent ? fb.inkFaint : (active ? Colors.white : fb.inkSoft);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => app.setActiveShoppingList(list.isMain ? null : list.id),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? fb.accent : fb.cardSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? fb.accent : fb.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (sent) ...[FbIcon('lock', size: fb.fs(13), color: fg), const SizedBox(width: 5)],
            Text(_listTitle(app, list), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _groupLabel(FbTheme fb, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5)),
      );

  Widget _itemGroup(BuildContext context, AppState app, FbTheme fb, List<ShoppingItem> list, bool frozen) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [for (final it in list) _row(context, app, fb, it, frozen)]),
    );
  }

  Widget _row(BuildContext context, AppState app, FbTheme fb, ShoppingItem it, bool frozen) {
    final lang = app.lang;
    final src = it.sourceRecipeId != null ? app.getRecipe(it.sourceRecipeId) : null;
    final qty = it.quantity != null ? fmtQtyForUnit(it.quantity, it.unit) + (it.unit != null ? ' ${unitLabel(it.unit, lang, it.quantity)}' : '') : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: fb.card, border: Border(bottom: BorderSide(color: fb.line))),
      child: Row(
        children: [
          GestureDetector(
            onTap: frozen ? null : () => app.shoppingToggle(it.id),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: it.checked ? fb.accent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: it.checked ? fb.accent : fb.lineStrong, width: 2)),
              child: it.checked ? const Center(child: FbIcon('check', size: 15, color: Colors.white)) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(TextSpan(children: [
                  if (qty.isNotEmpty) TextSpan(text: '$qty ', style: fb.ui(size: 15.5, weight: FontWeight.w700, color: it.checked ? fb.inkFaint : fb.accent)),
                  TextSpan(text: it.name, style: fb.ui(size: 15.5, color: it.checked ? fb.inkFaint : fb.ink, decoration: it.checked ? TextDecoration.lineThrough : null)),
                ])),
                if (src != null) Text(src.title, style: fb.ui(size: 11.5, color: fb.inkFaint)),
              ],
            ),
          ),
          if (!frozen && it.subRecipeId != null && app.getRecipe(it.subRecipeId) != null)
            GestureDetector(
              onTap: () {
                final ok = app.shoppingExpandSubRecipe(it.id);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('expand_failed'))));
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FbIcon('chevD', size: fb.fs(15), color: fb.accent),
                  const SizedBox(width: 5),
                  Text(app.t('expand_subrecipe'), style: fb.ui(size: 12.5, weight: FontWeight.w700, color: fb.accent)),
                ]),
              ),
            ),
          if (!frozen)
            GestureDetector(onTap: () => app.shoppingRemove(it.id), child: Padding(padding: const EdgeInsets.all(6), child: FbIcon('x', size: fb.fs(17), color: fb.inkFaint))),
        ],
      ),
    );
  }
}
