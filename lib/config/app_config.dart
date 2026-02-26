/// App configuration. No Supabase; sync is via Google Drive CSV only.
/// Optional: set offersApiBaseUrl / offersApiKey if you use an external Offers API.
class AppConfig {
  /// Google Drive folder name for app data (CSV files).
  static const String driveFolderName = 'FinManager';

  /// Optional: OAuth 2.0 Web client ID (xxx.apps.googleusercontent.com) from Google Cloud Console.
  /// If sign-in fails with DEVELOPER_ERROR / 10, create an OAuth "Web application" client in the
  /// same project and add its Client ID here. Also ensure an Android OAuth client exists with
  /// package name com.example.finance_manager and your app's SHA-1 (run: cd android && ./gradlew signingReport).
  static const String? googleSignInServerClientId = null;

  /// Optional: base URL for offers API (e.g. GET /offers?card_scheme=visa).
  static const String? offersApiBaseUrl = null;

  /// Optional: API key for offers API if required.
  static const String? offersApiKey = null;

  /// Optional: Logo.dev API token for bank/fintech logos in SMS import.
  /// When set, remote logos are fetched. When null, fallback to initial avatar.
  static const String? smsLogoApiToken = null;
}
