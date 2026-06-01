import 'dart:typed_data';

import 'package:flutter/material.dart' hide Step;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../nav.dart';
import '../services/recipe_import.dart' show RecipeImport, ImportResult, ImportException;
import '../services/import/import_engine.dart';
import '../services/import/import_debug.dart';
import '../widgets/fb_icon.dart';
import 'region_picker.dart';

/// The "+" entry point (§2f): opens a method chooser; non-manual methods run the
/// tiered importer and always land on the editor as a reviewable draft.
Future<void> showImportSheet(BuildContext context, {ImportMethod? startMethod, String? sharedText, Uint8List? sharedImage}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportSheet(rootContext: context, startMethod: startMethod, sharedText: sharedText, sharedImage: sharedImage),
  );
}

const _methods = [
  ('manual', 'pencil', 'method_manual', 'method_manual_sub'),
  ('link', 'link', 'method_link', 'method_link_sub'),
  ('camera', 'camera', 'method_photo', 'method_photo_sub'),
  ('text', 'note', 'method_text', 'method_text_sub'),
];

class _ImportSheet extends StatefulWidget {
  final BuildContext rootContext;
  final ImportMethod? startMethod;
  final String? sharedText;
  final Uint8List? sharedImage;
  const _ImportSheet({required this.rootContext, this.startMethod, this.sharedText, this.sharedImage});

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  ImportMethod? method; // null = chooser stage
  final _controller = TextEditingController();
  Uint8List? _photo;
  String _mediaType = 'image/jpeg';
  bool _regions = false; // photo: guide OCR by drawing ingredient/step regions
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    method = widget.startMethod;
    if (widget.sharedText != null) _controller.text = widget.sharedText!;
    _photo = widget.sharedImage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AppState get app => widget.rootContext.read<AppState>();

