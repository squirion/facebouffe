import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto/crypto.dart' show sha256;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/import/ondevice_ai.dart';
import '../services/sync/sync_backend.dart';
import '../services/sync/supabase_backend.dart';

import '../data/models.dart';
import '../data/i18n.dart';
import '../data/format.dart';

part 'app_state_sync.dart';

/// Cloud-sync health, surfaced in the account screen.
enum SyncStatus { idle, syncing, synced, offline, error }

/// Outcome of trying to add a friend by username.
enum AddFriendResult { sent, notFound, self, already, error }

/// Single source of truth for the whole app. Holds the recipe database, tags,
/// variant groups, profile/settings, shopping list, coach-mark flags and the
/// per-recipe photo store. Mutations notify listeners and persist locally.
class AppState extends ChangeNotifier {
  List<Recipe> recipes = [];
  List<Tag> tags = [];
  List<VariantGroup> variantGroups = [];
  Profile profile = Profile();
  List<ShoppingItem> shopping = [];
  TipsSeen tipsSeen = TipsSeen();
  Map<String, String> recipePhotos = {}; // recipe id (or "__draft") -> hero photo path
  Map<String, List<String>> recipeGallery = {}; // recipe id (or "__draft") -> gallery photo paths
  // Soft-delete buffer (newest first). Each entry: {recipe, photo, gallery, deletedAt}.
  // Photo files are kept on disk while buffered and only erased when an entry is
  // evicted past [maxTrash] or purged, so a delete is recoverable.
  List<Map<String, dynamic>> recentlyDeleted = [];
  static const int maxTrash = 25;
  Map<String, String> aliases = {}; // normalized ingredient name -> CNF food code (learned defaults, §2e)

  // ── import engine config (§2f) ──
  String preferredAI = 'online'; // which AI to prefer when one is needed: online | ondevice
  bool online = true; // network reachable (connectivity_plus); optimistic default
  String importProvider = 'claude'; // selected BYOK provider: claude | openai | gemini
  Map<String, String> importKeys = {}; // provider -> API key, cached from secure storage
  bool onDeviceAI = false; // whether the Tier 1 model has been downloaded
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  static const _secure = FlutterSecureStorage();

  // App-only settings (not part of the recipe schema)
  bool dark = false;
  String accentHex = '#C0563B';
  String homeLayout = 'editorial'; // editorial | grid
  String chimeSound = 'alarm'; // timer sound mode: 'alarm' (a phone alarm tone) | 'chime' (soft)
  String? chimeAlarmUri; // chosen alarm tone URI; null = device default alarm
  String? chimeAlarmName; // display title of the chosen alarm tone
  bool get chimeIsAlarm => chimeSound == 'alarm';

  bool reduceMotion = false;
  String appVersion = ''; // e.g. "1.0.1+2" — loaded from package_info
  SharedPreferences? _prefs;
  bool ready = false;

  // ── account / social layer (Phase 2) — optional sign-in ──
  final SyncBackend sync;
  Account? account; // null = signed out / offline-only
  StreamSubscription<Account?>? _acctSub;
  bool get signedIn => account != null;

  AppState({SyncBackend? sync}) : sync = sync ?? SupabaseSyncBackend();

  // ── cloud sync (Phase 2A) ──
  SyncStatus syncStatus = SyncStatus.idle;
  bool migrationPending = false; // later-device: local-only recipes await user choice
  final Set<String> _syncedIds = {}; // recipe ids known to exist in the cloud
  final Set<String> _localOnlyIds = {}; // recipes the user chose NOT to sync (later-device "skip")
  List<Recipe> _pendingLocalOnly = []; // recipes offered in the MigrationSheet
  bool _syncBusy = false;
  final Map<String, String> _imgHashCache = {}; // local photo path -> sha-256 content hash
  final Map<String, List<String>> _recipeImgHashes = {}; // recipe id -> last-synced image hash set
  List<FriendEdge> friends = []; // friendship edges (accepted + pending), resolved usernames
  // Transient: a friend's shared recipes while browsing their cookbook (online-only,
  // not in your library). getRecipe() falls through to these so the existing recipe
  // page / Sous-chef work by id without persisting anything.
  final Map<String, Recipe> visitingRecipes = {};

