import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../nav.dart';
import '../services/pdf_export.dart';
import '../services/data_export.dart';
import '../services/timer_notifications.dart';
import '../services/ringtone_picker.dart';
import 'export_select_screen.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? flash;

  void _showFlash(String msg) {
    setState(() => flash = msg);
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => flash = null);
    });
  }

  Future<void> _import(AppState app) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (res == null || res.files.isEmpty) return;
    try {
      final bytes = res.files.first.bytes;
      final text = bytes != null ? utf8.decode(bytes) : '';
      final data = jsonDecode(text) as Map<String, dynamic>;
      final n = app.importData(data);
      _showFlash('${app.t('imported')}$n${app.t('imported_recipes')}');
    } catch (_) {
      _showFlash(app.t('invalid_file'));
    }
  }

  Future<void> _exportJson(AppState app) async {
    await exportJsonShare(context, app);
    _showFlash(app.t('book_exported'));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    final savedCount = app.baseRecipes.length;

    return Column(
      children: [
        FbHeader(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: Align(alignment: Alignment.centerLeft, child: Text(app.t('settings_title'), style: fb.display(size: 28, weight: FontWeight.w600))))),
        Expanded(
          child: Stack(
            children: [
              ScreenScroll(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  // profile card
                  Container(
                    margin: const EdgeInsets.only(bottom: 22),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(20), boxShadow: fb.shadow),
                    child: Row(children: [
                      Container(width: 56, height: 56, decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text((app.profile.username.isEmpty ? '?' : app.profile.username)[0].toUpperCase(), style: fb.display(size: 26, weight: FontWeight.w600, color: Colors.white))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(app.t('username_label').toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4)),
                            _UsernameField(),
                            Text('$savedCount ${app.t('recipes_saved')}', style: fb.ui(size: 13, color: fb.inkSoft)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  _Group(label: app.t('set_language'), children: [
                    _SettingsRow(label: app.t('set_language'), width: 178, child: Segmented(value: lang, onChange: app.setLanguage, options: const [('fr', 'Français'), ('en', 'English')])),
                  ]),
                  _Group(label: app.t('set_units'), children: [
                    _SettingsRow(label: app.t('set_temp'), width: 150, child: Segmented(value: app.profile.temperature, onChange: app.setTemp, options: const [('celsius', '°C'), ('fahrenheit', '°F')])),
                    _SettingsRow(label: app.t('set_volume'), width: 178, child: Segmented(value: app.profile.volume, onChange: app.setVolume, options: [('metric', app.t('metric')), ('imperial', app.t('imperial'))])),
                    _SettingsRow(label: app.t('set_weight'), width: 178, last: true, child: Segmented(value: app.profile.weight, onChange: app.setWeight, options: [('metric', app.t('metric')), ('imperial', app.t('imperial'))])),
                  ]),
                  _Group(label: app.t('set_textsize'), children: [
                    _SettingsRow(label: app.t('set_textsize'), width: 150, last: true, child: Segmented(value: app.profile.fontSize, onChange: app.setFontSize, options: const [('small', 'A'), ('medium', 'A'), ('large', 'A')])),
                  ]),
                  _Group(label: app.t('appearance'), children: [
                    _SettingsRow(label: app.t('dark_mode'), last: true, child: _Toggle(on: app.dark, onTap: () => app.setDark(!app.dark))),
                  ]),
                  _Group(label: app.t('timer_sound'), children: const [
                    _SoundRow(alarm: true),
                    _SoundRow(alarm: false),
                    _SoundHint(),
                  ]),
                  _Group(label: app.t('custom_tags'), children: const [TagManager()]),
                  _Group(label: app.t('import_export'), children: [
                    _ActionRow(icon: 'basket', label: app.t('import_book'), onTap: () => _import(app)),
                    _ActionRow(icon: 'note', label: app.t('export_json'), onTap: () => _exportJson(app)),
                    _ActionRow(icon: 'note', label: app.t('export_book_pdf'), onTap: () => _exportBook(app), last: true),
                  ]),
                  _Group(label: app.t('help_section'), children: [
                    _ActionRow(icon: 'note', label: app.t('help_title'), onTap: () => Nav.openHelp(context)),
                    _ActionRow(icon: 'timer', label: app.t('replay_tips'), onTap: () { app.resetTips(); _showFlash(app.t('tips_reset_done')); }, last: true),
                  ]),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(app.t('version'), style: fb.ui(size: 12.5, color: fb.inkFaint)))),
                ],
              ),
              if (flash != null)
                Positioned(
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: fb.ink, borderRadius: BorderRadius.circular(999), boxShadow: fb.shadow),
                      child: Text(flash!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.canvas)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportBook(AppState app) async {
    final fb = context.fb;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: fb.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        Widget option(String icon, String label, String value, {bool primary = false}) => GestureDetector(
              onTap: () => Navigator.pop(ctx, value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: primary ? fb.accent : fb.cardSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary ? fb.accent : fb.line),
                ),
                child: Row(children: [
                  FbIcon(icon, size: 20, color: primary ? Colors.white : fb.accent),
                  const SizedBox(width: 12),
                  Text(label, style: fb.ui(size: 15.5, weight: FontWeight.w700, color: primary ? Colors.white : fb.ink)),
                ]),
              ),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Text(app.t('export_choose_title'), style: fb.display(size: 21, weight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(app.t('export_choose_sub'), style: fb.ui(size: 14, color: fb.inkSoft)),
              ),
              option('note', app.t('export_all'), 'all', primary: true),
              option('check', app.t('export_subset'), 'subset'),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (choice == 'all') {
      await exportRecipesPdf(context, app.baseRecipes);
    } else if (choice == 'subset') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportSelectScreen()));
    }
  }
}

class _UsernameField extends StatefulWidget {
  @override
  State<_UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<_UsernameField> {
  late final TextEditingController _c = TextEditingController(text: context.read<AppState>().profile.username);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return TextField(
      controller: _c,
      onChanged: (v) => context.read<AppState>().setUsername(v),
      style: fb.display(size: 20, weight: FontWeight.w600),
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
    );
  }
}

// ── small settings controls ──
class Segmented extends StatelessWidget {
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChange;
  const Segmented({super.key, required this.value, required this.options, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: fb.dark ? Colors.white.withValues(alpha: 0.06) : fb.canvas2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(o.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: value == o.$1 ? fb.card : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: value == o.$1 ? fb.shadow : null),
                  alignment: Alignment.center,
                  child: Text(o.$2, style: fb.ui(size: 14, weight: value == o.$1 ? FontWeight.w700 : FontWeight.w600, color: value == o.$1 ? fb.ink : fb.inkSoft)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _Toggle({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(color: on ? fb.accent : fb.lineStrong, borderRadius: BorderRadius.circular(999)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)])),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Group({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text(label.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5))),
          Container(decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow), clipBehavior: Clip.antiAlias, child: Column(children: children)),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;
  final double? width;
  final bool last;
  const _SettingsRow({required this.label, required this.child, this.width, this.last = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: fb.ui(size: 15.5, weight: FontWeight.w600))),
          const SizedBox(width: 14),
          width != null ? SizedBox(width: width, child: child) : child,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final bool last;
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon(icon, size: 17, color: fb.accent))),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: fb.ui(size: 15.5, weight: FontWeight.w600))),
          FbIcon('chevR', size: fb.fs(17), color: fb.inkFaint),
        ]),
      ),
    );
  }
}

