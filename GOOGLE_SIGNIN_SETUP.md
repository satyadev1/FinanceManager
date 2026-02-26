# Google Sign-In setup (Fin Manager)

If **Sign in with Google** fails (e.g. "developer config" or error 10), set up OAuth in Google Cloud Console:

## 1. Create / select a project

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.

## 2. Configure OAuth consent screen

1. **APIs & Services** → **OAuth consent screen**.
2. Choose **External** (or Internal for workspace only).
3. Fill App name (e.g. "Fin Manager"), support email, and save.

## 3. Create OAuth 2.0 credentials

### Android client (required)

1. **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**.
2. Application type: **Android**.
3. **Package name:** `com.example.finance_manager` (must match `android/app/build.gradle.kts`).
4. **SHA-1:** Get it by running in a terminal:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Copy the **SHA-1** from the **debug** (or **release** if you use a release keystore) section.
5. Create. You can add a second Android client later for release SHA-1 if needed.

### Web client (recommended if Android-only sign-in still fails)

1. **Create credentials** → **OAuth client ID** → Application type: **Web application**.
2. Name it e.g. "Fin Manager Web".
3. Create and copy the **Client ID** (ends with `.apps.googleusercontent.com`).
4. In the app, set it in `lib/config/app_config.dart`:
   ```dart
   static const String? googleSignInServerClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
   ```

## 4. Enable Google Drive API

1. **APIs & Services** → **Library**.
2. Search **Google Drive API** → Enable.

## 5. Rebuild the app

```bash
flutter clean && flutter run -d <device_id> --release
```

After this, Sign in with Google should work. If it still fails, the in-app error message will show; ensure the package name and SHA-1 match exactly what you added in the Console.
