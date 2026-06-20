// Web implementation of [printRecipeHtml]: drop the self-contained HTML into a
// hidden same-origin iframe (srcdoc), wait for the embedded paginator to signal
// readiness (postMessage), then call the iframe's window.print() — the browser's
// own print-to-PDF, which renders the mockup's CSS/pagination natively.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> printRecipeHtml(String html, {required String docName}) async {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.style
    ..position = 'fixed'
    ..left = '-10000px'
    ..top = '0'
    ..width = '0'
    ..height = '0'
    ..border = '0';
  iframe.setAttribute('aria-hidden', 'true');

  final ready = Completer<void>();
  void onMessage(web.Event e) {
    final data = (e as web.MessageEvent).data;
    if (data != null && data.isA<JSString>() && (data as JSString).toDart == 'fb-pdf-ready') {
      if (!ready.isCompleted) ready.complete();
    }
  }

  final jsOnMessage = onMessage.toJS;
  web.window.addEventListener('message', jsOnMessage);

  iframe.srcdoc = html.toJS;
  web.document.body!.appendChild(iframe);

  // Wait for layout + fonts + images to settle, but never hang.
  try {
    await ready.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    // fall through and print whatever has rendered
  }

  try {
    iframe.contentWindow?.focus();
    iframe.contentWindow?.print();
  } catch (_) {}

  web.window.removeEventListener('message', jsOnMessage);
  // Remove the iframe once the dialog has had time to capture the content.
  Future.delayed(const Duration(seconds: 2), () {
    try {
      iframe.remove();
    } catch (_) {}
  });
}
