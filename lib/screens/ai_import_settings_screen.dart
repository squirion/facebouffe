import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../services/import/byok_client.dart';
import '../services/import/ondevice_ai.dart';
import '../widgets/chrome.dart';
import '../widgets/coach.dart';
import '../widgets/fb_icon.dart';
import 'settings_screen.dart' show SettingsGroup;

/// Settings → AI Import Assistant: configure the optional AI engines used by the
/// import "+" — the on-device model (Tier 1), the BYOK API keys (Tier 2), and
/// which one to prefer when an AI is needed. (Tier 0, the link parser, always
/// ships and isn't a choice, so it doesn't appear here.)
class AIImportAssistantScreen extends StatelessWidget {
  const AIImportAssistantScreen({super.key});

  // First unseen coach mark on this page (keys, then preferred-AI).
  String? _activeTip(AppState app) {
    if (!app.tipsSeen.apiKeys) return 'apiKeys';
    if (!app.tipsSeen.preferredAi) return 'preferredAi';
    return null;
  }

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
                Expanded(child: Text(app.t('ai_import_title'), style: fb.display(size: 25, weight: FontWeight.w600))),
              ]),
            ),
          ),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                // on-device model + preferred-AI are native-only (web has no
                // on-device model; online API is the only/always-preferred engine)
                if (!kIsWeb) SettingsGroup(label: app.t('ondevice_model'), children: const [OnDeviceModelManager()]),
                Coach(
                  feature: 'apiKeys',
                  active: _activeTip(app) == 'apiKeys',
                  text: app.t('coach_apikeys'),
                  below: true,
                  child: SettingsGroup(label: app.t('api_keys'), children: const [ApiKeyManager()]),
                ),
                if (!kIsWeb)
                  Coach(
                    feature: 'preferredAi',
                    active: _activeTip(app) == 'preferredAi',
                    text: app.t('coach_preferred_ai'),
                    below: true,
                    child: SettingsGroup(label: app.t('preferred_ai'), children: const [PreferredAiSelector()]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Radio choice of which AI to prefer when an engine is needed: the online API
/// (Tier 2) or the on-device model (Tier 1). Each is disabled until configured.
class PreferredAiSelector extends StatelessWidget {
  const PreferredAiSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, fb, app, 'online', app.t('ai_online'), app.t('ai_online_sub'), app.hasAnyImportKey ? null : app.t('ai_online_disabled')),
        _row(context, fb, app, 'ondevice', app.t('import_ondevice'), app.t('ai_ondevice_sub'), app.onDeviceAI ? null : app.t('ai_ondevice_disabled')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: FbIcon('note', size: 15, color: fb.inkFaint)),
            const SizedBox(width: 9),
            Expanded(child: Text(app.t('preferred_ai_hint'), style: fb.ui(size: 12, color: fb.inkFaint, height: 1.5))),
          ]),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, FbTheme fb, AppState app, String key, String title, String sub, String? reason) {
    final disabled = reason != null;
    final on = app.preferredAI == key && !disabled;
    return GestureDetector(
      onTap: disabled ? null : () => app.setPreferredAI(key),
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

/// Settings — Tier 1 on-device model: a single one-time Phi download (robust
/// background DownloadManager), with progress / delete. Everything stays local.
class OnDeviceModelManager extends StatefulWidget {
  const OnDeviceModelManager({super.key});
  @override
  State<OnDeviceModelManager> createState() => _OnDeviceModelManagerState();
}

class _OnDeviceModelManagerState extends State<OnDeviceModelManager> {
  ModelDownloadStatus _status = const ModelDownloadStatus('none', 0, 0, null);
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Poll while the screen is open so a background download shows live progress.
    _poll = Timer.periodic(const Duration(milliseconds: 1200), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await OnDeviceAi.downloadStatus();
    if (!mounted) return;
    final wasDone = _status.isDone;
    setState(() => _status = s);
    if (s.isDone && !wasDone) await context.read<AppState>().refreshOnDevice();
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    final gb = bytes / (1024 * 1024 * 1024);
    return gb >= 1 ? '${gb.toStringAsFixed(2)} Go' : '${(bytes / (1024 * 1024)).round()} Mo';
  }

  Future<void> _start() async {
    await OnDeviceAi.startDownload();
    await _refresh();
  }

  Future<void> _cancel() async {
    await OnDeviceAi.cancelDownload();
    await _refresh();
  }

  Future<void> _delete() async {
    await OnDeviceAi.deleteModel();
    if (mounted) await context.read<AppState>().refreshOnDevice();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final ready = _status.isDone;
    final running = _status.isRunning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: ready ? const Color(0x1F6BA368) : fb.line, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon(ready ? 'check' : 'note', size: 16, color: ready ? const Color(0xFF4F7D4C) : fb.inkFaint))),
            const SizedBox(width: 11),
            Expanded(child: Text(ready ? '${app.t('ondevice_model_loaded')} · ${_fmtSize(_status.total)}' : app.t('ondevice_model_none'), style: fb.ui(size: 14.5, weight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Text(app.t('ondevice_model_hint'), style: fb.ui(size: 12, color: fb.inkFaint, height: 1.45)),
          const SizedBox(height: 12),
          if (running) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: _status.progress, minHeight: 8, backgroundColor: fb.line, color: fb.accent),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${app.t('ondevice_downloading')} ${_status.progress != null ? '${(_status.progress! * 100).round()}%' : ''}'.trim(), style: fb.ui(size: 12.5, weight: FontWeight.w600, color: fb.inkSoft)),
              if (_status.total > 0) Text('${_fmtSize(_status.downloaded)} / ${_fmtSize(_status.total)}', style: fb.ui(size: 12, color: fb.inkFaint)),
            ]),
            const SizedBox(height: 10),
            _btn(fb, app.t('cancel'), 'x', outline: true, onTap: _cancel),
          ] else if (ready) ...[
            _btn(fb, app.t('ondevice_delete_model'), 'trash', outline: true, danger: true, onTap: _delete),
          ] else ...[
            _btn(fb, app.t('ondevice_download_btn'), 'download', onTap: _start),
            if (_status.isFailed && _status.reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FbIcon('note', size: 14, color: Color(0xFFC0563B)),
                  const SizedBox(width: 7),
                  Expanded(child: Text('${app.t('ondevice_dl_failed')} — ${_status.reason}', style: fb.ui(size: 12, weight: FontWeight.w600, color: const Color(0xFF9C3F29), height: 1.4))),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _btn(FbTheme fb, String label, String icon, {bool outline = false, bool danger = false, required VoidCallback onTap}) {
    final color = danger ? const Color(0xFFC0563B) : (outline ? fb.accent : Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : fb.accent,
          borderRadius: BorderRadius.circular(11),
          border: outline ? Border.all(color: danger ? const Color(0x33C0563B) : fb.line) : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FbIcon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(label, style: fb.ui(size: 14.5, weight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
