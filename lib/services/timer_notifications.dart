import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A selectable timer chime. Each maps to its own notification channel because
/// a channel's sound is immutable once created — switching the user's choice
/// switches channels rather than mutating one. All play through the alarm
/// stream (loud, DND-bypassing) so timers are heard while the phone sleeps.
class ChimeSound {
  final String key;
  final String channelId;
  final AndroidNotificationSound? sound; // null => channel default notification sound
  const ChimeSound(this.key, this.channelId, this.sound);
}

/// OS-scheduled cooking-timer alerts. A timer's chime is a `zonedSchedule`d
/// local notification fired at an absolute wall-clock time on an alarm-usage
/// channel, so it survives backgrounding, screen-off and doze. The in-app tray
/// is only a visual mirror. All methods are no-ops on web (the iOS web app
/// falls back to the in-app visual countdown).
class TimerNotifications {
  TimerNotifications._();
  static final TimerNotifications instance = TimerNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;

  // Selectable chimes. 'alarm' (the device alarm tone) is the loud default;
  // 'ringtone' is the phone ringtone; 'chime' is the gentle notification tone.
  static const List<ChimeSound> sounds = [
    ChimeSound('alarm', 'fb_timer_alarm', UriAndroidNotificationSound('content://settings/system/alarm_alert')),
    ChimeSound('ringtone', 'fb_timer_ringtone', UriAndroidNotificationSound('content://settings/system/ringtone')),
    ChimeSound('chime', 'fb_timer_chime', null),
  ];
  static const String defaultSound = 'alarm';

  ChimeSound _soundFor(String key) =>
      sounds.firstWhere((s) => s.key == key, orElse: () => sounds.first);

  /// Idempotent and concurrency-safe: the body runs at most once.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC')); // degraded fallback, never crash
    }
    const android = AndroidInitializationSettings('ic_stat_timer');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: darwin));

    final android13 = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android13 != null) {
      // Retire the old single channel from earlier builds.
      await android13.deleteNotificationChannel(channelId: 'fb_cooking_timers');
      for (final s in sounds) {
        await android13.createNotificationChannel(AndroidNotificationChannel(
          s.channelId,
          'Minuterie · ${s.key}',
          description: 'Sonne quand une minuterie de cuisson se termine.',
          importance: Importance.max,
          playSound: true,
          sound: s.sound,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm, // sounds while asleep / under DND
        ));
      }
    }
    _ready = true;
  }

  /// Ask for POST_NOTIFICATIONS (Android 13+). Exact-alarm is auto-granted via
  /// the USE_EXACT_ALARM manifest permission, so no runtime request is needed.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await init();
    final android13 = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android13?.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _details(String soundKey) {
    final s = _soundFor(soundKey);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        s.channelId,
        'Minuterie · ${s.key}',
        channelDescription: 'Sonne quand une minuterie de cuisson se termine.',
        icon: 'ic_stat_timer',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        sound: s.sound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  Future<void> schedule(int id, int fireDelaySeconds, {required String title, required String body, String soundKey = defaultSound}) async {
    if (kIsWeb || fireDelaySeconds <= 0) return;
    await init(); // idempotent; guards against scheduling before init completes
    if (!_ready) return;
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: fireDelaySeconds));
    final details = _details(soundKey);
    try {
      await _plugin.zonedSchedule(
        id: id, title: title, body: body, scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[TimerNotifications] exact schedule failed ($e); retrying inexact');
      try {
        await _plugin.zonedSchedule(
          id: id, title: title, body: body, scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('[TimerNotifications] inexact schedule also failed: $e2');
      }
    }
  }

  /// Immediately post a sample notification so the user can hear a chime when
  /// choosing one in Settings. Auto-dismisses shortly after.
  Future<void> preview(String soundKey, {required String title, required String body}) async {
    if (kIsWeb) return;
    await requestPermissions();
    if (!_ready) return;
    final base = _details(soundKey).android!;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        base.channelId, base.channelName,
        channelDescription: base.channelDescription,
        icon: 'ic_stat_timer',
        importance: Importance.max, priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        sound: _soundFor(soundKey).sound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        timeoutAfter: 4000, // self-dismiss after 4s
      ),
    );
    await _plugin.show(id: 90001, title: title, body: body, notificationDetails: details);
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
