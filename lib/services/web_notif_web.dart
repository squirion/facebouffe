// Web implementation of timer alerts via the browser Notifications API.
// Foreground/tab-alive only (browsers can't fire while the tab is closed).
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> requestWebNotif() async {
  try {
    await web.Notification.requestPermission().toDart;
  } catch (_) {}
}

void showWebNotif(String title, String body) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(title, web.NotificationOptions(body: body));
    }
  } catch (_) {}
}
