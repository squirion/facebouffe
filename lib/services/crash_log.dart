import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'sync/sync_backend.dart' show CrashReportStatus;

/// A crash report the user already sent, kept locally so the app can read back
/// its status ("investigating", "fixed"…) on later launches.
class SentReport {
  final String id;
  final int sentAt; // ms epoch
  final String kind; // 'crash' | 'manual'
  String status;
  String? devNote;
  bool seen; // user saw the latest status change
  SentReport({required this.id, required this.sentAt, required this.kind, this.status = 'new', this.devNote, this.seen = true});

  Map<String, Object?> toJson() => {'id': id, 'sentAt': sentAt, 'kind': kind, 'status': status, 'devNote': devNote, 'seen': seen};
  static SentReport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return SentReport(
      id: id,
      sentAt: (raw['sentAt'] as num?)?.toInt() ?? 0,
      kind: raw['kind'] as String? ?? 'crash',
      status: raw['status'] as String? ?? 'new',
      devNote: raw['devNote'] as String?,
      seen: raw['seen'] as bool? ?? true,
    );
  }
}

/// Self-hosted crash logging: a bounded breadcrumb ring buffer persisted to
/// SharedPreferences, global-error capture, and crash auto-detection on next
/// launch. Two detection paths:
///  - Dart errors: the global handlers call [error], which writes an explicit
///    pending marker.
///  - Native kills (OOM while decoding images, etc.) that no Dart handler can
///    see: a run-state flag says whether the previous session died while
///    foregrounded ("dirty exit"). Native only — on web a closed tab looks
///    identical, so web relies on explicit markers alone.
///
/// Every public method is exception-safe: the logger must never take the app
/// down with it.
class CrashLog with WidgetsBindingObserver {
  CrashLog._();
  static final CrashLog instance = CrashLog._();

  static const maxCrumbs = 250;
  static const maxCrumbLen = 300;
  static const maxLogBytes = 64 * 1024;
  static const maxSentReports = 10;

  SharedPreferences? _prefs;
  final ListQueue<String> _crumbs = ListQueue();
  int _sinceFlush = 0;
  bool _inError = false;
  int build = 0;
  String version = '';

  /// Previous session's final breadcrumb log (rotated at boot) — what a
  /// startup crash report sends.
  String? previousSessionLog;

  /// A crash was detected for the previous session (marker or dirty exit).
  bool startupCrashPending = false;

  /// 'dart' (explicit error marker) or 'dirty-exit' (native kill heuristic).
  String startupSource = '';

  final List<SentReport> _sent = [];
  List<SentReport> get sentReports => List.unmodifiable(_sent);

  /// Raw status of the most recent unseen status change, if any (drives the
  /// "your report was updated" banner). Cleared by [markStatusesSeen].
  String? statusNotice;
  String? statusNoticeNote;

  /// Call once at startup, after ensureInitialized, before anything heavy.
  Future<void> init() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();

      // Rotate the previous session's log.
      previousSessionLog = prefs.getString(LocalStore.crashLog);
      if (previousSessionLog != null) prefs.setString(LocalStore.crashPrevLog, previousSessionLog!);
      prefs.remove(LocalStore.crashLog);

      try {
        final pkg = await PackageInfo.fromPlatform();
        version = '${pkg.version}+${pkg.buildNumber}';
        build = int.tryParse(pkg.buildNumber) ?? 0;
      } catch (_) {}

      // Explicit Dart error marker from last session?
      final marker = prefs.getString(LocalStore.crashPending);
      String prevState = 'none';
      if (marker != null) {
        prefs.remove(LocalStore.crashPending);
        startupCrashPending = true;
        startupSource = 'dart';
      }

      // Native dirty-exit heuristic: previous session was foregrounded when it
      // died. Skipped on web (closing a visible tab is indistinguishable) and
      // right after an app update (the updater kills the process).
      final rawRun = prefs.getString(LocalStore.runState);
      if (rawRun != null) {
        try {
          final run = jsonDecode(rawRun) as Map<String, dynamic>;
          prevState = run['state'] as String? ?? 'none';
          final prevBuild = (run['build'] as num?)?.toInt() ?? -1;
          if (!kIsWeb && !startupCrashPending && prevState == 'fg' && prevBuild == build) {
            startupCrashPending = true;
            startupSource = 'dirty-exit';
          }
        } catch (_) {}
      }
      _writeRunState('fg'); // launching = foregrounded

