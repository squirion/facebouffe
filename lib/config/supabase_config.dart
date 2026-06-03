/// Supabase connection config.
///
/// These two values are **public by design**: the publishable key is the
/// client-side key and is safe to ship in the app binary — Row-Level Security
/// is what actually protects the data. The **secret key is NEVER here** (it
/// lives only server-side / in CI). Rotating the publishable key = edit this
/// file. Overridable at build time via --dart-define for CI/staging.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ubzjhklkpxcbrghfmjdd.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_HznZxp4lHfxakg3sHq0N9A_aSYJRLgB',
  );
}
