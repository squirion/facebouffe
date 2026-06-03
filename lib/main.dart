import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'screens/shell.dart';
import 'services/timer_notifications.dart';
import 'services/sync/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseSyncBackend.boot(); // connect to Supabase (optional-login social layer)
  final app = AppState();
  TimerNotifications.instance.init(); // fire-and-forget; no-op on web; idempotent
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider(create: (_) => ShellTab()),
      ],
      child: const FacebouffeApp(),
    ),
  );
  app.init();
}

class FacebouffeApp extends StatelessWidget {
  const FacebouffeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = FbTheme.build(dark: app.dark, accent: hexColor(app.accentHex), fontSize: app.profile.fontSize);

    return MaterialApp(
      title: 'Facebouffe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: theme.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accent,
          brightness: app.dark ? Brightness.dark : Brightness.light,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) {
        // honor OS reduce-motion; keep AppState in sync for motion gating
        final reduce = MediaQuery.of(context).disableAnimations;
        WidgetsBinding.instance.addPostFrameCallback((_) => app.setReduceMotion(reduce));
        // Tap anywhere outside a field drops focus (removes the cursor +
        // dismisses the keyboard). Taps on buttons/fields win the gesture arena,
        // so this only fires on empty space; scrolling is unaffected.
        return FbThemeScope(
          theme: theme,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child!,
          ),
        );
      },
      home: app.ready ? const RootShell() : _Splash(theme: theme),
    );
  }
}

class _Splash extends StatelessWidget {
  final FbTheme theme;
  const _Splash({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.canvas,
      body: Center(
        child: Text('Facebouffe', style: theme.display(size: 34, weight: FontWeight.w600, color: theme.accent, letterSpacing: 0.3)),
      ),
    );
  }
}
