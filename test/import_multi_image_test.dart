// resolveChain's multi-image gate: multi-image is cloud-only (the on-device
// engine has no vision), so 'ondevice' must be excluded when multiImage is true.
import 'package:flutter_test/flutter_test.dart';

import 'package:facebouffe/services/import/import_engine.dart';
import 'package:facebouffe/state/app_state.dart';

void main() {
  test('multi-image excludes the on-device engine (cloud-only)', () {
    final app = AppState()
      ..preferredAI = 'ondevice'
      ..onDeviceAI = true
      ..online = true
      ..importKeys = {'claude': 'k'};

    // Single image: on-device preferred first, online as fallback.
    expect(ImportEngine.resolveChain(ImportMethod.photo, app), ['ondevice', 'online']);
    // Multiple images: cloud only.
    expect(ImportEngine.resolveChain(ImportMethod.photo, app, multiImage: true), ['online']);
  });

  test('multi-image with no cloud key is blocked (empty chain)', () {
    final app = AppState()
      ..preferredAI = 'ondevice'
      ..onDeviceAI = true
      ..online = true
      ..importKeys = {}; // no cloud key

    expect(ImportEngine.resolveChain(ImportMethod.photo, app, multiImage: true), isEmpty);
    // …but a single image still works on-device.
    expect(ImportEngine.resolveChain(ImportMethod.photo, app), ['ondevice']);
  });
}
