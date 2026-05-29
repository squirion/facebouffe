import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// OS-scheduled cooking-timer alerts. A timer's chime is a `zonedSchedule`d
/// local notification fired at an absolute wall-clock time on the alarm audio
/// channel, so it survives backgrounding, screen-off and doze. The in-app tray
/// is only a visual mirror. All methods are no-ops on web (the iOS web app
/// falls back to the in-app visual countdown).
class TimerNotifications {
  TimerNotifications._();
  static final TimerNotifications instance = TimerNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;
  static const String _channelId = 'fb_cooking_timers';
  static const String _channelName = 'Minuteries / Cooking timers';

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
    await android13?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Sonne quand une minuterie de cuisson se termine.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm, // sounds while asleep / under DND
    ));
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

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Sonne quand une minuterie de cuisson se termine.',
      icon: 'ic_stat_timer',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
  );

  Future<void> schedule(int id, int fireDelaySeconds, {required String title, required String body}) async {
    if (kIsWeb || fireDelaySeconds <= 0) return;
    await init(); // idempotent; guards against scheduling before init completes
    if (!_ready) return;
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: fireDelaySeconds));
    try {
      await _plugin.zonedSchedule(
        id: id, title: title, body: body, scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[TimerNotifications] exact schedule failed ($e); retrying inexact');
      try {
        await _plugin.zonedSchedule(
          id: id, title: title, body: body, scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('[TimerNotifications] inexact schedule also failed: $e2');
      }
    }
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
