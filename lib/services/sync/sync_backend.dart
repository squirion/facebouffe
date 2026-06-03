/// The one seam between the app and the cloud (Supabase today). Keeping every
/// backend call behind this interface keeps the host swappable (spec §6). Only
/// the Phase-1 auth/account surface is defined here; later phases (sync, friends,
/// sharing, steal) add methods as they're built.
library;

/// A signed-in account (auth identity). `username` is null until the profile is
/// created on first sign-in.
class Account {
  final String id; // auth user id (uuid)
  final String email;
  final String? username;
  const Account({required this.id, required this.email, this.username});

  Account withUsername(String? u) => Account(id: id, email: email, username: u);
}

abstract class SyncBackend {
  /// Current account, or null when signed out / offline-only.
  Account? get currentAccount;

  /// Fires whenever sign-in state changes (login, logout, token refresh).
  Stream<Account?> get accountChanges;

  /// Email a one-time sign-in **code** (OTP). Creates the user if new.
  Future<void> sendEmailCode(String email);

  /// Verify the emailed code → establishes a session.
  Future<void> verifyEmailCode(String email, String code);

  /// This account's username, or null if no profile row exists yet.
  Future<String?> fetchMyUsername();

  /// True if [handle] is free to claim (exact-match, case-insensitive).
  Future<bool> isUsernameAvailable(String handle);

  /// Create this account's profile with [handle]. Throws if already taken.
  Future<void> claimUsername(String handle);

  /// End the session (local data is untouched).
  Future<void> signOut();
}
