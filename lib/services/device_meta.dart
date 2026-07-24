import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'web_env.dart';

/// Device metadata attached to crash reports so a report can say "Samsung A14,
/// Android 13" instead of nothing. Best-effort: falls back to coarse
/// Platform fields rather than failing.
Future<({String platform, String osVersion, String deviceModel})> deviceMeta() async {
  if (kIsWeb) {
    final ua = webUserAgent();
    return (platform: 'web', osVersion: '', deviceModel: ua.substring(0, math.min(200, ua.length)));
  }
  try {
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      return (
        platform: 'android',
        osVersion: 'Android ${a.version.release} (SDK ${a.version.sdkInt})',
        deviceModel: '${a.manufacturer} ${a.model}',
      );
    }
    if (Platform.isIOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      return (platform: 'ios', osVersion: '${i.systemName} ${i.systemVersion}', deviceModel: i.utsname.machine);
    }
  } catch (_) {}
  return (platform: Platform.operatingSystem, osVersion: Platform.operatingSystemVersion, deviceModel: '');
}
