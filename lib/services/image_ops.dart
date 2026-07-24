import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Heavy image work, kept off the UI isolate. Full-resolution decode holds
/// width×height×4 bytes (30+ MB for a phone photo) plus resize/encode copies;
/// doing that on the main isolate froze the UI and tipped low-RAM Androids
/// into native OOM kills. `compute` ships the job to a worker isolate on
/// native; on web it runs inline, which is no worse than before.

Uint8List? _reencodeSync(({Uint8List bytes, int maxWidth, int quality}) job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  final resized = decoded.width > job.maxWidth ? img.copyResize(decoded, width: job.maxWidth) : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: job.quality));
}

/// Decode → downscale to [maxWidth] → JPEG. Null when the bytes don't decode.
Future<Uint8List?> reencodeImage(Uint8List bytes, {required int maxWidth, required int quality}) =>
    compute(_reencodeSync, (bytes: bytes, maxWidth: maxWidth, quality: quality), debugLabel: 'reencodeImage');

typedef RegionBox = (double, double, double, double); // normalized l, t, w, h

({List<Uint8List> ing, List<Uint8List> steps})? _cropRegionsSync(
    ({Uint8List bytes, List<RegionBox> ing, List<RegionBox> steps}) job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  List<Uint8List> cut(List<RegionBox> boxes) {
    final out = <Uint8List>[];
    for (final (l, t, w, h) in boxes) {
      final x = (l * decoded.width).round().clamp(0, decoded.width - 1);
      final y = (t * decoded.height).round().clamp(0, decoded.height - 1);
      final cw = (w * decoded.width).round().clamp(1, decoded.width - x);
      final ch = (h * decoded.height).round().clamp(1, decoded.height - y);
      final crop = img.copyCrop(decoded, x: x, y: y, width: cw, height: ch);
      out.add(Uint8List.fromList(img.encodeJpg(crop)));
    }
    return out;
  }

  return (ing: cut(job.ing), steps: cut(job.steps));
}

/// Region-guided import: decode the page once, cut every user-drawn box, and
/// JPEG-encode each crop for OCR. Boxes are normalized (left, top, width,
/// height) records — plain doubles so they can cross the isolate boundary.
/// Null when the page image doesn't decode.
Future<({List<Uint8List> ing, List<Uint8List> steps})?> cropRegions(
        Uint8List bytes, List<RegionBox> ingBoxes, List<RegionBox> stepBoxes) =>
    compute(_cropRegionsSync, (bytes: bytes, ing: ingBoxes, steps: stepBoxes), debugLabel: 'cropRegions');
