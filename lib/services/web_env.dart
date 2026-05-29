// Web-only helpers (reload, user-agent, PWA-installed check). The IO stub keeps
// these no-ops on Android so shared code can call them unconditionally.
export 'web_env_io.dart' if (dart.library.js_interop) 'web_env_web.dart';
