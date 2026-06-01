import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/import/ondevice_ai.dart';

import '../data/models.dart';
import '../data/i18n.dart';
import '../data/format.dart';

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
  Map<String, String> aliases = {}; // normalized ingredient name -> CNF food code (learned defaults, §2e)

  // ── import engine config (§2f) ──
  String importBackend = 'tier0'; // tier0 (link/JSON-LD) | ondevice | byok
  String importProvider = 'claude'; // selected BYOK provider: claude | openai | gemini
  Map<String, String> importKeys = {}; // provider -> API key, cached from secure storage
  bool onDeviceAI = false; // whether Tier 1 (on-device model) is usable on this device
  String onDeviceTemplate = 'gemma'; // chat template for the loaded model: gemma | qwen | generic
  int onDeviceMaxTokens = 1280; // model's compiled context (from its filename's ekvNNNN), input+output
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

  // ── lookups ──
  Map<String, Tag> get tagsById => {for (final t in tags) t.id: t};
  Recipe? getRecipe(String? id) {
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  VariantGroup? getVariantGroup(String? gid) {
    for (final g in variantGroups) {
      if (g.groupId == gid) return g;
    }
    return null;
  }

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
    final al = _prefs!.getString('fb_aliases');
    if (al != null) {
      try {
        aliases = Map<String, String>.from(jsonDecode(al) as Map);
      } catch (_) {}
    }
    importBackend = _prefs!.getString('fb_import_backend') ?? importBackend;
    importProvider = _prefs!.getString('fb_import_provider') ?? importProvider;
    onDeviceTemplate = _prefs!.getString('fb_ondevice_tpl') ?? onDeviceTemplate;
    onDeviceMaxTokens = _prefs!.getInt('fb_ondevice_maxtok') ?? onDeviceMaxTokens;
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
    ready = true;
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
    _persistDb();
    notifyListeners();
  }

  void setRating(String id, int v) => updateRecipe(id, (r) => r.personal.rating = v);

  /// Persist the in-memory database (used to flush inline notes edits without
  /// rebuilding the UI on every keystroke).
  void saveDb() => _persistDb();

  void markCooked(String id) {
    final r = getRecipe(id);
    if (r == null) return;
    r.personal.madeCount += 1;
    r.personal.lastCooked = '2026-05-28T00:00:00Z';
    _persistDb();
    notifyListeners();
  }

  void deleteRecipe(String id) {
    recipes.removeWhere((r) => r.id == id);
    if (recipePhotos.remove(id) != null) _persistPhotos();
    if (recipeGallery.remove(id) != null) _persistGallery();
    _persistDb();
    notifyListeners();
  }

  /// Save (create or replace). Returns the recipe id.
  String saveRecipe(Recipe form, Recipe? existing) {
    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      final idx = recipes.indexWhere((r) => r.id == existing.id);
      form.dateModified = now;
      if (idx >= 0) recipes[idx] = form;
      _persistDb();
      notifyListeners();
      return existing.id;
    }
    final id = uuid();
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
    notifyListeners();
    return id;
  }

  /// Create a variant: copies the base recipe into the same variant group.
  /// Returns the new recipe id (caller navigates to edit it).
  String addVariant(String id) {
    final base = getRecipe(id);
    if (base == null) return id;
    final newId = uuid();
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
    notifyListeners();
    return (id: id, created: true);
  }

  bool renameTag(String id, String name) {
    final dup = findTagByName(name);
    if (dup != null && dup.id != id) return false;
    final tg = tags.firstWhere((t) => t.id == id);
    tg.name = name.trim();
    _persistDb();
    notifyListeners();
    return true;
  }

  void deleteTag(String id) {
    tags.removeWhere((t) => t.id == id);
    for (final r in recipes) {
      r.tags.remove(id);
    }
    _persistDb();
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
  void setImportBackend(String b) {
    importBackend = b;
    _prefs?.setString('fb_import_backend', b);
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

  /// Whether a backend tier can run right now (device / keys permitting).
  bool engineAvailable(String backend) =>
      backend == 'tier0' || (backend == 'ondevice' && onDeviceAI) || (backend == 'byok' && hasAnyImportKey);

  /// The configured backend, falling back to tier0 if it's not currently usable.
  String get effectiveBackend => engineAvailable(importBackend) ? importBackend : 'tier0';

  /// Recompute Tier 1 availability after the on-device model is imported/deleted.
  Future<void> refreshOnDevice() async {
    onDeviceAI = await OnDeviceAi.available();
    notifyListeners();
  }

  void setOnDeviceTemplate(String t) {
    onDeviceTemplate = t;
    _prefs?.setString('fb_ondevice_tpl', t);
    notifyListeners();
  }

  void setOnDeviceMaxTokens(int n) {
    onDeviceMaxTokens = n;
    _prefs?.setInt('fb_ondevice_maxtok', n);
    notifyListeners();
  }

  /// Guess the chat template from a model's filename/URL (set on import).
  static String detectTemplate(String name) {
    final n = name.toLowerCase();
    if (n.contains('qwen')) return 'qwen';
    if (n.contains('gemma')) return 'gemma';
    return 'gemma';
  }

  /// Read the model's compiled context from its filename (litert bundles encode
  /// it as e.g. "…ekv1280…"). Falls back to a conservative 1280.
  static int detectMaxTokens(String name) {
    final m = RegExp(r'ekv(\d+)', caseSensitive: false).firstMatch(name);
    final v = m != null ? int.tryParse(m.group(1)!) : null;
    return (v != null && v >= 256 && v <= 32768) ? v : 1280;
  }

  /// Called when an on-device import attempt proves the model isn't actually
  /// usable here. Disables Tier 1 for this session and moves off it so the
  /// user isn't stuck on a dead engine.
  void markOnDeviceUnavailable() {
    onDeviceAI = false;
    if (importBackend == 'ondevice') {
      importBackend = hasAnyImportKey ? 'byok' : 'tier0';
      _prefs?.setString('fb_import_backend', importBackend);
    }
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
