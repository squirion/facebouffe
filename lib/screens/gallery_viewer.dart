import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';

/// Fullscreen gallery: swipe left/right through a recipe's photos, with a
/// page-dot indicator (and a counter for longer galleries) and a close button.
class GalleryViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const GalleryViewerScreen({super.key, required this.images, this.initialIndex = 0});

  @override
  State<GalleryViewerScreen> createState() => _GalleryViewerScreenState();
}

class _GalleryViewerScreenState extends State<GalleryViewerScreen> {
  late final PageController _pager = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final count = widget.images.length;
    final showDots = count > 1 && count <= 10;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // swipeable pages — pinch/double-tap to zoom, drag to pan when zoomed
          PageView.builder(
            controller: _pager,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(child: fileImage(widget.images[i], fit: BoxFit.contain)),
            ),
          ),
          // close (top-left)
          Positioned(
            top: topInset + 6,
            left: 14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: const Center(child: FbIcon('x', size: 22, color: Colors.white)),
              ),
            ),
          ),
          // counter (top-right) for context, esp. on longer galleries
          if (count > 1)
            Positioned(
              top: topInset + 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                child: Text('${_index + 1} / $count', style: fb.ui(size: 13, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          // page dots (bottom)
          if (showDots)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: _index == i ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _index == i ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
