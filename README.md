# Fin Manager — Android & Web with synced data

One app that runs on **Android** and **Web**, with **data synced** between both via a shared backend.

## How sync works

```
┌─────────────────┐                    ┌──────────────────┐
│  Android app    │                    │   Web app        │
│  (Flutter)      │                    │   (Flutter Web)  │
└────────┬────────┘                    └────────┬─────────┘
         │                                      │
         │         Same backend                 │
         └──────────────┬───────────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  Supabase        │
              │  (Postgres + API  │
              │   + Realtime)    │
              └──────────────────┘
```

- **Single codebase**: Flutter builds both the Android app and the web app.
- **Single source of truth**: Supabase holds all data; both clients read/write the same tables.
- **Realtime (optional)**: Changes on one device show up on the other without refresh.

## Setup

### 1. Install Flutter

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and ensure `flutter doctor` passes (Android toolchain for Android, Chrome for web).

### 2. Create the Flutter project (Android + Web)

If this folder doesn’t have `android/` and `web/` yet, run:

```bash
cd /Users/komaragiri.satyadev/WorkSpace/Learning/FinanceManager
flutter create . --project-name finance_manager
```

If Flutter asks to overwrite files, keep the existing `lib/` and `pubspec.yaml` (they already contain the sync setup).

### 3. Supabase backend (sync)

1. Create a free project at [supabase.com](https://supabase.com).
2. In **SQL Editor**, run the script in `supabase/schema.sql` to create the `transactions` table (and optional Realtime).
3. In **Project Settings → API**, copy:
   - **Project URL**
   - **anon public** key

4. In this repo, open `lib/config/app_config.dart` and set:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 4. Run the app

```bash
flutter pub get
```

- **Android**: connect a device or start an emulator, then run `flutter run`.
- **Web**: run `flutter run -d chrome` (or `flutter run -d web-server`).

Add or edit data on one platform; it will appear on the other (and in the Supabase table) because both use the same backend.

## Project layout

| Path | Purpose |
|------|--------|
| `lib/main.dart` | App entry, Supabase init |
| `lib/config/app_config.dart` | Supabase URL and anon key |
| `lib/models/transaction.dart` | Shared data model |
| `lib/services/sync_service.dart` | All Supabase read/write and realtime |
| `lib/screens/home_screen.dart` | List + add transactions |
| `supabase/schema.sql` | Table and policies for Supabase |

## Optional: offline support

For offline-first sync (e.g. use app without internet, then sync when back online), you can add local storage (e.g. `sqflite` / `hive`) and a sync layer that merges with Supabase when connected. The current setup is online-only with a shared backend.
