import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/app_state.dart';
import 'crash_log.dart';
import 'image_ops.dart';
import 'local_store.dart';
import '../theme.dart';
import '../widgets/fb_icon.dart';
import 'package:provider/provider.dart';

/// Where a picked photo should land, persisted while the picker is open so the
/// photo can be re-attached if Android kills the app during the camera intent
/// (see [ImagePick.recoverLostPick]). Step photos pass no target: they attach
/// to an unsaved in-memory form that dies with the process.
class PickTarget {
  final String kind; // 'hero' | 'gallery' | 'avatar'
  final String? id; // photoId for hero/gallery
  const PickTarget(this.kind, [this.id]);
}

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
  static Future<String?> pick(BuildContext context, {PickTarget? recover}) async {
    final source = await _chooseSource(context);
    if (source == null) return null;
    if (!context.mounted) return null;
    return pickFrom(context, source, recover: recover);
  }

  /// Pick from a known source, then crop. Returns cropped path or null.
  static Future<String?> pickFrom(BuildContext context, ImageSource source, {PickTarget? recover}) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final fb = context.fb;
    final screen = MediaQuery.sizeOf(context);
    // While the picker is open Android may kill us (camera is memory-hungry);
    // persist where the photo was headed so recoverLostPick can re-attach it.
    LocalStore? store;
    if (!kIsWeb && Platform.isAndroid && recover != null) {
      store = await LocalStore.create();
      store.setJson(LocalStore.pickCtx,
          {'kind': recover.kind, 'id': recover.id, 'ts': DateTime.now().millisecondsSinceEpoch});
    }
    if (!context.mounted) return null;
    try {
      return await _pickFromInner(context, source, app, messenger, fb, screen);
    } finally {
      store?.remove(LocalStore.pickCtx);
    }
  }

  static Future<String?> _pickFromInner(BuildContext context, ImageSource source, AppState app,
      ScaffoldMessengerState messenger, FbTheme fb, Size screen) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 92);
    } catch (e) {
      CrashLog.instance.add('img', 'pick failed (${source.name}): $e');
      messenger.showSnackBar(SnackBar(content: Text(app.lang == 'fr' ? 'Caméra indisponible' : 'Camera unavailable')));
      return null;
    }
    if (picked == null) return null;
    try {
      CrashLog.instance.add('img', 'picked ${source.name} ${(await picked.length() / 1024).round()}KB');
    } catch (_) {}
    final title = app.lang == 'fr' ? 'Cadrer la photo' : 'Reframe photo';
    if (!context.mounted) return null;
    final CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
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
          if (kIsWeb)
            WebUiSettings(
              context: context,
              // The stock dialog is a fixed 500×500 non-scrolling column; on
              // phone-sized viewports the Cancel/Crop footer gets clipped off
              // screen, so size the cropper to leave room for the chrome.
              size: CropperSize(
                width: math.max(240, math.min(500, screen.width.round() - 88)),
                height: math.max(240, math.min(500, screen.height.round() - 320)),
              ),
              translations: app.lang == 'fr'
                  ? const WebTranslations(
                      title: 'Cadrer la photo',
                      rotateLeftTooltip: 'Pivoter de 90° vers la gauche',
                      rotateRightTooltip: 'Pivoter de 90° vers la droite',
                      cancelButton: 'Annuler',
                      cropButton: 'Valider',
                    )
                  : const WebTranslations.en(),
              themeData: WebThemeData(rotateIconColor: fb.accent),
            ),
        ],
      );
    } catch (e) {
      // Native uCrop can fail on exotic files/devices — fail soft like pickImage.
      CrashLog.instance.add('img', 'crop failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(app.t('crop_failed'))));
      return null;
    }
    if (cropped == null) return null; // crop cancelled
    if (kIsWeb) {
      // Web has no file paths that persist; store a downscaled data URL so the
      // photo survives reloads (kept small to respect browser storage limits).
      final bytes = await cropped.readAsBytes();
      final out = await reencodeImage(bytes, maxWidth: 1280, quality: 80) ?? bytes;
      return 'data:image/jpeg;base64,${base64Encode(out)}';
    }
    // Android/iOS: downscale to ≤1600 px and re-encode into the app's documents
    // dir, so recipe photos stay reasonably small and persist (the crop output
    // lives in a cache dir that the OS can purge).
    return await saveRecipePhoto(cropped.readAsBytes) ?? cropped.path;
  }

  /// Android kills us during camera/gallery intents on low-RAM phones; the
  /// picked photo survives in the platform's saved state. Called once at
  /// startup (RootShell) to re-attach it where it was headed. Crop is skipped
  /// on recovery — the uCrop screen died with the process, and cold-launching
  /// a crop dialog out of nowhere would be disorienting.
  static Future<void> recoverLostPick(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = await LocalStore.create();
      final rawCtx = store.str(LocalStore.pickCtx);
      if (rawCtx == null) return; // no pick was in flight
      store.remove(LocalStore.pickCtx);
      final ctx = jsonDecode(rawCtx) as Map<String, dynamic>;
      // An unconsumed ctx means the app died mid-pick — evidence for the log.
      CrashLog.instance.add('img', 'lostData: pick was in flight last session');
      final response = await ImagePicker().retrieveLostData();
      if (response.exception != null) CrashLog.instance.add('img', 'lostData exception: ${response.exception!.code}');
      final file = response.isEmpty ? null : response.file;
      if (file == null) return;
      final ts = (ctx['ts'] as num?)?.toInt() ?? 0;
      final fresh = DateTime.now().millisecondsSinceEpoch - ts < 30 * 60 * 1000;
      final kind = ctx['kind'] as String?;
      final id = ctx['id'] as String?;
      if (!fresh) return;
      final path = await saveRecipePhoto(file.readAsBytes);
      if (path == null) return;
      switch (kind) {
        case 'hero' when id != null:
          app.setRecipePhoto(id, path);
        case 'gallery' when id != null:
          app.addGalleryPhoto(id, path);
        case 'avatar':
          await app.applyAvatar(path);
        default:
          return; // unknown target — drop silently
      }
      CrashLog.instance.add('img', 'lostData recovered kind=$kind');
      messenger.showSnackBar(SnackBar(content: Text(app.t('photo_recovered'))));
    } catch (_) {
      // best-effort recovery; never disturb startup
    }
  }

  /// Re-encode a picked/recovered photo off-isolate and persist it in the
  /// app's documents dir. Null on any failure (caller decides the fallback).
  static Future<String?> saveRecipePhoto(Future<Uint8List> Function() readBytes) async {
    try {
      final bytes = await readBytes();
      final out = await reencodeImage(bytes, maxWidth: 1600, quality: 88);
      if (out == null) return null;
      CrashLog.instance.add('img', 'reencode ${(bytes.length / 1024).round()}KB→${(out.length / 1024).round()}KB');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/photo_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(out);
      return file.path;
    } catch (e) {
      CrashLog.instance.add('img', 'save failed: $e');
      return null;
    }
  }
}
