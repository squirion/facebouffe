/// The one seam between the app and the cloud (Supabase today). Keeping every
/// backend call behind this interface keeps the host swappable (spec §6). Only
/// the Phase-1 auth/account surface is defined here; later phases (sync, friends,
/// sharing, steal) add methods as they're built.
library;

import 'dart:typed_data';

/// A signed-in account (auth identity). `username` is null until the profile is
/// created on first sign-in.
class Account {
  final String id; // auth user id (uuid)
  final String email;
  final String? username;
  final String? avatarHash; // sha-256 of the avatar image, or null
  const Account({required this.id, required this.email, this.username, this.avatarHash});

  Account withUsername(String? u) => Account(id: id, email: email, username: u, avatarHash: avatarHash);
  Account withAvatar(String? h) => Account(id: id, email: email, username: username, avatarHash: h);
}

/// Thrown by [SyncBackend.claimUsername] when the handle is already taken
/// (unique violation), so callers can tell it apart from a network/RLS error.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

/// Thrown by [SyncBackend.sendFriendRequest] when a friendship row already
/// exists for the pair (pending or accepted).
class FriendshipExistsException implements Exception {
  const FriendshipExistsException();
}

/// One review (a `comments` row): stars + text by one author on one recipe.
class Review {
  final String id;
  final String authorId;
  final String? authorUsername; // denormalized so non-friends' names still show
  final int stars;
  final String text;
  final DateTime updatedAt;
  const Review({required this.id, required this.authorId, required this.authorUsername, required this.stars, required this.text, required this.updatedAt});
}

/// One friendship edge from the signed-in user's perspective.
class FriendEdge {
  final String userId; // the other person
  final String? username; // resolved from profiles (null if unreadable)
  final String status; // 'pending' | 'accepted'
  final bool outgoing; // pending request that I sent
  final String? avatarHash;
  const FriendEdge({required this.userId, required this.username, required this.status, required this.outgoing, this.avatarHash});

  bool get accepted => status == 'accepted';
  bool get incoming => status == 'pending' && !outgoing;
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
  final String? ownerId; // set when reading someone else's recipe (steal/browse)
  final String? variantGroupId; // denormalized group id (uuid) for sibling traversal
  const CloudRecipe({
    required this.id,
    required this.visibility,
    required this.version,
    required this.dateModified,
    required this.content,
    required this.linkIds,
    this.ownerId,
    this.variantGroupId,
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

  /// This account's profile (username + avatar hash). username is null if no
  /// profile row exists yet.
  Future<({String? username, String? avatarHash})> fetchMyProfile();

  /// Set (or clear, with null) this account's avatar image hash.
  Future<void> setMyAvatar(String? hash);

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

  // ── Phase 2B: content-addressed images ──

  /// Upload [bytes] under [hash] (sha-256) to image storage and register it in
  /// the `images` table. No-op if the hash already exists (content-addressed
  /// dedup across all recipes/users).
  Future<void> uploadImageIfAbsent(String hash, Uint8List bytes, String contentType);

  /// Download the bytes for a content hash, or null if missing.
  Future<Uint8List?> downloadImage(String hash);

  /// Replace the set of image hashes linked to a recipe (drives ref-count GC).
  Future<void> setRecipeImages(String recipeId, List<String> hashes);

  // ── Phase 3: friends ──

  /// Exact-match username lookup (no partial search). Returns id+username, or
  /// null if no such user.
  Future<({String id, String username})?> lookupProfile(String handle);

  /// Send a pending friend request to [otherId]. Throws [FriendshipExistsException]
  /// if a friendship row already exists for the pair.
  Future<void> sendFriendRequest(String otherId);

  /// All friendship edges involving the signed-in user, with usernames resolved.
  Future<List<FriendEdge>> fetchFriends();

  /// Accept an incoming pending request from [otherId].
  Future<void> acceptFriend(String otherId);

  /// Remove a friendship/request with [otherId] (decline / cancel / unfriend).
  Future<void> removeFriend(String otherId);

  /// Block [otherId] (also removes any existing friendship).
  Future<void> blockUser(String otherId);

  // ── Phase 4: browse a friend's shared cookbook ──

  /// A friend's recipes that are shared with friends (RLS enforces access).
  Future<List<CloudRecipe>> fetchFriendRecipes(String friendId);

  // ── Phase 6: steal / link / fork ──

  /// Fetch one recipe by id (RLS-gated). Null if you can't read it (private,
  /// not a friend, or owner deleted it). Includes ownerId.
  Future<CloudRecipe?> pullRecipe(String id);

  /// Subscribe to (link) a recipe: record it in linked_recipes.
  Future<void> linkRecipe(String recipeId, String ownerId, int version);

  /// Drop a link subscription (on fork/unlink).
  Future<void> unlinkRecipe(String recipeId);

  /// This user's link subscriptions: recipe id → (owner id, version we pulled).
  Future<List<({String recipeId, String ownerId, int linkedVersion})>> fetchMyLinks();

  /// Readable recipes in a variant group (for stealing variant siblings).
  Future<List<CloudRecipe>> fetchVariantGroup(String groupId);

  /// Current `date_modified` of the given recipe ids that you can still read;
  /// ids you can't read are absent (owner deleted / unfriended → caller
  /// auto-forks). Used to detect "update available" on linked recipes.
  Future<Map<String, DateTime>> checkReadable(List<String> ids);

  // ── Phase 5: reviews ──

  /// All reviews on a recipe you can access (RLS-gated).
  Future<List<Review>> fetchReviews(String recipeId);

  /// Create or replace your review (one per author per recipe).
  Future<void> upsertReview(String recipeId, int stars, String text, String authorUsername);

  /// Delete a review by id (yours, or any on a recipe you own — moderation).
  Future<void> deleteReview(String commentId);
}