  // ── lookups ──
  Map<String, Tag> get tagsById => {for (final t in tags) t.id: t};
  Recipe? getRecipe(String? id) {
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    if (id != null) return visitingRecipes[id]; // friend's cookbook (transient)
    return null;
  }

  VariantGroup? getVariantGroup(String? gid) {
    for (final g in variantGroups) {
      if (g.groupId == gid) return g;
    }
    return null;
  }

  /// Public passthrough so the cloud-sync extension (a separate part) can poke
  /// listeners — `notifyListeners` itself is protected to ChangeNotifier.
  void notify() => notifyListeners();

  String t(String key) => tr(profile.language, key);
  String get lang => profile.language;
  UnitPrefs get prefs => UnitPrefs(temperature: profile.temperature, volume: profile.volume, weight: profile.weight);

  // ── init / persistence ──
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final db = _prefs!.getString('fb_db');
    if (db != null) {
      try {
        _loadDb(jsonDecode(db) as Map<String, dynamic>);
      } catch (_) {
        await _loadSeed();
      }
    } else {
      await _loadSeed();
    }
    // settings
    profile.language = _prefs!.getString('fb_lang') ?? profile.language;
    profile.fontSize = _prefs!.getString('fb_fontsize') ?? profile.fontSize;
    profile.temperature = _prefs!.getString('fb_temp') ?? profile.temperature;
    profile.volume = _prefs!.getString('fb_vol') ?? profile.volume;
    profile.weight = _prefs!.getString('fb_weight') ?? profile.weight;
    dark = _prefs!.getBool('fb_dark') ?? false;
    accentHex = _prefs!.getString('fb_accent') ?? accentHex;
    homeLayout = _prefs!.getString('fb_home') ?? homeLayout;
    chimeSound = _prefs!.getString('fb_chime') ?? chimeSound;
    chimeAlarmUri = _prefs!.getString('fb_chime_uri');
    chimeAlarmName = _prefs!.getString('fb_chime_name');
    final tips = _prefs!.getString('fb_tips');
    if (tips != null) {
      try {
        tipsSeen = TipsSeen.fromMap(jsonDecode(tips) as Map<String, dynamic>);
      } catch (_) {}
    }
    final photos = _prefs!.getString('fb_photos');
    if (photos != null) {
      try {
        recipePhotos = Map<String, String>.from(jsonDecode(photos) as Map);
      } catch (_) {}
    }
    final gallery = _prefs!.getString('fb_gallery');
    if (gallery != null) {
      try {
        recipeGallery = (jsonDecode(gallery) as Map).map((k, v) => MapEntry(k as String, (v as List).map((e) => e as String).toList()));
      } catch (_) {}
    }
    final trash = _prefs!.getString('fb_trash');
    if (trash != null) {
      try {
        recentlyDeleted = (jsonDecode(trash) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    final al = _prefs!.getString('fb_aliases');
    if (al != null) {
      try {
        aliases = Map<String, String>.from(jsonDecode(al) as Map);
      } catch (_) {}
    }
    preferredAI = _prefs!.getString('fb_preferred_ai') ?? preferredAI;
    importProvider = _prefs!.getString('fb_import_provider') ?? importProvider;
    _watchConnectivity();
    try {
      for (final p in const ['claude', 'openai', 'gemini']) {
        final k = await _secure.read(key: 'fb_key_$p');
        if (k != null && k.isNotEmpty) importKeys[p] = k;
      }
    } catch (_) {}
    onDeviceAI = await OnDeviceAi.available();
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}
    _initAccount();
    ready = true;
    notifyListeners();
  }

  // ── account / social ──
  void _initAccount() {
    account = sync.currentAccount;
    if (account != null) _refreshUsername();
    _acctSub = sync.accountChanges.listen((a) async {
      account = a;
      if (a != null && a.username == null) await _refreshUsername();
      notifyListeners();
    });
  }

  Future<void> _refreshUsername() async {
    try {
      final u = await sync.fetchMyUsername();
      account = account?.withUsername(u);
      notifyListeners();
      if (u != null) unawaited(runCloudSync());
    } catch (_) {}
  }

  Future<void> sendSignInCode(String email) => sync.sendEmailCode(email.trim());

  /// Verify the emailed code. Returns true if a username still needs to be chosen.
  Future<bool> verifySignInCode(String email, String code) async {
    await sync.verifyEmailCode(email.trim(), code);
    final u = await sync.fetchMyUsername();
    account = sync.currentAccount?.withUsername(u);
    notifyListeners();
    return u == null;
  }

  Future<bool> usernameAvailable(String handle) => sync.isUsernameAvailable(handle);

  Future<void> claimUsername(String handle) async {
    await sync.claimUsername(handle);
    account = account?.withUsername(handle.trim().toLowerCase());
    notifyListeners();
    unawaited(runCloudSync()); // first-ever sign-in → migrate this device's cookbook
  }

  Future<void> signOutAccount() async {
    await sync.signOut();
    account = null;
    _syncedIds.clear();
    _pendingLocalOnly = [];
    friends = [];
    migrationPending = false;
    syncStatus = SyncStatus.idle;
    notifyListeners();
  }

  Future<void> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/facebouffe-seed.json');
    _loadDb(jsonDecode(raw) as Map<String, dynamic>);
  }

