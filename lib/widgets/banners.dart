import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/update_check.dart';
import '../services/web_env.dart';
import 'fb_icon.dart';

Future<void> _open(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        onAction: () => _open(kApkLatestUrl),
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
