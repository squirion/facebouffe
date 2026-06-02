import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

/// Settings → Recently deleted: the last [AppState.maxTrash] soft-deleted
/// recipes, each restorable (or permanently removable). Older deletions are
/// evicted automatically.
class RecentlyDeletedScreen extends StatelessWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final entries = app.recentlyDeleted;
    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          FbHeader(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
                const SizedBox(width: 4),
                Expanded(child: Text(app.t('trash_title'), style: fb.display(size: 25, weight: FontWeight.w600))),
              ]),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        FbIcon('trash', size: 40, color: fb.inkFaint),
                        const SizedBox(height: 14),
                        Text(app.t('trash_empty'), textAlign: TextAlign.center, style: fb.ui(size: 14.5, color: fb.inkFaint, height: 1.5)),
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(app.t('trash_hint'), style: fb.ui(size: 12.5, color: fb.inkFaint, height: 1.45)),
                      ),
                      for (int i = 0; i < entries.length; i++) _card(context, app, fb, i, entries[i]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, AppState app, FbTheme fb, int index, Map<String, dynamic> entry) {
    final rj = entry['recipe'] as Map? ?? const {};
    final title = (rj['title'] ?? '').toString().trim();
    final ing = (rj['ingredients'] as List?)?.length ?? 0;
    final steps = (rj['steps'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line), boxShadow: fb.shadow),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title.isEmpty ? (app.lang == 'fr' ? 'Sans titre' : 'Untitled') : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 15.5, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                FbIcon('basket', size: 13, color: fb.inkFaint),
                const SizedBox(width: 4),
                Text('$ing', style: fb.ui(size: 12.5, color: fb.inkFaint)),
                const SizedBox(width: 10),
                FbIcon('note', size: 13, color: fb.inkFaint),
                const SizedBox(width: 4),
                Text('$steps', style: fb.ui(size: 12.5, color: fb.inkFaint)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              app.restoreDeleted(index);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${app.t('trash_restored')}${title.isEmpty ? '' : ' · $title'}')));
            },
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(11)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const FbIcon('refresh', size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(app.t('restore'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () => _confirmPurge(context, app, index, title),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SizedBox(width: 34, height: 38, child: Center(child: FbIcon('trash', size: 17, color: fb.inkFaint))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurge(BuildContext context, AppState app, int index, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('trash_purge_title')),
        content: Text(app.t('trash_purge_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('delete'), style: const TextStyle(color: Color(0xFFC0563B), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) app.purgeDeleted(index);
  }
}
