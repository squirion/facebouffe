// Native (Android/iOS) implementation of [printRecipeHtml]: render the HTML in a
// headless system WebView (Chromium on Android), wait for the embedded paginator
// to finish (fonts + images settled), then open the OS print framework — the
// familiar dialog with paper size + "Save as PDF". The WebView's Chromium engine
// reproduces the mockup's CSS/pagination exactly.
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> printRecipeHtml(String html, {required String docName}) async {
  final ready = Completer<void>();
  InAppWebViewController? controller;

  final headless = HeadlessInAppWebView(
    initialData: InAppWebViewInitialData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf8',
      baseUrl: WebUri('about:blank'),
    ),
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      supportZoom: false,
    ),
    onWebViewCreated: (c) {
      controller = c;
      // The paginator calls this once layout + fonts + images have settled.
      c.addJavaScriptHandler(
        handlerName: 'layoutDone',
        callback: (args) {
          if (!ready.isCompleted) ready.complete();
          return null;
        },
      );
    },
    onConsoleMessage: (c, msg) => debugPrint('[recipe-pdf] ${msg.message}'),
  );

  await headless.run();

  // Wait for the readiness signal, but never hang the export if it never arrives.
  try {
    await ready.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    debugPrint('[recipe-pdf] readiness timeout — printing current state');
  }

  try {
    await controller?.printCurrentPage(
      settings: PrintJobSettings(jobName: docName),
    );
  } finally {
    // Keep the WebView alive briefly so the print adapter can render its pages,
    // then tear it down. (printCurrentPage may return before the OS finishes.)
    Future.delayed(const Duration(seconds: 30), headless.dispose);
  }
}
