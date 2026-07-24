import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/crash_log.dart';
import '../services/update_check.dart';
import '../services/web_env.dart';
import 'crash_report_sheet.dart';
import 'fb_icon.dart';

Future<void> _open(String url) async {
  // Don't gate on canLaunchUrl: on Android 11+ it can return false for https
  // even when a browser exists. Just launch and ignore failures.
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Shared dismissible bar look used by both banners.
class _Bar extends StatelessWidget {
  final String icon;
  final Widget content;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  const _Bar({required this.icon, required this.content, this.actionLabel, this.onAction, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: fb.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fb.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          FbIcon(icon, size: 20, color: fb.accent),
          const SizedBox(width: 11),
          Expanded(child: content),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(color: fb.accent, borderRadius: BorderRadius.circular(10)),
                child: Text(actionLabel!, style: fb.ui(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(padding: EdgeInsets.all(6), child: FbIcon('x', size: 16)),
          ),
        ],
      ),
    );
  }
}

/// "Update available" bar — checks the deployed version.json on first build.
/// Android offers a download; web offers a refresh.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateInfo? _info;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    UpdateCheck.check().then((info) {
      if (mounted && info != null) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final fb = context.fb;
    final info = _info;
    if (info == null || _hidden) return const SizedBox.shrink();
    return _Bar(
      icon: 'flame',
      content: Text(
        '${app.t('update_available')}${info.version.isNotEmpty ? ' · v${info.version}' : ''}',
        style: fb.ui(size: 13.5, weight: FontWeight.w600),
      ),
      actionLabel: kIsWeb ? app.t('update_refresh') : app.t('update_get'),
      onAction: () {
        if (kIsWeb) {
          reloadApp();
        } else {
          _open(info.apkUrl.isNotEmpty ? info.apkUrl : kApkLatestUrl);
        }
      },
      onDismiss: () {
        UpdateCheck.dismiss(info.build);
        setState(() => _hidden = true);
      },
    );
  }
}

/// "Looks like the app crashed last time — send a report?" Shown when CrashLog
/// detected a crash for the previous session (explicit Dart marker or native
/// dirty-exit). Dismiss = decline; the offer doesn't come back for that crash.
class CrashReportBanner extends StatefulWidget {
  const CrashReportBanner({super.key});
  @override
  State<CrashReportBanner> createState() => _CrashReportBannerState();
}

class _CrashReportBannerState extends State<CrashReportBanner> {
  @override
  Widget build(BuildContext context) {
    if (!CrashLog.instance.startupCrashPending) return const SizedBox.shrink();
    final app = context.read<AppState>();
    final fb = context.fb;
    return _Bar(
      icon: 'flame',
      content: Text(app.t('crash_banner'), style: fb.ui(size: 13.5, weight: FontWeight.w600, height: 1.3)),
      actionLabel: app.t('crash_banner_send'),
      onAction: () async {
        final log = CrashLog.instance.previousSessionLog ?? CrashLog.instance.dump();
        await showCrashReportSheet(context, kind: 'crash', log: log);
        if (mounted) setState(() {}); // sheet clears the pending flag on send
      },
      onDismiss: () {
        CrashLog.instance.clearStartupPending();
        setState(() {});
      },
    );
  }
}

/// "Your report was updated" — the dev set a status/note on a report this
/// device sent. Dismiss marks everything seen.
class CrashStatusBanner extends StatefulWidget {
  const CrashStatusBanner({super.key});
  @override
  State<CrashStatusBanner> createState() => _CrashStatusBannerState();
}

class _CrashStatusBannerState extends State<CrashStatusBanner> {
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>(); // statusNotice is set during checkCrashReportStatuses
    final status = CrashLog.instance.statusNotice;
    if (status == null) return const SizedBox.shrink();
    final app = context.read<AppState>();
    final fb = context.fb;
    final note = CrashLog.instance.statusNoticeNote;
    return _Bar(
      icon: 'check',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${app.t('report_status_updated')} · ${crashStatusLabel(app, status)}',
              style: fb.ui(size: 13.5, weight: FontWeight.w600, height: 1.3)),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note, style: fb.ui(size: 12.5, color: fb.inkSoft, height: 1.3)),
            ),
        ],
      ),
      onDismiss: () {
        CrashLog.instance.markStatusesSeen();
        setState(() {});
      },
    );
  }
}

/// Localized label for a crash-report status (raw value if unknown).
String crashStatusLabel(AppState app, String status) {
  switch (status) {
    case 'new':
      return app.t('status_new');
    case 'investigating':
      return app.t('status_investigating');
    case 'fixed':
      return app.t('status_fixed');
    case 'closed':
      return app.t('status_closed');
    default:
      return status;
  }
}

/// Web-only promo: Android browsers get an "install the app" link to the APK;
/// iOS Safari users get an Add-to-Home-Screen hint. Hidden in the native app
/// and once installed as a PWA. Dismissal is remembered.
class WebPromoBanner extends StatefulWidget {
  const WebPromoBanner({super.key});
  @override
  State<WebPromoBanner> createState() => _WebPromoBannerState();
}

class _WebPromoBannerState extends State<WebPromoBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _hidden || isStandalonePwa()) return const SizedBox.shrink();
    final app = context.read<AppState>();
    final fb = context.fb;
    final ua = webUserAgent().toLowerCase();
    final isAndroid = ua.contains('android');
    final isIos = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    if (!isAndroid && !isIos) return const SizedBox.shrink();

    if (isAndroid) {
      return _Bar(
        icon: 'basket',
        content: Text(app.t('install_android'), style: fb.ui(size: 13.5, weight: FontWeight.w600)),
        actionLabel: app.t('install_get'),
        // One-tap direct download via top-level navigation (Content-Disposition:
        // attachment → downloads without leaving the app). Avoids the popup
        // download that stalled on Android Chrome.
        onAction: () => webDownload(kApkLatestUrl),
        onDismiss: () => setState(() => _hidden = true),
      );
    }
    return _Bar(
      icon: 'plus',
      content: Text(app.t('ios_a2hs'), style: fb.ui(size: 13, weight: FontWeight.w600, height: 1.35)),
      onDismiss: () => setState(() => _hidden = true),
    );
  }
}
