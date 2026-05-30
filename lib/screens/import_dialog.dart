import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../nav.dart';
import '../services/recipe_import.dart';
import '../widgets/fb_icon.dart';

/// Long-press on the "+" opens this: paste a recipe URL from a supported site
/// (Ricardo for now); Import fetches + parses it and opens the editor pre-filled
/// for the user to validate before saving.
Future<void> showImportDialog(BuildContext context) async {
  final url = await showDialog<String>(context: context, builder: (_) => const _ImportDialog());
  if (url == null || !context.mounted) return;
  await _runImport(context, url);
}

Future<void> _runImport(BuildContext context, String url) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final fb = context.fb;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fb.accent)),
          const SizedBox(width: 14),
          Text(app.t('importing'), style: fb.ui(size: 15, weight: FontWeight.w600)),
        ]),
      ),
    ),
  );

  try {
    final result = await RecipeImport.importFromUrl(url);
    final heroPath = result.heroImageUrl != null ? await RecipeImport.downloadImage(result.heroImageUrl!) : null;
    app.setRecipePhoto('__draft', heroPath);
    if (!context.mounted) return;
    Navigator.pop(context); // close loading
    Nav.editRecipeInitial(context, result.recipe);
    if (result.suggestedTags.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('${app.t('import_tags_hint')} ${result.suggestedTags.join(', ')}')));
    }
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading
    messenger.showSnackBar(SnackBar(content: Text(app.t('import_failed'))));
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctl = TextEditingController();
  String _url = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.read<AppState>();
    final trimmed = _url.trim();
    final supported = trimmed.isNotEmpty && RecipeImport.isSupported(trimmed);
    final showUnsupported = trimmed.isNotEmpty && !supported;

    return AlertDialog(
      backgroundColor: fb.card,
      title: Text(app.t('import_web_title'), style: fb.display(size: 20, weight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctl,
            onChanged: (v) => setState(() => _url = v),
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: fb.ui(size: 15),
            decoration: InputDecoration(
              hintText: app.t('import_url_hint'),
              hintStyle: fb.ui(size: 15, color: fb.inkFaint),
              isDense: true,
              filled: true,
              fillColor: fb.canvas2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: fb.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: fb.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: fb.accent)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FbIcon(showUnsupported ? 'x' : 'check', size: 15, color: showUnsupported ? const Color(0xFFC0563B) : (supported ? const Color(0xFF6BA368) : fb.inkFaint)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  showUnsupported ? app.t('import_unsupported') : app.t('import_supported_hint'),
                  style: fb.ui(size: 12.5, color: showUnsupported ? const Color(0xFFC0563B) : fb.inkSoft, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(app.t('cancel'), style: fb.ui(size: 14, weight: FontWeight.w600, color: fb.inkSoft)),
        ),
        TextButton(
          onPressed: supported ? () => Navigator.pop(context, trimmed) : null,
          child: Text(app.t('import_action'), style: fb.ui(size: 14, weight: FontWeight.w700, color: supported ? fb.accent : fb.inkFaint)),
        ),
      ],
    );
  }
}
