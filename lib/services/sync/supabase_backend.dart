import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'sync_backend.dart';

/// Supabase implementation of [SyncBackend]. Initialize [boot] once at startup
/// before using the app's account features.
class SupabaseSyncBackend implements SyncBackend {
  SupabaseClient get _c => Supabase.instance.client;

  static Future<void> boot() async {
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.publishableKey);
  }

  Account? _accountFrom(User? u) => u == null ? null : Account(id: u.id, email: u.email ?? '');

  @override
  Account? get currentAccount => _accountFrom(_c.auth.currentUser);

  @override
  Stream<Account?> get accountChanges => _c.auth.onAuthStateChange.map((s) => _accountFrom(s.session?.user));

  @override
  Future<void> sendEmailCode(String email) =>
      _c.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verifyEmailCode(String email, String code) =>
      _c.auth.verifyOTP(email: email, token: code.trim(), type: OtpType.email);

  @override
  Future<({String? username, String? avatarHash})> fetchMyProfile() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return (username: null, avatarHash: null);
    final row = await _c.from('profiles').select('username,avatar_hash').eq('id', uid).maybeSingle();
    return (username: row?['username'] as String?, avatarHash: row?['avatar_hash'] as String?);
  }

  @override
  Future<void> setMyAvatar(String? hash) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('profiles').update({'avatar_hash': hash}).eq('id', uid);
  }

  @override
  Future<bool> isUsernameAvailable(String handle) async {
    final res = await _c.rpc('lookup_username', params: {'handle': handle.trim().toLowerCase()});
    // lookup_username returns the matching row(s) (empty list = free).
    if (res is List) return res.isEmpty;
    return res == null;
  }

  @override
  Future<void> claimUsername(String handle) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    try {
      await _c.from('profiles').insert({'id': uid, 'username': handle.trim().toLowerCase()});
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (handle already taken). Anything else (e.g. a
      // missing RLS policy → 42501) is a real error and should surface as such.
      if (e.code == '23505') throw const UsernameTakenException();
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _c.auth.signOut();

  // ── Phase 2A: personal cloud sync ──

  @override
  Future<List<CloudRecipe>> fetchOwnedRecipes() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _c.from('recipes').select('id,visibility,version,date_modified,content,link_ids,variant_group_id').eq('owner_id', uid);
    return (rows as List).map((r) => _cloudRecipe(r as Map<String, dynamic>)).toList();
  }

  // Map a recipes row → CloudRecipe.
  CloudRecipe _cloudRecipe(Map<String, dynamic> m, {String? ownerId}) => CloudRecipe(
        id: m['id'] as String,
        ownerId: ownerId ?? m['owner_id'] as String?,
        visibility: m['visibility'] as String? ?? 'private',
        version: (m['version'] as num?)?.toInt() ?? 1,
        dateModified: DateTime.tryParse(m['date_modified'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        content: Map<String, dynamic>.from(m['content'] as Map),
        linkIds: (m['link_ids'] as List?)?.map((e) => e as String).toList() ?? const [],
        variantGroupId: m['variant_group_id'] as String?,
      );

  @override
  Future<void> upsertRecipe(CloudRecipe r) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('recipes').upsert({
      'id': r.id,
      'owner_id': uid,
      'visibility': r.visibility,
      'version': r.version,
      'date_modified': r.dateModified.toUtc().toIso8601String(),
      'content': r.content,
      'link_ids': r.linkIds,
      'variant_group_id': r.variantGroupId,
    });
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await _c.from('recipes').delete().eq('id', id);
  }

  @override
  Future<List<CloudOverlay>> fetchOverlays() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _c.from('recipe_overlays').select('recipe_id,notes,last_cooked,made_count,rating,updated_at').eq('user_id', uid);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return CloudOverlay(
        recipeId: m['recipe_id'] as String,
        notes: m['notes'] as String? ?? '',
        lastCooked: m['last_cooked'] != null ? DateTime.tryParse(m['last_cooked'] as String) : null,
        madeCount: (m['made_count'] as num?)?.toInt() ?? 0,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();
  }

  @override
  Future<void> upsertOverlay(CloudOverlay o) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('recipe_overlays').upsert({
      'user_id': uid,
      'recipe_id': o.recipeId,
      'notes': o.notes,
      'last_cooked': o.lastCooked?.toUtc().toIso8601String(),
      'made_count': o.madeCount,
      'rating': o.rating,
      'updated_at': o.updatedAt.toUtc().toIso8601String(),
    }, onConflict: 'user_id,recipe_id');
  }

  @override
  Future<({Map<String, dynamic> data, DateTime updatedAt})?> fetchLibrary() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _c.from('user_library').select('data,updated_at').eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    return (
      data: Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<void> upsertLibrary(Map<String, dynamic> data, DateTime updatedAt) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('user_library').upsert({
      'user_id': uid,
      'data': data,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
  }

  // ── Phase 2B: content-addressed images ──
  static const _bucket = 'recipe-images';

  @override
  Future<void> uploadImageIfAbsent(String hash, Uint8List bytes, String contentType) async {
    // content-addressed dedup: if the registry already has this hash, the bytes
    // are already in storage — nothing to do.
    final existing = await _c.from('images').select('hash').eq('hash', hash).maybeSingle();
    if (existing != null) return;
    await _c.storage.from(_bucket).uploadBinary(
          hash,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _c.from('images').upsert({
      'hash': hash,
      'r2_key': hash, // storage object key (R2 migration keeps this contract)
      'content_type': contentType,
      'size_bytes': bytes.length,
    });
  }

  @override
  Future<Uint8List?> downloadImage(String hash) async {
    try {
      return await _c.storage.from(_bucket).download(hash);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> imageUrl(String hash) async {
    try {
      return await _c.storage.from(_bucket).createSignedUrl(hash, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setRecipeImages(String recipeId, List<String> hashes) async {
    await _c.from('recipe_images').delete().eq('recipe_id', recipeId);
    final unique = hashes.toSet().toList();
    if (unique.isEmpty) return;
    await _c.from('recipe_images').insert([
      for (final h in unique) {'recipe_id': recipeId, 'image_hash': h},
    ]);
  }

  // ── Phase 3: friends ──

  // Friendships store one row per pair in canonical order (user_a < user_b).
  (String, String) _pair(String me, String other) => me.compareTo(other) < 0 ? (me, other) : (other, me);

  @override
  Future<({String id, String username})?> lookupProfile(String handle) async {
    final res = await _c.rpc('lookup_username', params: {'handle': handle.trim().toLowerCase()});
    if (res is List && res.isNotEmpty) {
      final m = res.first as Map<String, dynamic>;
      return (id: m['id'] as String, username: m['username'] as String);
    }
    return null;
  }

  @override
  Future<void> sendFriendRequest(String otherId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    final (a, b) = _pair(me, otherId);
    try {
      await _c.from('friendships').insert({'user_a': a, 'user_b': b, 'requested_by': me, 'status': 'pending'});
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const FriendshipExistsException();
      rethrow;
    }
  }

  @override
  Future<List<FriendEdge>> fetchFriends() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return [];
    final rows = await _c.from('friendships').select('user_a,user_b,requested_by,status').or('user_a.eq.$me,user_b.eq.$me');
    final edges = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final other = m['user_a'] == me ? m['user_b'] as String : m['user_a'] as String;
      return FriendEdge(userId: other, username: null, status: m['status'] as String? ?? 'pending', outgoing: m['requested_by'] == me);
    }).toList();
    if (edges.isEmpty) return edges;
    final profs = await _c.from('profiles').select('id,username,avatar_hash').inFilter('id', edges.map((e) => e.userId).toList());
    final byId = {for (final p in (profs as List)) (p as Map)['id'] as String: p};
    return [
      for (final e in edges)
        FriendEdge(
          userId: e.userId,
          username: byId[e.userId]?['username'] as String?,
          avatarHash: byId[e.userId]?['avatar_hash'] as String?,
          status: e.status,
          outgoing: e.outgoing,
        ),
    ];
  }

  @override
  Future<void> acceptFriend(String otherId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    final (a, b) = _pair(me, otherId);
    await _c.from('friendships').update({'status': 'accepted'}).eq('user_a', a).eq('user_b', b);
  }

  @override
  Future<void> removeFriend(String otherId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    final (a, b) = _pair(me, otherId);
    await _c.from('friendships').delete().eq('user_a', a).eq('user_b', b);
  }

  @override
  Future<void> blockUser(String otherId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    try {
      await _c.from('blocks').insert({'blocker_id': me, 'blocked_id': otherId});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already blocked → fine
    }
    final (a, b) = _pair(me, otherId);
    await _c.from('friendships').delete().eq('user_a', a).eq('user_b', b);
  }

  // ── Phase 4: browse a friend's shared cookbook ──

  @override
  Future<List<CloudRecipe>> fetchFriendRecipes(String friendId) async {
    final rows = await _c
        .from('recipes')
        .select('id,owner_id,visibility,version,date_modified,content,link_ids,variant_group_id')
        .eq('owner_id', friendId)
        .eq('visibility', 'friends');
    return (rows as List).map((r) => _cloudRecipe(r as Map<String, dynamic>, ownerId: friendId)).toList();
  }

  // ── Phase 6: steal / link / fork ──

  @override
  Future<CloudRecipe?> pullRecipe(String id) async {
    final m = await _c.from('recipes').select('id,owner_id,visibility,version,date_modified,content,link_ids,variant_group_id').eq('id', id).maybeSingle();
    if (m == null) return null;
    return _cloudRecipe(m);
  }

  @override
  Future<List<CloudRecipe>> fetchVariantGroup(String groupId) async {
    final rows = await _c.from('recipes').select('id,owner_id,visibility,version,date_modified,content,link_ids,variant_group_id').eq('variant_group_id', groupId);
    return (rows as List).map((r) => _cloudRecipe(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> linkRecipe(String recipeId, String ownerId, int version) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');
    await _c.from('linked_recipes').upsert({
      'user_id': me,
      'recipe_id': recipeId,
      'source_owner_id': ownerId,
      'linked_version': version,
    }, onConflict: 'user_id,recipe_id');
  }

  @override
  Future<void> unlinkRecipe(String recipeId) async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return;
    await _c.from('linked_recipes').delete().eq('user_id', me).eq('recipe_id', recipeId);
  }

  @override
  Future<List<({String recipeId, String ownerId, int linkedVersion})>> fetchMyLinks() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return [];
    final rows = await _c.from('linked_recipes').select('recipe_id,source_owner_id,linked_version').eq('user_id', me);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return (recipeId: m['recipe_id'] as String, ownerId: m['source_owner_id'] as String, linkedVersion: (m['linked_version'] as num?)?.toInt() ?? 0);
    }).toList();
  }

  @override
  Future<Map<String, DateTime>> checkReadable(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _c.from('recipes').select('id,date_modified').inFilter('id', ids);
    return {
      for (final r in (rows as List))
        (r as Map)['id'] as String: DateTime.tryParse(r['date_modified'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchImageHashes(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _c.from('recipes').select('id,content').inFilter('id', ids);
    final out = <String, Map<String, dynamic>>{};
    for (final r in (rows as List)) {
      final id = (r as Map)['id'] as String;
      final content = r['content'];
      final ih = content is Map ? content['imageHashes'] : null;
      if (ih is Map) out[id] = Map<String, dynamic>.from(ih);
    }
    return out;
  }

  // ── Phase 5: reviews ──

  @override
  Future<List<Review>> fetchReviews(String recipeId) async {
    final rows = await _c.from('comments').select('id,author_id,author_username,stars,text,updated_at').eq('recipe_id', recipeId).order('updated_at');
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return Review(
        id: m['id'] as String,
        authorId: m['author_id'] as String,
        authorUsername: m['author_username'] as String?,
        stars: (m['stars'] as num?)?.toInt() ?? 0,
        text: m['text'] as String? ?? '',
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();
  }

  @override
  Future<void> upsertReview(String recipeId, int stars, String text, String authorUsername) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('comments').upsert({
      'recipe_id': recipeId,
      'author_id': uid,
      'author_username': authorUsername,
      'stars': stars,
      'text': text,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'recipe_id,author_id');
  }

  @override
  Future<void> deleteReview(String commentId) async {
    await _c.from('comments').delete().eq('id', commentId);
  }

  // ── Phase 7: share a grocery list ──

  @override
  Future<void> sendSharedList(String toUserId, String fromUsername, List<Map<String, dynamic>> items) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    await _c.from('shared_lists').insert({
      'from_user': uid,
      'from_username': fromUsername,
      'to_user': toUserId,
      'items': items,
    });
  }

  @override
  Future<List<SharedList>> fetchSharedLists() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _c.from('shared_lists').select('id,from_user,from_username,items,created_at').eq('to_user', uid).order('created_at');
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final created = DateTime.tryParse(m['created_at'] as String? ?? '');
      return SharedList(
        id: m['id'] as String,
        fromUser: m['from_user'] as String,
        fromUsername: m['from_username'] as String? ?? '',
        createdAt: created?.millisecondsSinceEpoch ?? 0,
        items: ((m['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }).toList();
  }

  @override
  Future<void> deleteSharedList(String id) async {
    await _c.from('shared_lists').delete().eq('id', id);
  }

  @override
  Stream<void> sharedListInserts() {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const Stream<void>.empty();
    final controller = StreamController<void>();
    final channel = _c.channel('shared_lists:$uid');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shared_lists',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_user', value: uid),
          callback: (_) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    controller.onCancel = () async {
      await _c.removeChannel(channel);
    };
    return controller.stream;
  }

  // ── Crash reports ──

  static final _crashUuidRe = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  static final _crashRng = Random();

  // Mirrors _uuidV4 in app_state_sync.dart (private there; a shared util would
  // be nice-to-have cleanup, not worth coupling state↔services for).
  static String _uuidV4() {
    final b = List<int>.generate(16, (_) => _crashRng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 1
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  @override
  Future<String> sendCrashReport({
    required String kind,
    required String notes,
    required String log,
    required String appVersion,
    required int build,
    required String platform,
    required String osVersion,
    required String deviceModel,
    String? username,
  }) async {
    // No signed-in guard, by design: crash reports are the one anonymous write.
    // Id is client-minted because the table's RLS is insert-only — a .select()
    // readback would 42501.
    final id = _uuidV4();
    await _c.from('crash_reports').insert({
      'id': id,
      'user_id': _c.auth.currentUser?.id, // null when anonymous (policy allows)
      'username': username,
      'app_version': appVersion,
      'build': build,
      'platform': platform,
      'os_version': osVersion,
      'device_model': deviceModel,
      'kind': kind,
      'notes': notes,
      'log': log,
    });
    return id;
  }

  @override
  Future<List<CrashReportStatus>> crashReportStatuses(List<String> ids) async {
    // One malformed id would 22P02 the whole RPC call — filter defensively.
    final clean = ids.where(_crashUuidRe.hasMatch).toList();
    if (clean.isEmpty) return const [];
    final res = await _c.rpc('crash_report_statuses', params: {'ids': clean});
    if (res is! List) return const [];
    return [
      for (final r in res.whereType<Map>())
        CrashReportStatus(
          id: r['id'] as String,
          status: r['status'] as String? ?? 'new',
          devNote: r['dev_note'] as String?,
          updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
  }
}
