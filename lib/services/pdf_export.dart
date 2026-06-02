import 'package:flutter/material.dart' hide Step;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/format.dart';
import '../data/i18n.dart';
import '../state/app_state.dart';

/// Renders one or more recipes to a PDF in the user's current language + units
/// and opens the system print/share sheet. Temperature and link tokens are
/// resolved to plain text so the document reads naturally.
Future<void> exportRecipesPdf(BuildContext context, List<Recipe> recipes) async {
  final app = context.read<AppState>();
  final lang = app.lang;
  final prefs = app.prefs;
  final tempPref = prefTempUnit(prefs);

  String plain(String text) {
    var s = text;
    // temperatures → converted display value
    s = s.replaceAllMapped(RegExp(r'\{\{temp:([0-9.]+):([cfCF])\}\}'), (m) => fmtTemp(num.parse(m.group(1)!), m.group(2)!, tempPref));
    // links → the linked recipe's title
    s = s.replaceAllMapped(RegExp(r'\{\{link:([^}]+)\}\}'), (m) => app.getRecipe(m.group(1))?.title ?? '');
    return s;
  }

  final doc = pw.Document();
  final accent = PdfColor.fromInt(0xFFC0563B);

  pw.Widget buildRecipe(Recipe r) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(r.title, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: accent)),
        if (r.source != null && r.source!.isNotEmpty)
          pw.Text(r.source!, style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        pw.Text('${tr(lang, 'prep')}: ${fmtDuration(r.prepTimeMinutes, lang)}   ·   ${tr(lang, 'cook')}: ${fmtDuration(r.cookTimeMinutes, lang)}   ·   ${r.servings} ${tr(lang, 'servings')}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        if (r.description.isNotEmpty) ...[
          pw.Text(plain(r.description), style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
          pw.SizedBox(height: 14),
        ],
        pw.Text(tr(lang, 'ingredients'), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final (s, sec) in groupedSections(r.ingredients, (i) => i.group).indexed) ...[
          if (sec.hasHeader)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: s == 0 ? 0 : 6, bottom: 3),
              child: pw.Text(sec.name!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
            ),
          ...sec.items.map((ing) {
            final d = displayIngredient(ing.quantity, ing.unit, ing.name, ing.note, 1, prefs, lang);
            final qty = '${d.qtyText}${d.unitText.isNotEmpty ? ' ${d.unitText}' : ''}';
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.SizedBox(width: 80, child: pw.Text(qty, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent))),
                pw.Expanded(child: pw.Text(d.note != null ? '${d.name} · ${d.note}' : d.name, style: const pw.TextStyle(fontSize: 11))),
              ]),
            );
          }),
        ],
        pw.SizedBox(height: 14),
        pw.Text(tr(lang, 'steps'), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final (s, sec) in groupedSections(r.steps, (st) => st.group).indexed) ...[
          if (sec.hasHeader)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: s == 0 ? 0 : 8, bottom: 4),
              child: pw.Text(sec.name!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
            ),
          for (int k = 0; k < sec.items.length; k++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 18, child: pw.Text('${sec.indices[k] + 1}.', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent))),
                pw.Expanded(
                  child: pw.Text(
                    plain(sec.items[k].text) + (sec.items[k].timerSeconds != null ? '  (${fmtTimer(sec.items[k].timerSeconds)})' : ''),
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                  ),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) {
        final widgets = <pw.Widget>[];
        for (int i = 0; i < recipes.length; i++) {
          widgets.add(buildRecipe(recipes[i]));
          if (i < recipes.length - 1) {
            widgets.add(pw.SizedBox(height: 24));
            widgets.add(pw.Divider());
            widgets.add(pw.SizedBox(height: 24));
          }
        }
        return widgets;
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: recipes.length == 1 ? recipes.first.title : 'facebouffe');
}
