import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/format.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'fb_icon.dart';

// ── Rating stars ────────────────────────────────────────────────
class Stars extends StatelessWidget {
  final int value;
  final double size;
  final double gap;
  final bool interactive;
  final ValueChanged<int>? onChange;
  const Stars({super.key, this.value = 0, this.size = 16, this.gap = 2, this.interactive = false, this.onChange});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i < 5 ? gap : 0),
            child: GestureDetector(
              onTap: interactive ? () => onChange?.call(i == value ? 0 : i) : null,
              child: FbIcon('star', size: size, fill: i <= value, color: i <= value ? fb.gold : fb.inkFaint),
            ),
          ),
      ],
    );
  }
}

// ── Tag chip ────────────────────────────────────────────────────
class TagChip extends StatelessWidget {
  final Tag tag;
  final String lang;
  final String size; // sm | md
  final bool active;
  final VoidCallback? onTap;
  final bool showIcon;
  const TagChip({super.key, required this.tag, required this.lang, this.size = 'md', this.active = false, this.onTap, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final tagColor = hexColor(tag.color);
    final pad = size == 'sm' ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3) : const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
    final fontSize = size == 'sm' ? 12.0 : 13.5;
    final bg = active ? tagColor : (fb.dark ? Colors.white.withValues(alpha: 0.06) : Colors.white);
    final fg = active ? Colors.white : fb.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? tagColor : fb.line),
          boxShadow: active || fb.dark ? null : [BoxShadow(color: const Color(0xFF4A3728).withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.25) : tagColor.withValues(alpha: 0.13), shape: BoxShape.circle),
                child: Center(child: FbIcon(tag.icon, size: 11, color: active ? Colors.white : tagColor)),
              ),
              const SizedBox(width: 5),
            ],
            Text(tag.displayName(lang), style: fb.ui(size: fontSize, weight: FontWeight.w600, color: fg, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}

// ── Fallback tile — deterministic warm art for photo-less recipes ──
class FallbackTile extends StatelessWidget {
  final Recipe recipe;
  final Tag? tag;
  final double radius;
  final double glyphSize;
  final String? label;
  const FallbackTile({super.key, required this.recipe, this.tag, this.radius = 20, this.glyphSize = 92, this.label});

  @override
  Widget build(BuildContext context) {
    final pal = fallbackColorFor(recipe.id.isNotEmpty ? recipe.id : recipe.title);
    final icon = tag?.icon ?? 'utensils';
    final initial = (recipe.title.trim().isEmpty ? '?' : recipe.title.trim())[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: pal.bg),
          // dot texture
          CustomPaint(painter: _DotPainter(pal.ink.withValues(alpha: 0.12))),
          // warm sheen
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.64, -0.76),
                radius: 0.9,
                colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
                stops: const [0, 0.55],
              ),
            ),
          ),
          // big glyph bottom-right
          Positioned(
            right: -glyphSize * 0.18,
            bottom: -glyphSize * 0.2,
            child: FbIcon(icon, size: glyphSize, color: pal.ink.withValues(alpha: 0.32)),
          ),
          // monogram top-left
          Positioned(
            left: 14,
            top: 8,
            child: Text(initial, style: GoogleFonts.newsreader(fontSize: glyphSize * 0.5, height: 1, fontWeight: FontWeight.w500, color: pal.ink.withValues(alpha: 0.92))),
          ),
          if (label != null)
            Positioned(
              left: 14,
              bottom: 12,
              child: Text(label!, style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, letterSpacing: 0.3, color: pal.ink.withValues(alpha: 0.7))),
            ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 15.0;
    for (double y = 4; y < size.height; y += step) {
      for (double x = 4; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
}

/// Resolves a stored photo path to an Image widget (web blob vs file).
Widget? recipeImage(BuildContext context, String? id, {BoxFit fit = BoxFit.cover}) {
  if (id == null) return null;
  final path = context.read<AppState>().recipePhotos[id];
  if (path == null || path.isEmpty) return null;
  if (kIsWeb) return Image.network(path, fit: fit, gaplessPlayback: true);
  return Image.file(File(path), fit: fit, gaplessPlayback: true);
}

// ── Hero media — photo if present, else fallback tile ───────────
class HeroMedia extends StatelessWidget {
  final Recipe recipe;
  final Tag? tag;
  final double height;
  final double radius;
  const HeroMedia({super.key, required this.recipe, this.tag, required this.height, this.radius = 0});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>(); // rebuild when a photo is added/removed
    final img = recipeImage(context, recipe.id);
    if (img != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(height: height, width: double.infinity, child: img));
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FallbackTile(recipe: recipe, tag: tag, radius: radius, glyphSize: (height * 0.7).clamp(0, 150).toDouble(), label: recipe.heroImage),
    );
  }
}

