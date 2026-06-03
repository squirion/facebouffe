import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/sync/sync_backend.dart' show UsernameTakenException;
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

// ── shared chrome ──────────────────────────────────────────────────────────

/// Back-header used by all the account screens. [canPop] hides the back arrow
/// for steps the user shouldn't be able to abandon (username setup).
class _AccountHeader extends StatelessWidget {
  final String title;
  final bool canPop;
  const _AccountHeader({required this.title, this.canPop = true});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return FbHeader(
      child: Padding(
        padding: EdgeInsets.fromLTRB(canPop ? 8 : 20, 8, 20, 12),
        child: Row(children: [
          if (canPop) ...[
            GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: fb.display(size: 25, weight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

/// Full-width accent action button with a busy/disabled state.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _PrimaryButton({required this.label, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final enabled = onTap != null && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 52,
          decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label, style: fb.ui(size: 16, weight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(FbTheme fb, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: fb.ui(size: 16, color: fb.inkFaint),
      isDense: true,
      filled: true,
      fillColor: fb.canvas2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.accent)),
    );

// ── sign-in (email → OTP code) ───────────────────────────────────────────────

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  bool _codeStage = false; // false = enter email, true = enter code
  bool _busy = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  String get _email => _emailCtl.text.trim();

  Future<void> _sendCode(AppState app) async {
    if (!_emailRe.hasMatch(_email)) {
      setState(() => _error = app.t('email_invalid'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await app.sendSignInCode(_email);
      if (!mounted) return;
      setState(() { _codeStage = true; _busy = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = app.t('signin_error'); });
    }
  }

  Future<void> _verify(AppState app) async {
    final code = _codeCtl.text.trim();
    if (code.length < 6) return;
    setState(() { _busy = true; _error = null; });
    try {
      final needsUsername = await app.verifySignInCode(_email, code);
      if (!mounted) return;
      if (needsUsername) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UsernameSetupScreen()));
      } else {
        Navigator.pop(context); // signed in, profile already exists
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = app.t('code_invalid'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          _AccountHeader(title: app.t('signin')),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              children: _codeStage ? _codeBody(app, fb) : _emailBody(app, fb),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _emailBody(AppState app, FbTheme fb) => [
        Text(app.t('signin_intro'), style: fb.ui(size: 15, color: fb.inkSoft, height: 1.45)),
        const SizedBox(height: 22),
        Text(app.t('email_label').toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onChanged: (_) { if (_error != null) setState(() => _error = null); },
          onSubmitted: (_) => _sendCode(app),
          style: fb.ui(size: 16),
          decoration: _fieldDecoration(fb, app.t('email_ph')),
        ),
        if (_error != null) _errorText(fb, _error!),
        const SizedBox(height: 20),
        _PrimaryButton(label: _busy ? app.t('sending') : app.t('send_code'), busy: _busy, onTap: () => _sendCode(app)),
        const SizedBox(height: 18),
        Text(app.t('signin_local_note'), style: fb.ui(size: 13, color: fb.inkFaint, height: 1.4)),
      ];

  List<Widget> _codeBody(AppState app, FbTheme fb) => [
        Text(app.t('code_sent_sub').replaceFirst('%s', _email), style: fb.ui(size: 15, color: fb.inkSoft, height: 1.45)),
        const SizedBox(height: 22),
        Text(app.t('code_label').toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.go,
          maxLength: 6,
          onChanged: (_) { if (_error != null) setState(() => _error = null); setState(() {}); },
          onSubmitted: (_) => _verify(app),
          style: fb.display(size: 24, weight: FontWeight.w600, letterSpacing: 6),
          decoration: _fieldDecoration(fb, app.t('code_ph')).copyWith(counterText: ''),
        ),
        if (_error != null) _errorText(fb, _error!),
        const SizedBox(height: 20),
        _PrimaryButton(label: _busy ? app.t('verifying') : app.t('verify_code'), busy: _busy, onTap: _codeCtl.text.trim().length >= 6 ? () => _verify(app) : null),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(onTap: _busy ? null : () => _sendCode(app), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(app.t('resend_code'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.accent)))),
          Text('·', style: fb.ui(size: 14, color: fb.inkFaint)),
          GestureDetector(onTap: _busy ? null : () => setState(() { _codeStage = false; _error = null; _codeCtl.clear(); }), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(app.t('change_email'), style: fb.ui(size: 14, weight: FontWeight.w700, color: fb.inkSoft)))),
        ]),
      ];

  Widget _errorText(FbTheme fb, String msg) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(msg, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: const Color(0xFFC0563B))),
      );
}

// ── username setup ───────────────────────────────────────────────────────────

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

enum _Avail { idle, checking, free, taken, invalid }

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _ctl = TextEditingController();
  Timer? _debounce;
  _Avail _state = _Avail.idle;
  bool _claiming = false;
  String? _claimError; // non-"taken" failure (network / server / RLS)
  int _checkSeq = 0; // guards against out-of-order async results

  static final _re = RegExp(r'^[a-z0-9_]{3,20}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  String get _handle => _ctl.text.trim().toLowerCase();

  void _onChanged(AppState app) {
    _debounce?.cancel();
    if (_claimError != null) _claimError = null;
    final h = _handle;
    if (h.isEmpty) {
      setState(() => _state = _Avail.idle);
      return;
    }
    if (!_re.hasMatch(h)) {
      setState(() => _state = _Avail.invalid);
      return;
    }
    setState(() => _state = _Avail.checking);
    final seq = ++_checkSeq;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await app.usernameAvailable(h);
        if (!mounted || seq != _checkSeq) return;
        setState(() => _state = free ? _Avail.free : _Avail.taken);
      } catch (_) {
        if (!mounted || seq != _checkSeq) return;
        setState(() => _state = _Avail.idle);
      }
    });
  }

  Future<void> _claim(AppState app) async {
    if (_state != _Avail.free) return;
    setState(() { _claiming = true; _claimError = null; });
    try {
      await app.claimUsername(_handle);
      if (!mounted) return;
      Navigator.pop(context);
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() { _claiming = false; _state = _Avail.taken; });
    } catch (_) {
      // network / server / policy error — not a name collision
      if (!mounted) return;
      setState(() { _claiming = false; _claimError = app.t('signin_error'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    return PopScope(
      canPop: false, // must choose a username before continuing
      child: Scaffold(
        backgroundColor: fb.canvas,
        body: Column(
          children: [
            _AccountHeader(title: app.t('choose_username'), canPop: false),
            Expanded(
              child: ScreenScroll(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  Text(app.t('username_intro'), style: fb.ui(size: 15, color: fb.inkSoft, height: 1.45)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _ctl,
                    autofocus: true,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    maxLength: 20,
                    onChanged: (_) => _onChanged(app),
                    style: fb.ui(size: 18, weight: FontWeight.w600),
                    decoration: _fieldDecoration(fb, 'nom_utilisateur').copyWith(
                      counterText: '',
                      prefixText: '@ ',
                      prefixStyle: fb.ui(size: 18, weight: FontWeight.w600, color: fb.inkFaint),
                      suffixIcon: _suffix(fb),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_hint(app), style: fb.ui(size: 13, weight: FontWeight.w600, color: _hintColor(fb), height: 1.4)),
                  const SizedBox(height: 8),
                  Text(app.t('username_permanent'), style: fb.ui(size: 13, color: fb.inkFaint)),
                  if (_claimError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_claimError!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: const Color(0xFFC0563B)))),
                  const SizedBox(height: 22),
                  _PrimaryButton(label: app.t('continue_btn'), busy: _claiming, onTap: _state == _Avail.free ? () => _claim(app) : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _suffix(FbTheme fb) {
    switch (_state) {
      case _Avail.checking:
        return Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fb.inkFaint)));
      case _Avail.free:
        return Icon(Icons.check_circle, color: fb.accent, size: 22);
      case _Avail.taken:
      case _Avail.invalid:
        return const Icon(Icons.error_outline, color: Color(0xFFC0563B), size: 22);
      case _Avail.idle:
        return null;
    }
  }

  String _hint(AppState app) {
    switch (_state) {
      case _Avail.checking:
        return app.t('username_checking');
      case _Avail.free:
        return '@$_handle ${app.t('username_available')}';
      case _Avail.taken:
        return '@$_handle ${app.t('username_taken')}';
      case _Avail.invalid:
        return app.t('username_invalid');
      case _Avail.idle:
        return app.t('username_invalid');
    }
  }

  Color _hintColor(FbTheme fb) {
    switch (_state) {
      case _Avail.free:
        return fb.accent;
      case _Avail.taken:
      case _Avail.invalid:
        return const Color(0xFFC0563B);
      default:
        return fb.inkFaint;
    }
  }
}

// ── account (signed-in) ──────────────────────────────────────────────────────

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, AppState app) async {
    final fb = context.fb;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fb.card,
        title: Text(app.t('signout_confirm'), style: fb.display(size: 19, weight: FontWeight.w600)),
        content: Text(app.t('signout_note'), style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('signout'), style: fb.ui(size: 14, weight: FontWeight.w700, color: const Color(0xFFC0563B)))),
        ],
      ),
    );
    if (go != true) return;
    await app.signOutAccount();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final acct = app.account;

    // Signed out — render blank during the pop animation. _confirmSignOut owns
    // the navigation (popping here too would double-pop past the root → black).
    if (acct == null) {
      return Scaffold(backgroundColor: fb.canvas, body: const SizedBox.shrink());
    }

    final handle = acct.username ?? '…';
    final initial = (acct.username?.isNotEmpty == true ? acct.username! : acct.email).characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          _AccountHeader(title: app.t('account')),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                // identity card
                Container(
                  margin: const EdgeInsets.only(bottom: 22),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(20), boxShadow: fb.shadow),
                  child: Row(children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text(initial, style: fb.display(size: 26, weight: FontWeight.w600, color: Colors.white))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('@$handle', style: fb.display(size: 21, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(acct.email, style: fb.ui(size: 13.5, color: fb.inkSoft)),
                        ],
                      ),
                    ),
                  ]),
                ),
                _InfoGroup(label: app.t('account_sync'), rows: [
                  _SyncRow(),
                ]),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _confirmSignOut(context, app),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(children: [
                      const Icon(Icons.logout, size: 20, color: Color(0xFFC0563B)),
                      const SizedBox(width: 12),
                      Text(app.t('signout'), style: fb.ui(size: 15.5, weight: FontWeight.w700, color: const Color(0xFFC0563B))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  final String label;
  final List<Widget> rows;
  const _InfoGroup({required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text(label.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5))),
        Container(decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow), clipBehavior: Clip.antiAlias, child: Column(children: rows)),
      ],
    );
  }
}

