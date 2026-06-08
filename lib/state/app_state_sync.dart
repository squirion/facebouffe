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
    _pushFailedDuringSync = false;
    _setSyncStatus(SyncStatus.syncing);
    try {
      await _handleAccountSwitch(); // reset local store if it belongs to another account
      _loadSyncState();
      if (!_migrated) {
        await _initialMigration();
      } else {
        await _reconcile();
      }
      await _reconcileLinks();
      _prefs?.setString('fb_local_owner', account!.id);
      await refreshFriends();
      // Don't report "synced" if a push that ran during this sync failed.
      _setSyncStatus(_pushFailedDuringSync ? SyncStatus.error : SyncStatus.synced);
    } catch (e) {
      debugPrint('[sync] runCloudSync failed: $e');
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    } finally {
      _syncBusy = false;
      // Run any pushes that were deferred while the sync held the lock.
      final pending = List.of(_pendingPushes);
      _pendingPushes.clear();
      for (final op in pending) {
        unawaited(_safe(op));
      }
    }
  }

  // Run a fire-and-forget cloud push now, or defer it until the in-flight sync
  // finishes (avoids interleaving with reconcile's await-heavy loops).
  void _enqueuePush(Future<void> Function() op) {
    if (_syncBusy) {
      _pendingPushes.add(op);
    } else {
      unawaited(_safe(op));
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
    // reconstruct variant groups from the shared members present; the real base
    // travels in content['variantBaseId'] (owner's library isn't readable).
    visitingGroups.clear();
    final byGroup = <String, List<String>>{};
    final groupBase = <String, String?>{};
    for (final c in cloud) {
      final gid = c.variantGroupId ?? c.content['variantGroupId'] as String?;
      if (gid != null && _isUuid(gid)) {
        byGroup.putIfAbsent(gid, () => []).add(c.id);
        groupBase[gid] ??= c.content['variantBaseId'] as String?;
      }
    }
    byGroup.forEach((gid, members) {
      if (members.length < 2) return;
      final declared = groupBase[gid];
      final base = (declared != null && members.contains(declared)) ? declared : members.first;
      visitingGroups[gid] = VariantGroup(groupId: gid, memberIds: members, baseId: base);
    });
    notify();
    unawaited(_downloadImages(imgs, persist: false)); // visiting images aren't persisted
    return out;
  }

  // ── avatars ──
  /// Local cached path for an avatar hash, or null (kicks off a background
  /// download when missing — the widget rebuilds when it lands).
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
        final u = await sync.imageUrl(hash); // web: signed URL, no file cache
        if (u != null) {
          avatarCache[hash] = u;
          notify();
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/avatar_$hash.jpg');
      if (!await f.exists()) {
        final bytes = await sync.downloadImage(hash);
        if (bytes == null) return;
        await f.writeAsBytes(bytes);
      }
      avatarCache[hash] = f.path;
      notify();
    } catch (_) {
      // leave uncached; falls back to the letter
    } finally {
      _avatarLoading.remove(hash);
    }
  }

  /// Set the signed-in user's avatar from a picked/cropped local image.
  Future<void> applyAvatar(String localPath) async {
    if (!_canSync) return;
    try {
      final bytes = await _readImageBytes(localPath);
      if (bytes == null) return;
      final hash = sha256.convert(bytes).toString();
      await sync.uploadImageIfAbsent(hash, bytes, 'image/jpeg');
      await sync.setMyAvatar(hash);
      avatarCache[hash] = localPath; // show the picked file immediately
      account = account?.withAvatar(hash);
      notify();
    } catch (_) {
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  Future<void> removeAvatar() async {
    if (!_canSync) return;
    try {
      await sync.setMyAvatar(null);
      account = account?.withAvatar(null);
      notify();
    } catch (_) {
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  // ── steal / link / fork (Phase 6) ──
  bool alreadyStolen(String id) => recipes.any((r) => r.id == id);
  bool updateAvailable(String id) => updatableLinks.contains(id);

  String? _resolveOwnerName(String ownerId, String? hint) {
    if (ownerId == account?.id) return account?.username;
    for (final f in friends) {
      if (f.userId == ownerId) return f.username;
    }
    return hint;
  }

  /// Resolve the recursive steal bundle (main recipe + its linked dependencies),
  /// caching pulled content for the commit. Skips deps you already have and
  /// unreadable ones. Returns null when offline / unreadable.
  Future<StealBundle?> resolveStealBundle(String rootId, String? ownerNameHint) async {
    if (!_canSync) return null;
    final order = <String>[];
    final visited = <String>{};
    final visitedGroups = <String>{};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (visited.contains(id)) continue;
      visited.add(id);
      List<String> links;
      String? gid;
      if (alreadyStolen(id)) {
        final local = getRecipe(id);
        links = local?.links ?? const [];
        gid = local?.variantGroupId;
      } else {
        final c = _stealCache[id] ?? await sync.pullRecipe(id);
        if (c == null) continue; // unreadable dependency → skip
        _stealCache[id] = c;
        links = c.linkIds;
        gid = c.variantGroupId ?? c.content['variantGroupId'] as String?;
      }
      order.add(id);
      queue.addAll(links);
      // pull in readable variant siblings of this recipe
      if (gid != null && _isUuid(gid) && !visitedGroups.contains(gid)) {
        visitedGroups.add(gid);
        try {
          for (final m in await sync.fetchVariantGroup(gid)) {
            _stealCache.putIfAbsent(m.id, () => m);
            queue.add(m.id);
          }
        } catch (_) {}
      }
    }
    if (!order.contains(rootId)) return null;
    String titleOf(String id) => _stealCache[id]?.content['title'] as String? ?? getRecipe(id)?.title ?? '…';
    return StealBundle(
      mainId: rootId,
      mainTitle: titleOf(rootId),
      extras: [for (final id in order.where((x) => x != rootId)) StealItem(id: id, title: titleOf(id), already: alreadyStolen(id))],
    );
  }

  /// Commit the steal: link + cache the main recipe and all new dependencies.
  Future<void> doSteal(String rootId, String? ownerNameHint) async {
    if (!_canSync) return;
    _setSyncStatus(SyncStatus.syncing);
    try {
      final bundle = await resolveStealBundle(rootId, ownerNameHint);
      if (bundle == null) {
        _setSyncStatus(SyncStatus.error);
        return;
      }
      for (final id in [bundle.mainId, ...bundle.extras.map((e) => e.id)]) {
        if (alreadyStolen(id)) continue;
        final c = _stealCache[id];
        if (c == null || c.ownerId == null) continue;
        final r = _recipeFromCloud(c)
          ..linkedOwnerId = c.ownerId
          ..linkedOwnerName = _resolveOwnerName(c.ownerId!, ownerNameHint);
        recipes.insert(0, r);
        await sync.linkRecipe(id, c.ownerId!, c.version);
        final ih = c.content['imageHashes'];
        if (ih is Map) await _downloadImages({id: Map<String, dynamic>.from(ih)});
      }
      _rebuildStolenVariantGroups(bundle.mainId);
      _stealCache.clear();
      _persistDb();
      notify();
      _setSyncStatus(SyncStatus.synced);
    } catch (_) {
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  // After a steal, recreate the local VariantGroup(s) for any stolen recipes
  // that carry a variantGroupId, so the variant chips work (mixed linked/owned).
  void _rebuildStolenVariantGroups(String mainId) {
    final byGroup = <String, List<String>>{};
    for (final r in recipes) {
      final gid = r.variantGroupId;
      if (gid != null && _isUuid(gid)) byGroup.putIfAbsent(gid, () => []).add(r.id);
    }
    for (final entry in byGroup.entries) {
      if (entry.value.length < 2) continue; // not a real group
      final existing = getVariantGroup(entry.key);
      if (existing == null) {
        // prefer the owner's declared base (denormalized in content), else main/first
        String? declared;
        for (final id in entry.value) {
          declared ??= _stealCache[id]?.content['variantBaseId'] as String?;
        }
        final base = (declared != null && entry.value.contains(declared))
            ? declared
            : (entry.value.contains(mainId) ? mainId : entry.value.first);
        variantGroups.add(VariantGroup(groupId: entry.key, memberIds: entry.value, baseId: base));
      } else {
        for (final m in entry.value) {
          if (!existing.memberIds.contains(m)) existing.memberIds.add(m);
        }
      }
    }
  }

  /// Pull the owner's latest into a linked recipe (keeps your overlay + review).
  Future<void> pullUpdate(String recipeId) async {
    if (!_canSync) return;
    final local = getRecipe(recipeId);
    if (local == null || !local.isLinked) return;
    try {
      final c = await sync.pullRecipe(recipeId);
      if (c == null) {
        await _forkLocal(local, deleteSub: true); // owner deleted → fork from cache
        return;
      }
      _replaceContent(local, c); // owner content (incl. dateModified); keeps personal + linked meta
      updatableLinks.remove(recipeId);
      final ih = c.content['imageHashes'];
      if (ih is Map) await _downloadImages({recipeId: Map<String, dynamic>.from(ih)});
      _persistDb();
      notify();
    } catch (_) {
      _setSyncStatus(online ? SyncStatus.error : SyncStatus.offline);
    }
  }

  /// Detach (unlink) a linked recipe → fork it into an editable owned copy.
  /// Returns the new owned recipe id (the recipe's id changes on fork).
  Future<String?> detachLinked(String recipeId) async {
    final r = getRecipe(recipeId);
    if (r == null || !r.isLinked) return null;
    return _forkLocal(r, deleteSub: true);
  }

  // Convert a linked recipe (in place) into a new owned recipe from its cache,
  // remapping referrers' links/{{link}} tokens and pushing it as mine. Returns
  // the new id.
  Future<String> _forkLocal(Recipe linked, {required bool deleteSub}) async {
    final oldId = linked.id;
    final newId = _uuidV4();
    for (final r in recipes) {
      if (r.id == oldId) continue;
      if (r.links.contains(oldId)) r.links = r.links.map((l) => l == oldId ? newId : l).toList();
      r.description = _remapDescription(r.description, {oldId: newId});
    }
    linked
      ..id = newId
      ..linkedOwnerId = null
      ..linkedOwnerName = null
      ..createdBy = account?.username ?? ''
      ..visibility = 'private'
      ..dateModified = DateTime.now().toIso8601String();
    final p = recipePhotos.remove(oldId);
    if (p != null) recipePhotos[newId] = p;
    final g = recipeGallery.remove(oldId);
    if (g != null) recipeGallery[newId] = g;
    updatableLinks.remove(oldId);
    if (deleteSub) {
      try {
        await sync.unlinkRecipe(oldId);
      } catch (_) {}
    }
    _persistDb();
    _persistPhotos();
    _persistGallery();
    cloudPushRecipe(linked); // owned now → uploads content + re-registers images from cache
    notify();
    return newId;
  }

  // Reconcile link subscriptions. Decisions are based on the LOCAL linked copy +
  // readability (not on the subscription surviving), so owner-delete auto-forks
  // even if the linked_recipes row was cascade-deleted.
  Future<void> _reconcileLinks() async {
    if (!_canSync) return;
    final subs = await sync.fetchMyLinks();
    final subIds = subs.map((s) => s.recipeId).toSet();
    final localLinked = recipes.where((r) => r.isLinked).toList();
    final allIds = {...localLinked.map((r) => r.id), ...subIds}.toList();
    final readable = await sync.checkReadable(allIds);

    // 1) each local linked recipe: fork if unreadable, drop if unlinked
    //    elsewhere, flag if the owner has a newer version.
    for (final r in localLinked) {
      if (!readable.containsKey(r.id)) {
        await _forkLocal(r, deleteSub: true); // owner deleted / unfriended → fork from cache
      } else if (!subIds.contains(r.id)) {
        // readable but no subscription → unlinked on another device → drop
        recipes.removeWhere((x) => x.id == r.id);
        recipePhotos.remove(r.id);
        recipeGallery.remove(r.id);
        updatableLinks.remove(r.id);
      } else if (readable[r.id]!.isAfter(_parse(r.dateModified))) {
        updatableLinks.add(r.id);
      }
    }

    // 2) subscriptions with no local copy → materialize (linked on another device)
    for (final s in subs) {
      if (recipes.any((r) => r.id == s.recipeId)) continue;
      if (!readable.containsKey(s.recipeId)) continue;
      final c = await sync.pullRecipe(s.recipeId);
      if (c != null && c.ownerId != null) {
        final r = _recipeFromCloud(c)
          ..linkedOwnerId = c.ownerId
          ..linkedOwnerName = _resolveOwnerName(c.ownerId!, null);
        recipes.insert(0, r);
        final ih = c.content['imageHashes'];
        if (ih is Map) await _downloadImages({c.id: Map<String, dynamic>.from(ih)});
      }
    }

    // 3) refresh images for all existing linked recipes — signed URLs expire
    //    between sessions (web) and files may be missing (new device). One batch
    //    DB call; _downloadImages skips files already cached on native.
    final existingIds = recipes
        .where((r) => r.isLinked && readable.containsKey(r.id))
        .map((r) => r.id)
        .toList();
    if (existingIds.isNotEmpty) {
      final imgByRecipe = await sync.fetchImageHashes(existingIds);
      unawaited(_downloadImages(imgByRecipe));
    }

    _persistDb();
    _persistPhotos();
    _persistGallery();
    notify();
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
    visitingGroups.clear();
  }

  // ── fire-and-forget push hooks (called from mutators) ──
  void cloudPushRecipe(Recipe r) {
    if (!_canSync || !_migrated || _localOnlyIds.contains(r.id)) return;
    if (r.isLinked) {
      // a stolen recipe isn't mine to push — but my overlay (rating/notes) is
      _enqueuePush(() => sync.upsertOverlay(_overlayOf(r)));
      return;
    }
    if (!_isUuid(r.id)) return; // legacy non-uuid id — the reconcile sweep re-mints + pushes it
    _enqueuePush(() async {
      await _pushRecipeFull(r);
      _syncedIds.add(r.id);
      _persistSyncState();
    });
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
    // After the recipe row exists, register its image refs (FK to recipes.id).
    await _registerRecipeImages(r.id, hashes);
    await sync.upsertOverlay(_overlayOf(r));
  }

  void cloudDeleteRecipe(String id) {
    _syncedIds.remove(id);
    _localOnlyIds.remove(id);
    if (!_canSync || !_migrated) return;
    _persistSyncState();
    _enqueuePush(() => sync.deleteRecipe(id));
  }

  void cloudPushLibrary() {
    if (!_canSync || !_migrated) return;
    _enqueuePush(() => sync.upsertLibrary(_libraryData(), DateTime.now()));
  }

  /// Drop a link subscription (deleting a stolen recipe just unlinks it).
  void cloudUnlink(String id) {
    updatableLinks.remove(id);
    if (!_canSync || !_migrated) return;
    _enqueuePush(() => sync.unlinkRecipe(id));
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
    updatableLinks.clear();
    _stealCache.clear();
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
    _remintVariantGroupIds();
    for (final r in recipes) {
      if (r.isLinked) continue;
      await _pushRecipeFull(r);
    }
    await sync.upsertLibrary(_libraryData(), DateTime.now());
  }

  // Re-mint legacy 'vg-…' variant-group ids to real UUIDs so they can populate
  // the uuid `recipes.variant_group_id` column (needed to steal variant siblings).
  bool _remintVariantGroupIds() {
    final map = <String, String>{};
    for (final g in variantGroups) {
      if (!_isUuid(g.groupId)) map[g.groupId] = _uuidV4();
    }
    if (map.isEmpty) return false;
    for (final g in variantGroups) {
      final n = map[g.groupId];
      if (n != null) g.groupId = n;
    }
    for (final r in recipes) {
      final vg = r.variantGroupId;
      if (vg != null && map.containsKey(vg)) r.variantGroupId = map[vg];
    }
    _persistDb();
    return true;
  }

  // ── steady-state reconcile (pull-on-open + push local changes, LWW) ──
  Future<void> _reconcile() async {
    // Heal any local recipe that still has a legacy non-uuid id (e.g. created
    // before id-generation was fixed) so it can live in the uuid-keyed pool.
    if (recipes.any((r) => !_isUuid(r.id))) _remintAllIds();
    // Heal legacy variant-group ids → uuids and backfill content.variantBaseId,
    // re-pushing affected owned grouped recipes so the cloud has both (one-time).
    final vbaseKey = 'fb_vbase_${account!.id}';
    final needBackfill = !(_prefs?.getBool(vbaseKey) ?? false);
    if (_remintVariantGroupIds() || needBackfill) {
      for (final r in recipes.where((r) => !r.isLinked && r.variantGroupId != null)) {
        await _pushRecipeFull(r);
      }
      _prefs?.setBool(vbaseKey, true);
    }
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
      } else {
        final lm = _parse(local.dateModified);
        if (c.dateModified.isAfter(lm)) {
          _replaceContent(local, c);
          final o = overlayById[c.id];
          if (o != null) _applyOverlayTo(local, o);
        }
      }
      noteImages(c); // every recipe — so web re-mints signed image URLs each sync
                     // (native skips already-cached files inside _downloadImages)
    }
    if (lib != null) _applyLibraryIfAny(lib);

    // 2) handle local recipes absent from the cloud
    for (final r in List<Recipe>.from(recipes)) {
      if (r.isLinked) continue; // linked recipes are reconciled separately
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
      ..addAll(recipes.where((r) => !_localOnlyIds.contains(r.id) && !r.isLinked).map((r) => r.id));
    await sync.upsertLibrary(_libraryData(), DateTime.now());
    _persistSyncState();
    _persistDb();
    _persistPhotos();
    _persistGallery();
    notify();
    unawaited(_downloadImages(imgByRecipe)); // fill photos in the background
  }

  // ── images (Phase 2B) ──

  /// Upload a recipe's hero + gallery photo bytes (content-addressed dedup).
  /// Returns `{hero: hash?, gallery: [hash,…]}`. Does NOT touch recipe_images —
  /// that ref-count registration runs in [_registerRecipeImages] AFTER the
  /// recipe row exists (recipe_images.recipe_id FKs recipes.id, so a brand-new
  /// recipe must be upserted first).
  Future<Map<String, dynamic>> _uploadImagesFor(Recipe r) async {
    String? heroHash;
    final hero = recipePhotos[r.id];
    if (hero != null && hero.isNotEmpty) heroHash = await _hashAndUpload(hero);
    final galleryHashes = <String>[];
    for (final p in (recipeGallery[r.id] ?? const <String>[])) {
      final h = await _hashAndUpload(p);
      if (h != null) galleryHashes.add(h);
    }
    return {'hero': heroHash, 'gallery': galleryHashes};
  }

  /// Reconcile the recipe→image ref-count rows (drives image GC). Must run after
  /// the recipe row exists, since recipe_images.recipe_id FKs recipes.id.
  Future<void> _registerRecipeImages(String recipeId, Map<String, dynamic> hashes) async {
    final hero = hashes['hero'] as String?;
    final gallery = (hashes['gallery'] as List?)?.map((e) => e as String).toList() ?? const [];
    final all = [?hero, ...gallery];
    final prev = _recipeImgHashes[recipeId];
    if (prev == null || !_listEq(prev, all)) {
      await sync.setRecipeImages(recipeId, all);
      _recipeImgHashes[recipeId] = all;
    }
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
    if (byRecipe.isEmpty) return;
    if (kIsWeb) return _resolveImageUrls(byRecipe); // web: signed URLs, no file cache
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

  // Web: resolve hashes to signed Storage URLs (no file cache) and store them as
  // the photo paths, so the Image.network display path renders them.
  Future<void> _resolveImageUrls(Map<String, Map<String, dynamic>> byRecipe) async {
    var changed = false;
    for (final entry in byRecipe.entries) {
      final id = entry.key;
      final ih = entry.value;
      final hero = ih['hero'] as String?;
      final curHero = recipePhotos[id];
      // re-resolve when missing or when it's a (possibly-expired) signed URL;
      // keep data: URLs (web-added photos are stable).
      final heroStale = curHero == null || curHero.isEmpty || curHero.startsWith('http');
      if (hero != null && heroStale) {
        final u = await sync.imageUrl(hero);
        if (u != null) {
          recipePhotos[id] = u;
          changed = true;
        }
      }
      final galleryHashes = (ih['gallery'] as List?)?.map((e) => e as String).toList() ?? const [];
      final curGallery = recipeGallery[id];
      final galleryStale = curGallery == null || curGallery.isEmpty || curGallery.any((p) => p.startsWith('http'));
      if (galleryHashes.isNotEmpty && galleryStale) {
        final urls = <String>[];
        for (final h in galleryHashes) {
          final u = await sync.imageUrl(h);
          if (u != null) urls.add(u);
        }
        if (urls.isNotEmpty) {
          recipeGallery[id] = urls;
          changed = true;
        }
      }
    }
    if (changed) notify(); // in-memory only — signed URLs expire, don't persist
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
    // denormalize the group's base so a viewer (who can't read my library) knows it
    if (r.variantGroupId != null) {
      final g = getVariantGroup(r.variantGroupId);
      if (g != null) content['variantBaseId'] = g.baseId;
    }
    // refresh embedded sub-recipe snapshots from the live sub-recipes so a friend
    // who can't read them still sees current nutrition/weight (operate on the
    // json copy so the in-memory recipe isn't mutated by a push)
    final ings = content['ingredients'];
    if (ings is List) {
      for (final e in ings) {
        if (e is Map && e['recipeRef'] is Map) {
          final subId = (e['recipeRef'] as Map)['recipeId'] as String?;
          final b = subId == null ? null : getRecipe(subId);
          if (b != null) e['recipeRef'] = buildRecipeRefSnapshot(b).toJson();
        }
      }
    }
    return CloudRecipe(
      id: r.id,
      visibility: r.visibility,
      // Sync is timestamp-LWW by date_modified (see _reconcile/_reconcileLinks);
      // version is a monotonic stamp derived from the modification time so the
      // recipes.version / linked_recipes.linked_version columns are truthful
      // (re-pushing unchanged content keeps the same value — no spurious bumps).
      version: _parse(r.dateModified).millisecondsSinceEpoch ~/ 60000,
      dateModified: _parse(r.dateModified),
      content: content,
      linkIds: r.links.where(_isUuid).toList(), // uuid[] column; non-uuid links live in content
      variantGroupId: (r.variantGroupId != null && _isUuid(r.variantGroupId!)) ? r.variantGroupId : null,
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

  // Replace owner-content in place (keeps id, visibility, the personal overlay,
  // and linked metadata — all applied separately) so held references stay valid.
  // Field list lives on Recipe._assignContent, so new content fields propagate
  // here automatically.
  void _replaceContent(Recipe local, CloudRecipe c) => local.applyContentFrom(c.content);

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
      if (_syncBusy) _pushFailedDuringSync = true; // so the sync doesn't end on "synced"
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
