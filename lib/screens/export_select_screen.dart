import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../services/pdf_export.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

/// PDF "book" recipe picker: alphabetical list of recipes with checkboxes, a
/// search filter, an All/None toggle, and an Export action. Opened from the
/// Settings "Export as book (PDF)" choice when the user picks a subset.
/// All recipes start selected (uncheck to exclude). Matches the app's chrome.
class ExportSelectScreen extends StatefulWidget {
  const ExportSelectScreen({super.key});

  @override
  State<ExportSelectScreen> createState() => _ExportSelectScreenState();
}

class _ExportSelectScreenState extends State<ExportSelectScreen> {
  final _ctl = TextEditingController();
  String q = '';
  late final List<Recipe> _all;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _all = app.baseRecipes.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _selected = _all.map((r) => r.id).toSet(); // all pre-checked
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<Recipe> get _filtered {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return _all;
    return _all.where((r) => r.title.toLowerCase().contains(qq)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final filtered = _filtered;
    // "All/None" acts on the currently visible (filtered) set.
    final allVisibleSelected = filtered.isNotEmpty && filtered.every((r) => _selected.contains(r.id));

    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          FbHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
                      const SizedBox(width: 4),
                      Expanded(child: Text(app.t('select_recipes'), style: fb.display(size: 25, weight: FontWeight.w600))),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (allVisibleSelected) {
                            _selected.removeAll(filtered.map((r) => r.id));
                          } else {
                            _selected.addAll(filtered.map((r) => r.id));
                          }
                        }),
                        child: Text(allVisibleSelected ? app.t('select_none') : app.t('select_all'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.accent)),
                      ),
                    ],
                  ),
                ),
                // search filter (mirrors the Search screen field)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
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
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? ListView(children: [EmptyState(icon: 'search', title: app.t('no_results'))])
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _row(app, fb, filtered[i]),
                  ),
          ),
          // export action bar
          _ExportBar(count: _selected.length, onExport: _selected.isEmpty ? null : () => _export(app)),
        ],
      ),
    );
  }

  Widget _row(AppState app, FbTheme fb, Recipe r) {
    final on = _selected.contains(r.id);
    return GestureDetector(
      onTap: () => setState(() => on ? _selected.remove(r.id) : _selected.add(r.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? fb.accent : fb.line), boxShadow: fb.shadow),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: on ? fb.accent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: on ? fb.accent : fb.lineStrong, width: 2)),
              child: on ? const Center(child: FbIcon('check', size: 15, color: Colors.white)) : null,
            ),
            const SizedBox(width: 13),
            Expanded(child: Text(r.title, style: fb.ui(size: 15.5, weight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Future<void> _export(AppState app) async {
    final chosen = _all.where((r) => _selected.contains(r.id)).toList();
    final nav = Navigator.of(context);
    await exportRecipesPdf(context, chosen); // opens the share/print sheet
    if (nav.mounted) nav.pop();
  }
}

class _ExportBar extends StatelessWidget {
  final int count;
  final VoidCallback? onExport;
  const _ExportBar({required this.count, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: fb.glass, border: Border(top: BorderSide(color: fb.line))),
      child: Opacity(
        opacity: onExport == null ? 0.5 : 1,
        child: GestureDetector(
          onTap: onExport,
          child: Container(
            height: 52,
            decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FbIcon('note', size: 19, color: Colors.white),
                const SizedBox(width: 9),
                Text('${app.t('export_selected_count')} · $count', style: fb.ui(size: 16, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