      _loadSentReports(prefs);
      WidgetsBinding.instance.addObserver(this);
      add('app', 'boot v$version prev=$prevState${startupCrashPending ? ' crash=$startupSource' : ''}');
    } catch (_) {}
  }

  /// Append a breadcrumb: `add('img', 'reencode 2.1MB→410KB')`.
  void add(String cat, String msg) {
    try {
      var m = msg.replaceAll('\n', ' ');
      if (m.length > maxCrumbLen) m = m.substring(0, maxCrumbLen);
      _crumbs.add('${DateTime.now().millisecondsSinceEpoch % 100000000} [$cat] $m');
      while (_crumbs.length > maxCrumbs) {
        _crumbs.removeFirst();
      }
      if (kDebugMode) debugPrint('[fb:$cat] $m');
      if (++_sinceFlush >= 10) _flush();
    } catch (_) {}
  }

  /// Record a caught-at-the-top error. [marker] also flags the session as
  /// crashed so the next launch offers to send a report.
  void error(Object e, StackTrace? st, {required String source, bool marker = true}) {
    if (_inError) return;
    _inError = true;
    try {
      final head = e.toString().replaceAll('\n', ' ');
      final lines = StringBuffer('ERROR ${head.length > maxCrumbLen ? head.substring(0, maxCrumbLen) : head}');
      if (st != null) {
        for (final f in st.toString().split('\n').take(12)) {
          final line = f.trimRight();
          if (line.isEmpty) continue;
          lines.write('\n  ${line.length > 200 ? line.substring(0, 200) : line}');
        }
      }
      _crumbs.add('${DateTime.now().millisecondsSinceEpoch % 100000000} [err:$source] $lines');
      while (_crumbs.length > maxCrumbs) {
        _crumbs.removeFirst();
      }
      if (kDebugMode) debugPrint('[fb:err:$source] $head');
      _flush();
      if (marker) {
        _prefs?.setString(LocalStore.crashPending,
            jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'source': source, 'error': head.length > 300 ? head.substring(0, 300) : head}));
      }
    } catch (_) {
    } finally {
      _inError = false;
    }
  }

  /// The current session's log, serialized (what a manual report sends).
  String dump() {
    try {
      return _crumbs.join('\n');
    } catch (_) {
      return '';
    }
  }

  /// Banner dismissed or crash report sent — stop offering.
  void clearStartupPending() {
    startupCrashPending = false;
    startupSource = '';
  }

  // ── sent-report bookkeeping ──

  void recordSentReport(String id, String kind) {
    try {
      _sent.insert(0, SentReport(id: id, sentAt: DateTime.now().millisecondsSinceEpoch, kind: kind));
      while (_sent.length > maxSentReports) {
        _sent.removeLast();
      }
      _persistSentReports();
      add('report', 'sent ${id.substring(0, 8)} kind=$kind');
    } catch (_) {}
  }

  /// Merge fresh statuses from the server; true when something changed (the
  /// caller then notifies listeners so banners/settings rebuild).
  bool applyStatuses(List<CrashReportStatus> fresh) {
    try {
      var changed = false;
      for (final f in fresh) {
        for (final s in _sent) {
          if (s.id != f.id) continue;
          if (s.status != f.status || s.devNote != f.devNote) {
            s.status = f.status;
            s.devNote = f.devNote;
            s.seen = false;
            statusNotice = f.status;
            statusNoticeNote = f.devNote;
            changed = true;
          }
        }
      }
      if (changed) _persistSentReports();
      return changed;
    } catch (_) {
      return false;
    }
  }

  void markStatusesSeen() {
    try {
      for (final s in _sent) {
        s.seen = true;
      }
      statusNotice = null;
      statusNoticeNote = null;
      _persistSentReports();
    } catch (_) {}
  }

  // ── internals ──

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 'inactive' already counts as background: kills while the camera/uCrop
    // activity is up are handled by ImagePick.recoverLostPick, not the crash
    // banner — and permission dialogs shouldn't arm the dirty-exit flag.
    if (state == AppLifecycleState.resumed) {
      _writeRunState('fg');
    } else {
      _writeRunState('bg');
      _flush();
    }
  }

  void _writeRunState(String state) {
    try {
      _prefs?.setString(LocalStore.runState, jsonEncode({'state': state, 'build': build}));
    } catch (_) {}
  }

  void _flush() {
    try {
      _sinceFlush = 0;
      final list = _crumbs.toList();
      var encoded = jsonEncode(list);
      while (encoded.length > maxLogBytes && list.isNotEmpty) {
        list.removeAt(0);
        encoded = jsonEncode(list);
      }
      _prefs?.setString(LocalStore.crashLog, encoded);
    } catch (_) {}
  }

  void _loadSentReports(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(LocalStore.crashReports);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _sent
        ..clear()
        ..addAll(list.map(SentReport.fromJson).whereType<SentReport>().take(maxSentReports));
      final unseen = _sent.where((s) => !s.seen).toList();
      if (unseen.isNotEmpty) {
        statusNotice = unseen.first.status;
        statusNoticeNote = unseen.first.devNote;
      }
    } catch (_) {}
  }

  void _persistSentReports() {
    _prefs?.setString(LocalStore.crashReports, jsonEncode([for (final s in _sent) s.toJson()]));
  }
}

/// Route-change breadcrumbs. Routes get names via RouteSettings in nav.dart.
class CrashNavObserver extends NavigatorObserver {
  void _log(String verb, Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) CrashLog.instance.add('nav', '$verb $name');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _log('push', route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _log('pop', route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _log('replace', newRoute);
}
