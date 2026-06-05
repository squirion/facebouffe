import 'package:flutter/material.dart';

import '../theme.dart';
import '../responsive.dart';
import 'fb_icon.dart';

/// A scrollable screen body with sensible bottom padding (clears the tab bar).
/// On wide screens the content is capped + centered ([wide] uses the roomier
/// browse cap for grids; the default uses the narrower reading cap).
class ScreenScroll extends StatelessWidget {
  final List<Widget> children;
  final double padBottom;
  final EdgeInsets? padding;
  final bool wide;
  const ScreenScroll({super.key, required this.children, this.padBottom = 96, this.padding, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final list = ListView(
      padding: (padding ?? EdgeInsets.zero).copyWith(bottom: padBottom + bottomInset),
      children: children,
    );
    final cap = wide ? context.layout.browseMax : context.layout.readMax;
    if (cap == null) return list;
    return Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: cap), child: list));
  }
}

/// Fixed top header (blurred glass look) sitting above the scroll area.
class FbHeader extends StatelessWidget {
  final Widget child;
  final bool topSafe;
  const FbHeader({super.key, required this.child, this.topSafe = true});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final top = topSafe ? MediaQuery.of(context).padding.top : 0.0;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: fb.glass,
        border: Border(bottom: BorderSide(color: fb.line)),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  const SectionLabel({super.key, required this.child, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DefaultTextStyle(style: fb.display(size: 21, weight: FontWeight.w600, letterSpacing: 0.2), child: child),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.accent)),
            ),
        ],
      ),
    );
  }
}

/// Round translucent button used over hero images (back / star / edit).
class RoundBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final bool fill;
  final Color color;
  const RoundBtn({super.key, required this.icon, required this.onTap, this.fill = false, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), shape: BoxShape.circle),
        child: Center(child: FbIcon(icon, size: 21, color: color, fill: fill)),
      ),
    );
  }
}

/// Empty-state / no-results centerpiece (icon bubble + title + hint).
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? hint;
  const EmptyState({super.key, required this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: fb.accentSoft, shape: BoxShape.circle),
            child: Center(child: FbIcon(icon, size: 28, color: fb.accent)),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: fb.display(size: 21, weight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, textAlign: TextAlign.center, style: fb.ui(size: 14, color: fb.inkSoft, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
