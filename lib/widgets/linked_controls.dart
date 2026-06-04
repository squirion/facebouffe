import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../nav.dart';
import 'fb_icon.dart';

// ── Mode A: steal action on a friend's recipe (visiting) ──────────────────────
class StealAction extends StatefulWidget {
  final String recipeId;
  final String? ownerName;
  const StealAction({super.key, required this.recipeId, this.ownerName});

  @override
  State<StealAction> createState() => _StealActionState();
}

class _StealActionState extends State<StealAction> {
  bool _busy = false;

  Future<void> _steal(AppState app) async {
    setState(() => _busy = true);
    final bundle = await app.resolveStealBundle(widget.recipeId, widget.ownerName);
    if (!mounted) return;
    if (bundle != null && bundle.newCount >= 1) {
      setState(() => _busy = false);
      await showStealPreview(context, app, bundle, widget.ownerName);
    } else {
      await app.doSteal(widget.recipeId, widget.ownerName);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    if (app.alreadyStolen(widget.recipeId)) {
      return Container(
        height: 56,
        decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FbIcon('check', size: fb.fs(20), color: fb.accent),
          const SizedBox(width: 9),
          Text(app.t('already_stolen'), style: fb.ui(size: 16, weight: FontWeight.w700, color: fb.accent)),
        ]),
      );
    }
    return GestureDetector(
      onTap: _busy ? null : () => _steal(app),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: fb.accent.withValues(alpha: 0.33), blurRadius: 26, offset: const Offset(0, 10))]),
        child: Center(
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FbIcon('link', size: fb.fs(20), color: Colors.white),
                  const SizedBox(width: 9),
                  Text(app.t('steal_recipe'), style: fb.ui(size: 17, weight: FontWeight.w700, color: Colors.white)),
                ]),
        ),
      ),
    );
  }
}

/// Preview the bundle a steal would bring in, then commit.
Future<void> showStealPreview(BuildContext context, AppState app, StealBundle bundle, String? ownerName) async {
  final fb = context.fb;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: fb.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.t('steal_preview_title'), style: fb.display(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('« ${bundle.mainTitle} » ${app.t('steal_bundles')} ${bundle.newCount} ${app.t('steal_n_linked')}.', style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5)),
            const SizedBox(height: 16),
            _PreviewRow(icon: 'link', title: bundle.mainTitle, primary: true),
            for (final e in bundle.extras) ...[
              const SizedBox(height: 8),
              _PreviewRow(icon: 'link', title: e.title, already: e.already),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                await app.doSteal(bundle.mainId, ownerName);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(app.t('steal_all'), style: fb.ui(size: 16, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              behavior: HitTestBehavior.opaque,
              child: Container(height: 46, alignment: Alignment.center, child: Text(app.t('cancel'), style: fb.ui(size: 15, weight: FontWeight.w700, color: fb.inkSoft))),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  final String icon, title;
  final bool primary, already;
  const _PreviewRow({required this.icon, required this.title, this.primary = false, this.already = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Opacity(
      opacity: already ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? fb.accentSoft : fb.cardSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: primary ? fb.accent.withValues(alpha: 0.4) : fb.line),
        ),
        child: Row(children: [
          FbIcon(primary ? 'link' : 'link', size: fb.fs(17), color: primary ? fb.accent : fb.inkSoft),
          const SizedBox(width: 11),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w600))),
          if (already) Text(context.read<AppState>().t('steal_already'), style: fb.ui(size: 11.5, weight: FontWeight.w600, color: fb.inkFaint)),
        ]),
      ),
    );
  }
}

// ── Mode C: linked-recipe controls (update banner + lock/fork menu) ──────────
class LinkedControls extends StatelessWidget {
  final String recipeId;
  const LinkedControls({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    return Column(
      children: [
        if (app.updateAvailable(recipeId)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.accent.withValues(alpha: 0.35))),
            child: Row(children: [
              FbIcon('refresh', size: fb.fs(19), color: fb.accent),
              const SizedBox(width: 11),
              Expanded(child: Text(app.t('update_available'), style: fb.ui(size: 13.5, weight: FontWeight.w700))),
              GestureDetector(
                onTap: () => app.pullUpdate(recipeId),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(11)),
                  alignment: Alignment.center,
                  child: Text(app.t('refresh'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: () => _menu(context, app),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line), boxShadow: fb.shadow),
            child: Row(children: [
              FbIcon('lock', size: fb.fs(18), color: fb.inkSoft),
              const SizedBox(width: 10),
              Expanded(child: Text(app.t('locked_readonly'), style: fb.ui(size: 14.5, weight: FontWeight.w600, color: fb.inkSoft))),
              FbIcon('chevD', size: fb.fs(18), color: fb.inkFaint),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _menu(BuildContext context, AppState app) async {
    final fb = context.fb;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: fb.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          _MenuRow(icon: 'plus', label: app.t('make_variant'), onTap: () => Navigator.pop(ctx, 'variant')),
          _MenuRow(icon: 'link', label: app.t('unlink_source'), onTap: () => Navigator.pop(ctx, 'unlink')),
          _MenuRow(icon: 'trash', label: app.t('remove_from_book'), danger: true, onTap: () => Navigator.pop(ctx, 'remove')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'variant') {
      final id = app.addVariant(recipeId);
      if (context.mounted) Nav.editRecipe(context, id);
    } else if (choice == 'unlink') {
      final newId = await app.detachLinked(recipeId);
      // the recipe's id changed on fork → reopen the now-owned recipe
      if (newId != null && context.mounted) Nav.openRecipe(context, newId, replace: true);
    } else if (choice == 'remove') {
      app.deleteRecipe(recipeId); // linked → just unlinks; leaves the book
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _MenuRow extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final bool danger;
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final color = danger ? const Color(0xFFC0563B) : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          FbIcon(icon, size: 18, color: color ?? fb.accent),
          const SizedBox(width: 12),
          Text(label, style: fb.ui(size: 15, weight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

/// "🔒 de @owner" chip shown in a linked recipe's title card.
class LinkedOwnerChip extends StatelessWidget {
  final Recipe recipe;
  const LinkedOwnerChip({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    if (!recipe.isLinked) return const SizedBox.shrink();
    final name = recipe.linkedOwnerName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FbIcon('lock', size: fb.fs(12), color: fb.accent),
        const SizedBox(width: 5),
        Text(name != null ? '${context.read<AppState>().t('from_owner')} @$name' : context.read<AppState>().t('locked_readonly'), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.accent)),
      ]),
    );
  }
}
