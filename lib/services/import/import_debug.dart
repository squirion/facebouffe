import '../crash_log.dart';

/// Verbose import diagnostics (§2f debugging). Flip [kImportDebug] to false — or
/// delete this file and its references — to remove all the extra logging and the
/// raw on-screen error detail once the import engine is stable.
const bool kImportDebug = true;

void importLog(String message) {
  // Always breadcrumbed (crash reports need the import trail); CrashLog
  // echoes to debugPrint in debug builds, so console behavior is unchanged.
  CrashLog.instance.add('import', message);
}
