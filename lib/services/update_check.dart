import 'dart:convert';
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
  static Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;
      final url = '$kVersionUrl?t=${DateTime.now().millisecondsSinceEpoch}'; // bust CDN cache
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteBuild = (j['build'] as num?)?.toInt() ?? 0;
      if (remoteBuild <= localBuild) return null;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('fb_update_dismissed') == remoteBuild) return null; // dismissed this version
      return UpdateInfo(j['version'] as String? ?? '', remoteBuild, j['apk'] as String? ?? kApkLatestUrl);
    } catch (_) {
      return null; // offline / not yet deployed — no banner
    }
  }

  static Future<void> dismiss(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fb_update_dismissed', build);
  }
}
