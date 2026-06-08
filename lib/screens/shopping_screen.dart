import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final items = app.shopping;
    final toBuy = items.where((i) => !i.checked).toList();
    final inCart = items.where((i) => i.checked).toList();

    return Column(
      children: [
        FbHeader(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(app.t('list_title'), style: fb.display(size: 28, weight: FontWeight.w600)),
                const Spacer(),
                if (inCart.isNotEmpty)
                  GestureDetector(onTap: () => app.shoppingClearChecked(), child: Text(app.t('clear_checked'), style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.accent))),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  GestureDetector(onTap: () => _confirmClearAll(context, app), child: FbIcon('trash', size: fb.fs(20), color: fb.inkSoft)),
                ],
              ],
            ),
          ),
        ),
        // add bar
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
                      _itemGroup(context, app, fb, toBuy),
                    ],
                    if (inCart.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.only(top: 12), child: _groupLabel(fb, '${app.t('in_cart')} · ${inCart.length}')),
                      Opacity(opacity: 0.75, child: _itemGroup(context, app, fb, inCart)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _groupLabel(FbTheme fb, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5)),
      );

  Widget _itemGroup(BuildContext context, AppState app, FbTheme fb, List<ShoppingItem> list) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [for (final it in list) _row(context, app, fb, it)]),
    );
  }

  Widget _row(BuildContext context, AppState app, FbTheme fb, ShoppingItem it) {
    final lang = app.lang;
    final src = it.sourceRecipeId != null ? app.getRecipe(it.sourceRecipeId) : null;
    final qty = it.quantity != null ? fmtQtyForUnit(it.quantity, it.unit) + (it.unit != null ? ' ${unitLabel(it.unit, lang, it.quantity)}' : '') : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: fb.card, border: Border(bottom: BorderSide(color: fb.line))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => app.shoppingToggle(it.id),
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
          if (it.subRecipeId != null && app.getRecipe(it.subRecipeId) != null)
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
          GestureDetector(onTap: () => app.shoppingRemove(it.id), child: Padding(padding: const EdgeInsets.all(6), child: FbIcon('x', size: fb.fs(17), color: fb.inkFaint))),
        ],
      ),
    );
  }
}
