// Minimal static file server for build/web (dev verification only).
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args[0] : 'build/web';
  final port = args.length > 1 ? int.parse(args[1]) : 8011;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('serving $root on http://localhost:$port');
  const types = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.css': 'text/css',
    '.png': 'image/png',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.bin': 'application/octet-stream',
    '.symbols': 'application/octet-stream',
  };
  await for (final req in server) {
    var path = req.uri.path;
    if (path == '/') path = '/index.html';
    final file = File('$root$path');
    if (await file.exists()) {
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
      req.response.headers.contentType = ContentType.parse(types[ext] ?? 'application/octet-stream');
      await req.response.addStream(file.openRead());
    } else {
      req.response.statusCode = 404;
    }
    await req.response.close();
  }
}