  void _loadDb(Map<String, dynamic> j) {
    recipes = (j['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    tags = (j['tags'] as List).map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    variantGroups = (j['variantGroups'] as List? ?? []).map((e) => VariantGroup.fromJson(e as Map<String, dynamic>)).toList();
    if (j['profile'] != null) profile = Profile.fromJson(j['profile'] as Map<String, dynamic>);
  }

  Map<String, dynamic> exportData() => {
        'schemaVersion': 1,
        'profile': profile.toJson(),
        'tags': tags.map((e) => e.toJson()).toList(),
        'variantGroups': variantGroups.map((e) => e.toJson()).toList(),
        'recipes': recipes.map((e) => e.toJson()).toList(),
      };

  void _persistDb() {
    _prefs?.setString('fb_db', jsonEncode(exportData()));
  }

  void _persistSettings() {
    final p = _prefs;
    if (p == null) return;
    p.setString('fb_lang', profile.language);
    p.setString('fb_fontsize', profile.fontSize);
    p.setString('fb_temp', profile.temperature);
    p.setString('fb_vol', profile.volume);
    p.setString('fb_weight', profile.weight);
    p.setBool('fb_dark', dark);
    p.setString('fb_accent', accentHex);
    p.setString('fb_home', homeLayout);
    p.setString('fb_chime', chimeSound);
    if (chimeAlarmUri != null) {
      p.setString('fb_chime_uri', chimeAlarmUri!);
    } else {
      p.remove('fb_chime_uri');
    }
    if (chimeAlarmName != null) {
      p.setString('fb_chime_name', chimeAlarmName!);
    } else {
      p.remove('fb_chime_name');
    }
  }

  // ── settings mutations ──
  void setLanguage(String v) {
    profile.language = v;
    _persistSettings();
    notifyListeners();
  }

  void setFontSize(String v) {
    profile.fontSize = v;
    _persistSettings();
    notifyListeners();
  }

  void setTemp(String v) {
    profile.temperature = v;
    _persistSettings();
    notifyListeners();
  }

  void setVolume(String v) {
    profile.volume = v;
    _persistSettings();
    notifyListeners();
  }

  void setWeight(String v) {
    profile.weight = v;
    _persistSettings();
    notifyListeners();
  }

  void setDark(bool v) {
    dark = v;
    _persistSettings();
    notifyListeners();
  }

  void setAccent(String hex) {
    accentHex = hex;
    _persistSettings();
    notifyListeners();
  }

  void setHomeLayout(String v) {
    homeLayout = v;
    _persistSettings();
    notifyListeners();
  }

  void setChimeMode(String v) {
    chimeSound = v;
    _persistSettings();
    notifyListeners();
  }

  /// Pick a specific phone alarm tone (also switches the mode to 'alarm').
  void setAlarmTone(String? uri, String? name) {
    chimeSound = 'alarm';
    chimeAlarmUri = uri;
    chimeAlarmName = name;
    _persistSettings();
    notifyListeners();
  }

  void setUsername(String v) {
    profile.username = v;
    _persistDb();
    notifyListeners();
  }

  void setReduceMotion(bool v) {
    if (reduceMotion == v) return;
    reduceMotion = v;
    notifyListeners();
  }

  // ── recipe mutations ──
  bool isFav(Recipe? r) => r != null && r.tags.contains('tag-fav');

  void updateRecipe(String id, void Function(Recipe) fn) {
    final r = getRecipe(id);
    if (r == null) return;
    fn(r);
    r.dateModified = DateTime.now().toIso8601String();
    _persistDb();
    cloudPushRecipe(r);
    notifyListeners();
  }

  void toggleFav(String id) {
    final r = getRecipe(id);
    if (r == null) return;
    if (r.tags.contains('tag-fav')) {
      r.tags.remove('tag-fav');
    } else {
      r.tags.add('tag-fav');
    }
    r.dateModified = DateTime.now().toIso8601String();
    _persistDb();
    cloudPushRecipe(r);
    notifyListeners();
  }

  void setRating(String id, int v) => updateRecipe(id, (r) => r.personal.rating = v);

  /// Set a recipe's share visibility ('private' | 'friends'). Owned recipes only.
  void setVisibility(String id, String v) {
    final r = getRecipe(id);
    if (r == null || !recipes.any((x) => x.id == id)) return; // owned only
    r.visibility = v;
    r.dateModified = DateTime.now().toIso8601String();
    _persistDb();
    cloudPushRecipe(r);
    notifyListeners();
  }

  /// Persist the in-memory database (used to flush inline notes edits without
  /// rebuilding the UI on every keystroke). Pass [touchedId] to also bump that
  /// recipe's modified time and push the change to the cloud.
  void saveDb([String? touchedId]) {
    if (touchedId != null) {
      final r = getRecipe(touchedId);
      if (r != null) {
        r.dateModified = DateTime.now().toIso8601String();
        _persistDb();
        cloudPushRecipe(r);
        return;
      }
    }
    _persistDb();
  }

  void markCooked(String id) {
    final r = getRecipe(id);
    if (r == null) return;
    r.personal.madeCount += 1;
    r.personal.lastCooked = DateTime.now().toIso8601String();
    r.dateModified = DateTime.now().toIso8601String();
    _persistDb();
    cloudPushRecipe(r);
    notifyListeners();
  }

  /// Soft-delete: removes the recipe from the active set but keeps a snapshot
  /// (and its photo files) in [recentlyDeleted] so it can be restored. Files are
  /// only erased when the entry is evicted past [maxTrash] or purged.
  void deleteRecipe(String id) {
    final r = getRecipe(id);
    recipes.removeWhere((x) => x.id == id);
    final photo = recipePhotos.remove(id);
    final gallery = recipeGallery.remove(id);
    if (r != null) {
      recentlyDeleted.insert(0, {
        'recipe': r.toJson(),
        'photo': photo,
        'gallery': gallery ?? const <String>[],
        'deletedAt': DateTime.now().toIso8601String(),
      });
      while (recentlyDeleted.length > maxTrash) {
        _deleteEntryFiles(recentlyDeleted.removeLast());
      }
      _persistTrash();
    }
    if (photo != null) _persistPhotos();
    if (gallery != null) _persistGallery();
    _persistDb();
    cloudDeleteRecipe(id);
    notifyListeners();
  }

  void _persistTrash() => _prefs?.setString('fb_trash', jsonEncode(recentlyDeleted));

  /// Restore a buffered recipe (by index in [recentlyDeleted]) to the active set.
  void restoreDeleted(int index) {
    if (index < 0 || index >= recentlyDeleted.length) return;
    final entry = recentlyDeleted.removeAt(index);
    final recipe = Recipe.fromJson(Map<String, dynamic>.from(entry['recipe'] as Map));
    recipes.removeWhere((x) => x.id == recipe.id); // guard against a reused id
    recipes.insert(0, recipe);
    final photo = entry['photo'];
    if (photo is String && photo.isNotEmpty) recipePhotos[recipe.id] = photo;
    final gallery = (entry['gallery'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    if (gallery.isNotEmpty) recipeGallery[recipe.id] = List<String>.from(gallery);
    _persistTrash();
    _persistPhotos();
    _persistGallery();
    _persistDb();
    cloudPushRecipe(recipe);
    notifyListeners();
  }

  /// Permanently remove a buffered entry (deletes its photo files).
  void purgeDeleted(int index) {
    if (index < 0 || index >= recentlyDeleted.length) return;
    _deleteEntryFiles(recentlyDeleted.removeAt(index));
    _persistTrash();
    notifyListeners();
  }

  // Erase the on-disk photo files referenced by a buffered entry (hero, gallery,
  // step images). Skips web data-URLs and non-path placeholder labels.
  void _deleteEntryFiles(Map<String, dynamic> entry) {
    if (kIsWeb) return;
    final paths = <String?>[entry['photo'] as String?];
    for (final g in (entry['gallery'] as List? ?? const [])) {
      paths.add(g?.toString());
    }
    final rj = entry['recipe'];
    if (rj is Map) {
      for (final s in (rj['steps'] as List? ?? const [])) {
        if (s is Map) paths.add(s['image'] as String?);
      }
    }
    for (final p in paths) {
      if (p == null || p.isEmpty || p.startsWith('data:') || !p.contains('/')) continue;
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  /// Save (create or replace). Returns the recipe id.
  String saveRecipe(Recipe form, Recipe? existing) {
    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      final idx = recipes.indexWhere((r) => r.id == existing.id);
      form.dateModified = now;
      if (idx >= 0) recipes[idx] = form;
      _persistDb();
      cloudPushRecipe(form);
      notifyListeners();
      return existing.id;
    }
    final id = _uuidV4(); // real UUID — recipes live in a uuid-keyed cloud pool
    form.id = id;
    form.createdBy = profile.username;
    form.dateAdded = now;
    form.dateModified = now;
    recipes.insert(0, form);
    // migrate any draft hero photo + gallery to the new recipe id
    final draft = recipePhotos.remove('__draft');
    if (draft != null) recipePhotos[id] = draft;
    final draftGallery = recipeGallery.remove('__draft');
    if (draftGallery != null && draftGallery.isNotEmpty) recipeGallery[id] = draftGallery;
    _persistPhotos();
    _persistGallery();
    _persistDb();
    cloudPushRecipe(form);
    notifyListeners();
    return id;
  }

  /// Create a variant: copies the base recipe into the same variant group.
  /// Returns the new recipe id (caller navigates to edit it).
  String addVariant(String id) {
    final base = getRecipe(id);
    if (base == null) return id;
    final newId = _uuidV4();
    String gid;
    if (base.variantGroupId != null) {
      gid = base.variantGroupId!;
      final g = getVariantGroup(gid);
      g?.memberIds.add(newId);
    } else {
      gid = 'vg-${uuid()}';
      variantGroups.add(VariantGroup(groupId: gid, memberIds: [id, newId], baseId: id));
      base.variantGroupId = gid;
    }
    final now = DateTime.now().toIso8601String();
    final copy = base.deepCopy();
    copy.id = newId;
    copy.title = base.title + (lang == 'fr' ? ' (variante)' : ' (variant)');
    copy.variantGroupId = gid;
    copy.dateAdded = now;
    copy.dateModified = now;
    copy.tags = copy.tags.where((t) => t != 'tag-fav').toList();
    copy.personal = Personal();
    copy.heroImage = null;
    copy.gallery = [];
    copy.links = [];
    recipes.insert(0, copy);
    _persistDb();
    cloudPushRecipe(base); // base may have gained a variantGroupId
    cloudPushRecipe(copy);
    cloudPushLibrary(); // variant group membership changed
    notifyListeners();
    return newId;
  }

  /// Slot an already-built recipe [gen] into [baseId]'s variant group (creating
  /// the group if needed) — used by the AI "mutation" generator. Returns its id.
  String addGeneratedVariant(String baseId, Recipe gen) {
    final base = getRecipe(baseId);
    if (base == null) return baseId;
    final newId = _uuidV4();
    String gid;
    if (base.variantGroupId != null) {
      gid = base.variantGroupId!;
      getVariantGroup(gid)?.memberIds.add(newId);
    } else {
      gid = 'vg-${uuid()}';
      variantGroups.add(VariantGroup(groupId: gid, memberIds: [baseId, newId], baseId: baseId));
      base.variantGroupId = gid;
    }
    final now = DateTime.now().toIso8601String();
    gen.id = newId;
    gen.variantGroupId = gid;
    gen.createdBy = profile.username;
    gen.dateAdded = now;
    gen.dateModified = now;
    recipes.insert(0, gen);
    _persistDb();
    cloudPushRecipe(base);
    cloudPushRecipe(gen);
    cloudPushLibrary();
    notifyListeners();
    return newId;
  }

  // ── tags ──
  static const _paletteTags = ['#C0563B', '#E0A458', '#6BA368', '#9C6B8E', '#4A7BA6', '#C58A2E', '#5B8C7E'];
  static const _tagIcons = ['leaf', 'flame', 'bowl', 'cake', 'utensils', 'sunrise', 'dumbbell', 'shrimp'];

  Tag? findTagByName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final tg in tags) {
      if (tg.allNames.any((x) => x.toLowerCase() == n)) return tg;
    }
    return null;
  }

  /// Returns (id, created).
  ({String id, bool created}) addTag(String name) {
    final existing = findTagByName(name);
    if (existing != null) return (id: existing.id, created: false);
    final id = 'tag-${uuid()}';
    tags.add(Tag(id: id, system: false, name: name.trim(), icon: _tagIcons[tags.length % _tagIcons.length], color: _paletteTags[tags.length % _paletteTags.length]));
    _persistDb();
    cloudPushLibrary();
    notifyListeners();
    return (id: id, created: true);
  }

  bool renameTag(String id, String name) {
    final dup = findTagByName(name);
    if (dup != null && dup.id != id) return false;
    final tg = tags.firstWhere((t) => t.id == id);
    tg.name = name.trim();
    _persistDb();
    cloudPushLibrary();
    notifyListeners();
    return true;
  }

  void deleteTag(String id) {
    tags.removeWhere((t) => t.id == id);
    final touched = <Recipe>[];
    for (final r in recipes) {
      if (r.tags.remove(id)) {
        r.dateModified = DateTime.now().toIso8601String();
        touched.add(r);
      }
    }
    _persistDb();
    cloudPushLibrary();
    for (final r in touched) {
      cloudPushRecipe(r);
    }
    notifyListeners();
  }

  int recipesWithTag(String id) => recipes.where((r) => r.tags.contains(id)).length;

  // ── coach marks ──
  void markTipSeen(String key) {
    switch (key) {
      case 'sousChef':
        tipsSeen.sousChef = true;
        break;
      case 'variants':
        tipsSeen.variants = true;
        break;
      case 'shoppingAdd':
        tipsSeen.shoppingAdd = true;
        break;
      case 'pdfExport':
        tipsSeen.pdfExport = true;
        break;
      case 'variantChips':
        tipsSeen.variantChips = true;
        break;
      case 'cookStack':
        tipsSeen.cookStack = true;
        break;
      case 'customTags':
        tipsSeen.customTags = true;
        break;
      case 'ingredientAliases':
        tipsSeen.ingredientAliases = true;
        break;
      case 'apiKeys':
        tipsSeen.apiKeys = true;
        break;
      case 'preferredAi':
        tipsSeen.preferredAi = true;
        break;
    }
    _prefs?.setString('fb_tips', jsonEncode(tipsSeen.toMap()));
    notifyListeners();
  }

  void resetTips() {
    tipsSeen = TipsSeen();
    _prefs?.setString('fb_tips', jsonEncode(tipsSeen.toMap()));
    notifyListeners();
  }

  // ── photos ──
  void _persistPhotos() => _prefs?.setString('fb_photos', jsonEncode(recipePhotos));

  void setRecipePhoto(String id, String? path) {
    if (path == null) {
      recipePhotos.remove(id);
    } else {
      recipePhotos[id] = path;
    }
    _persistPhotos();
    notifyListeners();
  }

  // ── gallery ──
  void _persistGallery() => _prefs?.setString('fb_gallery', jsonEncode(recipeGallery));

  static const int maxGalleryPhotos = 5;

  List<String> galleryOf(String id) => recipeGallery[id] ?? const [];

  void addGalleryPhoto(String id, String path) {
    final list = recipeGallery[id] ??= [];
    if (list.length >= maxGalleryPhotos) return; // hard cap
    list.add(path);
    _persistGallery();
    notifyListeners();
  }

  void removeGalleryPhoto(String id, int index) {
    final list = recipeGallery[id];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) recipeGallery.remove(id);
    _persistGallery();
    notifyListeners();
  }

  // ── ingredient aliases (learned CNF defaults, §2e) ──
  static String normalizeIngredientName(String name) => name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  void addAlias(String name, String foodCode) {
    final key = normalizeIngredientName(name);
    if (key.isEmpty) return;
    aliases[key] = foodCode;
    _prefs?.setString('fb_aliases', jsonEncode(aliases));
    notifyListeners();
  }

  void removeAlias(String key) {
    aliases.remove(key);
    _prefs?.setString('fb_aliases', jsonEncode(aliases));
    notifyListeners();
  }

  // ── import engine config (§2f) ──
  void _watchConnectivity() {
    Future<void> apply(List<ConnectivityResult> r) async {
      final up = r.any((c) => c != ConnectivityResult.none);
      if (up != online) {
        online = up;
        notifyListeners();
      }
    }

    try {
      Connectivity().checkConnectivity().then(apply);
      _connSub = Connectivity().onConnectivityChanged.listen(apply);
    } catch (_) {}
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _acctSub?.cancel();
    super.dispose();
  }

  void setPreferredAI(String p) {
    preferredAI = p;
    _prefs?.setString('fb_preferred_ai', p);
    notifyListeners();
  }

  void setImportProvider(String p) {
    importProvider = p;
    _prefs?.setString('fb_import_provider', p);
    notifyListeners();
  }

  Future<void> setImportKey(String provider, String key) async {
    final v = key.trim();
    if (v.isEmpty) {
      importKeys.remove(provider);
      try {
        await _secure.delete(key: 'fb_key_$provider');
      } catch (_) {}
    } else {
      importKeys[provider] = v;
      try {
        await _secure.write(key: 'fb_key_$provider', value: v);
      } catch (_) {}
    }
    notifyListeners();
  }

  bool importKeyFor(String provider) => (importKeys[provider] ?? '').trim().isNotEmpty;
  bool get hasAnyImportKey => importKeys.values.any((k) => k.trim().isNotEmpty);

  // ── AI engine availability (for the decision tree) ──
  bool get onDeviceReady => onDeviceAI; // Tier 1 model present (no network needed)
  bool get onlineAiReady => hasAnyImportKey && online; // Tier 2 key + connection

  /// Recompute Tier 1 availability after the on-device model is imported/deleted.
  Future<void> refreshOnDevice() async {
    onDeviceAI = await OnDeviceAi.available();
    notifyListeners();
  }

  /// Called when an on-device import attempt proves the model isn't actually
  /// usable here. Disables Tier 1 for this session.
  void markOnDeviceUnavailable() {
    onDeviceAI = false;
    notifyListeners();
  }

  // ── shopping ──
  void shoppingAdd(ShoppingItem it) {
    shopping.add(it);
    notifyListeners();
  }

  void shoppingAddMany(List<ShoppingItem> arr) {
    for (final it in arr) {
      final idx = shopping.indexWhere((x) => !x.checked && x.name == it.name && x.unit == it.unit);
      if (idx >= 0 && it.quantity != null && shopping[idx].quantity != null) {
        shopping[idx].quantity = shopping[idx].quantity! + it.quantity!;
      } else {
        shopping.add(it);
      }
    }
    notifyListeners();
  }

  void shoppingToggle(String id) {
    final it = shopping.firstWhere((x) => x.id == id);
    it.checked = !it.checked;
    notifyListeners();
  }

  void shoppingRemove(String id) {
    shopping.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  void shoppingClearChecked() {
    shopping.removeWhere((x) => x.checked);
    notifyListeners();
  }

  int get shoppingUncheckedCount => shopping.where((x) => !x.checked).length;

  // ── import ──
  int importData(Map<String, dynamic> data) {
    if (data['recipes'] is! List) throw Exception('bad');
    final incoming = (data['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    final byId = {for (final r in recipes) r.id: r};
    for (final r in incoming) {
      byId[r.id] = r;
    }
    recipes = byId.values.toList();
    if (data['tags'] is List) {
      final tById = {for (final t in tags) t.id: t};
      for (final tg in (data['tags'] as List)) {
        final t = Tag.fromJson(tg as Map<String, dynamic>);
        tById[t.id] = t;
      }
      tags = tById.values.toList();
    }
    if (data['variantGroups'] is List) {
      final gById = {for (final g in variantGroups) g.groupId: g};
      for (final vg in (data['variantGroups'] as List)) {
        final g = VariantGroup.fromJson(vg as Map<String, dynamic>);
        gById[g.groupId] = g;
      }
      variantGroups = gById.values.toList();
    }
    _persistDb();
    notifyListeners();
    return incoming.length;
  }

  /// Number of variant-group members that still exist (deleted recipes leave
  /// stale ids in [VariantGroup.memberIds]; restoring re-counts them). Used for
  /// the "N variantes" badge so it never counts trashed/purged variants.
  int liveVariantCount(String? groupId) {
    if (groupId == null) return 0;
    final g = getVariantGroup(groupId);
    if (g == null) return 0;
    final ids = recipes.map((r) => r.id).toSet();
    return g.memberIds.where(ids.contains).length;
  }

  /// Recipes deduplicated by variant group (group shown once via its base).
  List<Recipe> get baseRecipes => recipes.where((r) {
        if (r.variantGroupId == null) return true;
        final g = getVariantGroup(r.variantGroupId);
        return g == null || g.baseId == r.id;
      }).toList();
}

final _rand = Random();
String uuid() {
  final a = _rand.nextInt(1 << 32).toRadixString(36);
  final b = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'id-$a$b';
}
