import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// A picked alarm sound: its content URI and a human-readable title.
class PickedAlarm {
  final String? uri; // null = the system default alarm
  final String? title;
  const PickedAlarm(this.uri, this.title);
}

/// Opens the device's system ALARM ringtone picker (alarm tones only).
class RingtonePicker {
  static const _channel = MethodChannel('facebouffe/ringtone');

  /// Returns the chosen alarm, or null if cancelled / unavailable.
  static Future<PickedAlarm?> pickAlarm({String? current, String title = 'Alarme'}) async {
    if (kIsWeb) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pickAlarm', {'current': current, 'title': title});
      if (res == null) return null;
      return PickedAlarm(res['uri'] as String?, res['title'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Resolve the display title of a URI (or the default alarm when null).
  static Future<String?> titleFor(String? uri) async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('ringtoneTitle', {'uri': uri});
    } catch (_) {
      return null;
    }
  }
}
