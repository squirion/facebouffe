import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../services/cnf.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import '../widgets/nutrition.dart';
import 'settings_screen.dart' show SettingsGroup, TagManager;

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
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
                Text(app.t('advanced'), style: fb.display(size: 25, weight: FontWeight.w600)),
              ]),
            ),
          ),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                SettingsGroup(label: app.t('custom_tags'), children: const [TagManager()]),
                SettingsGroup(label: app.t('aliases_title'), children: const [AliasManager()]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings editor for the learned ingredient → CNF food alias table.
class AliasManager extends StatefulWidget {
  const AliasManager({super.key});
  @override
  State<AliasManager> createState() => _AliasManagerState();
}

class _AliasManagerState extends State<AliasManager> {
  String? editKey;
  bool remember = true;

  @override
  void initState() {
    super.initState();
    Cnf.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final entries = app.aliases.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: entries.isNotEmpty ? BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))) : null,
          child: Text(app.t('aliases_hint'), style: fb.ui(size: 12.5, color: fb.inkFaint, height: 1.45)),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text(app.t('aliases_empty'), style: fb.ui(size: 13.5, color: fb.inkFaint, height: 1.5)),
          ),
        for (int i = 0; i < entries.length; i++)
          Container(
            decoration: i < entries.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))) : null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon('leaf', size: 15, color: fb.accent))),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(entries[i].key, style: fb.ui(size: 15, weight: FontWeight.w600)),
                        Text('→ ${Cnf.instance.cnfName(entries[i].value, app.lang)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12.5, color: fb.inkSoft)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() { editKey = editKey == entries[i].key ? null : entries[i].key; remember = true; }), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('pencil', size: 16, color: fb.inkSoft)))),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => app.removeAlias(entries[i].key), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('trash', size: 16, color: fb.inkSoft)))),
                  ]),
                ),
                if (editKey == entries[i].key)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: CnfPicker(
                      ingredientName: entries[i].key,
                      remember: remember,
                      setRemember: (v) => setState(() => remember = v),
                      onPick: (food) { app.addAlias(entries[i].key, food.code); setState(() => editKey = null); },
                      onClose: () => setState(() => editKey = null),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
