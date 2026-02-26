import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import '../config/app_config.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/lending.dart';
import '../models/loan.dart';
import '../models/notification.dart';
import '../utils/csv_io.dart';
import 'database_service.dart';
import 'google_auth_service.dart';
import 'sync_preferences.dart';

/// Syncs app data with Google Drive via CSV files in a single folder.
///
/// The local SQLite database is the **single source of truth**. Google Drive is
/// a remote backup/sync target only. On startup we load from the DB first so
/// data is available instantly, then merge any newer data from Drive.
class DriveSyncService extends ChangeNotifier {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  drive.DriveApi? _driveApi;
  dynamic _httpClient;
  String? _folderId;
  final Map<String, String> _fileIds = {};

  List<Account> _accounts = [];
  List<Transaction> _transactions = [];
  List<Lending> _lendings = [];
  List<Loan> _loans = [];
  List<AppNotification> _notifications = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<Lending> get lendings => List.unmodifiable(_lendings);
  List<Loan> get loans => List.unmodifiable(_loans);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Last sync/load error message, if any. Cleared on next successful sync or load.
  String? lastSyncError;

  DatabaseService get _dbService => DatabaseService.instance;

  static const _folderMimeType = 'application/vnd.google-apps.folder';
  static const _csvMimeType = 'text/csv';
  static const _csvFiles = ['accounts.csv', 'transactions.csv', 'lending.csv', 'loans.csv', 'notifications.csv'];

