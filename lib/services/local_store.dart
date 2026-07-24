import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// The single seam for local key/value persistence (SharedPreferences). Centralizes
/// every `fb_*` key so they're declared once (no scattered string literals), and
/// consolidates the JSON encode/decode for the blob values. AppState owns the
/// in-memory state and decides *what*/*when* to persist; this owns *how*/*where*.
///
/// Key strings and serialization are intentionally unchanged from the previous
/// inline access, so existing stored data loads identically.
class LocalStore {
  LocalStore(this._p);
  final SharedPreferences _p;

  static Future<LocalStore> create() async => LocalStore(await SharedPreferences.getInstance());

  // ── keys (single source of truth) ──
  static const db = 'fb_db';
  static const lang = 'fb_lang';
  static const fontSize = 'fb_fontsize';
  static const temp = 'fb_temp';
  static const volume = 'fb_vol';
  static const weight = 'fb_weight';
  static const keepCups = 'fb_keepcups';
  static const pdfPaper = 'fb_pdf_paper';
  static const dark = 'fb_dark';
  static const accent = 'fb_accent';
  static const home = 'fb_home';
  static const chime = 'fb_chime';
  static const chimeUri = 'fb_chime_uri';
  static const chimeName = 'fb_chime_name';
  static const tips = 'fb_tips';
  static const shopping = 'fb_shopping';
  static const photos = 'fb_photos';
  static const gallery = 'fb_gallery';
  static const trash = 'fb_trash';
  static const aliases = 'fb_aliases';
  static const preferredAi = 'fb_preferred_ai';
  static const importProvider = 'fb_import_provider';
  static const localOwner = 'fb_local_owner';
  // Crash logging / reporting (see services/crash_log.dart).
  static const crashLog = 'fb_crash_log'; // this session's breadcrumbs (flushed)
  static const crashPrevLog = 'fb_crash_prev_log'; // previous session's final log
  static const crashPending = 'fb_crash_pending'; // un-reported Dart error marker
  static const runState = 'fb_run_state'; // {state:'fg'|'bg', build} dirty-exit detector
  static const crashReports = 'fb_crash_reports'; // sent-report bookkeeping (cap 10)
  static const pickCtx = 'fb_pick_ctx'; // in-flight photo pick target (Android lost-data recovery)
  // Per-account keys (shared-device safety).
  static const _syncedPrefix = 'fb_synced_';
  static String synced(String accountId) => '$_syncedPrefix$accountId';
  static String syncState(String accountId) => 'fb_sync_state_$accountId';
  static String vbase(String accountId) => 'fb_vbase_$accountId';
  /// True for any [synced] key, used to detect a prior account on this device.
  static bool isSyncedKey(String key) => key.startsWith(_syncedPrefix);

  // ── typed access ──
  String? str(String key) => _p.getString(key);
  bool? flag(String key) => _p.getBool(key);
  void setStr(String key, String value) => _p.setString(key, value);
  void setFlag(String key, bool value) => _p.setBool(key, value);
  void remove(String key) => _p.remove(key);
  Set<String> keys() => _p.getKeys();

  /// Store [value] (any json-encodable) as a JSON string under [key].
  void setJson(String key, Object value) => _p.setString(key, jsonEncode(value));

  /// Write [value] under [key], or remove the key when null.
  void setStrOrRemove(String key, String? value) => value == null ? _p.remove(key) : _p.setString(key, value);
}
