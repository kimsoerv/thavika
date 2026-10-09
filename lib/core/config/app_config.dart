/// Settings for cloud sync, passed in at build time:
///
///   flutter run --dart-define-from-file=env.json
///
/// Without them the app still works fully, offline, as a guest.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// OAuth client of type "Web application" (also used on Android).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// OAuth client of type "iOS".
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// True when a Supabase project is configured, so sign-in and sync can run.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
