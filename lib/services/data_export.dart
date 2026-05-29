import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';

/// Exports the full recipe book as a pretty-printed JSON file via the system
/// share sheet (a download on web). Round-trips with [AppState.importData].
Future<void> exportJsonShare(BuildContext context, AppState app) async {
  final json = const JsonEncoder.withIndent('  ').convert(app.exportData());
  final bytes = Uint8List.fromList(utf8.encode(json));
  final file = XFile.fromData(bytes, mimeType: 'application/json', name: 'facebouffe-livre.json');
  await Share.shareXFiles([file], fileNameOverrides: ['facebouffe-livre.json']);
}