// ── PhotoDrop — editable hero photo target (camera / gallery) ───
class PhotoDrop extends StatelessWidget {
  final String photoId;
  final Recipe recipe;
  final Tag? tag;
  final double height;
  final double radius;
  final bool removable;
  const PhotoDrop({super.key, required this.photoId, required this.recipe, this.tag, required this.height, this.radius = 0, this.removable = false});

  Future<void> _pick(BuildContext context) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final fb = ctx.fb;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const FbIcon('camera'), title: Text(app.lang == 'fr' ? 'Prendre une photo' : 'Take a photo', style: fb.ui(size: 15.5)), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
              ListTile(leading: const FbIcon('note'), title: Text(app.lang == 'fr' ? 'Choisir dans la galerie' : 'Choose from gallery', style: fb.ui(size: 15.5)), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (x != null) app.setRecipePhoto(photoId, x.path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(app.lang == 'fr' ? 'Impossible d\'accéder à la caméra' : 'Camera unavailable')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final hasPhoto = (app.recipePhotos[photoId] ?? '').isNotEmpty;
    final img = recipeImage(context, photoId);
    return GestureDetector(
      onTap: () => _pick(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (img != null) img else FallbackTile(recipe: recipe, tag: tag, radius: radius, glyphSize: (height * 0.7).clamp(0, 150).toDouble()),
              if (!hasPhoto)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const FbIcon('camera', size: 16, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(app.t('add_photo'), style: fb.ui(size: 13, weight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
              if (hasPhoto && removable)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => app.setRecipePhoto(photoId, null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const FbIcon('trash', size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(app.t('remove_photo'), style: fb.ui(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Meta pill (time / servings) ─────────────────────────────────
class MetaPill extends StatelessWidget {
  final String icon;
  final String text;
  const MetaPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FbIcon(icon, size: fb.fs(15), color: fb.inkFaint),
        const SizedBox(width: 5),
        Text(text, style: fb.ui(size: 13, weight: FontWeight.w500, color: fb.inkSoft)),
      ],
    );
  }
}

// ── Rich text — {{link:id}} + {{temp:v:u}} inline chips ─────────
class RichRecipeText extends StatelessWidget {
  final String text;
  final void Function(String id)? onLink;
  final bool dark;
  final double fontSize;
  final double height;
  final Color? color;
  const RichRecipeText({super.key, required this.text, this.onLink, this.dark = false, this.fontSize = 15.5, this.height = 1.6, this.color});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final baseColor = color ?? (dark ? Colors.white : fb.inkSoft);
    final parts = text.split(RegExp(r'(\{\{(?:link|temp):[^}]+\}\})'));
    final spans = <InlineSpan>[];
    final linkRe = RegExp(r'^\{\{link:([^}]+)\}\}$');
    final tempRe2 = RegExp(r'^\{\{temp:([0-9.]+):([cfCF])\}\}$');
    for (final p in parts) {
      final lm = linkRe.firstMatch(p);
      if (lm != null) {
        final r = app.getRecipe(lm.group(1));
        if (r == null) continue;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _LinkChip(title: r.title, dark: dark, onTap: () => onLink?.call(r.id)),
        ));
        continue;
      }
      final tm = tempRe2.firstMatch(p);
      if (tm != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _TempChip(value: num.parse(tm.group(1)!), unit: tm.group(2)!, dark: dark),
        ));
        continue;
      }
      if (p.isNotEmpty) spans.add(TextSpan(text: p));
    }
    return Text.rich(
      TextSpan(children: spans, style: fb.ui(size: fontSize, color: baseColor, height: height)),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String title;
  final bool dark;
  final VoidCallback onTap;
  const _LinkChip({required this.title, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.16) : fb.accentSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(title, style: fb.ui(size: fb.fs(14), weight: FontWeight.w700, color: dark ? Colors.white : fb.accent)),
      ),
    );
  }
}

class _TempChip extends StatelessWidget {
  final num value;
  final String unit;
  final bool dark;
  const _TempChip({required this.value, required this.unit, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final pref = prefTempUnit(app.prefs);
    final c = dark ? Colors.white : fb.accent;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Text(fmtTemp(value, unit, pref), style: fb.ui(size: fb.fs(14), weight: FontWeight.w700, color: c)),
    );
  }
}
