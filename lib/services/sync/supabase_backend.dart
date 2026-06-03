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
    await _c.from('profiles').insert({'id': uid, 'username': handle.trim().toLowerCase()});
  }

  @override
  Future<void> signOut() => _c.auth.signOut();
}
