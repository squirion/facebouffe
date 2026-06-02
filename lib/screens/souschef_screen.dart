import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Step;
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../state/app_state.dart';
import '../data/models.dart';
import '../data/format.dart';
import '../theme.dart';
import '../nav.dart';
import '../services/timer_notifications.dart';
import '../widgets/common.dart';
import '../widgets/fb_icon.dart';

/// A cooking timer anchored to a wall-clock end time so the displayed
/// countdown stays correct after the app is backgrounded / the phone sleeps
/// (the in-app ticker only repaints; the real chime is an OS-scheduled
/// notification keyed by [notifId]). [notifId] == stepIdx (one timer per step).
class _Timer {
  final String key;
  final String recipeId; // which stacked recipe owns this timer
  final int stepIdx;
  final int notifId;
  final int total;
  DateTime? endTime; // set while running; null while paused
  int remaining; // authoritative only while paused
  bool running = true;
  _Timer({required this.key, required this.recipeId, required this.stepIdx, required this.notifId, required this.total, this.endTime, required this.remaining});

  int get left {
    if (running && endTime != null) {
      final s = endTime!.difference(DateTime.now()).inSeconds;
      return s < 0 ? 0 : s;
    }
    return remaining;
  }
}

/// One open recipe in the cooking stack. Holds the per-recipe UI state so each
/// stacked recipe keeps its own pane, step position and ingredient checklist
/// (timers live in the shared list, tagged by [recipeId]).
class _CookSession {
  final String recipeId;
  int servings;
  int pane = 0; // 0 = ingredients, 1 = steps
  int stepIdx = 0;
  final Set<int> checked = {};
  _CookSession(this.recipeId, this.servings);
}

/// Lean cooking helper: two swipeable panes (ingredients checklist + step-by-
/// step), big readable type, tappable per-step timers and a persistent
/// running-timers tray. The screen is conceptually kept awake (indicated).
class SousChefScreen extends StatefulWidget {
  final String id;
  final int servings;
  const SousChefScreen({super.key, required this.id, required this.servings});

  @override
  State<SousChefScreen> createState() => _SousChefScreenState();
}

class _SousChefScreenState extends State<SousChefScreen> with WidgetsBindingObserver {
  final _pager = PageController();
  final List<_CookSession> _sessions = [];
  // ignore: prefer_final_fields — becomes mutable when tab-switching lands (Commit B)
  int _active = 0;
  final List<_Timer> _timers = [];
  int _notifSeq = 1000; // monotonic, globally-unique notification ids across recipes
  Timer? _ticker;

  _CookSession get _s => _sessions[_active];

  @override
  void initState() {
    super.initState();
    _sessions.add(_CookSession(widget.id, widget.servings));
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // keep the screen awake while cooking (web + Android)
    if (!kIsWeb) TimerNotifications.instance.requestPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from background/sleep: the ticker was frozen, so repaint the
    // wall-clock-derived countdown and restart the cosmetic ticker if needed.
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _ensureTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _pager.dispose();
    WakelockPlus.disable();
    // Cooking session is over — cancel any pending chimes for this session.
    for (final t in _timers) {
      TimerNotifications.instance.cancel(t.notifId);
    }
    super.dispose();
  }

