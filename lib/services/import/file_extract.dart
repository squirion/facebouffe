import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../recipe_import.dart' show ImportException, RecipeImport;

/// Pulls plain text out of a picked recipe file (PDF / .docx / .txt / .md /
/// .html) so it can flow into the same AI import path as pasted text. Throws an
/// [ImportException] whose code the import sheet maps to a message
/// ('pdf_scanned', 'file_empty', 'file_unreadable').
class FileImport {
  static const allowedExtensions = ['pdf', 'docx', 'txt', 'md', 'markdown', 'text', 'html', 'htm'];
  static const _maxChars = 16000; // keep the AI payload (and cost) sane

  static Future<String> extractText({required String name, required Uint8List bytes}) async {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    String text;
    switch (ext) {
      case 'pdf':
        text = _pdf(bytes);
        if (text.trim().length < 10) throw ImportException('pdf_scanned'); // no text layer
        break;
      case 'docx':
        text = _docx(bytes);
        break;
      case 'html':
      case 'htm':
        text = RecipeImport.htmlToText(utf8.decode(bytes, allowMalformed: true));
        break;
      default: // txt, md, markdown, or anything else → treat as plain text
        text = utf8.decode(bytes, allowMalformed: true);
    }
    text = text.trim();
    if (text.isEmpty) throw ImportException('file_empty');
    return text.length > _maxChars ? text.substring(0, _maxChars) : text;
  }

  static String _pdf(Uint8List bytes) {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
      return PdfTextExtractor(doc).extractText();
    } catch (e) {
      throw ImportException('file_unreadable', '$e');
    } finally {
      doc?.dispose();
    }
  }

  // A .docx is a zip; visible text lives in word/document.xml inside <w:t> runs.
  // Turn paragraph/tab/break tags into whitespace, strip the rest, unescape.
  static String _docx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? entry;
      for (final f in archive.files) {
        if (f.name == 'word/document.xml') {
          entry = f;
          break;
        }
      }
      if (entry == null) throw ImportException('file_unreadable', 'no word/document.xml');
      var s = utf8.decode((entry.content as List<int>), allowMalformed: true);
      s = s
          .replaceAll(RegExp(r'<w:p\b[^>]*/>'), '\n')
          .replaceAll('</w:p>', '\n')
          .replaceAll(RegExp(r'<w:tab\b[^>]*/?>'), '\t')
          .replaceAll(RegExp(r'<w:br\b[^>]*/?>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ''); // strip tags → leaves <w:t> text
      s = _unescapeXml(s).replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
      return s;
    } on ImportException {
      rethrow;
    } catch (e) {
      throw ImportException('file_unreadable', '$e');
    }
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
}
