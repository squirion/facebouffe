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
  Future<String?> fetchMyUsername() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _c.from('profiles').select('username').eq('id', uid).maybeSingle();
    return row?['username'] as String?;
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
    final rows = await _c.from('recipes').select('id,visibility,version,date_modified,content,link_ids').eq('owner_id', uid);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return CloudRecipe(
        id: m['id'] as String,
        visibility: m['visibility'] as String? ?? 'private',
        version: (m['version'] as num?)?.toInt() ?? 1,
        dateModified: DateTime.tryParse(m['date_modified'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        content: Map<String, dynamic>.from(m['content'] as Map),
        linkIds: (m['link_ids'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
    }).toList();
  }

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
    final profs = await _c.from('profiles').select('id,username').inFilter('id', edges.map((e) => e.userId).toList());
    final nameById = {for (final p in (profs as List)) (p as Map)['id'] as String: p['username'] as String?};
    return [
      for (final e in edges) FriendEdge(userId: e.userId, username: nameById[e.userId], status: e.status, outgoing: e.outgoing),
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
        .select('id,visibility,version,date_modified,content,link_ids')
        .eq('owner_id', friendId)
        .eq('visibility', 'friends');
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return CloudRecipe(
        id: m['id'] as String,
        visibility: m['visibility'] as String? ?? 'friends',
        version: (m['version'] as num?)?.toInt() ?? 1,
        dateModified: DateTime.tryParse(m['date_modified'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        content: Map<String, dynamic>.from(m['content'] as Map),
        linkIds: (m['link_ids'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
    }).toList();
  }
}
