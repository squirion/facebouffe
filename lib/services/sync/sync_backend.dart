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

/// Thrown by [SyncBackend.claimUsername] when the handle is already taken
/// (unique violation), so callers can tell it apart from a network/RLS error.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

/// One owned recipe in the cloud (`recipes` row). [content] is the recipe's
/// full json minus the private `personal` overlay (which syncs separately).
class CloudRecipe {
  final String id;
  final String visibility; // 'private' | 'friends'
  final int version;
  final DateTime dateModified;
  final Map<String, dynamic> content;
  final List<String> linkIds;
  const CloudRecipe({
    required this.id,
    required this.visibility,
    required this.version,
    required this.dateModified,
    required this.content,
    required this.linkIds,
  });
}

/// One user's private overlay for a recipe (`recipe_overlays` row).
class CloudOverlay {
  final String recipeId;
  final String notes;
  final DateTime? lastCooked;
  final int madeCount;
  final int rating;
  final DateTime updatedAt;
  const CloudOverlay({
    required this.recipeId,
    required this.notes,
    required this.lastCooked,
    required this.madeCount,
    required this.rating,
    required this.updatedAt,
  });
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

  // ── Phase 2A: personal cloud sync ──

  /// All recipes owned by the signed-in user.
  Future<List<CloudRecipe>> fetchOwnedRecipes();

  /// Create or replace one owned recipe (upsert by id; RLS enforces ownership).
  Future<void> upsertRecipe(CloudRecipe recipe);

  /// Delete one owned recipe by id.
  Future<void> deleteRecipe(String id);

  /// This user's private overlays (notes/rating/madeCount/lastCooked).
  Future<List<CloudOverlay>> fetchOverlays();

  /// Create or replace one overlay (upsert by user+recipe).
  Future<void> upsertOverlay(CloudOverlay overlay);

  /// This user's library blob (tag defs, variant groups, aliases) + its
  /// updated_at, or null if none exists yet.
  Future<({Map<String, dynamic> data, DateTime updatedAt})?> fetchLibrary();

  /// Create or replace this user's library blob.
  Future<void> upsertLibrary(Map<String, dynamic> data, DateTime updatedAt);
}
