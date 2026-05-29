import 'package:web/web.dart' as web;

void reloadApp() => web.window.location.reload();

/// Top-level navigation to [url]. For a server response with
/// Content-Disposition: attachment (our APK), the browser downloads it and
/// stays on the page — the same reliable path as typing the URL in the address
/// bar (unlike window.open popups, which can stall on Android Chrome).
void webDownload(String url) => web.window.location.assign(url);

String webUserAgent() => web.window.navigator.userAgent;

/// True when the page is running as an installed PWA (standalone display mode,
/// or iOS Safari's legacy navigator.standalone).
bool isStandalonePwa() {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  } catch (_) {}
  return false;
}
