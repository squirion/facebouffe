import 'package:flutter/material.dart';

/// Facebouffe theme — warm cookbook palette, ported from the mockup's buildTheme.
/// Two surfaces (light/dark), an accent color, and a font scale driven by the
/// user's "text size" setting. Display face = Newsreader, UI face = Hanken Grotesk.
class FbTheme {
  final bool dark;
  final Color accent;
  final double scale;

  final Color canvas, canvas2, card, cardSoft;
  final Color ink, inkSoft, inkFaint;
  final Color line, lineStrong, accentSoft;
  final Color glass, scrim;
  final List<BoxShadow> shadow;
  final Color gold = const Color(0xFFF4B400);
  // Semantic colors — theme-independent mid-tones, legible on both surfaces.
  final Color favorite = const Color(0xFFD64545); // favorite heart (warm red)
  final Color danger = const Color(0xFFC0563B); // destructive actions / errors
  final Color dangerInk = const Color(0xFF9C3F29); // darker danger, for text on tint
  final Color success = const Color(0xFF6BA368); // confirmations / "in cart"
  final Color warn = const Color(0xFFC58A2E); // caution (mustard)
  final Color warnIcon = const Color(0xFF9A6C1E);
  final Color warnInk = const Color(0xFF8A6018); // warning text on tint
  Color get warnBg => warn.withValues(alpha: dark ? 0.16 : 0.08);
  Color get warnBorder => warn.withValues(alpha: 0.33);

  FbTheme._({
    required this.dark,
    required this.accent,
    required this.scale,
    required this.canvas,
    required this.canvas2,
    required this.card,
    required this.cardSoft,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.accentSoft,
    required this.glass,
    required this.scrim,
    required this.shadow,
  });

  factory FbTheme.build({
    required bool dark,
    required Color accent,
    required String fontSize,
  }) {
    final scale = const {'small': 0.92, 'medium': 1.0, 'large': 1.12}[fontSize] ?? 1.0;
    if (dark) {
      return FbTheme._(
        dark: true,
        accent: accent,
        scale: scale,
        canvas: const Color(0xFF19150F),
        canvas2: const Color(0xFF211C15),
        card: const Color(0xFF272019),
        cardSoft: const Color(0xFF2F271E),
        ink: const Color(0xFFF3ECE1),
        inkSoft: const Color(0xFFB7AC9D),
        inkFaint: const Color(0xFF857B6D),
        line: Colors.white.withValues(alpha: 0.09),
        lineStrong: Colors.white.withValues(alpha: 0.16),
        accentSoft: const Color(0xFFD9734F).withValues(alpha: 0.18),
        glass: const Color(0xFF211C15).withValues(alpha: 0.92),
        scrim: Colors.black.withValues(alpha: 0.6),
        shadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 8))],
      );
    }
    return FbTheme._(
      dark: false,
      accent: accent,
      scale: scale,
      canvas: const Color(0xFFFBF6EE),
      canvas2: const Color(0xFFF4ECE0),
      card: Colors.white,
      cardSoft: const Color(0xFFFBF6EF),
      ink: const Color(0xFF2B2620),
      inkSoft: const Color(0xFF736A5E),
      inkFaint: const Color(0xFFA89E90),
      line: const Color(0xFF2B2620).withValues(alpha: 0.10),
      lineStrong: const Color(0xFF2B2620).withValues(alpha: 0.16),
      accentSoft: accent.withValues(alpha: 0.10),
      glass: const Color(0xFFFBF6EE).withValues(alpha: 0.92),
      scrim: const Color(0xFF281E16).withValues(alpha: 0.5),
      shadow: [BoxShadow(color: const Color(0xFF4A3728).withValues(alpha: 0.13), blurRadius: 34, offset: const Offset(0, 10))],
    );
  }

  /// Scale a px font size by the user's text-size preference.
  double fs(double px) => (px * scale * 100).roundToDouble() / 100;

  TextStyle display({double size = 16, FontWeight weight = FontWeight.w500, Color? color, double? height, double? letterSpacing, FontStyle? fontStyle}) {
    return TextStyle(
      fontFamily: 'Newsreader',
      fontSize: fs(size),
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  /// Heavy brand wordmark face (Bricolage Grotesque), used for the home title bar.
  TextStyle wordmark({double size = 33, FontWeight weight = FontWeight.w800, Color? color, double? height, double? letterSpacing}) {
    return TextStyle(
      fontFamily: 'Bricolage Grotesque',
      fontSize: fs(size),
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle ui({double size = 14, FontWeight weight = FontWeight.w500, Color? color, double? height, double? letterSpacing, FontStyle? fontStyle, TextDecoration? decoration}) {
    return TextStyle(
      fontFamily: 'Hanken Grotesk',
      fontSize: fs(size),
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }
}

/// Curated warm fallback palette — deterministic stand-in art for recipes
/// without a photo. Ported from FALLBACK_PALETTE.
class FallbackColor {
  final Color bg;
  final Color ink;
  const FallbackColor(this.bg, this.ink);
}

const List<FallbackColor> kFallbackPalette = [
  FallbackColor(Color(0xFFC0563B), Color(0xFFFFF3EC)), // terracotta
  FallbackColor(Color(0xFFE0A458), Color(0xFF3A2A12)), // ochre
  FallbackColor(Color(0xFF6BA368), Color(0xFFF2F8EE)), // sage
  FallbackColor(Color(0xFF4A7BA6), Color(0xFFEAF2F8)), // slate blue
  FallbackColor(Color(0xFFB8743F), Color(0xFFFFF1E4)), // clay
  FallbackColor(Color(0xFF9C6B8E), Color(0xFFFBEEF6)), // plum
  FallbackColor(Color(0xFF7E8B4E), Color(0xFFF6F8EC)), // olive
  FallbackColor(Color(0xFFD08552), Color(0xFFFFF1E6)), // apricot
  FallbackColor(Color(0xFF5B8C7E), Color(0xFFECF6F2)), // pine
  FallbackColor(Color(0xFFC58A2E), Color(0xFFFFF6E6)), // mustard
];

/// Parse a "#RRGGBB" (or "#AARRGGBB") hex string to a Color.
Color hexColor(String hex, {double opacity = 1}) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.parse(h, radix: 16);
  return Color(v).withValues(alpha: opacity);
}

int hashStr(String s) {
  int h = 0;
  for (int i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.codeUnitAt(i);
    h = h.toSigned(32);
  }
  return h.abs();
}

FallbackColor fallbackColorFor(String seed) {
  final s = seed.isEmpty ? 'x' : seed;
  return kFallbackPalette[hashStr(s) % kFallbackPalette.length];
}

/// Lets any widget read the current theme via `context.fb`.
extension FbThemeContext on BuildContext {
  FbTheme get fb {
    final w = dependOnInheritedWidgetOfExactType<_FbThemeScope>();
    assert(w != null, 'FbTheme not found in context');
    return w!.theme;
  }
}

class FbThemeScope extends StatelessWidget {
  final FbTheme theme;
  final Widget child;
  const FbThemeScope({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) => _FbThemeScope(theme: theme, child: child);
}

class _FbThemeScope extends InheritedWidget {
  final FbTheme theme;
  const _FbThemeScope({required this.theme, required super.child});

  @override
  bool updateShouldNotify(_FbThemeScope oldWidget) =>
      oldWidget.theme.dark != theme.dark ||
      oldWidget.theme.accent != theme.accent ||
      oldWidget.theme.scale != theme.scale;
}
