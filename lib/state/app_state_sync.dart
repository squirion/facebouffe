part of 'app_state.dart';

// ── Phase 2A: personal cloud sync ────────────────────────────────────────────
//
// All cloud orchestration lives here as an extension on [AppState] (same library
// via `part`, so it can touch private state + persistence). The model:
//
//  • Recipes sync as `recipes.content` (the recipe json minus the private
//    `personal` overlay). Overlays (notes/rating/madeCount/lastCooked) sync to
//    `recipe_overlays`. Tag defs + variant groups + aliases sync to a per-user
//    `user_library` blob. Conflict resolution is recipe-level last-write-wins by
//    `dateModified` (overlay rides the same clock as its recipe).
//  • Local recipe ids are re-minted to real UUIDs on first migration (seed ids
//    like `rec-…` collide across installs; the cloud `recipes.id` is `uuid`).
//  • First device (cloud empty) migrates everything; a later device (cloud
//    non-empty) pulls first, drops its pristine seeds, and offers any local-only
//    *user* recipes via the MigrationSheet — never a blind upload (spec §8).

final _uuidRe = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
bool _isUuid(String s) => _uuidRe.hasMatch(s);

final _syncRng = Random();
String _uuidV4() {
  final b = List<int>.generate(16, (_) => _syncRng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 1
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

// Remap `{{link:old-id}}` description tokens through an id map.
String _remapDescription(String desc, Map<String, String> map) =>
    desc.replaceAllMapped(RegExp(r'\{\{link:([^}]+)\}\}'), (m) {
      final old = m.group(1)!;
      return '{{link:${map[old] ?? old}}}';
    });

extension CloudSync on AppState {
  // ── public surface ──
  bool get _canSync => signedIn && account?.username != null;
  bool get _migrated => account != null && (_prefs?.getBool('fb_synced_${account!.id}') ?? false);
  int get pendingMigrationCount => _pendingLocalOnly.length;

  /// Entry point: run once after sign-in and on app open. Migrates on first run,
  /// reconciles thereafter. Safe to call repeatedly (guards against re-entry).
  Future<void> runCloudSync() async {
    if (!_canSync || _syncBusy) return;
    _syncBusy = true;
    _setSyncStatus(SyncStatus.syncing);
    try {
      await _handleAccountSwitch(); // reset local store if it belongs to another account
      _loadSyncState();
      if (!_migrated) {
        await _initialMigration();
      } else {
        await _reconcile();
      }
      _prefs?.setString('fb_local_owner', account!.id);
      await refreshFriends();
      _setSyncStatus(SyncStatus.synced);
    } catch (e) {
      debugPrint('[sync] runCloudSync failed: $e');
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    } finally {
      _syncBusy = false;
    }
  }

  /// Resolve the later-device MigrationSheet: add the local-only recipes to the
  /// account (re-mint + push) or keep them local-only (do-not-sync).
  Future<void> resolveMigration(bool addToAccount) async {
    final pending = _pendingLocalOnly;
    _pendingLocalOnly = [];
    migrationPending = false;
    if (addToAccount && pending.isNotEmpty) {
      final map = <String, String>{};
      for (final r in pending) {
        map[r.id] = _isUuid(r.id) ? r.id : _uuidV4();
      }
      for (final r in pending) {
        r.links = r.links.map((l) => map[l] ?? l).toList();
        r.description = _remapDescription(r.description, map);
        final old = r.id;
        r.id = map[old]!;
        final p = recipePhotos.remove(old);
        if (p != null) recipePhotos[r.id] = p;
        final g = recipeGallery.remove(old);
        if (g != null) recipeGallery[r.id] = g;
        _localOnlyIds.remove(old);
      }
      for (final grp in variantGroups) {
        grp.memberIds = grp.memberIds.map((m) => map[m] ?? m).toList();
        grp.baseId = map[grp.baseId] ?? grp.baseId;
      }
      try {
        for (final r in pending) {
          await _pushRecipeFull(r);
          _syncedIds.add(r.id);
        }
        await sync.upsertLibrary(_libraryData(), DateTime.now());
        _setSyncStatus(SyncStatus.synced);
      } catch (_) {
        _setSyncStatus(SyncStatus.error);
      }
    }
    // on "skip", pending recipes stay local and their ids remain in _localOnlyIds
    _persistSyncState();
    _persistDb();
    _persistPhotos();
    _persistGallery();
    notify();
  }

  // ── friends (Phase 3) ──
  List<FriendEdge> get acceptedFriends => friends.where((f) => f.accepted).toList();
  List<FriendEdge> get incomingRequests => friends.where((f) => f.incoming).toList();
  List<FriendEdge> get outgoingRequests => friends.where((f) => f.status == 'pending' && f.outgoing).toList();
  int get incomingRequestCount => friends.where((f) => f.incoming).length;

  Future<void> refreshFriends() async {
    if (!_canSync) return;
    try {
      friends = await sync.fetchFriends();
      notify();
    } catch (_) {/* keep last-known list */}
  }

  /// Look up [handle] and send a friend request. Returns the outcome (+ the
  /// resolved username on success).
  Future<({AddFriendResult result, String? username})> addFriend(String handle) async {
    if (!_canSync) return (result: AddFriendResult.error, username: null);
    try {
      final prof = await sync.lookupProfile(handle);
      if (prof == null) return (result: AddFriendResult.notFound, username: null);
      if (prof.id == account!.id) return (result: AddFriendResult.self, username: null);
      await sync.sendFriendRequest(prof.id);
      await refreshFriends();
      return (result: AddFriendResult.sent, username: prof.username);
    } on FriendshipExistsException {
      return (result: AddFriendResult.already, username: null);
    } catch (_) {
      return (result: AddFriendResult.error, username: null);
    }
  }

  Future<void> acceptFriendRequest(String otherId) async {
    await _friendOp(() => sync.acceptFriend(otherId));
  }

  Future<void> removeFriendship(String otherId) async {
    await _friendOp(() => sync.removeFriend(otherId));
  }

  Future<void> blockUser(String otherId) async {
    await _friendOp(() => sync.blockUser(otherId));
  }

  Future<void> _friendOp(Future<void> Function() op) async {
    try {
      await op();
      await refreshFriends();
    } catch (_) {
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  // ── browse a friend's cookbook (Phase 4) ──

  /// Fetch a friend's shared recipes into [visitingRecipes] (transient) and
  /// kick off image downloads. Throws on network error so the UI can show the
  /// online-required state.
  Future<List<Recipe>> loadFriendCookbook(String friendId) async {
    final cloud = await sync.fetchFriendRecipes(friendId);
    final imgs = <String, Map<String, dynamic>>{};
    final out = <Recipe>[];
    for (final c in cloud) {
      final r = _recipeFromCloud(c)..visibility = c.visibility;
      visitingRecipes[r.id] = r;
      out.add(r);
      final ih = c.content['imageHashes'];
      if (ih is Map) imgs[c.id] = Map<String, dynamic>.from(ih);
    }
    notify();
    unawaited(_downloadImages(imgs, persist: false)); // visiting images aren't persisted
    return out;
  }

  // ── reviews (Phase 5) ──
  List<Review> reviewsFor(String recipeId) => _reviewsCache[recipeId] ?? const [];

  Review? myReview(String recipeId) {
    final me = account?.id;
    if (me == null) return null;
    for (final r in reviewsFor(recipeId)) {
      if (r.authorId == me) return r;
    }
    return null;
  }

  Future<void> loadReviews(String recipeId) async {
    if (!_canSync) return;
    try {
      _reviewsCache[recipeId] = await sync.fetchReviews(recipeId);
      notify();
    } catch (_) {/* keep last-known */}
  }

  Future<void> submitReview(String recipeId, int stars, String text) async {
    if (!_canSync || stars < 1) return;
    await sync.upsertReview(recipeId, stars, text.trim(), account!.username!);
    await loadReviews(recipeId);
  }

  Future<void> deleteReview(String recipeId, String commentId) async {
    if (!_canSync) return;
    await sync.deleteReview(commentId);
    await loadReviews(recipeId);
  }

  /// Drop transient visiting recipes + their in-memory image paths.
  void clearVisiting() {
    for (final id in visitingRecipes.keys) {
      recipePhotos.remove(id);
      recipeGallery.remove(id);
    }
    visitingRecipes.clear();
  }

  // ── fire-and-forget push hooks (called from mutators) ──
  void cloudPushRecipe(Recipe r) {
    if (!_canSync || !_migrated || _localOnlyIds.contains(r.id)) return;
    if (!_isUuid(r.id)) return; // legacy non-uuid id — the reconcile sweep re-mints + pushes it
    unawaited(_safe(() async {
      await _pushRecipeFull(r);
      _syncedIds.add(r.id);
      _persistSyncState();
    }));
  }

  /// Upload the recipe's photos (content-addressed), then upsert its content
  /// (with image hashes embedded) and its overlay.
  Future<void> _pushRecipeFull(Recipe r) async {
    final base = _cloudRecipeOf(r);
    final hashes = await _uploadImagesFor(r);
    final content = Map<String, dynamic>.from(base.content)..['imageHashes'] = hashes;
    await sync.upsertRecipe(CloudRecipe(
      id: base.id,
      visibility: base.visibility,
      version: base.version,
      dateModified: base.dateModified,
      content: content,
      linkIds: base.linkIds,
    ));
    await sync.upsertOverlay(_overlayOf(r));
  }

  void cloudDeleteRecipe(String id) {
    _syncedIds.remove(id);
    _localOnlyIds.remove(id);
    if (!_canSync || !_migrated) return;
    _persistSyncState();
    unawaited(_safe(() => sync.deleteRecipe(id)));
  }

  void cloudPushLibrary() {
    if (!_canSync || !_migrated) return;
    unawaited(_safe(() => sync.upsertLibrary(_libraryData(), DateTime.now())));
  }

  // ── account ownership of the local store (shared-device safety) ──
  //
  // The local cookbook belongs to one account (or anonymous) at a time. If a
  // *different* account signs in on this device, the local recipes are the
  // previous user's (already safe in their cloud) — so reset to a clean slate
  // and pull this account's cookbook fresh.
  Future<void> _handleAccountSwitch() async {
    final me = account!.id;
    String? owner = _prefs?.getString('fb_local_owner');
    if (owner == null) {
      // first run with this marker — infer from any account migrated here
      for (final k in (_prefs?.getKeys() ?? const <String>{})) {
        if (k.startsWith('fb_synced_') && (_prefs?.getBool(k) ?? false)) {
          owner = k.substring('fb_synced_'.length);
          break;
        }
      }
    }
    if (owner == null || owner == me) return; // anonymous/same owner → no switch
    await _resetLocalCookbook();
    _prefs?.remove('fb_synced_$me');
    _prefs?.remove('fb_sync_state_$me');
    _syncedIds.clear();
    _localOnlyIds.clear();
  }

  // Wipe the local cookbook back to seeds (preserving app settings), clearing
  // all per-account sync/photo/review state.
  Future<void> _resetLocalCookbook() async {
    final keepProfile = profile;
    await _loadSeed(); // recipes/tags/variantGroups ← seed
    profile = keepProfile; // keep language/units/etc.
    recipePhotos.clear();
    recipeGallery.clear();
    _reviewsCache.clear();
    friends = [];
    clearVisiting();
    _persistDb();
    _persistPhotos();
    _persistGallery();
    notify();
  }

  // ── migration ──
  Future<void> _initialMigration() async {
    final cloud = await sync.fetchOwnedRecipes();
    if (cloud.isEmpty) {
      // FIRST DEVICE: re-mint all local ids, upload everything.
      _remintAllIds();
      await _pushEverything();
      _syncedIds
        ..clear()
        ..addAll(recipes.map((r) => r.id));
      _markMigrated();
    } else {
      // LATER DEVICE: pull the account cookbook; offer local-only user recipes.
      final overlays = await sync.fetchOverlays();
      final lib = await sync.fetchLibrary();
      final localUser = recipes.where((r) => !_isSeed(r)).toList();
      recipes.removeWhere(_isSeed); // pristine seeds are replaced by cloud copies
      _applyLibraryIfAny(lib);
      final overlayById = {for (final o in overlays) o.recipeId: o};
      final imgByRecipe = <String, Map<String, dynamic>>{};
      for (final c in cloud) {
        if (getRecipe(c.id) == null) {
          final r = _recipeFromCloud(c);
          final o = overlayById[c.id];
          if (o != null) _applyOverlayTo(r, o);
          recipes.add(r);
          final ih = c.content['imageHashes'];
          if (ih is Map) imgByRecipe[c.id] = Map<String, dynamic>.from(ih);
        }
      }
      _syncedIds
        ..clear()
        ..addAll(cloud.map((c) => c.id));
      _pendingLocalOnly = localUser;
      _localOnlyIds
        ..clear()
        ..addAll(localUser.map((r) => r.id));
      migrationPending = localUser.isNotEmpty;
      _markMigrated();
      _persistDb();
      _persistPhotos();
      _persistGallery();
      unawaited(_downloadImages(imgByRecipe)); // restore photos in the background
    }
  }

  void _markMigrated() {
    _prefs?.setBool('fb_synced_${account!.id}', true);
    _persistSyncState();
  }

  bool _isSeed(Recipe r) => r.id.startsWith('rec-');

  void _remintAllIds() {
    final map = <String, String>{};
    for (final r in recipes) {
      map[r.id] = _isUuid(r.id) ? r.id : _uuidV4();
    }
    for (final r in recipes) {
      r.links = r.links.map((l) => map[l] ?? l).toList();
      r.description = _remapDescription(r.description, map);
      r.id = map[r.id]!;
    }
    recipePhotos = {for (final e in recipePhotos.entries) (map[e.key] ?? e.key): e.value};
    recipeGallery = {for (final e in recipeGallery.entries) (map[e.key] ?? e.key): e.value};
    for (final g in variantGroups) {
      g.memberIds = g.memberIds.map((m) => map[m] ?? m).toList();
      g.baseId = map[g.baseId] ?? g.baseId;
    }
    _persistDb();
    _persistPhotos();
    _persistGallery();
  }

  Future<void> _pushEverything() async {
    for (final r in recipes) {
      await _pushRecipeFull(r);
    }
    await sync.upsertLibrary(_libraryData(), DateTime.now());
  }

  // ── steady-state reconcile (pull-on-open + push local changes, LWW) ──
  Future<void> _reconcile() async {
    // Heal any local recipe that still has a legacy non-uuid id (e.g. created
    // before id-generation was fixed) so it can live in the uuid-keyed pool.
    if (recipes.any((r) => !_isUuid(r.id))) _remintAllIds();
    final cloud = await sync.fetchOwnedRecipes();
    final overlays = await sync.fetchOverlays();
    final lib = await sync.fetchLibrary();
    final cloudById = {for (final c in cloud) c.id: c};
    final overlayById = {for (final o in overlays) o.recipeId: o};

    final imgByRecipe = <String, Map<String, dynamic>>{};
    void noteImages(CloudRecipe c) {
      final ih = c.content['imageHashes'];
      if (ih is Map) imgByRecipe[c.id] = Map<String, dynamic>.from(ih);
    }

    // 1) pull: add new cloud recipes / apply cloud when it's newer (LWW)
    for (final c in cloud) {
      final local = getRecipe(c.id);
      if (local == null) {
        final r = _recipeFromCloud(c);
        final o = overlayById[c.id];
        if (o != null) _applyOverlayTo(r, o);
        recipes.insert(0, r);
        noteImages(c);
      } else {
        final lm = _parse(local.dateModified);
        if (c.dateModified.isAfter(lm)) {
          _replaceContent(local, c);
          final o = overlayById[c.id];
          if (o != null) _applyOverlayTo(local, o);
          noteImages(c);
        }
      }
    }
    if (lib != null) _applyLibraryIfAny(lib);

    // 2) handle local recipes absent from the cloud
    for (final r in List<Recipe>.from(recipes)) {
      if (cloudById.containsKey(r.id) || _localOnlyIds.contains(r.id)) continue;
      if (_syncedIds.contains(r.id)) {
        // was synced, now gone from cloud → deleted on another device
        recipes.removeWhere((x) => x.id == r.id);
        recipePhotos.remove(r.id);
        recipeGallery.remove(r.id);
      } else {
        // created locally (e.g. offline) → push
        await _pushRecipeFull(r);
      }
    }

    // 3) push local recipes that are newer than the cloud copy
    for (final c in cloud) {
      final local = getRecipe(c.id);
      if (local == null) continue;
      if (_parse(local.dateModified).isAfter(c.dateModified)) {
        await _pushRecipeFull(local);
      }
    }

    _syncedIds
      ..clear()
      ..addAll(recipes.where((r) => !_localOnlyIds.contains(r.id)).map((r) => r.id));
    await sync.upsertLibrary(_libraryData(), DateTime.now());
    _persistSyncState();
    _persistDb();
    _persistPhotos();
    _persistGallery();
    notify();
    unawaited(_downloadImages(imgByRecipe)); // fill photos in the background
  }

  // ── images (Phase 2B) ──

  /// Upload a recipe's hero + gallery photos (content-addressed dedup) and
  /// register them for ref-count GC. Returns `{hero: hash?, gallery: [hash,…]}`.
  Future<Map<String, dynamic>> _uploadImagesFor(Recipe r) async {
    String? heroHash;
    final hero = recipePhotos[r.id];
    if (hero != null && hero.isNotEmpty) heroHash = await _hashAndUpload(hero);
    final galleryHashes = <String>[];
    for (final p in (recipeGallery[r.id] ?? const <String>[])) {
      final h = await _hashAndUpload(p);
      if (h != null) galleryHashes.add(h);
    }
    final all = [?heroHash, ...galleryHashes];
    final prev = _recipeImgHashes[r.id];
    if (prev == null || !_listEq(prev, all)) {
      await sync.setRecipeImages(r.id, all);
      _recipeImgHashes[r.id] = all;
    }
    return {'hero': heroHash, 'gallery': galleryHashes};
  }

  Future<String?> _hashAndUpload(String path) async {
    final cached = _imgHashCache[path];
    if (cached != null) return cached; // already hashed (and uploaded) this session
    final bytes = await _readImageBytes(path);
    if (bytes == null) return null;
    final hash = sha256.convert(bytes).toString();
    await sync.uploadImageIfAbsent(hash, bytes, 'image/jpeg');
    _imgHashCache[path] = hash;
    return hash;
  }

  Future<Uint8List?> _readImageBytes(String path) async {
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

  /// Download + cache any cloud images referenced by pulled recipes, then map
  /// them back into recipePhotos / recipeGallery. Runs in the background.
  Future<void> _downloadImages(Map<String, Map<String, dynamic>> byRecipe, {bool persist = true}) async {
    if (byRecipe.isEmpty || kIsWeb) return;
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      return;
    }
    var changed = false;
    for (final entry in byRecipe.entries) {
      final id = entry.key;
      final ih = entry.value;
      final hero = ih['hero'] as String?;
      final heroPath = recipePhotos[id];
      if (hero != null && (heroPath == null || !File(heroPath).existsSync())) {
        final p = await _ensureCached(dir, hero);
        if (p != null) {
          recipePhotos[id] = p;
          changed = true;
        }
      }
      final galleryHashes = (ih['gallery'] as List?)?.map((e) => e as String).toList() ?? const [];
      if (galleryHashes.isNotEmpty && (recipeGallery[id] == null || recipeGallery[id]!.isEmpty)) {
        final paths = <String>[];
        for (final h in galleryHashes) {
          final p = await _ensureCached(dir, h);
          if (p != null) paths.add(p);
        }
        if (paths.isNotEmpty) {
          recipeGallery[id] = paths;
          changed = true;
        }
      }
    }
    if (changed) {
      if (persist) {
        _persistPhotos();
        _persistGallery();
      }
      notify();
    }
  }

  Future<String?> _ensureCached(Directory dir, String hash) async {
    final f = File('${dir.path}/img_$hash.jpg');
    if (await f.exists()) {
      _imgHashCache[f.path] = hash;
      return f.path;
    }
    final bytes = await sync.downloadImage(hash);
    if (bytes == null) return null;
    try {
      await f.writeAsBytes(bytes);
    } catch (_) {
      return null;
    }
    _imgHashCache[f.path] = hash;
    return f.path;
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── mapping helpers ──
  CloudRecipe _cloudRecipeOf(Recipe r) {
    final content = r.toJson()..remove('personal'); // overlay syncs separately
    return CloudRecipe(
      id: r.id,
      visibility: r.visibility,
      version: 1, // real versioning arrives with steal/"update available" (Phase 6)
      dateModified: _parse(r.dateModified),
      content: content,
      linkIds: r.links.where(_isUuid).toList(), // uuid[] column; non-uuid links live in content
    );
  }

  CloudOverlay _overlayOf(Recipe r) => CloudOverlay(
        recipeId: r.id,
        notes: r.personal.notes,
        lastCooked: r.personal.lastCooked != null ? DateTime.tryParse(r.personal.lastCooked!) : null,
        madeCount: r.personal.madeCount,
        rating: r.personal.rating,
        updatedAt: _parse(r.dateModified),
      );

  Recipe _recipeFromCloud(CloudRecipe c) => Recipe.fromJson(c.content);

  void _applyOverlayTo(Recipe r, CloudOverlay o) {
    r.personal.notes = o.notes;
    r.personal.rating = o.rating;
    r.personal.madeCount = o.madeCount;
    r.personal.lastCooked = o.lastCooked?.toIso8601String();
  }

  // Replace owner-content fields in place (keep the existing Personal overlay,
  // which is applied separately) so held references stay valid.
  void _replaceContent(Recipe local, CloudRecipe c) {
    final f = Recipe.fromJson(c.content);
    local
      ..title = f.title
      ..createdBy = f.createdBy
      ..dateAdded = f.dateAdded
      ..dateModified = f.dateModified
      ..source = f.source
      ..heroImage = f.heroImage
      ..gallery = f.gallery
      ..description = f.description
      ..servings = f.servings
      ..prepTimeMinutes = f.prepTimeMinutes
      ..cookTimeMinutes = f.cookTimeMinutes
      ..tags = f.tags
      ..variantGroupId = f.variantGroupId
      ..links = f.links
      ..ingredients = f.ingredients
      ..steps = f.steps
      ..nutrition = f.nutrition;
  }

  Map<String, dynamic> _libraryData() => {
        'tags': tags.where((t) => !t.system).map((t) => t.toJson()).toList(),
        'variantGroups': variantGroups.map((g) => g.toJson()).toList(),
        'aliases': aliases,
      };

  void _applyLibraryIfAny(({Map<String, dynamic> data, DateTime updatedAt})? lib) {
    if (lib == null) return;
    final data = lib.data;
    final byId = {for (final t in tags) t.id: t};
    for (final tj in (data['tags'] as List? ?? const [])) {
      final t = Tag.fromJson(Map<String, dynamic>.from(tj as Map));
      byId[t.id] = t;
    }
    tags = byId.values.toList();
    final gById = {for (final g in variantGroups) g.groupId: g};
    for (final gj in (data['variantGroups'] as List? ?? const [])) {
      final g = VariantGroup.fromJson(Map<String, dynamic>.from(gj as Map));
      gById[g.groupId] = g;
    }
    variantGroups = gById.values.toList();
    final a = data['aliases'];
    if (a is Map) {
      a.forEach((k, v) => aliases[k.toString()] = v.toString());
    }
  }

  // ── persistence + plumbing ──
  void _setSyncStatus(SyncStatus s) {
    syncStatus = s;
    notify();
  }

  DateTime _parse(String iso) => DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('[sync] push failed: $e');
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  void _persistSyncState() {
    if (account == null) return;
    _prefs?.setString('fb_sync_state_${account!.id}', jsonEncode({
      'synced': _syncedIds.toList(),
      'localOnly': _localOnlyIds.toList(),
    }));
  }

  void _loadSyncState() {
    if (account == null) return;
    _syncedIds.clear();
    _localOnlyIds.clear();
    final raw = _prefs?.getString('fb_sync_state_${account!.id}');
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _syncedIds.addAll((m['synced'] as List? ?? const []).map((e) => e as String));
      _localOnlyIds.addAll((m['localOnly'] as List? ?? const []).map((e) => e as String));
    } catch (_) {}
  }
}
