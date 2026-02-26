# Fin Manager – Pending implementation tasks

Below are the remaining tasks to complete the app per the Drive-only sync plan. Items already done are listed under **Completed** for reference.

---

## Completed

- [x] **Config**: No Supabase; `AppConfig` with Drive folder name and optional Offers API placeholders.
- [x] **Pubspec**: `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth`, `path_provider`, `uuid`; no Supabase.
- [x] **Models**: `Account`, `Transaction` (with type, source, account_id), `Lending`, `Loan`, `AppNotification`, `Offer`.
- [x] **CSV utils**: `lib/utils/csv_io.dart` (parse/serialize RFC 4180); `docs/csv_columns.md` (column layout for all CSVs).
- [x] **Google Sign-In**: `GoogleAuthService` (sign in/out, Drive scope, stream); `SignInScreen`; main app routes to SignIn or Home by auth state; Sign out in HomeScreen app bar.
- [x] **Main**: No Supabase; auth-based home (SignInScreen vs HomeScreen).
- [x] **SyncService**: Stubbed (returns empty data) until Drive is wired.

---

## Pending

### 1. Drive sync service (high priority)

- [ ] **Implement `DriveSyncService`** (or `GoogleDriveDataService`):
  - Use `GoogleAuthService` to get authenticated HTTP client (via `extension_google_sign_in_as_googleapis_auth`).
  - Find or create app folder on Drive (name from `AppConfig.driveFolderName`).
  - For each entity: find or create CSV file in that folder (`accounts.csv`, `transactions.csv`, `lending.csv`, `loans.csv`, `notifications.csv`).
  - **Read**: Download CSV content, parse with `csv_io.csvToMapList`, map to Dart models (`Account`, `Transaction`, etc.), cache in memory.
  - **Write**: Serialize model lists to CSV with `csv_io.mapListToCsv` (headers per `docs/csv_columns.md`), upload/create or update file on Drive.
  - Expose: `getAccounts()`, `saveAccounts()`, `getTransactions()`, `saveTransactions()`, same for lending, loans, notifications.
- [ ] **Replace or wrap `SyncService`** so it uses `DriveSyncService` for transactions (and later accounts, etc.) instead of returning empty data.
- [ ] **Refresh from Drive**: Add a “Refresh” action (e.g. in app bar or per screen) that re-reads CSVs from Drive and updates UI.

### 2. App shell and navigation

- [ ] **Bottom navigation** (or tab bar): Tabs for **Accounts**, **Transactions**, **Lending**, **Loans**, **Reports**, **Messages**, **Offers** (or a subset; “Messages” and “Offers” can be optional).
- [ ] **Shell widget**: One scaffold with bottom nav; body = selected tab’s screen. After sign-in, show this shell instead of a single HomeScreen.

### 3. Screens (data + UI)

- [ ] **Accounts screen** (`lib/screens/accounts_screen.dart`):
  - List all accounts (banks and cards) from Drive (or in-memory cache).
  - Each row: name, type badge (Bank/Card), for bank show **current balance**, for card show “Used X / Limit Y” (computed from transactions).
  - FAB or primary button “Add account”; form: choose Bank or Card, then Bank = name + current balance + optional bank name/last 4; Card = name + card number (for detection) + optional limit (amount + period). Save writes to Drive via DriveSyncService.
- [ ] **Transactions screen** (enhance or replace `home_screen.dart`):
  - List transactions from Drive; add/edit transaction with **account** picker (from accounts), type (credit/debit), amount, date, title, optional category.
  - Optional filters: by account, by type (credit/debit).
- [ ] **Lending screen** (`lib/screens/lending_screen.dart`):
  - List lending entries; add/edit (contact name, amount, currency, given_at, due_at, status, notes). Read/write `lending.csv` via DriveSyncService.
- [ ] **Loans screen** (`lib/screens/loans_screen.dart`):
  - List loans; add/edit (lender name, amount, currency, taken_at, due_at, status, interest_rate, notes). Read/write `loans.csv` via DriveSyncService.
- [ ] **Reports screen** (`lib/screens/reports_screen.dart`):
  - Period selector: This week, This month, Last month, Last 3 months, Custom (date range).
  - Filters: account (All or multi-select), type (Debit / Credit / Both).
  - Summary card: Total spend and Total credit for period.
  - Breakdown: by account (card/bank) and/or by week/month; optional % of total.
  - Use `lib/utils/report_aggregator.dart` (or similar): input = transactions + accounts + filter params; output = aggregated rows + totals.
- [ ] **Messages screen** (optional) (`lib/screens/messages_screen.dart`):
  - List from `notifications.csv`; mark as read; optional badge on tab.
- [ ] **Offers screen** (optional) (`lib/screens/offers_screen.dart`):
  - If `AppConfig.offersApiBaseUrl` is set: call external API (e.g. by card_scheme), show list of offers. Otherwise placeholder or hide tab.

### 4. Card detection and limits

- [ ] **Card type detection** (`lib/services/card_detect_service.dart` or `lib/utils/card_utils.dart`):
  - Input: card number (or first 6 + last 4). Output: scheme (visa, mastercard, rupay, amex) + last four. Use BIN rules or a free BIN API.
  - When adding a card account, run detection and set `scheme` and `last_four`.
- [ ] **Card limits**: Already in `Account` model (`limit_amount`, `limit_period`). In Accounts screen, show “Used X / Limit Y” for cards (sum debits for that account in period if limit_period is monthly, else all-time).

### 5. Optional features

- [ ] **SMS import (Android only)**:
  - Permission `READ_SMS`; parse bank SMS (regex per bank or generic); create transactions with `source = 'sms'`, optional `account_id`; append to in-memory list and call DriveSyncService to write `transactions.csv`.
  - Platform guards so this code runs only on Android.
- [ ] **Offline cache**:
  - After reading CSVs from Drive, save raw content (or parsed lists) to local file via `path_provider`. On launch without network, load from file and show “Offline – data may be outdated”; when back online, write pending changes and re-read from Drive.
- [ ] **Backup to timestamped folder**: Optional “Backup” action that copies current CSVs to a subfolder like `FinManager_backup_YYYY-MM-DD` on Drive.

---

## Suggested order

1. Drive sync service (so all screens can read/write real data).
2. App shell with bottom nav.
3. Accounts screen, then Transactions (with account picker), then Lending, Loans.
4. Reports (aggregator + screen with filters).
5. Messages and Offers (optional).
6. Card detection; then SMS and offline (optional).
