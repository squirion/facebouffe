import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../responsive.dart';
import '../widgets/fb_icon.dart';
import '../services/crash_log.dart';
import '../services/image_pick.dart';
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
  void go(int i) {
    if (i != value) CrashLog.instance.add('nav', 'tab $i');
    value = i;
  }
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

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  bool _migrationShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // "Partager vers Facebouffe" — handle links/images shared from other apps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ShareImport.init(context);
      // Re-attach a photo lost to an Android process-kill during pick.
      if (mounted) ImagePick.recoverLostPick(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().onAppResumed();
    }
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

    const screens = [HomeScreen(), SearchScreen(), ShoppingScreen(), SettingsScreen()];

    // Wide layouts: a left navigation rail replaces the bottom bar + FAB.
    if (context.layout.useRail) {
      return Scaffold(
        backgroundColor: fb.canvas,
        body: Row(
          children: [
            _NavRail(index: index, app: app, onTap: tab.go),
            Expanded(child: IndexedStack(index: index, children: screens)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: fb.canvas,
      body: IndexedStack(index: index, children: screens),
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

/// Left navigation rail for tablet/desktop widths: brand, a "+" add button (the
/// FAB's role), and the four tabs. Replaces the bottom tab bar.
class _NavRail extends StatelessWidget {
  final int index;
  final AppState app;
  final ValueChanged<int> onTap;
  const _NavRail({required this.index, required this.app, required this.onTap});

  static const _items = [
    ('home', 'tab_home'),
    ('search', 'tab_search'),
    ('basket', 'tab_list'),
    ('sliders', 'tab_settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: 88,
      padding: EdgeInsets.fromLTRB(0, topInset + 16, 0, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(color: fb.card, border: Border(right: BorderSide(color: fb.line))),
      child: Column(
        children: [
          Image.asset('assets/logo_mark.png', height: 34, filterQuality: FilterQuality.medium),
          const SizedBox(height: 14),
          // add (the rail's "+", same as the phone FAB)
          GestureDetector(
            onTap: () => showImportSheet(context),
            onLongPress: app.hasAnyImportKey ? () => Nav.openAdventure(context) : null,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: fb.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]),
              child: const Center(child: FbIcon('plus', size: 26, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _items.length; i++)
            _RailItem(
              icon: _items[i].$1,
              label: app.t(_items[i].$2),
              active: index == i,
              badge: i == 2 ? app.shoppingUncheckedCount : 0,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String icon, label;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _RailItem({required this.icon, required this.label, required this.active, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: active ? fb.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                FbIcon(icon, size: 25, fill: active && icon == 'home', color: active ? fb.accent : fb.inkFaint),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(999), border: Border.all(color: fb.card, width: 2)),
                      alignment: Alignment.center,
                      child: Text('$badge', style: fb.ui(size: 10, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(label, style: fb.ui(size: 10.5, weight: active ? FontWeight.w700 : FontWeight.w600, color: active ? fb.accent : fb.inkFaint)),
          ],
        ),
      ),
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
