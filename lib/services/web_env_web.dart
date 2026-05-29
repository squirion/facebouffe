import 'package:web/web.dart' as web;

void reloadApp() => web.window.location.reload();

String webUserAgent() => web.window.navigator.userAgent;

/// True when the page is running as an installed PWA (standalone display mode,
/// or iOS Safari's legacy navigator.standalone).
bool isStandalonePwa() {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  } catch (_) {}
  return false;
}
