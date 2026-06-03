import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/fb_icon.dart';
import '../services/import/share_import.dart';
import '../nav.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'shopping_screen.dart';
import 'settings_screen.dart';
import 'import_sheet.dart';
import 'account_screens.dart' show showMigrationSheet;

/// Holds the active bottom-tab index; screens switch tabs via [go].
class ShellTab extends ValueNotifier<int> {
  ShellTab() : super(0);
  void go(int i) => value = i;
}

/// Root scaffold: the 4 tab screens in an IndexedStack, a blurred bottom tab
/// bar, and a floating "+" on Home / Search. Pushed screens (recipe, edit,
/// sous-chef, filter, help) cover this via the root Navigator.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static const _tabs = [
    ('home', 'tab_home'),
    ('search', 'tab_search'),
    ('basket', 'tab_list'),
    ('sliders', 'tab_settings'),
  ];

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _migrationShowing = false;

  @override
  void initState() {
    super.initState();
    // "Partager vers Facebouffe" — handle links/images shared from other apps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ShareImport.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final tab = context.watch<ShellTab>();
    final index = tab.value;
    final showFab = index == 0 || index == 1;

    // Later-device migration: ask once whether to add local-only recipes (§8).
    if (app.migrationPending && !_migrationShowing) {
      _migrationShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showMigrationSheet(context, app);
        _migrationShowing = false;
      });
    }

    return Scaffold(
      backgroundColor: fb.canvas,
      body: IndexedStack(
        index: index,
        children: const [HomeScreen(), SearchScreen(), ShoppingScreen(), SettingsScreen()],
      ),
      floatingActionButton: showFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 2),
              child: GestureDetector(
                onTap: () => showImportSheet(context), // method chooser: manual / link / photo / text (§2f)
                onLongPress: app.hasAnyImportKey ? () => Nav.openAdventure(context) : null, // easter egg: "I'm feeling adventurous!" (BYOK only)
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: fb.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: fb.accent.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 10))],
                  ),
                  child: const Center(child: FbIcon('plus', size: 28, color: Colors.white)),
                ),
              ),
            )
          : null,
      bottomNavigationBar: _TabBar(index: index, app: app, onTap: tab.go),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final AppState app;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(bottom: bottomInset, top: 8, left: 6, right: 6),
          decoration: BoxDecoration(color: fb.glass, border: Border(top: BorderSide(color: fb.line))),
          child: Row(
            children: [
              for (int i = 0; i < RootShell._tabs.length; i++) _tabItem(context, fb, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem(BuildContext context, FbTheme fb, int i) {
    final (icon, key) = RootShell._tabs[i];
    final on = index == i;
    final color = on ? fb.accent : fb.inkFaint;
    final badge = i == 2 ? app.shoppingUncheckedCount : 0;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FbIcon(icon, size: 25, color: color, fill: on && i == 0),
                  if (badge > 0)
                    Positioned(
                      top: -3,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(999)),
                        alignment: Alignment.center,
                        child: Text('$badge', style: fb.ui(size: 10, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(app.t(key), style: fb.ui(size: 10.5, weight: on ? FontWeight.w700 : FontWeight.w600, color: color, letterSpacing: 0.1)),
            ],
          ),
        ),
      ),
    );
  }
}
