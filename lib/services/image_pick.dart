import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/fb_icon.dart';
import 'package:provider/provider.dart';

/// Shared photo flow: choose camera vs gallery, pick, then crop/reframe in the
/// system uCrop screen. Returns the cropped file path, or null if the user
/// cancelled at any step. Used by the hero photo and the gallery.
class ImagePick {
  static Future<ImageSource?> _chooseSource(BuildContext context) {
    final app = context.read<AppState>();
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final fb = ctx.fb;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const FbIcon('camera'),
                title: Text(app.lang == 'fr' ? 'Prendre une photo' : 'Take a photo', style: fb.ui(size: 15.5)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const FbIcon('note'),
                title: Text(app.lang == 'fr' ? 'Choisir dans la galerie' : 'Choose from gallery', style: fb.ui(size: 15.5)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Full flow: ask source → pick → crop. Returns cropped path or null.
  static Future<String?> pick(BuildContext context) async {
    final source = await _chooseSource(context);
    if (source == null) return null;
    if (!context.mounted) return null;
    return pickFrom(context, source);
  }

  /// Pick from a known source, then crop. Returns cropped path or null.
  static Future<String?> pickFrom(BuildContext context, ImageSource source) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final fb = context.fb;
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 92);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(app.lang == 'fr' ? 'Caméra indisponible' : 'Camera unavailable')));
      return null;
    }
    if (picked == null) return null;
    final title = app.lang == 'fr' ? 'Cadrer la photo' : 'Reframe photo';
    if (!context.mounted) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: fb.accent,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: fb.accent,
          backgroundColor: Colors.black,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: title, aspectRatioLockEnabled: false),
        if (kIsWeb) WebUiSettings(context: context),
      ],
    );
    if (cropped == null) return null; // crop cancelled
    if (kIsWeb) {
      // Web has no file paths that persist; store a downscaled data URL so the
      // photo survives reloads (kept small to respect browser storage limits).
      final bytes = await cropped.readAsBytes();
      final decoded = img.decodeImage(bytes);
      List<int> out = bytes;
      if (decoded != null) {
        final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
        out = img.encodeJpg(resized, quality: 80);
      }
      return 'data:image/jpeg;base64,${base64Encode(out)}';
    }
    // Android/iOS: downscale to ≤1600 px and re-encode into the app's documents
    // dir, so recipe photos stay reasonably small and persist (the crop output
    // lives in a cache dir that the OS can purge).
    try {
      final bytes = await cropped.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final resized = decoded.width > 1600 ? img.copyResize(decoded, width: 1600) : decoded;
        final out = img.encodeJpg(resized, quality: 88);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/photo_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await file.writeAsBytes(out);
        return file.path;
      }
    } catch (_) {
      // fall back to the raw cropped path
    }
    return cropped.path;
  }
}
