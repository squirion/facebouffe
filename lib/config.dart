// Deployment endpoints (GitHub Pages + Releases).
const String kVersionUrl = 'https://squirion.github.io/facebouffe/version.json';
const String kApkLatestUrl = 'https://github.com/squirion/facebouffe/releases/latest/download/facebouffe.apk';
// The release page (normal web page) — most reliable place to tap the APK from
// a mobile browser; avoids SPA-initiated downloads stalling on Android Chrome.
const String kReleasesPageUrl = 'https://github.com/squirion/facebouffe/releases/latest';
const String kWebAppUrl = 'https://squirion.github.io/facebouffe/';
