import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// A round account avatar: shows the cached avatar image for [hash] if present,
/// otherwise a colored circle with [letter]. Watches AppState so it fills in
/// once the image downloads.
class Avatar extends StatelessWidget {
  final String? hash;
  final String letter;
  final double size;
  final Color? background; // circle fill for the letter fallback (default accent)
  final Color? foreground; // letter color (default white)
  const Avatar({super.key, required this.hash, required this.letter, this.size = 40, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final path = app.avatarFor(hash);
    if (path != null) {
      final img = kIsWeb
          ? Image.network(path, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Image.file(File(path), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
      return ClipOval(child: img);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? fb.accent, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        (letter.isEmpty ? '?' : letter).characters.first.toUpperCase(),
        style: fb.display(size: size * 0.46, weight: FontWeight.w600, color: foreground ?? Colors.white),
      ),
    );
  }
}
