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
}