// ── Timer sound selector ──
// Two options: a phone alarm tone (pick any of the device's alarms) or a soft
// chime. Tapping a row selects it and plays a short preview; the alarm row also
// opens the system alarm picker to change which tone is used.
class _SoundRow extends StatelessWidget {
  final bool alarm;
  const _SoundRow({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final on = app.chimeIsAlarm == alarm;

    void preview() => TimerNotifications.instance.preview(
          isAlarm: alarm,
          alarmUri: app.chimeAlarmUri,
          title: app.t('timer_sound'),
          body: alarm ? app.t('sound_alarm') : app.t('sound_soft'),
        );

    Future<void> pick() async {
      final picked = await RingtonePicker.pickAlarm(current: app.chimeAlarmUri, title: app.t('sound_alarm'));
      if (picked == null) return; // cancelled
      app.setAlarmTone(picked.uri, picked.title);
      preview();
    }

    void select() {
      if (alarm) {
        app.setAlarmTone(app.chimeAlarmUri, app.chimeAlarmName);
      } else {
        app.setChimeMode('chime');
      }
      preview();
    }

    final title = alarm ? app.t('sound_alarm') : app.t('sound_soft');
    final sub = alarm ? (app.chimeAlarmName ?? app.t('sound_default_alarm')) : null;

    return GestureDetector(
      onTap: select,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: on ? fb.accent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: on ? fb.accent : fb.lineStrong, width: 2)),
              child: on ? const Center(child: FbIcon('check', size: 13, color: Colors.white)) : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: fb.ui(size: 15.5, weight: FontWeight.w600)),
                  if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 12.5, color: fb.inkFaint)),
                ],
              ),
            ),
            if (alarm) ...[
              GestureDetector(
                onTap: pick,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(app.t('sound_change'), style: fb.ui(size: 13, weight: FontWeight.w700, color: fb.accent)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              onTap: preview,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FbIcon('play', size: 14, color: fb.accent),
                  const SizedBox(width: 5),
                  Text(app.t('chime_test'), style: fb.ui(size: 12.5, weight: FontWeight.w700, color: fb.accent)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundHint extends StatelessWidget {
  const _SoundHint();
  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Text(context.read<AppState>().t('timer_sound_hint'), style: fb.ui(size: 12.5, color: fb.inkFaint)),
    );
  }
}

// ── Tag manager (user tags: rename / delete / create) ──
class TagManager extends StatefulWidget {
  const TagManager({super.key});

  @override
  State<TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends State<TagManager> {
  String? editId;
  final _renameCtl = TextEditingController();
  String? warnId;
  String? confirmId;
  final _newCtl = TextEditingController();
  bool createWarn = false;

  @override
  void dispose() {
    _renameCtl.dispose();
    _newCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;
    final userTags = app.tags.where((t) => !t.system).toList();

    return Column(
      children: [
        if (userTags.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), child: Align(alignment: Alignment.centerLeft, child: Text(app.t('no_user_tags'), style: fb.ui(size: 13.5, color: fb.inkFaint)))),
        for (int i = 0; i < userTags.length; i++) _tagRow(app, fb, lang, userTags[i], i < userTags.length - 1),
        // create row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: userTags.isNotEmpty ? BoxDecoration(border: Border(top: BorderSide(color: fb.line))) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon('plus', size: 16, color: fb.accent))),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newCtl,
                    onChanged: (_) => setState(() => createWarn = false),
                    onSubmitted: (_) => _doCreate(app),
                    style: fb.ui(size: 14.5),
                    decoration: _renameDecoration(fb, app.t('add_tag')),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => _doCreate(app), child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Text(app.t('create_label'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white)))),
              ]),
              if (createWarn) Padding(padding: const EdgeInsets.only(top: 8, left: 41), child: Text(app.t('tag_exists'), style: fb.ui(size: 12.5, weight: FontWeight.w600, color: const Color(0xFFC0563B)))),
            ],
          ),
        ),
      ],
    );
  }

  void _doCreate(AppState app) {
    final v = _newCtl.text.trim();
    if (v.isEmpty) return;
    final r = app.addTag(v);
    if (!r.created) {
      setState(() => createWarn = true);
      return;
    }
    _newCtl.clear();
    setState(() => createWarn = false);
  }

  InputDecoration _renameDecoration(FbTheme fb, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: fb.ui(size: 14.5, color: fb.inkFaint),
        isDense: true,
        filled: true,
        fillColor: fb.canvas2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: fb.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: fb.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: fb.accent)),
      );

  Widget _tagRow(AppState app, FbTheme fb, String lang, Tag tg, bool border) {
    final editing = editId == tg.id;
    final name = tg.displayName(lang);
    final n = app.recipesWithTag(tg.id);
    return Container(
      decoration: border ? BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 30, height: 30, decoration: BoxDecoration(color: hexColor(tg.color).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon(tg.icon, size: 16, color: hexColor(tg.color)))),
              const SizedBox(width: 11),
              Expanded(
                child: editing
                    ? TextField(controller: _renameCtl, autofocus: true, onChanged: (_) => setState(() => warnId = null), onSubmitted: (_) => _commit(app, tg), style: fb.ui(size: 15), decoration: _renameDecoration(fb, ''))
                    : Text(name, style: fb.ui(size: 15.5, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              if (editing)
                GestureDetector(onTap: () => _commit(app, tg), child: Container(width: 34, height: 34, decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(9)), child: const Center(child: FbIcon('check', size: 17, color: Colors.white))))
              else
                GestureDetector(onTap: () => _startRename(tg, name), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('pencil', size: 16, color: fb.inkSoft)))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() { confirmId = confirmId == tg.id ? null : tg.id; editId = null; }), child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), child: Center(child: FbIcon('trash', size: 16, color: fb.inkSoft)))),
            ]),
          ),
          if (warnId == tg.id) Padding(padding: const EdgeInsets.fromLTRB(57, 0, 16, 12), child: Text(app.t('tag_exists'), style: fb.ui(size: 12.5, weight: FontWeight.w600, color: const Color(0xFFC0563B)))),
          if (confirmId == tg.id)
            Padding(
              padding: const EdgeInsets.fromLTRB(57, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang == 'fr' ? 'Supprimer « $name » ? Ce tag sera retiré de $n ${n == 1 ? "recette" : "recettes"}.' : 'Delete "$name"? It will be removed from $n ${n == 1 ? "recipe" : "recipes"}.', style: fb.ui(size: 13, color: fb.inkSoft, height: 1.4)),
                  const SizedBox(height: 9),
                  Row(children: [
                    GestureDetector(onTap: () => setState(() => confirmId = null), child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: fb.line)), alignment: Alignment.center, child: Text(app.t('cancel'), style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkSoft)))),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () { app.deleteTag(tg.id); setState(() => confirmId = null); }, child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0xFFC0563B), borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Text(app.t('delete'), style: fb.ui(size: 13, weight: FontWeight.w700, color: Colors.white)))),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _startRename(Tag tg, String name) {
    setState(() {
      editId = tg.id;
      warnId = null;
      confirmId = null;
      _renameCtl.text = tg.name is String ? tg.name as String : name;
    });
  }

  void _commit(AppState app, Tag tg) {
    final v = _renameCtl.text.trim();
    if (v.isEmpty) {
      setState(() => editId = null);
      return;
    }
    if (!app.renameTag(tg.id, v)) {
      setState(() => warnId = tg.id);
      return;
    }
    setState(() { editId = null; warnId = null; });
  }
}
