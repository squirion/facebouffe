// ignore_for_file: avoid_print — this IS a console tool.
//
// Dev CLI for the crash_reports table. Reads the SERVICE-ROLE key (bypasses
// RLS) from <repo-root>/.env — see .env.example. Never ship or commit that key.
//
//   dart run tool/crash_reports.dart list [--status new] [--limit 20]
//   dart run tool/crash_reports.dart show <id>
//   dart run tool/crash_reports.dart set-status <id> <status> [--note "..."]
//
// Statuses by convention: new | investigating | fixed | closed. `set-status`
// (with --note) is what lights up the "your report was updated" banner in the
// reporter's app on their next launch.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultUrl = 'https://ubzjhklkpxcbrghfmjdd.supabase.co';
const _listCols = 'id,created_at,username,app_version,build,platform,device_model,kind,status';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    exit(1);
  }
  final env = _loadEnv();
  final url = env['SUPABASE_URL'] ?? _defaultUrl;
  final key = env['SUPABASE_SERVICE_ROLE_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('Missing SUPABASE_SERVICE_ROLE_KEY in .env (see .env.example).');
    stderr.writeln('Get it from the Supabase dashboard → Project Settings → API keys.');
    exit(1);
  }
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
  };

  switch (args.first) {
    case 'list':
      final status = _flag(args, '--status');
      final limit = int.tryParse(_flag(args, '--limit') ?? '') ?? 25;
      var q = '$url/rest/v1/crash_reports?select=$_listCols&order=created_at.desc&limit=$limit';
      if (status != null) q += '&status=eq.${Uri.encodeComponent(status)}';
      final rows = await _getJson(q, headers);
      if (rows.isEmpty) {
        print('No reports${status != null ? ' with status "$status"' : ''}.');
        return;
      }
      print(_pad(['ID', 'DATE', 'USER', 'VERSION', 'PLATFORM', 'DEVICE', 'KIND', 'STATUS']));
      for (final r in rows) {
        print(_pad([
          (r['id'] as String).substring(0, 8),
          (r['created_at'] as String? ?? '').substring(0, 16).replaceFirst('T', ' '),
          r['username'] as String? ?? '(anon)',
          '${r['app_version']}+${r['build']}',
          r['platform'] as String? ?? '',
          r['device_model'] as String? ?? '',
          r['kind'] as String? ?? '',
          r['status'] as String? ?? '',
        ]));
      }

    case 'show':
      final id = _requireId(args);
      final rows = await _getJson('$url/rest/v1/crash_reports?select=*&id=like.$id*', headers);
      if (rows.isEmpty) {
        stderr.writeln('No report matching id "$id".');
        exit(1);
      }
      final r = rows.first;
      for (final k in ['id', 'created_at', 'updated_at', 'user_id', 'username', 'app_version', 'build', 'platform', 'os_version', 'device_model', 'kind', 'status', 'dev_note', 'notes']) {
        print('${k.padRight(13)} ${r[k] ?? ''}');
      }
      print('--- log ---');
      final log = r['log'] as String? ?? '';
      // Stored as a JSON list of breadcrumb strings; print one per line.
      try {
        for (final line in (jsonDecode(log) as List)) {
          print(line);
        }
      } catch (_) {
        print(log);
      }

    case 'set-status':
      final id = _requireId(args);
      if (args.length < 3) {
        stderr.writeln('Usage: set-status <id> <status> [--note "..."]');
        exit(1);
      }
      final body = <String, Object?>{'status': args[2]};
      final note = _flag(args, '--note');
      if (note != null) body['dev_note'] = note;
      final res = await http.patch(
        Uri.parse('$url/rest/v1/crash_reports?id=like.$id*'),
        headers: {...headers, 'Prefer': 'return=representation'},
        body: jsonEncode(body),
      );
      _check(res);
      final rows = jsonDecode(res.body) as List;
      if (rows.isEmpty) {
        stderr.writeln('No report matching id "$id".');
        exit(1);
      }
      final r = rows.first as Map;
      print('Updated ${(r['id'] as String).substring(0, 8)} → status=${r['status']}${r['dev_note'] != null ? ' note="${r['dev_note']}"' : ''}');

    default:
      _usage();
      exit(1);
  }
}

void _usage() {
  print('Usage: dart run tool/crash_reports.dart <command>');
  print('  list [--status <s>] [--limit <n>]   newest reports');
  print('  show <id>                            full report incl. log (8-char id prefix OK)');
  print('  set-status <id> <status> [--note s]  answer a report (new|investigating|fixed|closed)');
}

String _requireId(List<String> args) {
  if (args.length < 2 || args[1].startsWith('--')) {
    stderr.writeln('Missing <id> argument.');
    exit(1);
  }
  final id = args[1].toLowerCase();
  if (!RegExp(r'^[0-9a-f-]{4,36}$').hasMatch(id)) {
    stderr.writeln('"$id" does not look like a report id.');
    exit(1);
  }
  return id;
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

Map<String, String> _loadEnv() {
  final out = <String, String>{};
  final f = File('.env');
  if (!f.existsSync()) return out;
  for (final raw in f.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var v = line.substring(eq + 1).trim();
    final hash = v.indexOf(' #');
    if (hash >= 0) v = v.substring(0, hash).trim();
    out[line.substring(0, eq).trim()] = v;
  }
  return out;
}

Future<List<dynamic>> _getJson(String url, Map<String, String> headers) async {
  final res = await http.get(Uri.parse(url), headers: headers);
  _check(res);
  return jsonDecode(res.body) as List;
}

void _check(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  stderr.writeln('HTTP ${res.statusCode}: ${res.body}');
  exit(1);
}

String _pad(List<String> cells) {
  const widths = [9, 17, 14, 11, 9, 22, 7, 14];
  final b = StringBuffer();
  for (var i = 0; i < cells.length; i++) {
    final w = i < widths.length ? widths[i] : 12;
    final c = cells[i].length > w - 1 ? cells[i].substring(0, w - 1) : cells[i];
    b.write(c.padRight(w));
  }
  return b.toString();
}
