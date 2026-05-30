import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../services/cnf.dart';
import '../services/import/byok_client.dart';
import '../services/import/ondevice_ai.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import '../widgets/nutrition.dart';
import 'settings_screen.dart' show SettingsGroup, TagManager;

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          FbHeader(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
                const SizedBox(width: 4),
                Text(app.t('advanced'), style: fb.display(size: 25, weight: FontWeight.w600)),
              ]),
            ),
          ),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                SettingsGroup(label: app.t('custom_tags'), children: const [TagManager()]),
                SettingsGroup(label: app.t('aliases_title'), children: const [AliasManager()]),
                SettingsGroup(label: app.t('import_group'), children: const [ImportSettings()]),
                SettingsGroup(label: app.t('ondevice_model'), children: const [OnDeviceModelManager()]),
                SettingsGroup(label: app.t('api_keys'), children: const [ApiKeyManager()]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings editor for the learned ingredient → CNF food alias table.
class AliasManager extends StatefulWidget {
  const AliasManager({super.key});
  @override
  State<AliasManager> createState() => _AliasManagerState();
}

class _AliasManagerState extends State<AliasManager> {
  String? editKey;
  bool remember = true;

  @override
  void initState() {
    super.initState();
    Cnf.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final entries = app.aliases.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: entries.isNotEmpty ? BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))) : null,
          child: Text(app.t('aliases_hint'), style: fb.ui(size: 12.5, color: fb.inkFaint, height: 1.45)),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text(app.t('aliases_empty'), style: fb.ui(size: 13.5, color: fb.inkFaint, height: 1.5)),
          ),
        for (int i = 0; i < entries.length; i++)
          Container(
            decoration: i < entries.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))) : null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon('leaf', size: 15, color: fb.accent))),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(entries[i].key, style: fb.ui(size: 15, weight: FontWeight.w600)),
                        Text('→ ${Cnf.instance.cnfName(entries[i].value, app.lang)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12.5, color: fb.inkSoft)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() { editKey = editKey == entries[i].key ? null : entries[i].key; remember = true; }), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('pencil', size: 16, color: fb.inkSoft)))),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => app.removeAlias(entries[i].key), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('trash', size: 16, color: fb.inkSoft)))),
                  ]),
                ),
                if (editKey == entries[i].key)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: CnfPicker(
                      ingredientName: entries[i].key,
                      remember: remember,
                      setRemember: (v) => setState(() => remember = v),
                      onPick: (food) { app.addAlias(entries[i].key, food.code); setState(() => editKey = null); },
                      onClose: () => setState(() => editKey = null),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Settings — default import engine (tier radio). Configuration only; the
/// import action lives on the "+". A tier is disabled (with a reason) when the
/// device/keys can't run it.
class ImportSettings extends StatelessWidget {
  const ImportSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final tiers = [
      ('tier0', app.t('import_tier0'), app.t('import_tier0_sub'), null),
      ('ondevice', app.t('import_ondevice'), app.t('import_ondevice_sub'), app.onDeviceAI ? null : app.t('ondevice_unsupported')),
      ('byok', app.t('import_byok'), app.t('import_byok_sub'), app.hasAnyImportKey ? null : app.t('byok_disabled')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text(app.t('default_import_engine').toUpperCase(), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4))),
        for (final t in tiers) _tierRow(context, fb, app, t.$1, t.$2, t.$3, t.$4),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: FbIcon('note', size: 15, color: fb.inkFaint)),
            const SizedBox(width: 9),
            Expanded(child: Text(app.t('import_privacy'), style: fb.ui(size: 12, color: fb.inkFaint, height: 1.5))),
          ]),
        ),
      ],
    );
  }

  Widget _tierRow(BuildContext context, FbTheme fb, AppState app, String key, String title, String sub, String? reason) {
    final disabled = reason != null;
    final on = app.importBackend == key && !disabled;
    return GestureDetector(
      onTap: disabled ? null : () => app.setImportBackend(key),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 22, height: 22, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? fb.accent : fb.lineStrong, width: 2), color: on ? fb.accent : Colors.transparent), child: on ? const Center(child: FbIcon('check', size: 12, color: Colors.white)) : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: fb.ui(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: fb.ui(size: 12.5, color: fb.inkSoft, height: 1.4)),
                if (disabled) Padding(padding: const EdgeInsets.only(top: 5), child: Text(reason, style: fb.ui(size: 12, weight: FontWeight.w600, color: const Color(0xFF9A6C1E), height: 1.4))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Settings — per-provider BYOK key (select provider, paste/test/delete).
/// Keys live in the OS keystore; only sent to the chosen provider.
class ApiKeyManager extends StatefulWidget {
  const ApiKeyManager({super.key});
  @override
  State<ApiKeyManager> createState() => _ApiKeyManagerState();
}

class _ApiKeyManagerState extends State<ApiKeyManager> {
  static const _providers = [('claude', 'Claude'), ('openai', 'ChatGPT'), ('gemini', 'Gemini')];
  final _controller = TextEditingController();
  String _provider = 'claude';
  String? _test; // testing | valid | invalid | empty
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppState>().importProvider;
    _controller.text = context.read<AppState>().importKeys[_provider] ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectProvider(String p) {
    final app = context.read<AppState>();
    app.setImportProvider(p);
    setState(() {
      _provider = p;
      _controller.text = app.importKeys[p] ?? '';
      _test = null;
    });
  }

  Future<void> _runTest() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _test = 'empty');
      return;
    }
    setState(() => _test = 'testing');
    final ok = await ByokClient.testKey(_provider, key);
    if (mounted) setState(() => _test = ok ? 'valid' : 'invalid');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final hasKey = _controller.text.trim().isNotEmpty;

    final statusColor = {
      'testing': fb.inkSoft,
      'valid': const Color(0xFF4F7D4C),
      'invalid': const Color(0xFFC0563B),
      'empty': const Color(0xFF9A6C1E),
    }[_test];
    final statusLabel = {
      'testing': app.t('key_testing'),
      'valid': app.t('key_valid'),
      'invalid': app.t('key_invalid'),
      'empty': app.t('key_empty'),
    }[_test];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text(app.t('provider').toUpperCase(), style: fb.ui(size: 11.5, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: fb.dark ? Colors.white.withValues(alpha: 0.06) : fb.canvas2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              for (final p in _providers)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectProvider(p.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(color: _provider == p.$1 ? fb.card : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: _provider == p.$1 ? fb.shadow : null),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(p.$2, style: fb.ui(size: 13.5, weight: _provider == p.$1 ? FontWeight.w700 : FontWeight.w600, color: _provider == p.$1 ? fb.ink : fb.inkSoft)),
                        if (app.importKeyFor(p.$1)) ...[const SizedBox(width: 5), Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6BA368), shape: BoxShape.circle))],
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: fb.canvas2, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
            child: Row(children: [
              FbIcon('link', size: 16, color: fb.inkFaint),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _controller, obscureText: _obscure, onChanged: (v) { context.read<AppState>().setImportKey(_provider, v); setState(() => _test = null); }, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 1), decoration: InputDecoration.collapsed(hintText: app.t('import_key_ph'), hintStyle: fb.ui(size: 14, color: fb.inkFaint)))),
              GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: FbIcon(_obscure ? 'note' : 'check', size: 16, color: fb.inkFaint)),
            ]),
          ),
        ),
        if (statusLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
            child: Row(children: [
              _test == 'testing'
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: statusColor))
                  : FbIcon(_test == 'valid' ? 'check' : 'note', size: 14, color: statusColor),
              const SizedBox(width: 7),
              Text(statusLabel, style: fb.ui(size: 12.5, weight: FontWeight.w600, color: statusColor)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _test == 'testing' ? null : _runTest,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(11)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const FbIcon('check', size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(app.t('test_key'), style: fb.ui(size: 14, weight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: hasKey ? () { context.read<AppState>().setImportKey(_provider, ''); _controller.clear(); setState(() => _test = null); } : null,
              child: Opacity(
                opacity: hasKey ? 1 : 0.5,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: fb.line)),
                  child: Row(children: [
                    FbIcon('trash', size: 16, color: hasKey ? const Color(0xFFC0563B) : fb.inkFaint),
                    const SizedBox(width: 7),
                    Text(app.t('delete_key'), style: fb.ui(size: 14, weight: FontWeight.w700, color: hasKey ? const Color(0xFFC0563B) : fb.inkFaint)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Settings — manage the local Tier 1 model (MediaPipe Gemma .task): import a
/// file, download from a URL with progress, or delete. Everything stays local.
class OnDeviceModelManager extends StatefulWidget {
  const OnDeviceModelManager({super.key});
  @override
  State<OnDeviceModelManager> createState() => _OnDeviceModelManagerState();
}

class _OnDeviceModelManagerState extends State<OnDeviceModelManager> {
  final _urlController = TextEditingController();
  bool _busy = false;
  String _busyLabel = '';
  double? _progress; // 0..1 during download
  int _sizeBytes = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _refreshSize() async {
    final s = await OnDeviceAi.modelSizeBytes();
    if (mounted) setState(() => _sizeBytes = s);
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  Future<void> _importFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() { _busy = true; _busyLabel = context.read<AppState>().t('ondevice_importing'); _progress = null; _error = null; });
    try {
      await OnDeviceAi.importModelFromFile(path);
      if (mounted) await context.read<AppState>().refreshOnDevice();
      await _refreshSize();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final app = context.read<AppState>();
    setState(() { _busy = true; _busyLabel = app.t('ondevice_downloading'); _progress = 0; _error = null; });
    try {
      await OnDeviceAi.downloadModel(url, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) await context.read<AppState>().refreshOnDevice();
      await _refreshSize();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _delete() async {
    await OnDeviceAi.deleteModel();
    if (mounted) await context.read<AppState>().refreshOnDevice();
    await _refreshSize();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final loaded = app.onDeviceAI && _sizeBytes > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // status
          Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: loaded ? const Color(0x1F6BA368) : fb.line, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon(loaded ? 'check' : 'note', size: 16, color: loaded ? const Color(0xFF4F7D4C) : fb.inkFaint))),
            const SizedBox(width: 11),
            Expanded(child: Text(loaded ? '${app.t('ondevice_model_loaded')} · ${_fmtSize(_sizeBytes)}' : app.t('ondevice_model_none'), style: fb.ui(size: 14.5, weight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Text(app.t('ondevice_model_hint'), style: fb.ui(size: 12, color: fb.inkFaint, height: 1.45)),
          const SizedBox(height: 12),
          if (_busy) ...[
            Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fb.accent, value: _progress)),
              const SizedBox(width: 10),
              Text(_progress != null ? '$_busyLabel ${(_progress! * 100).round()}%' : _busyLabel, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.inkSoft)),
            ]),
          ] else if (loaded) ...[
            GestureDetector(
              onTap: _delete,
              child: Container(
                height: 42,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: fb.line)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const FbIcon('trash', size: 16, color: Color(0xFFC0563B)),
                  const SizedBox(width: 7),
                  Text(app.t('ondevice_delete_model'), style: fb.ui(size: 14, weight: FontWeight.w700, color: const Color(0xFFC0563B))),
                ]),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _importFile,
              child: Container(
                height: 44,
                decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const FbIcon('plus', size: 17, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(app.t('ondevice_import_file'), style: fb.ui(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: fb.canvas2, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
              child: Row(children: [
                FbIcon('link', size: 16, color: fb.inkFaint),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _urlController, keyboardType: TextInputType.url, onChanged: (_) => setState(() {}), style: fb.ui(size: 13.5), decoration: InputDecoration.collapsed(hintText: app.t('ondevice_url_ph'), hintStyle: fb.ui(size: 13.5, color: fb.inkFaint)))),
                if (_urlController.text.trim().isNotEmpty)
                  GestureDetector(onTap: _download, child: Padding(padding: const EdgeInsets.only(left: 6), child: Text(app.t('ondevice_download'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)))),
              ]),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(fontFamily: 'monospace', fontSize: fb.fs(11.5), color: const Color(0xFF9C3F29), height: 1.4)),
            ),
        ],
      ),
    );
  }
}
