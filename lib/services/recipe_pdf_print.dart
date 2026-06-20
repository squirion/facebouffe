// Loads a self-contained print-ready HTML document (built by recipe_pdf_html.dart)
// into a real browser engine and opens the system print-to-PDF flow. Native
// (Android) uses a headless WebView + the print framework; web uses a hidden
// iframe + window.print(). Mirrors the conditional-import pattern in web_env.dart.
//
// Contract (declared identically in both impls):
//   Future<void> printRecipeHtml(String html, {required String docName})
export 'recipe_pdf_print_io.dart' if (dart.library.js_interop) 'recipe_pdf_print_web.dart';
