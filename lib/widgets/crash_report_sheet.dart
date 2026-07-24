import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/crash_log.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'fb_icon.dart';

/// Bottom sheet to send a crash/problem report: optional notes + one Send
/// button (online only). [kind] is 'crash' (offered after a detected crash,
/// sends the previous session's log) or 'manual' (Settings → report a
/// problem, sends the current session's log).
Future<void> showCrashReportSheet(BuildContext context, {required String kind, required String log}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // keyboard pushes the sheet up
    backgroundColor: context.fb.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _CrashReportSheet(kind: kind, log: log),
  );
}

class _CrashReportSheet extends StatefulWidget {
  final String kind;
  final String log;
  const _CrashReportSheet({required this.kind, required this.log});

  @override
  State<_CrashReportSheet> createState() => _CrashReportSheetState();
}

class _CrashReportSheetState extends State<_CrashReportSheet> {
  final _notes = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send(AppState app) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await app.sendCrashReport(kind: widget.kind, notes: _notes.text.trim(), log: widget.log);
      if (widget.kind == 'crash') CrashLog.instance.clearStartupPending();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('report_sent'))));
    } catch (e) {
      CrashLog.instance.add('report', 'send failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('report_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final online = app.online;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(app.t('report_title'), style: fb.display(size: 21, weight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(app.t('report_log_hint'), style: fb.ui(size: 13.5, color: fb.inkSoft)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _notes,
                maxLines: 4,
                minLines: 2,
                maxLength: 4000,
                style: fb.ui(size: 14.5),
                decoration: InputDecoration(
                  hintText: app.t('report_notes_ph'),
                  hintStyle: fb.ui(size: 14, color: fb.inkFaint),
                  counterText: '',
                  filled: true,
                  fillColor: fb.cardSoft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fb.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fb.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fb.accent)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: online && !_sending ? () => _send(app) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: online ? fb.accent : fb.cardSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: online ? fb.accent : fb.line),
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FbIcon('check', size: 18, color: online ? Colors.white : fb.inkFaint),
                                const SizedBox(width: 9),
                                Text(
                                  online ? app.t('report_send') : app.t('report_offline'),
                                  style: fb.ui(size: 15.5, weight: FontWeight.w700, color: online ? Colors.white : fb.inkFaint),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
