import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'web_notif_stub.dart' if (dart.library.js_interop) 'web_notif_web.dart' as webnotif;

/// OS-scheduled cooking-timer alerts. A timer's chime is a `zonedSchedule`d
/// local notification fired at an absolute wall-clock time on an alarm-usage
/// channel, so it survives backgrounding, screen-off and doze. The in-app tray
/// is only a visual mirror. All methods are no-ops on web (the iOS web app
/// falls back to the in-app visual countdown).
///
/// Two flavours: a soft "chime" (the system notification tone) or an "alarm"
/// (any of the phone's own alarm tones, chosen via the system picker). Because
/// a channel's sound is immutable, each distinct alarm URI gets its own channel.
class TimerNotifications {
  TimerNotifications._();
  static final TimerNotifications instance = TimerNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;

  static const String _chimeChannel = 'fb_timer_chime';
  static const String _alarmPrefix = 'fb_timer_alarm_';
  // The device's default alarm tone, used when the user hasn't picked a specific one.
  static const String defaultAlarmUri = 'content://settings/system/alarm_alert';
  final Set<String> _ensured = {};
  final Map<int, Timer> _webTimers = {}; // web: in-page timers → Web Notifications

  String _alarmChannelId(String? uri) => '$_alarmPrefix${(uri ?? 'default').hashCode}';

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

    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a != null) {
      // Retire channels from earlier builds (fixed alarm/ringtone options).
      for (final legacy in ['fb_cooking_timers', 'fb_timer_alarm', 'fb_timer_ringtone']) {
        await a.deleteNotificationChannel(channelId: legacy);
      }
      await a.createNotificationChannel(const AndroidNotificationChannel(
        _chimeChannel,
        'Minuterie · carillon',
        description: 'Sonne quand une minuterie de cuisson se termine.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm, // sounds while asleep / under DND
      ));
    }
    _ready = true;
  }

  /// Create the channel for a specific alarm URI (once), pruning stale ones.
  Future<void> _ensureAlarmChannel(String? uri) async {
    final id = _alarmChannelId(uri);
    if (_ensured.contains(id)) return;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (a == null) return;
    await a.createNotificationChannel(AndroidNotificationChannel(
      id,
      'Minuterie · alarme',
      description: 'Sonne quand une minuterie de cuisson se termine.',
      importance: Importance.max,
      playSound: true,
      sound: UriAndroidNotificationSound(uri ?? defaultAlarmUri),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    _ensured.add(id);
    // prune previously-created alarm channels that are no longer selected
    try {
      final existing = await a.getNotificationChannels() ?? [];
      for (final ch in existing) {
        if (ch.id.startsWith(_alarmPrefix) && ch.id != id) {
          await a.deleteNotificationChannel(channelId: ch.id);
        }
      }
    } catch (_) {}
  }

  /// Ask for POST_NOTIFICATIONS (Android 13+). Exact-alarm is auto-granted via
  /// the USE_EXACT_ALARM manifest permission, so no runtime request is needed.
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      await webnotif.requestWebNotif();
      return true;
    }
    await init();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestNotificationsPermission() ?? false;
  }

  Future<NotificationDetails> _details({required bool isAlarm, String? alarmUri}) async {
    if (isAlarm) {
      await _ensureAlarmChannel(alarmUri);
      return NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId(alarmUri),
          'Minuterie · alarme',
          channelDescription: 'Sonne quand une minuterie de cuisson se termine.',
          icon: 'ic_stat_timer',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          sound: UriAndroidNotificationSound(alarmUri ?? defaultAlarmUri),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _chimeChannel,
        'Minuterie · carillon',
        channelDescription: 'Sonne quand une minuterie de cuisson se termine.',
        icon: 'ic_stat_timer',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  Future<void> schedule(int id, int fireDelaySeconds, {required String title, required String body, required bool isAlarm, String? alarmUri}) async {
    if (fireDelaySeconds <= 0) return;
    if (kIsWeb) {
      // web: an in-page timer fires a Web Notification (foreground/tab-alive only)
      _webTimers.remove(id)?.cancel();
      _webTimers[id] = Timer(Duration(seconds: fireDelaySeconds), () {
        webnotif.showWebNotif(title, body);
        _webTimers.remove(id);
      });
      return;
    }
    await init(); // idempotent; guards against scheduling before init completes
    if (!_ready) return;
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: fireDelaySeconds));
    final details = await _details(isAlarm: isAlarm, alarmUri: alarmUri);
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

  /// Immediately post a sample notification so the user can hear a sound when
  /// choosing one in Settings. Auto-dismisses shortly after.
  Future<void> preview({required bool isAlarm, String? alarmUri, required String title, required String body}) async {
    if (kIsWeb) {
      await requestPermissions();
      webnotif.showWebNotif(title, body);
      return;
    }
    await requestPermissions();
    if (!_ready) return;
    final base = (await _details(isAlarm: isAlarm, alarmUri: alarmUri)).android!;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        base.channelId, base.channelName,
        channelDescription: base.channelDescription,
        icon: 'ic_stat_timer',
        importance: Importance.max, priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        sound: isAlarm ? UriAndroidNotificationSound(alarmUri ?? defaultAlarmUri) : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        timeoutAfter: 4000, // self-dismiss after 4s
      ),
    );
    await _plugin.show(id: 90001, title: title, body: body, notificationDetails: details);
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) {
      _webTimers.remove(id)?.cancel();
      return;
    }
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      for (final t in _webTimers.values) {
        t.cancel();
      }
      _webTimers.clear();
      return;
    }
    await _plugin.cancelAll();
  }
}
