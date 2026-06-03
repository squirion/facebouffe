import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/sync/sync_backend.dart' show FriendEdge;
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';
import 'settings_screen.dart' show SettingsGroup;

/// The "Amis" hub: add by exact username, manage incoming/outgoing requests,
/// and the accepted friends list (with remove / block).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _ctl = TextEditingController();
  bool _sending = false;
  String? _flash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshFriends();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _showFlash(String msg) {
    setState(() => _flash = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _submit(AppState app) async {
    final handle = _ctl.text.trim();
    if (handle.isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await app.addFriend(handle);
    if (!mounted) return;
    setState(() => _sending = false);
    switch (res.result) {
      case AddFriendResult.sent:
        _ctl.clear();
        _showFlash('${app.t('request_sent')} @${res.username}');
      case AddFriendResult.notFound:
        _showFlash(app.t('user_not_found'));
      case AddFriendResult.self:
        _showFlash(app.t('cannot_self'));
      case AddFriendResult.already:
        _showFlash(app.t('already_friend'));
      case AddFriendResult.error:
        _showFlash(app.t('signin_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final incoming = app.incomingRequests;
    final outgoing = app.outgoingRequests;
    final accepted = app.acceptedFriends;

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
                Text(app.t('social_friends'), style: fb.display(size: 25, weight: FontWeight.w600)),
              ]),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ScreenScroll(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    // add a friend
                    SettingsGroup(label: app.t('add_friend'), children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Row(children: [
                          Text('@', style: fb.display(size: 18, weight: FontWeight.w600, color: fb.inkFaint)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _ctl,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(app),
                              style: fb.ui(size: 15.5),
                              decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, hintText: app.t('add_friend_ph'), hintStyle: fb.ui(size: 15.5, color: fb.inkFaint)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _ctl.text.trim().isEmpty ? null : () => _submit(app),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(color: _ctl.text.trim().isEmpty ? fb.line : fb.accent, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: _sending
                                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(app.t('send_request'), style: fb.ui(size: 13.5, weight: FontWeight.w700, color: _ctl.text.trim().isEmpty ? fb.inkFaint : Colors.white)),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                    // incoming requests
                    if (incoming.isNotEmpty)
                      SettingsGroup(label: app.t('requests_in'), children: [
                        for (int i = 0; i < incoming.length; i++)
                          _FriendRow(
                            edge: incoming[i],
                            last: i == incoming.length - 1,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              _PillButton(label: app.t('accept'), primary: true, onTap: () => app.acceptFriendRequest(incoming[i].userId)),
                              const SizedBox(width: 8),
                              _PillButton(label: app.t('decline'), primary: false, onTap: () => app.removeFriendship(incoming[i].userId)),
                            ]),
                          ),
                      ]),
                    // outgoing requests
                    if (outgoing.isNotEmpty)
                      SettingsGroup(label: app.t('requests_out'), children: [
                        for (int i = 0; i < outgoing.length; i++)
                          _FriendRow(
                            edge: outgoing[i],
                            last: i == outgoing.length - 1,
                            trailing: GestureDetector(
                              onTap: () => app.removeFriendship(outgoing[i].userId),
                              behavior: HitTestBehavior.opaque,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                FbIcon('clock', size: fb.fs(14), color: fb.inkFaint),
                                const SizedBox(width: 5),
                                Text(app.t('pending'), style: fb.ui(size: 13, weight: FontWeight.w600, color: fb.inkFaint)),
                                const SizedBox(width: 8),
                                FbIcon('x', size: fb.fs(16), color: fb.inkSoft),
                              ]),
                            ),
                          ),
                      ]),
                    // accepted friends
                    SettingsGroup(label: '${app.t('friends_list')} · ${accepted.length}', children: [
                      if (accepted.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22), child: Text(app.t('friends_empty'), textAlign: TextAlign.center, style: fb.ui(size: 14, color: fb.inkSoft, height: 1.5)))
                      else
                        for (int i = 0; i < accepted.length; i++)
                          _FriendRow(
                            edge: accepted[i],
                            last: i == accepted.length - 1,
                            trailing: GestureDetector(
                              onTap: () => _friendMenu(app, accepted[i]),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(padding: const EdgeInsets.all(4), child: FbIcon('more', size: fb.fs(20), color: fb.inkSoft)),
                            ),
                          ),
                    ]),
                  ],
                ),
                if (_flash != null)
                  Positioned(
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: fb.ink, borderRadius: BorderRadius.circular(999), boxShadow: fb.shadow),
                        child: Text(_flash!, style: fb.ui(size: 13.5, weight: FontWeight.w600, color: fb.canvas)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _friendMenu(AppState app, FriendEdge edge) async {
    final fb = context.fb;
    final handle = edge.username ?? '…';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: fb.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Align(alignment: Alignment.centerLeft, child: Text('@$handle', style: fb.display(size: 19, weight: FontWeight.w600)))),
            _SheetRow(icon: 'x', label: app.t('remove_friend'), onTap: () => Navigator.pop(ctx, 'remove')),
            _SheetRow(icon: 'trash', label: app.t('block_user'), danger: true, onTap: () => Navigator.pop(ctx, 'block')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'remove') {
      await app.removeFriendship(edge.userId);
    } else if (choice == 'block') {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: fb.card,
          title: Text(app.t('block_confirm').replaceFirst('%s', handle), style: fb.display(size: 19, weight: FontWeight.w600)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('block_user'), style: fb.ui(size: 14, weight: FontWeight.w700, color: const Color(0xFFC0563B)))),
          ],
        ),
      );
      if (ok == true) await app.blockUser(edge.userId);
    }
  }
}

class _FriendRow extends StatelessWidget {
  final FriendEdge edge;
  final Widget trailing;
  final bool last;
  const _FriendRow({required this.edge, required this.trailing, this.last = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final handle = edge.username ?? '…';
    final initial = (edge.username?.isNotEmpty == true ? edge.username! : '?').characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text(initial, style: fb.display(size: 18, weight: FontWeight.w600, color: Colors.white))),
        const SizedBox(width: 12),
        Expanded(child: Text('@$handle', style: fb.ui(size: 15.5, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        trailing,
      ]),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? fb.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: primary ? null : Border.all(color: fb.line),
        ),
        alignment: Alignment.center,
        child: Text(label, style: fb.ui(size: 13, weight: FontWeight.w700, color: primary ? Colors.white : fb.inkSoft)),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;
  const _SheetRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final color = danger ? const Color(0xFFC0563B) : fb.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          FbIcon(icon, size: 18, color: danger ? color : fb.inkSoft),
          const SizedBox(width: 12),
          Text(label, style: fb.ui(size: 15, weight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
