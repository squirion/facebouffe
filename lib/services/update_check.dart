import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  const UpdateInfo(this.version, this.build, this.apkUrl);
}

/// Checks the deployed version.json against the running build and reports when a
/// newer version is available (so sideloaded Android / web users can update).
class UpdateCheck {
  /// Returns update info if a newer build is deployed. [ignoreDismissed] is used
  /// by the manual "check for updates" action so a dismissed version still shows.
  /// Throws on network/parse failure when [throwOnError] (for manual checks).
  static Future<UpdateInfo?> check({bool ignoreDismissed = false, bool throwOnError = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;
      final url = '$kVersionUrl?t=${DateTime.now().millisecondsSinceEpoch}'; // bust CDN cache
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        if (throwOnError) throw Exception('HTTP ${res.statusCode}');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteBuild = (j['build'] as num?)?.toInt() ?? 0;
      if (remoteBuild <= localBuild) return null;
      if (!ignoreDismissed) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getInt('fb_update_dismissed') == remoteBuild) return null; // dismissed this version
      }
      final apkUrl = j['apk'] as String? ?? kApkLatestUrl;
      // On Android, only advertise once the APK is actually downloadable — the
      // version.json (which drives this) deploys before the slower APK release
      // job finishes, so the versioned APK URL 404s during that window.
      if (!kIsWeb && apkUrl.isNotEmpty) {
        try {
          final head = await http.head(Uri.parse(apkUrl)).timeout(const Duration(seconds: 8));
          if (head.statusCode != 200) {
            if (throwOnError) throw Exception('APK not published yet (HTTP ${head.statusCode})');
            return null;
          }
        } catch (e) {
          if (throwOnError) rethrow;
          return null; // not reachable yet — don't advertise
        }
      }
      return UpdateInfo(j['version'] as String? ?? '', remoteBuild, apkUrl);
    } catch (e) {
      if (throwOnError) rethrow;
      return null; // offline / not yet deployed — no banner
    }
  }

  static Future<void> dismiss(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fb_update_dismissed', build);
  }
}
