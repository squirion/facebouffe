import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adaptive layout decisions, derived from the available content width.
/// Breakpoints (mockup fb-tablet): <600 phone, 600–1000 tablet-portrait,
/// ≥1000 tablet-landscape / desktop.
class Layout {
  final double width;
  final bool landscape;
  const Layout(this.width, this.landscape);

  bool get compact => width < 600; // phone
  bool get medium => width >= 600 && width < 1000; // tablet portrait
  bool get expanded => width >= 1000; // tablet landscape / desktop

  bool get useRail => width >= 600; // side nav rail replaces the bottom bar
  bool get twoPane => width >= 1000; // recipe / sous-chef side-by-side

  int get gridCols => compact ? 1 : (expanded ? 3 : 2); // browse grid columns

  // Centered content caps (null = fill, phone).
  double? get browseMax => compact ? null : (expanded ? 1180 : 760);
  double? get readMax => compact ? null : (expanded ? 780 : 680);
  double? get recipeMax => compact ? null : (expanded ? 1120 : 760);
}

extension LayoutContext on BuildContext {
  Layout get layout {
    final s = MediaQuery.of(this).size;
    return Layout(s.width, s.width >= s.height);
  }
}

/// Cap content at [max] and center it (a no-op when narrower). Use inside scroll
/// views so reading/forms/browse panes don't stretch on wide screens.
class MaxW extends StatelessWidget {
  final double? max;
  final Widget child;
  final Alignment alignment;
  const MaxW({super.key, required this.max, required this.child, this.alignment = Alignment.topCenter});

  @override
  Widget build(BuildContext context) {
    if (max == null) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max!), child: child),
    );
  }
}

/// Overall app width cap for very wide screens: above [maxAppWidth] the whole UI
/// is centered on the canvas (so a 5K display shows a comfortable column, not a
/// full-width sprawl). Also overrides MediaQuery width so downstream [Layout]
/// decisions use the *capped* width. Wraps every route (via MaterialApp.builder).
const double maxAppWidth = 1400;

class AppWidthCap extends StatelessWidget {
  final Widget child;
  final Color background;
  const AppWidthCap({super.key, required this.child, required this.background});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxAppWidth) return child;
    return ColoredBox(
      color: background,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: maxAppWidth,
          child: MediaQuery(data: mq.copyWith(size: Size(maxAppWidth, mq.size.height)), child: child),
        ),
      ),
    );
  }
}

/// Locks phones (shortestSide < 600) to portrait; tablets/desktop rotate freely.
/// No-op on web. Re-evaluates when the metrics change.
class PortraitLock extends StatefulWidget {
  final Widget child;
  const PortraitLock({super.key, required this.child});

  @override
  State<PortraitLock> createState() => _PortraitLockState();
}

class _PortraitLockState extends State<PortraitLock> {
  bool? _compact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final compact = MediaQuery.of(context).size.shortestSide < 600;
    if (compact == _compact) return;
    _compact = compact;
    SystemChrome.setPreferredOrientations(
      compact ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown] : DeviceOrientation.values,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
