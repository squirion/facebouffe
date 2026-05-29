// Generates launcher-icon source images from assets/facebouffe-logo.png:
//  - assets/gen/icon_fg.png   : bowl on transparent, scaled into the adaptive
//                               safe zone (for adaptive_icon_foreground)
//  - assets/gen/icon_full.png : bowl on the warm cream background, full-bleed
//                               (for the legacy/web icon image_path)
// The source bowl sits on a flat light background; we flood-fill that to
// transparent from the borders so it composites cleanly over the cream.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/facebouffe-logo.png').readAsBytesSync())!;
  final im = src.convert(numChannels: 4);
  final w = im.width, h = im.height;

  bool isLight(int x, int y) {
    final p = im.getPixel(x, y);
    return p.r > 205 && p.g > 205 && p.b > 205; // the light backdrop, not the orange bowl
  }

  // Flood-fill the connected light background from the four borders → transparent.
  final visited = List<bool>.filled(w * h, false);
  final stack = <int>[];
  void seed(int x, int y) {
    final i = y * w + x;
    if (!visited[i] && isLight(x, y)) {
      visited[i] = true;
      stack.add(i);
    }
  }
  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }
  const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w, y = i ~/ w;
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    for (final d in dirs) {
      final nx = x + d[0], ny = y + d[1];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final ni = ny * w + nx;
      if (!visited[ni] && isLight(nx, ny)) {
        visited[ni] = true;
        stack.add(ni);
      }
    }
  }

  final bowl = img.trim(im, mode: img.TrimMode.transparent);

  img.Image place(double frac, img.Color? bg) {
    const canvas = 1024;
    final c = img.Image(width: canvas, height: canvas, numChannels: 4);
    img.fill(c, color: bg ?? img.ColorRgba8(0, 0, 0, 0));
    final maxDim = (canvas * frac).round();
    final longest = bowl.width > bowl.height ? bowl.width : bowl.height;
    final scale = maxDim / longest;
    final rw = (bowl.width * scale).round(), rh = (bowl.height * scale).round();
    final resized = img.copyResize(bowl, width: rw, height: rh, interpolation: img.Interpolation.cubic);
    img.compositeImage(c, resized, dstX: (canvas - rw) ~/ 2, dstY: (canvas - rh) ~/ 2);
    return c;
  }

  Directory('assets/gen').createSync(recursive: true);
  // Adaptive foreground: keep the bowl well within the 66% safe zone.
  File('assets/gen/icon_fg.png').writeAsBytesSync(img.encodePng(place(0.62, null)));
  // Legacy / web: bowl on cream, modest margin.
  File('assets/gen/icon_full.png').writeAsBytesSync(img.encodePng(place(0.80, img.ColorRgb8(0xFB, 0xF6, 0xEE))));
  stdout.writeln('icons generated: bowl ${bowl.width}x${bowl.height}');
}