  Future<void> _ensureClient() async {
    if (_driveApi != null) return;
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) throw StateError('Not signed in');
    _httpClient = client;
    _driveApi = drive.DriveApi(client);
  }

  Future<String> _ensureFolder() async {
    await _ensureClient();
    if (_folderId != null) return _folderId!;
    final api = _driveApi!;
    final list = await api.files.list(
      q: "name = '${AppConfig.driveFolderName}' and mimeType = '$_folderMimeType' and trashed = false",
      $fields: 'files(id, name)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      _folderId = list.files!.first.id;
      return _folderId!;
    }
    final folder = drive.File()
      ..name = AppConfig.driveFolderName
      ..mimeType = _folderMimeType;
    final created = await api.files.create(folder);
    _folderId = created.id;
    return _folderId!;
  }

  Future<String?> _getOrCreateFileId(String filename, String initialContent) async {
    final folderId = await _ensureFolder();
    if (_fileIds.containsKey(filename)) return _fileIds[filename];
    final api = _driveApi!;
    final list = await api.files.list(
      q: "name = '$filename' and '$folderId' in parents and trashed = false",
      $fields: 'files(id, name)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      _fileIds[filename] = list.files!.first.id!;
      return _fileIds[filename];
    }
    final file = drive.File()
      ..name = filename
      ..parents = [folderId]
      ..mimeType = _csvMimeType;
    final bytes = utf8.encode(initialContent);
    final created = await api.files.create(
      file,
      uploadMedia: drive.Media(
        Stream.value(bytes),
        bytes.length,
      ),
    );
    _fileIds[filename] = created.id!;
    return _fileIds[filename];
  }

  Future<String> _readFileContent(String fileId) async {
    await _ensureClient();
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) throw Exception('Drive read failed: ${response.statusCode}');
    return response.body;
  }

  Future<void> _writeFileContent(String fileId, String content) async {
    await _ensureClient();
    final api = _driveApi!;
    final bytes = utf8.encode(content);
    await api.files.update(
      drive.File(),
      fileId,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
  }

  bool get _isSignedIn => GoogleAuthService.instance.currentUser != null;

  /// Load all data: always from local DB first (instant), then merge from
  /// Google Drive if signed in. This ensures data is always available even
  /// when offline or Drive is unreachable.
  Future<void> loadAll() async {
    lastSyncError = null;

    // Step 1: Load from local DB (instant, always available)
    if (!kIsWeb) {
      await _loadFromDb();
      debugPrint('[Sync] Loaded from local DB: '
          '${_accounts.length} accounts, ${_transactions.length} transactions, '
          '${_lendings.length} lending, ${_loans.length} loans, '
          '${_notifications.length} notifications');
    }

    // Step 2: If signed in, pull from Drive and merge
    if (_isSignedIn) {
      try {
        await _ensureFolder();
        for (final name in _csvFiles) {
          final id = await _getOrCreateFileId(name, _headerOnly(name));
          final content = await _readFileContent(id!);
          _mergeDriveDataIntoCache(name, content);
        }
        // Persist merged data back to DB
        await _persistAllToDb();
        await _syncToDriveIfDue();
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('[Sync] Drive sync failed, using local DB data: $e');
      }
    }
    notifyListeners();
  }

  /// Push all data to Drive if schedule is due (daily/weekly) or when instant. Call after loadAll when signed in.
  Future<void> _syncToDriveIfDue() async {
    if (!_isSignedIn) return;
    final interval = await SyncPreferences.instance.getInterval();
    if (interval == SyncInterval.instant) return; // instant syncs happen in each save*()
    if (!await SyncPreferences.instance.isScheduledSyncDue()) return;
    await _pushAllToDrive();
  }

  /// Push all CSVs to Drive now and update last sync time. Use for "Sync now" or scheduled sync.
  Future<void> syncNow() async {
    if (!_isSignedIn) return;
    lastSyncError = null;
    await _pushAllToDrive();
  }

  Future<void> _pushAllToDrive() async {
    if (!_isSignedIn) return;
    try {
      await _ensureFolder();
      await _writeAccountsToDrive();
      await _writeTransactionsToDrive();
      await _writeLendingToDrive();
      await _writeLoansToDrive();
      await _writeNotificationsToDrive();
      await SyncPreferences.instance.setLastSyncNow();
    } catch (e) {
      lastSyncError = e.toString();
    }
  }

  Future<void> _loadFromDb() async {
    try {
      _accounts = await _dbService.getAccounts();
      _transactions = await _dbService.getTransactions();
      _lendings = await _dbService.getLending();
      _loans = await _dbService.getLoans();
      _notifications = await _dbService.getNotifications();
    } catch (e) {
      debugPrint('[DB] Load failed: $e');
    }
  }

  /// Persist all in-memory data to the local DB.
  Future<void> _persistAllToDb() async {
    if (kIsWeb) return;
    try {
      await _dbService.replaceAllAccounts(_accounts);
      await _dbService.replaceAllTransactions(_transactions);
      await _dbService.replaceAllLending(_lendings);
      await _dbService.replaceAllLoans(_loans);
      await _dbService.replaceAllNotifications(_notifications);
    } catch (e) {
      debugPrint('[DB] Persist failed: $e');
    }
  }

  /// Merge Drive CSV data into the current in-memory cache. Records from Drive
  /// that don't already exist locally (by id) are added; existing records are
  /// kept as-is so local edits are not overwritten.
  void _mergeDriveDataIntoCache(String filename, String content) {
    final rows = csvToMapList(content);
    switch (filename) {
      case 'accounts.csv':
        final existing = <String>{for (final a in _accounts) if (a.id != null) a.id!};
        for (final r in rows) {
          final a = Account.fromMap(r);
          if (a.id != null && !existing.contains(a.id)) {
            _accounts.add(a);
            existing.add(a.id!);
          }
        }
        break;
      case 'transactions.csv':
        final existing = <String>{for (final t in _transactions) if (t.id != null) t.id!};
        for (final r in rows) {
          final t = Transaction.fromMap(r);
          if (t.id != null && !existing.contains(t.id)) {
            _transactions.add(t);
            existing.add(t.id!);
          }
        }
        _transactions.sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
        break;
      case 'lending.csv':
        final existing = <String>{for (final l in _lendings) if (l.id != null) l.id!};
        for (final r in rows) {
          final l = Lending.fromMap(r);
          if (l.id != null && !existing.contains(l.id)) {
            _lendings.add(l);
            existing.add(l.id!);
          }
        }
        break;
      case 'loans.csv':
        final existing = <String>{for (final l in _loans) if (l.id != null) l.id!};
        for (final r in rows) {
          final l = Loan.fromMap(r);
          if (l.id != null && !existing.contains(l.id)) {
            _loans.add(l);
            existing.add(l.id!);
          }
        }
        break;
      case 'notifications.csv':
        final existing = <String>{for (final n in _notifications) if (n.id != null) n.id!};
        for (final r in rows) {
          final n = AppNotification.fromMap(r);
          if (n.id != null && !existing.contains(n.id)) {
            _notifications.add(n);
            existing.add(n.id!);
          }
        }
        break;
    }
  }

  String _headerOnly(String filename) {
    switch (filename) {
      case 'accounts.csv':
        return 'id,name,type,balance,currency,bank_name,last_four,scheme,limit_amount,limit_period,created_at\n';
      case 'transactions.csv':
        return 'id,title,amount,type,date,source,account_id,category,created_at\n';
      case 'lending.csv':
        return 'id,contact_name,amount,currency,given_at,due_at,status,notes,created_at,updated_at\n';
      case 'loans.csv':
        return 'id,lender_name,amount,currency,taken_at,due_at,status,interest_rate,notes,created_at,updated_at\n';
      case 'notifications.csv':
        return 'id,title,body,type,read,created_at\n';
      default:
        return 'id\n';
    }
  }

  Future<void> saveAccounts() async {
    if (!kIsWeb) {
      await _dbService.replaceAllAccounts(_accounts);
    }
    if (_isSignedIn && await SyncPreferences.instance.getInterval() == SyncInterval.instant) {
      try {
        await _writeAccountsToDrive();
      } catch (_) {}
    } else if (_isSignedIn) {
      await _syncToDriveIfDue();
    }
  }

  Future<void> _writeAccountsToDrive() async {
    if (!_isSignedIn) return; // Sync to Drive only when signed in; otherwise data stays local.
    const header = ['id', 'name', 'type', 'balance', 'currency', 'bank_name', 'last_four', 'scheme', 'limit_amount', 'limit_period', 'created_at'];
    final rows = _accounts.map((e) => e.toMap()).toList();
    final csv = mapListToCsv(header, rows);
    final id = await _getOrCreateFileId('accounts.csv', _headerOnly('accounts.csv'));
    await _writeFileContent(id!, csv);
  }

  Future<void> saveTransactions() async {
    if (!kIsWeb) {
      await _dbService.replaceAllTransactions(_transactions);
    }
    if (_isSignedIn && await SyncPreferences.instance.getInterval() == SyncInterval.instant) {
      try {
        await _writeTransactionsToDrive();
      } catch (_) {}
    } else if (_isSignedIn) {
      await _syncToDriveIfDue();
    }
  }

  Future<void> _writeTransactionsToDrive() async {
    if (!_isSignedIn) return; // Sync to Drive only when signed in; otherwise data stays local.
    const header = ['id', 'title', 'amount', 'type', 'date', 'source', 'account_id', 'category', 'created_at'];
    final rows = _transactions.map((e) => e.toMap()).toList();
    final csv = mapListToCsv(header, rows);
    final id = await _getOrCreateFileId('transactions.csv', _headerOnly('transactions.csv'));
    await _writeFileContent(id!, csv);
  }

  Future<void> saveLending() async {
    if (!kIsWeb) {
      await _dbService.replaceAllLending(_lendings);
    }
    if (_isSignedIn && await SyncPreferences.instance.getInterval() == SyncInterval.instant) {
      try {
        await _writeLendingToDrive();
      } catch (_) {}
    } else if (_isSignedIn) {
      await _syncToDriveIfDue();
    }
  }

  Future<void> _writeLendingToDrive() async {
    if (!_isSignedIn) return; // Sync to Drive only when signed in; otherwise data stays local.
    const header = ['id', 'contact_name', 'amount', 'currency', 'given_at', 'due_at', 'status', 'notes', 'created_at', 'updated_at'];
    final rows = _lendings.map((e) => e.toMap()).toList();
    final csv = mapListToCsv(header, rows);
    final id = await _getOrCreateFileId('lending.csv', _headerOnly('lending.csv'));
    await _writeFileContent(id!, csv);
  }

  Future<void> saveLoans() async {
    if (!kIsWeb) {
      await _dbService.replaceAllLoans(_loans);
    }
    if (_isSignedIn && await SyncPreferences.instance.getInterval() == SyncInterval.instant) {
      try {
        await _writeLoansToDrive();
      } catch (_) {}
    } else if (_isSignedIn) {
      await _syncToDriveIfDue();
    }
  }

  Future<void> _writeLoansToDrive() async {
    if (!_isSignedIn) return; // Sync to Drive only when signed in; otherwise data stays local.
    const header = ['id', 'lender_name', 'amount', 'currency', 'taken_at', 'due_at', 'status', 'interest_rate', 'notes', 'created_at', 'updated_at'];
    final rows = _loans.map((e) => e.toMap()).toList();
    final csv = mapListToCsv(header, rows);
    final id = await _getOrCreateFileId('loans.csv', _headerOnly('loans.csv'));
    await _writeFileContent(id!, csv);
  }

  Future<void> saveNotifications() async {
    if (!kIsWeb) {
      await _dbService.replaceAllNotifications(_notifications);
    }
    if (_isSignedIn && await SyncPreferences.instance.getInterval() == SyncInterval.instant) {
      try {
        await _writeNotificationsToDrive();
      } catch (_) {}
    } else if (_isSignedIn) {
      await _syncToDriveIfDue();
    }
  }

  Future<void> _writeNotificationsToDrive() async {
    if (!_isSignedIn) return; // Sync to Drive only when signed in; otherwise data stays local.
    const header = ['id', 'title', 'body', 'type', 'read', 'created_at'];
    final rows = _notifications.map((e) => e.toMap()).toList();
    final csv = mapListToCsv(header, rows);
    final id = await _getOrCreateFileId('notifications.csv', _headerOnly('notifications.csv'));
    await _writeFileContent(id!, csv);
  }

  // --- Mutations (update in-memory then save to Drive) ---

  void addAccount(Account a) {
    _accounts = [..._accounts, a];
  }

  void updateAccount(int index, Account a) {
    final list = List<Account>.from(_accounts);
    list[index] = a;
    _accounts = list;
  }

  void removeAccountAt(int index) {
    _accounts = List.from(_accounts)..removeAt(index);
  }

  /// Merges multiple accounts into one: reassigns all transactions from
  /// [mergeAwayAccountIds] to [keepAccountId], then removes the merged-away accounts.
  void mergeAccounts(String keepAccountId, List<String> mergeAwayAccountIds) {
    if (mergeAwayAccountIds.isEmpty) return;
    final toRemove = mergeAwayAccountIds.toSet();
    _transactions = _transactions.map((t) {
      if (t.accountId != null && toRemove.contains(t.accountId!)) {
        return Transaction(
          id: t.id,
          title: t.title,
          amount: t.amount,
          type: t.type,
          date: t.date,
          category: t.category,
          source: t.source,
          accountId: keepAccountId,
          createdAt: t.createdAt,
        );
      }
      return t;
    }).toList();
    final indicesToRemove = <int>[];
    for (int i = 0; i < _accounts.length; i++) {
      if (toRemove.contains(_accounts[i].id)) indicesToRemove.add(i);
    }
    for (final i in indicesToRemove.reversed) {
      _accounts = List.from(_accounts)..removeAt(i);
    }
  }

  void addTransaction(Transaction t) {
    _transactions = [t, ..._transactions];
  }

  void updateTransaction(int index, Transaction t) {
    final list = List<Transaction>.from(_transactions);
    list[index] = t;
    _transactions = list;
  }

  void removeTransactionAt(int index) {
    _transactions = List.from(_transactions)..removeAt(index);
  }

  void addLending(Lending l) {
    _lendings = [..._lendings, l];
  }

  void updateLending(int index, Lending l) {
    final list = List<Lending>.from(_lendings);
    list[index] = l;
    _lendings = list;
  }

  void removeLendingAt(int index) {
    _lendings = List.from(_lendings)..removeAt(index);
  }

  void addLoan(Loan l) {
    _loans = [..._loans, l];
  }

  void updateLoan(int index, Loan l) {
    final list = List<Loan>.from(_loans);
    list[index] = l;
    _loans = list;
  }

  void removeLoanAt(int index) {
    _loans = List.from(_loans)..removeAt(index);
  }

  void removeNotificationAt(int index) {
    _notifications = List.from(_notifications)..removeAt(index);
    notifyListeners();
  }

  /// Refreshes notifications from local DB and, if signed in, from Drive.
  /// Call when opening Messages so new messages appear and the UI updates.
  Future<void> refreshNotifications() async {
    if (!kIsWeb) {
      _notifications = await _dbService.getNotifications();
    }
    if (_isSignedIn) {
      try {
        await _ensureFolder();
        final id = await _getOrCreateFileId('notifications.csv', _headerOnly('notifications.csv'));
        final content = await _readFileContent(id!);
        _mergeDriveDataIntoCache('notifications.csv', content);
        if (!kIsWeb) {
          await _dbService.replaceAllNotifications(_notifications);
        }
      } catch (e) {
        debugPrint('[Sync] Notifications refresh from Drive failed: $e');
      }
    }
    notifyListeners();
  }

  /// Marks the notification at [index] as read and persists.
  Future<void> markNotificationAsRead(int index) async {
    if (index < 0 || index >= _notifications.length) return;
    final n = _notifications[index];
    if (n.read) return;
    final list = List<AppNotification>.from(_notifications);
    list[index] = n.copyWith(read: true);
    _notifications = list;
    await saveNotifications();
    notifyListeners();
  }

  /// Marks all notifications as read and persists. Call when user opens Messages.
  Future<void> markAllNotificationsAsRead() async {
    bool changed = false;
    final list = _notifications.map((n) {
      if (!n.read) {
        changed = true;
        return n.copyWith(read: true);
      }
      return n;
    }).toList();
    if (!changed) return;
    _notifications = list;
    await saveNotifications();
    notifyListeners();
  }
}