  void _pickMethod(String key) {
    if (key == 'manual') {
      Navigator.pop(context);
      Nav.addRecipe(widget.rootContext);
      return;
    }
    setState(() {
      method = key == 'link' ? ImportMethod.link : key == 'camera' ? ImportMethod.photo : ImportMethod.text;
      _error = null;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 2200, imageQuality: 88);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (x.name.toLowerCase().endsWith('.png')) _mediaType = 'image/png';
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {}
  }

  void _useSample() {
    setState(() {
      if (method == ImportMethod.link) {
        _controller.text = 'https://www.ricardocuisine.com/recettes/8389-tarte-au-sucre';
      } else if (method == ImportMethod.text) {
        _controller.text = 'Tarte au sucre\n8 portions\n\n1 abaisse de tarte\n250 g cassonade\n250 ml crème 35 %\n2 c. à soupe farine\n1 oeuf\n1 c. à thé vanille\n\nPréchauffer le four à 180 °C. Mélanger, verser dans l\'abaisse et cuire 35 minutes.';
      }
    });
  }

  bool get _ready => method == ImportMethod.photo ? _photo != null : _controller.text.trim().isNotEmpty;

  // On-device inference runs in-app; keep the screen awake so the OS doesn't
  // background/throttle/kill it mid-run. (The download itself is handled by
  // DownloadManager and needs no wake-lock.)
  bool get _keepAwake => method != ImportMethod.link && app.effectiveBackend == 'ondevice';

  Future<void> _run() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_keepAwake) WakelockPlus.enable();
    try {
      final res = await ImportEngine.run(
        method: method!,
        app: app,
        url: method == ImportMethod.link ? _controller.text : null,
        text: method == ImportMethod.text ? _controller.text : null,
        imageBytes: method == ImportMethod.photo ? _photo : null,
        mediaType: _mediaType,
      );
      if (!mounted) return;
      await _finish(res);
    } on ImportException catch (e) {
      importLog('import failed: ${e.code} | ${e.detail ?? ''}');
      if (e.code == 'ondevice_unavailable') app.markOnDeviceUnavailable();
      if (mounted) setState(() { _busy = false; _error = kImportDebug ? '[${e.code}]\n${e.detail ?? '(no detail)'}' : _msg(e.code); });
    } catch (e, st) {
      importLog('import crashed: $e\n$st');
      if (mounted) setState(() { _busy = false; _error = kImportDebug ? e.toString() : app.t('import_err_generic'); });
    } finally {
      WakelockPlus.disable();
    }
  }

  // Region-guided photo import: draw ingredient boxes, then step boxes, then run.
  Future<void> _runRegions() async {
    if (_photo == null || _busy) return;
    final root = widget.rootContext;
    final fr = app.lang == 'fr';
    final ing = await Navigator.of(root).push<List<Rect>>(MaterialPageRoute(builder: (_) => RegionPicker(
          image: _photo!,
          title: fr ? 'Encadrez les ingrédients' : 'Box the ingredients',
          hint: fr ? 'Glissez pour dessiner une ou plusieurs zones' : 'Drag to draw one or more boxes',
          isLast: false,
        )));
    if (ing == null || !mounted || !root.mounted) return;
    final steps = await Navigator.of(root).push<List<Rect>>(MaterialPageRoute(builder: (_) => RegionPicker(
          image: _photo!,
          title: fr ? 'Encadrez les étapes' : 'Box the steps',
          hint: fr ? 'Glissez pour dessiner une ou plusieurs zones' : 'Drag to draw one or more boxes',
          isLast: true,
        )));
    if (steps == null || !mounted) return;
    if ((ing.isEmpty) && (steps.isEmpty)) {
      setState(() => _error = app.t('import_err_no_recipe'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    if (app.effectiveBackend == 'ondevice') WakelockPlus.enable();
    try {
      final res = await ImportEngine.extractFromRegions(app: app, imageBytes: _photo!, ingredientBoxes: ing, stepBoxes: steps);
      if (!mounted) return;
      await _finish(res);
    } on ImportException catch (e) {
      importLog('region import failed: ${e.code} | ${e.detail ?? ''}');
      if (e.code == 'ondevice_unavailable') app.markOnDeviceUnavailable();
      if (mounted) setState(() { _busy = false; _error = kImportDebug ? '[${e.code}]\n${e.detail ?? '(no detail)'}' : _msg(e.code); });
    } catch (e, st) {
      importLog('region import crashed: $e\n$st');
      if (mounted) setState(() { _busy = false; _error = kImportDebug ? e.toString() : app.t('import_err_generic'); });
    } finally {
      WakelockPlus.disable();
    }
  }

  Future<void> _finish(ImportResult res) async {
    final root = widget.rootContext;
    // Hero image: a downloaded web image (Tier 0) or the photo the user imported.
    String? heroPath;
    if (res.heroImageUrl != null) {
      heroPath = await RecipeImport.downloadImage(res.heroImageUrl!);
    }
    app.setRecipePhoto('__draft', heroPath);
    if (!mounted) return;
    Navigator.pop(context); // close the sheet
    if (!root.mounted) return;
    Nav.editRecipeInitial(root, res.recipe);
    if (res.suggestedTags.isNotEmpty) {
      ScaffoldMessenger.of(root).showSnackBar(
        SnackBar(content: Text('${root.read<AppState>().t('import_tags_hint')} ${res.suggestedTags.join(', ')}')),
      );
    }
  }

  String _msg(String code) {
    switch (code) {
      case 'needs_ai':
        return app.t('import_err_needs_ai');
      case 'ondevice_unavailable':
        return app.t('import_err_ondevice_na');
      case 'bad_key':
        return app.t('import_err_bad_key');
      case 'rate_limited':
        return app.t('import_err_rate');
      case 'no_recipe':
      case 'empty_input':
        return app.t('import_err_no_recipe');
      case 'provider_error':
      case 'bad_provider':
      case 'bad_json':
        return app.t('import_err_provider');
      default:
        return app.t('import_err_generic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        decoration: BoxDecoration(color: fb.canvas, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 5, decoration: BoxDecoration(color: fb.lineStrong, borderRadius: BorderRadius.circular(99))),
                method == null ? _chooser(fb) : _input(fb),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chooser(FbTheme fb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.t('add_method_title'), style: fb.display(size: 24, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          for (final m in _methods) ...[
            _methodCard(fb, m.$1, m.$2, app.t(m.$3), app.t(m.$4)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: FbIcon('search', size: 15, color: fb.inkFaint)),
            const SizedBox(width: 8),
            Expanded(child: Text(app.t('import_share_note'), style: fb.ui(size: 12, color: fb.inkFaint, height: 1.45))),
          ]),
        ],
      ),
    );
  }

  Widget _methodCard(FbTheme fb, String key, String icon, String title, String sub) {
    final primary = key == 'manual';
    return GestureDetector(
      onTap: () => _pickMethod(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: primary ? fb.accentSoft : fb.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary ? fb.accent : fb.line),
          boxShadow: primary ? null : fb.shadow,
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: primary ? fb.accent : fb.accentSoft, borderRadius: BorderRadius.circular(13)), child: Center(child: FbIcon(icon, size: 21, color: primary ? Colors.white : fb.accent))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: fb.ui(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(sub, style: fb.ui(size: 13, color: fb.inkSoft)),
            ]),
          ),
          FbIcon('chevR', size: fb.fs(18), color: fb.inkFaint),
        ]),
      ),
    );
  }

  Widget _input(FbTheme fb) {
    final m = method!;
    final tier = ImportEngine.tierFor(m, app);
    final tierNum = tier == 'tier0' ? '0' : tier == 'ondevice' ? '1' : '2';
    final tierLabel = tier == 'tier0' ? app.t('import_tier0') : tier == 'ondevice' ? app.t('import_ondevice') : app.t('import_byok');
    final runLabel = tier == 'tier0' ? app.t('import_reading_web') : tier == 'byok' ? app.t('import_byok_run') : app.t('import_ondevice_run');
    final titleKey = m == ImportMethod.link ? 'method_link' : m == ImportMethod.photo ? 'method_photo' : 'method_text';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: _busy ? null : () => setState(() { method = null; _error = null; }),
              child: Opacity(opacity: _busy ? 0.4 : 1, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: fb.line)), child: Center(child: FbIcon('back', size: 18, color: fb.inkSoft)))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(app.t(titleKey), style: fb.display(size: 20, weight: FontWeight.w600))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)), child: Text('${app.lang == 'fr' ? 'Niveau' : 'Tier'} $tierNum · $tierLabel', style: fb.ui(size: 11, weight: FontWeight.w700, color: fb.accent))),
          ]),
          const SizedBox(height: 14),
          if (_busy)
            _analyzing(fb, runLabel)
          else ...[
            _inputField(fb, m),
            if (m != ImportMethod.photo)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: _useSample,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    FbIcon('plus', size: 14, color: fb.accent),
                    const SizedBox(width: 6),
                    Text(app.t('import_use_sample'), style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.accent)),
                  ]),
                ),
              ),
            if (m == ImportMethod.photo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _regions = !_regions),
                  behavior: HitTestBehavior.opaque,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 22, height: 22, decoration: BoxDecoration(color: _regions ? fb.accent : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: _regions ? fb.accent : fb.lineStrong, width: 2)), child: _regions ? const Center(child: FbIcon('check', size: 12, color: Colors.white)) : null),
                    const SizedBox(width: 10),
                    Expanded(child: Text(app.t('import_regions_toggle'), style: fb.ui(size: 12.5, weight: FontWeight.w600, color: fb.inkSoft, height: 1.4))),
                  ]),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFC0563B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FbIcon('note', size: 15, color: Color(0xFFC0563B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: kImportDebug
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: SingleChildScrollView(
                                child: SelectableText(_error!, style: TextStyle(fontFamily: 'monospace', fontSize: fb.fs(11.5), color: const Color(0xFF9C3F29), height: 1.4)),
                              ),
                            )
                          : Text(_error!, style: fb.ui(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF9C3F29), height: 1.4)),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _ready ? (method == ImportMethod.photo && _regions ? _runRegions : _run) : null,
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: _ready ? fb.accent : fb.line, borderRadius: BorderRadius.circular(15)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FbIcon(method == ImportMethod.photo && _regions ? 'camera' : 'plus', size: fb.fs(19), color: _ready ? Colors.white : fb.inkFaint),
                  const SizedBox(width: 8),
                  Text(method == ImportMethod.photo && _regions ? app.t('import_regions_run') : app.t('import_run'), style: fb.ui(size: 16, weight: FontWeight.w700, color: _ready ? Colors.white : fb.inkFaint)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
              child: Text(app.t('import_review_note'), textAlign: TextAlign.center, style: fb.ui(size: 11.5, color: fb.inkFaint, height: 1.45)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inputField(FbTheme fb, ImportMethod m) {
    if (m == ImportMethod.link) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line), boxShadow: fb.shadow),
        child: Row(children: [
          FbIcon('link', size: fb.fs(18), color: fb.inkFaint),
          const SizedBox(width: 9),
          Expanded(child: TextField(controller: _controller, keyboardType: TextInputType.url, autofocus: true, onChanged: (_) => setState(() {}), style: fb.ui(size: 15.5), decoration: InputDecoration.collapsed(hintText: app.t('import_link_ph'), hintStyle: fb.ui(size: 15.5, color: fb.inkFaint)))),
        ]),
      );
    }
    if (m == ImportMethod.text) {
      return Container(
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line), boxShadow: fb.shadow),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: TextField(controller: _controller, maxLines: 6, minLines: 6, autofocus: true, onChanged: (_) => setState(() {}), style: fb.ui(size: 15, height: 1.5), decoration: InputDecoration.collapsed(hintText: app.t('import_text_ph'), hintStyle: fb.ui(size: 15, color: fb.inkFaint))),
      );
    }
    // photo
    final has = _photo != null;
    return Column(
      children: [
        Container(
          height: 168,
          decoration: BoxDecoration(
            color: has ? fb.accentSoft : fb.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: has ? fb.accent : fb.lineStrong, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: has
              ? Stack(fit: StackFit.expand, children: [
                  Image.memory(_photo!, fit: BoxFit.cover),
                  Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const FbIcon('check', size: 14, color: Colors.white))),
                ])
              : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: fb.accentSoft, shape: BoxShape.circle), child: Center(child: FbIcon('camera', size: 24, color: fb.accent))),
                  const SizedBox(height: 10),
                  Text(app.t('import_photo_drop'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft)),
                ])),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _photoBtn(fb, 'camera', app.t('import_photo_camera'), ImageSource.camera)),
          const SizedBox(width: 10),
          Expanded(child: _photoBtn(fb, 'note', app.t('import_photo_gallery'), ImageSource.gallery)),
        ]),
      ],
    );
  }

  Widget _photoBtn(FbTheme fb, String icon, String label, ImageSource source) => GestureDetector(
        onTap: () => _pickPhoto(source),
        child: Container(
          height: 44,
          decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: fb.line)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FbIcon(icon, size: 16, color: fb.accent),
            const SizedBox(width: 7),
            Text(label, style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent)),
          ]),
        ),
      );

  Widget _analyzing(FbTheme fb, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 24, 10, 30),
        child: Column(children: [
          SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: fb.accent)),
          const SizedBox(height: 18),
          Text(label, style: fb.ui(size: 15.5, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_keepAwake ? app.t('import_ondevice_slow') : app.t('import_validating'), textAlign: TextAlign.center, style: fb.ui(size: 12.5, color: fb.inkFaint, height: 1.45)),
        ]),
      );
}
