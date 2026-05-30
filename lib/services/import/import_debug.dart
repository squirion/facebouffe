import 'package:flutter/foundation.dart';

/// Verbose import diagnostics (§2f debugging). Flip [kImportDebug] to false — or
/// delete this file and its references — to remove all the extra logging and the
/// raw on-screen error detail once the import engine is stable.
const bool kImportDebug = true;

void importLog(String message) {
  if (kImportDebug) debugPrint('[import] $message');
}
