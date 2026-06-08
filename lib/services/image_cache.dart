import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show File, Directory;
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'sync/sync_backend.dart';

/// Content-addressed image store, extracted from AppState. Hashes local photos,
/// uploads/downloads bytes via the [SyncBackend], caches them on disk (native)
/// or resolves signed URLs (web), maintains the recipe→image ref-count rows, and
/// holds the avatar cache. AppState still owns the recipe→path maps
/// (`recipePhotos`/`recipeGallery`) and decides when to persist/notify — this
/// service is the pure byte/network/filesystem layer, independently testable.
class ImageCacheService {
  ImageCacheService(this._sync, this._onChanged);

  final SyncBackend _sync;
  final void Function() _onChanged; // notify listeners (avatar lands in background)

  final Map<String, String> _imgHashCache = {}; // local photo path -> sha-256 hash
  final Map<String, List<String>> _recipeImgHashes = {}; // recipe id -> last-synced hash set
  final Map<String, String> avatarCache = {}; // avatar hash -> local path (or web signed URL)
  final Set<String> _avatarLoading = {}; // avatar hashes currently downloading
  Directory? _docsDir;

  Future<Directory?> _dir() async {
    if (_docsDir != null) return _docsDir;
    try {
      return _docsDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Read a local photo's bytes (a `data:` URL or, on native, a file path).
  Future<Uint8List?> readBytes(String path) async {
    try {
      if (path.startsWith('data:')) {
        final i = path.indexOf(',');
        return base64Decode(path.substring(i + 1));
      }
      if (kIsWeb) return null; // web non-data paths aren't readable as files
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Hash a local photo and upload its bytes (content-addressed dedup). Returns
  /// the hash, or null if the bytes can't be read.
  Future<String?> hashAndUpload(String path) async {
    final cached = _imgHashCache[path];
    if (cached != null) return cached; // already hashed (and uploaded) this session
    final bytes = await readBytes(path);
    if (bytes == null) return null;
    final hash = sha256.convert(bytes).toString();
    await _sync.uploadImageIfAbsent(hash, bytes, 'image/jpeg');
    _imgHashCache[path] = hash;
    return hash;
  }

  /// Upload a recipe's hero + gallery photo bytes. Returns
  /// `{hero: hash?, gallery: [hash,…]}`. Does NOT touch recipe_images — that
  /// registration runs in [registerRecipeImages] AFTER the recipe row exists.
  Future<Map<String, dynamic>> uploadImagesFor(String? heroPath, List<String> galleryPaths) async {
    String? heroHash;
    if (heroPath != null && heroPath.isNotEmpty) heroHash = await hashAndUpload(heroPath);
    final galleryHashes = <String>[];
    for (final p in galleryPaths) {
      final h = await hashAndUpload(p);
      if (h != null) galleryHashes.add(h);
    }
    return {'hero': heroHash, 'gallery': galleryHashes};
  }

  /// Reconcile the recipe→image ref-count rows (drives image GC). Must run after
  /// the recipe row exists, since recipe_images.recipe_id FKs recipes.id.
  Future<void> registerRecipeImages(String recipeId, Map<String, dynamic> hashes) async {
    final hero = hashes['hero'] as String?;
    final gallery = (hashes['gallery'] as List?)?.map((e) => e as String).toList() ?? const [];
    final all = [?hero, ...gallery];
    final prev = _recipeImgHashes[recipeId];
    if (prev == null || !_listEq(prev, all)) {
      await _sync.setRecipeImages(recipeId, all);
      _recipeImgHashes[recipeId] = all;
    }
  }

  /// Native: ensure the image for [hash] is cached on disk; returns its local
  /// path, or null if it can't be fetched.
  Future<String?> cachedPath(String hash) async {
    final dir = await _dir();
    if (dir == null) return null;
    final f = File('${dir.path}/img_$hash.jpg');
    if (await f.exists()) {
      _imgHashCache[f.path] = hash;
      return f.path;
    }
    final bytes = await _sync.downloadImage(hash);
    if (bytes == null) return null;
    try {
      await f.writeAsBytes(bytes);
    } catch (_) {
      return null;
    }
    _imgHashCache[f.path] = hash;
    return f.path;
  }

  /// Web: a time-limited signed URL for [hash], or null if missing.
  Future<String?> signedUrl(String hash) => _sync.imageUrl(hash);

  // ── avatars ──
  /// Cached path/URL for an avatar hash, or null (kicks off a background fetch;
  /// listeners are notified when it lands).
  String? avatarFor(String? hash) {
    if (hash == null) return null;
    final p = avatarCache[hash];
    if (p != null) return p;
    unawaited(_ensureAvatar(hash));
    return null;
  }

  Future<void> _ensureAvatar(String hash) async {
    if (avatarCache.containsKey(hash) || _avatarLoading.contains(hash)) return;
    _avatarLoading.add(hash);
    try {
      if (kIsWeb) {
        final u = await _sync.imageUrl(hash); // web: signed URL, no file cache
        if (u != null) {
          avatarCache[hash] = u;
          _onChanged();
        }
        return;
      }
      final dir = await _dir();
      if (dir == null) return;
      final f = File('${dir.path}/avatar_$hash.jpg');
      if (!await f.exists()) {
        final bytes = await _sync.downloadImage(hash);
        if (bytes == null) return;
        await f.writeAsBytes(bytes);
      }
      avatarCache[hash] = f.path;
      _onChanged();
    } catch (_) {
      // leave uncached; falls back to the letter avatar
    } finally {
      _avatarLoading.remove(hash);
    }
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