  // Cosmetic ticker: repaints the derived countdown ~1×/s while a timer runs.
  // Correctness comes from each timer's wall-clock endTime + the OS chime.
  void _ensureTicker() {
    final active = _timers.any((t) => t.running && t.left > 0);
    if (active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {});
        if (!_timers.any((t) => t.running && t.left > 0)) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    }
  }

  // Build the bilingual chime title/body for a step timer (names its recipe).
  ({String title, String body}) _chimeText(String recipeId, int stepIdx) {
    final app = context.read<AppState>();
    final recipe = app.getRecipe(recipeId);
    final step = '${app.t('sc_step')} ${stepIdx + 1}';
    return (title: app.t('sc_timer_done'), body: recipe != null ? '${recipe.title} · $step' : step);
  }

  void _startStepTimer(_CookSession s, int idx, int total) {
    final end = DateTime.now().add(Duration(seconds: total));
    late int notifId;
    setState(() {
      final ex = _timers.where((t) => t.recipeId == s.recipeId && t.stepIdx == idx).firstOrNull;
      if (ex != null) {
        ex.endTime = end;
        ex.remaining = total;
        ex.running = true;
        notifId = ex.notifId;
      } else {
        notifId = _notifSeq++;
        _timers.add(_Timer(key: '${s.recipeId}-$idx-${DateTime.now().microsecondsSinceEpoch}', recipeId: s.recipeId, stepIdx: idx, notifId: notifId, total: total, endTime: end, remaining: total));
      }
    });
    final txt = _chimeText(s.recipeId, idx);
    final app = context.read<AppState>();
    TimerNotifications.instance.cancel(notifId);
    TimerNotifications.instance.schedule(notifId, total, title: txt.title, body: txt.body, isAlarm: app.chimeIsAlarm, alarmUri: app.chimeAlarmUri);
    _ensureTicker();
  }

  void _toggleTimer(_Timer t) {
    if (t.running) {
      // pause: freeze remaining and cancel the pending chime
      setState(() {
        t.remaining = t.left;
        t.endTime = null;
        t.running = false;
      });
      TimerNotifications.instance.cancel(t.notifId);
    } else {
      // resume (or restart if it had finished): reschedule the chime
      final secs = t.left <= 0 ? t.total : t.remaining;
      setState(() {
        t.endTime = DateTime.now().add(Duration(seconds: secs));
        t.remaining = secs;
        t.running = true;
      });
      final txt = _chimeText(t.recipeId, t.stepIdx);
      final app = context.read<AppState>();
      TimerNotifications.instance.cancel(t.notifId);
      TimerNotifications.instance.schedule(t.notifId, secs, title: txt.title, body: txt.body, isAlarm: app.chimeIsAlarm, alarmUri: app.chimeAlarmUri);
    }
    _ensureTicker();
  }

  // Normalized group label (null/blank → null) for headers & boundary checks.
  String? _g(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  void _setPane(int i) {
    setState(() => _s.pane = i);
    _pager.animateToPage(i, duration: Duration(milliseconds: context.read<AppState>().reduceMotion ? 120 : 340), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final s = _s;
    final recipe = app.getRecipe(s.recipeId);
    if (recipe == null) return const SizedBox();
    final ratio = s.servings / recipe.servings;
    final steps = recipe.steps;
    final pal = fallbackColorFor(recipe.id);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final surface = Colors.white.withValues(alpha: 0.10);
    final faint = Colors.white.withValues(alpha: 0.42);
    final dimC = Colors.white.withValues(alpha: 0.66);
    const good = Color(0xFF7FC47B);
    final line = Colors.white.withValues(alpha: 0.16);

    return Scaffold(
      body: Stack(
        children: [
          // dimmed background
          Positioned.fill(child: Container(color: pal.bg)),
          Positioned.fill(child: CustomPaint(painter: _BgDots(pal.ink.withValues(alpha: 0.15)))),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.78)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: topInset),
              // top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: surface, shape: BoxShape.circle), child: const Center(child: FbIcon('x', size: 22, color: Colors.white))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.display(size: 17, weight: FontWeight.w600, color: Colors.white)),
                          Text('${s.servings} ${s.servings == 1 ? app.t('serving_one') : app.t('servings')}', style: fb.ui(size: 12, weight: FontWeight.w600, color: dimC)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: good, shape: BoxShape.circle, boxShadow: [BoxShadow(color: good, blurRadius: 8)])),
                        const SizedBox(width: 6),
                        Text(app.t('awake'), style: fb.ui(size: 11, weight: FontWeight.w600, color: dimC)),
                      ]),
                    ),
                  ],
                ),
              ),
              // running timers tray
              if (_timers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: Row(children: [
                          FbIcon('timer', size: fb.fs(13), color: dimC),
                          const SizedBox(width: 6),
                          Text(app.t('timers_running').toUpperCase(), style: fb.ui(size: 11, weight: FontWeight.w700, color: dimC, letterSpacing: 0.4)),
                          const Spacer(),
                          Text(app.t('scheduled_note'), style: fb.ui(size: 10.5, color: faint)),
                        ]),
                      ),
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _timers.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final tm = _timers[i];
                            final done = tm.left <= 0;
                            return Container(
                              constraints: const BoxConstraints(minWidth: 138),
                              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                              decoration: BoxDecoration(
                                color: done ? good.withValues(alpha: 0.22) : surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: done ? good : line),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                GestureDetector(
                                  onTap: () => _toggleTimer(tm),
                                  child: FbIcon(done ? 'check' : (tm.running ? 'timer' : 'play'), size: fb.fs(16), fill: done, color: done ? good : Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(done ? app.t('sc_timer_done') : fmtTimer(tm.left), style: fb.ui(size: 15, weight: FontWeight.w700, color: done ? good : Colors.white, height: 1)),
                                    GestureDetector(
                                      onTap: () { setState(() => _s.stepIdx = tm.stepIdx); _setPane(1); },
                                      child: Text('${app.t('sc_step')} ${tm.stepIdx + 1}', style: fb.ui(size: 10.5, color: dimC)),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () { TimerNotifications.instance.cancel(tm.notifId); setState(() => _timers.removeWhere((x) => x.key == tm.key)); },
                                  child: FbIcon('x', size: fb.fs(15), color: faint),
                                ),
                              ]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              // pane toggle + dots
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < 2; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i == 0 ? 4 : 0),
                              child: GestureDetector(
                                onTap: () => _setPane(i),
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(color: s.pane == i ? fb.accent : surface, borderRadius: BorderRadius.circular(12)),
                                  alignment: Alignment.center,
                                  child: Text(
                                    i == 0 ? app.t('sc_ingredients') : '${app.t('sc_steps')}  ${(s.stepIdx + 1).clamp(1, steps.length)}/${steps.length}',
                                    style: fb.ui(size: 15, weight: FontWeight.w700, color: Colors.white.withValues(alpha: s.pane == i ? 1 : 0.7)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 2; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: s.pane == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(color: s.pane == i ? Colors.white : faint, borderRadius: BorderRadius.circular(999)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // panes
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _s.pane = i),
                  children: [
                    _ingredientsPane(context, recipe, ratio, app, fb, line, faint, good),
                    _stepsPane(context, recipe, steps, app, fb, surface, line, dimC, good, bottomInset),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ingredientsPane(BuildContext context, Recipe recipe, double ratio, AppState app, FbTheme fb, Color line, Color faint, Color accentGood) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(22, 8, 22, 30 + bottomInset),
      children: [
        for (final (s, sec) in groupedSections(recipe.ingredients, (i) => i.group).indexed) ...[
          if (sec.hasHeader) _scSectionHeader(fb, sec.name!, first: s == 0),
          for (int k = 0; k < sec.items.length; k++)
            _scIngredientRow(sec.items[k], sec.indices[k], ratio, app, fb, line, faint),
        ],
      ],
    );
  }

  // Dark-theme section heading for the cooking panes.
  Widget _scSectionHeader(FbTheme fb, String name, {required bool first}) => Padding(
        padding: EdgeInsets.only(top: first ? 6 : 20, bottom: 4),
        child: Row(children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 9),
          Expanded(child: Text(name.toUpperCase(), style: fb.ui(size: 13, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.92), letterSpacing: 0.5))),
        ]),
      );

  Widget _scIngredientRow(Ingredient ing, int index, double ratio, AppState app, FbTheme fb, Color line, Color faint) {
    final d = displayIngredient(ing.quantity, ing.unit, ing.name, ing.note, ratio, app.prefs, app.lang);
    final on = _s.checked.contains(index);
    return GestureDetector(
      onTap: () => setState(() => on ? _s.checked.remove(index) : _s.checked.add(index)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: on ? fb.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: on ? fb.accent : Colors.white.withValues(alpha: 0.4), width: 2),
              ),
              child: on ? const Center(child: FbIcon('check', size: 16, color: Colors.white)) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${d.qtyText}${d.unitText.isNotEmpty ? ' ${d.unitText}' : ''} ', style: fb.ui(size: 18, weight: FontWeight.w700, color: on ? faint : fb.accent)),
                  TextSpan(text: d.name, style: fb.ui(size: 18, color: on ? faint : Colors.white, decoration: on ? TextDecoration.lineThrough : null)),
                  if (d.note != null) TextSpan(text: ' · ${d.note}', style: fb.ui(size: 18, color: faint, fontStyle: FontStyle.italic)),
                ]),
                style: const TextStyle(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepsPane(BuildContext context, Recipe recipe, List<Step> steps, AppState app, FbTheme fb, Color surface, Color line, Color dimC, Color good, double bottomInset) {
    final finished = _s.stepIdx >= steps.length;
    if (finished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 96, height: 96, decoration: BoxDecoration(color: surface, shape: BoxShape.circle), child: Center(child: FbIcon('check', size: 48, color: good))),
              const SizedBox(height: 20),
              Text(app.t('sc_all_done'), style: fb.display(size: 32, weight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 6),
              Text(app.t('sc_all_done_sub'), style: fb.ui(size: 16, color: dimC)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () { app.markCooked(recipe.id); Navigator.pop(context); },
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text(app.t('sc_close'), style: fb.ui(size: 16, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final step = steps[_s.stepIdx];
    final myTimer = _timers.where((t) => t.recipeId == _s.recipeId && t.stepIdx == _s.stepIdx).firstOrNull;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            children: [
              Text('${app.t('sc_step')} ${_s.stepIdx + 1} ${app.t('sc_of')} ${steps.length}', style: fb.ui(size: 13.5, weight: FontWeight.w700, color: fb.accent, letterSpacing: 0.6)),
              if (_g(step.group) != null) ...[
                const SizedBox(height: 7),
                Row(children: [
                  Container(width: 3, height: 18, decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_g(step.group)!, style: fb.display(size: 19, weight: FontWeight.w600, color: Colors.white))),
                ]),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < steps.length; i++)
                    Expanded(
                      child: Container(
                        // a wider gap marks a group boundary (next step starts a new section)
                        margin: EdgeInsets.only(right: i < steps.length - 1 ? (_g(steps[i].group) != _g(steps[i + 1].group) ? 14 : 6) : 0),
                        height: 5,
                        decoration: BoxDecoration(color: i <= _s.stepIdx ? fb.accent : Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              RichRecipeText(text: step.text, dark: true, onLink: (id) => Nav.openRecipe(context, id), fontSize: 22, height: 1.4, color: Colors.white),
              if (step.timerSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: GestureDetector(
                    onTap: () => _startStepTimer(_s, _s.stepIdx, step.timerSeconds!),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: myTimer != null ? fb.accent.withValues(alpha: 0.2) : surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: myTimer != null ? fb.accent : line, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        FbIcon('timer', size: fb.fs(19), color: fb.accent),
                        const SizedBox(width: 9),
                        Text(
                          myTimer != null
                              ? (myTimer.left <= 0 ? app.t('sc_timer_done') : '${fmtTimer(myTimer.left)} · ${app.t('timers_running')}')
                              : '${app.t('sc_start_timer')} · ${fmtTimer(step.timerSeconds)}',
                          style: fb.ui(size: 15.5, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + bottomInset),
          child: Row(
            children: [
              GestureDetector(
                onTap: _s.stepIdx == 0 ? null : () => setState(() => _s.stepIdx--),
                child: Opacity(
                  opacity: _s.stepIdx == 0 ? 0.4 : 1,
                  child: Container(width: 56, height: 56, decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 1.5)), child: const Center(child: FbIcon('chevL', size: 24, color: Colors.white))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _s.stepIdx++),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(16)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_s.stepIdx == steps.length - 1 ? app.t('sc_finish') : app.t('sc_next'), style: fb.ui(size: 17, weight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 8),
                      const FbIcon('chevR', size: 22, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BgDots extends CustomPainter {
  final Color color;
  _BgDots(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 18.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BgDots old) => old.color != color;
}