/// Live sync-status row. Tapping it forces a re-sync.
class _SyncRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final (label, color, spin) = switch (app.syncStatus) {
      SyncStatus.syncing => (app.t('sync_syncing'), fb.inkSoft, true),
      SyncStatus.synced => (app.t('sync_synced'), fb.accent, false),
      SyncStatus.offline => (app.t('sync_offline'), fb.inkSoft, false),
      SyncStatus.error => (app.t('sync_error'), const Color(0xFFC0563B), false),
      SyncStatus.idle => (app.t('sync_synced'), fb.inkSoft, false),
    };
    return GestureDetector(
      onTap: () => app.runCloudSync(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(children: [
          Expanded(child: Text(app.t('account_sync'), style: fb.ui(size: 15.5, weight: FontWeight.w600))),
          if (spin) ...[
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fb.inkSoft)),
            const SizedBox(width: 8),
          ],
          Text(label, style: fb.ui(size: 14.5, weight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

/// Modal asking a later device whether to add its local-only recipes to the
/// account (spec §8). Shown automatically when [AppState.migrationPending].
Future<void> showMigrationSheet(BuildContext context, AppState app) async {
  final fb = context.fb;
  final n = app.pendingMigrationCount;
  if (n == 0) {
    await app.resolveMigration(false);
    return;
  }
  final add = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: fb.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.t('migrate_title'), style: fb.display(size: 21, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(app.t('migrate_body').replaceFirst('%s', '$n'), style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.45)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(app.t('migrate_add'), style: fb.ui(size: 15.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: fb.line)),
                alignment: Alignment.center,
                child: Text(app.t('migrate_keep'), style: fb.ui(size: 15.5, weight: FontWeight.w600, color: fb.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await app.resolveMigration(add ?? false);
}
