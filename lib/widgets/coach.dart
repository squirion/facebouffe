import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Single just-in-time coach mark anchored to a control. Shows a spotlight ring
/// + tooltip when [active] and the feature hasn't been seen; dismiss writes the
/// seen-flag. Fades in (reduce-motion shortens the fade).
class Coach extends StatelessWidget {
  final String feature;
  final bool active;
  final String text;
  final bool below; // tooltip placement: below the child (else above)
  final Widget child;
  const Coach({super.key, required this.feature, required this.active, required this.text, this.below = false, required this.child});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final show = active && !app.tipsSeen.seen(feature);
    if (!show) return child;

    final tooltip = Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: fb.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 34, offset: const Offset(0, 14))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: fb.ui(size: 13.5, weight: FontWeight.w500, color: fb.canvas, height: 1.45)),
            const SizedBox(height: 11),
            GestureDetector(
              onTap: () => app.markTipSeen(feature),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(9)),
                child: Text(app.t('got_it'), style: fb.ui(size: 13, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: app.reduceMotion ? 120 : 240),
      tween: Tween(begin: 0, end: 1),
      builder: (context, v, _) => Opacity(opacity: v, child: _build(context, fb, tooltip)),
    );
  }

  Widget _build(BuildContext context, FbTheme fb, Widget tooltip) {
    final ringed = Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fb.accent, width: 3),
              ),
            ),
          ),
        ),
      ],
    );
    final tip = Center(child: tooltip);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: below
          ? [ringed, const SizedBox(height: 10), tip]
          : [tip, const SizedBox(height: 10), ringed],
    );
  }
}
