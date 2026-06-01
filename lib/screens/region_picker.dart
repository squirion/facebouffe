import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/fb_icon.dart';

/// Full-screen step where the user draws one or more boxes over [image] to mark
/// a recipe region (ingredients, then steps). Returns the boxes as fractional
/// [Rect]s (0–1 of the image), an empty list if skipped, or null if cancelled.
/// Region-guided OCR sharply improves the small on-device model's accuracy.
class RegionPicker extends StatefulWidget {
  final Uint8List image;
  final String title;
  final String hint;
  final bool isLast;
  const RegionPicker({super.key, required this.image, required this.title, required this.hint, required this.isLast});

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker> {
  ui.Image? _img;
  final List<Rect> _boxes = []; // fractional (0..1) of the image
  Rect? _dragPx; // in-progress box, in the displayed-image pixel space
  Offset? _start;
  Rect _shown = Rect.zero; // displayed image rect within the canvas

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.image, (img) {
      if (mounted) setState(() => _img = img);
    });
  }

  // contain-fit the image inside [box]
  Rect _fit(Size box) {
    final iw = _img!.width.toDouble(), ih = _img!.height.toDouble();
    final scale = (box.width / iw).clamp(0.0, double.infinity);
    final s = (box.height / ih) < scale ? (box.height / ih) : scale;
    final w = iw * s, h = ih * s;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  void _onStart(Offset p) {
    if (!_shown.contains(p)) return;
    _start = p;
    setState(() => _dragPx = Rect.fromPoints(p, p));
  }

  void _onUpdate(Offset p) {
    if (_start == null) return;
    final c = Offset(p.dx.clamp(_shown.left, _shown.right), p.dy.clamp(_shown.top, _shown.bottom));
    setState(() => _dragPx = Rect.fromPoints(_start!, c));
  }

  void _onEnd() {
    final d = _dragPx;
    _start = null;
    if (d == null) return;
    // ignore tiny taps
    if (d.width > 12 && d.height > 12) {
      final frac = Rect.fromLTRB(
        (d.left - _shown.left) / _shown.width,
        (d.top - _shown.top) / _shown.height,
        (d.right - _shown.left) / _shown.width,
        (d.bottom - _shown.top) / _shown.height,
      );
      _boxes.add(frac);
    }
    setState(() => _dragPx = null);
  }

  Rect _toPx(Rect frac) => Rect.fromLTRB(
        _shown.left + frac.left * _shown.width,
        _shown.top + frac.top * _shown.height,
        _shown.left + frac.right * _shown.width,
        _shown.top + frac.bottom * _shown.height,
      );

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context, null), child: const SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: 22, color: Colors.white)))),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: fb.display(size: 20, weight: FontWeight.w600, color: Colors.white)),
                    Text(widget.hint, style: fb.ui(size: 12.5, color: Colors.white70)),
                  ]),
                ),
                if (_boxes.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _boxes.clear()),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(app.lang == 'fr' ? 'Effacer' : 'Clear', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white))),
                  ),
              ]),
            ),
            // canvas
            Expanded(
              child: _img == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : LayoutBuilder(builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      _shown = _fit(size);
                      return GestureDetector(
                        onPanStart: (d) => _onStart(d.localPosition),
                        onPanUpdate: (d) => _onUpdate(d.localPosition),
                        onPanEnd: (_) => _onEnd(),
                        child: Stack(children: [
                          Positioned.fromRect(rect: _shown, child: Image.memory(widget.image, fit: BoxFit.fill)),
                          // dim outside? keep simple: draw boxes
                          for (var i = 0; i < _boxes.length; i++) _boxWidget(fb, _toPx(_boxes[i]), i),
                          if (_dragPx != null)
                            Positioned.fromRect(
                              rect: _dragPx!,
                              child: Container(decoration: BoxDecoration(color: fb.accent.withValues(alpha: 0.18), border: Border.all(color: fb.accent, width: 2))),
                            ),
                        ]),
                      );
                    }),
            ),
            // footer
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, <Rect>[]),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white30)),
                      child: Center(child: Text(app.lang == 'fr' ? 'Passer' : 'Skip', style: fb.ui(size: 15, weight: FontWeight.w700, color: Colors.white))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, List<Rect>.from(_boxes)),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text('${widget.isLast ? (app.lang == 'fr' ? 'Importer' : 'Import') : (app.lang == 'fr' ? 'Suivant' : 'Next')}${_boxes.isEmpty ? '' : ' (${_boxes.length})'}', style: fb.ui(size: 15.5, weight: FontWeight.w700, color: Colors.white))),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boxWidget(FbTheme fb, Rect px, int i) => Positioned.fromRect(
        rect: px,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(decoration: BoxDecoration(color: fb.accent.withValues(alpha: 0.16), border: Border.all(color: fb.accent, width: 2))),
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
              onTap: () => setState(() => _boxes.removeAt(i)),
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFFC0563B), shape: BoxShape.circle), child: const Center(child: FbIcon('x', size: 13, color: Colors.white))),
            ),
          ),
        ]),
      );
}
