import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../screens/import_sheet.dart';
import 'import_engine.dart';

/// "Partager vers Facebouffe" (§2f): receives a link/text or image shared from
/// another app and opens the same import review flow as the "+".
class ShareImport {
  static StreamSubscription<List<SharedMediaFile>>? _sub;
  static bool _started = false;

  /// Wire up once, with a context that lives under the Navigator (the shell).
  static void init(BuildContext context) {
    if (kIsWeb || _started) return;
    _started = true;
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then((list) {
        if (list.isNotEmpty && context.mounted) {
          _open(context, list);
          ReceiveSharingIntent.instance.reset();
        }
      });
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen((list) {
        if (list.isNotEmpty && context.mounted) _open(context, list);
      });
    } catch (_) {
      // plugin unavailable on this platform — ignore
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static Future<void> _open(BuildContext context, List<SharedMediaFile> list) async {
    final item = list.first;
    ImportMethod method;
    String? text;
    Uint8List? bytes;

    if (item.type == SharedMediaType.image || item.type == SharedMediaType.file) {
      method = ImportMethod.photo;
      try {
        bytes = await File(item.path).readAsBytes();
      } catch (_) {
        return;
      }
    } else {
      // text or url — the shared string is in `path`
      final value = item.path.trim();
      if (value.isEmpty) return;
      final uri = Uri.tryParse(value);
      final isUrl = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      method = isUrl ? ImportMethod.link : ImportMethod.text;
      text = value;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showImportSheet(context, startMethod: method, sharedText: text, sharedImage: bytes);
    });
  }
}
