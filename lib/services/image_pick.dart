import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

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
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: app.lang == 'fr' ? 'Cadrer la photo' : 'Reframe photo',
          toolbarColor: fb.accent,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: fb.accent,
          backgroundColor: Colors.black,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: app.lang == 'fr' ? 'Cadrer la photo' : 'Reframe photo',
          aspectRatioLockEnabled: false,
        ),
      ],
    );
    return cropped?.path; // null if the crop screen was cancelled
  }
}
