import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/account.dart';
import '../models/lending.dart';
import '../models/loan.dart';
import '../models/notification.dart';
import '../models/transaction.dart';

/// Local SQLite database — the single source of truth for all app data.
/// Google Drive is treated as a remote backup/sync target only.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web');
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fin_manager.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'bank',
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        bank_name TEXT,
        last_four TEXT,
        scheme TEXT,
        limit_amount REAL,
        limit_period TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'debit',
        date TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        account_id TEXT,
        category TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lending (
        id TEXT PRIMARY KEY,
        contact_name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        given_at TEXT NOT NULL,
        due_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        lender_name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        taken_at TEXT NOT NULL,
        due_at TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        interest_rate REAL,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'info',
        read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions(date DESC)');
    await db.execute(
        'CREATE INDEX idx_transactions_account ON transactions(account_id)');
  }

  // ---------------------------------------------------------------------------
  // Accounts
  // ---------------------------------------------------------------------------

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final rows = await db.query('accounts');
    return rows.map((r) => Account.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> upsertAccount(Account a) async {
    final db = await database;
    await db.insert(
      'accounts',
      _accountToRow(a),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllAccounts(List<Account> accounts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('accounts');
      for (final a in accounts) {
        await txn.insert('accounts', _accountToRow(a));
      }
    });
  }

  Map<String, dynamic> _accountToRow(Account a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'balance': a.balance,
        'currency': a.currency,
        'bank_name': a.bankName,
        'last_four': a.lastFour,
        'scheme': a.scheme,
        'limit_amount': a.limitAmount,
        'limit_period': a.limitPeriod,
        'created_at': a.createdAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'created_at DESC, date DESC');
    return rows.map((r) => Transaction.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> upsertTransaction(Transaction t) async {
    final db = await database;
    await db.insert(
      'transactions',
      _transactionToRow(t),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllTransactions(List<Transaction> transactions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      for (final t in transactions) {
        await txn.insert('transactions', _transactionToRow(t));
      }
    });
  }

  Map<String, dynamic> _transactionToRow(Transaction t) => {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'type': t.type,
        'date': t.date.toIso8601String(),
        'source': t.source,
        'account_id': t.accountId,
        'category': t.category,
        'created_at': t.createdAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Lending
  // ---------------------------------------------------------------------------

  Future<List<Lending>> getLending() async {
    final db = await database;
    final rows = await db.query('lending');
    return rows.map((r) => Lending.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> upsertLending(Lending l) async {
    final db = await database;
    await db.insert(
      'lending',
      _lendingToRow(l),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLending(String id) async {
    final db = await database;
    await db.delete('lending', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllLending(List<Lending> lending) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('lending');
      for (final l in lending) {
        await txn.insert('lending', _lendingToRow(l));
      }
    });
  }

  Map<String, dynamic> _lendingToRow(Lending l) => {
        'id': l.id,
        'contact_name': l.contactName,
        'amount': l.amount,
        'currency': l.currency,
        'given_at': l.givenAt.toIso8601String(),
        'due_at': l.dueAt?.toIso8601String(),
        'status': l.status,
        'notes': l.notes,
        'created_at': l.createdAt?.toIso8601String(),
        'updated_at': l.updatedAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Loans
  // ---------------------------------------------------------------------------

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final rows = await db.query('loans');
    return rows.map((r) => Loan.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> upsertLoan(Loan l) async {
    final db = await database;
    await db.insert(
      'loans',
      _loanToRow(l),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLoan(String id) async {
    final db = await database;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllLoans(List<Loan> loans) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('loans');
      for (final l in loans) {
        await txn.insert('loans', _loanToRow(l));
      }
    });
  }

  Map<String, dynamic> _loanToRow(Loan l) => {
        'id': l.id,
        'lender_name': l.lenderName,
        'amount': l.amount,
        'currency': l.currency,
        'taken_at': l.takenAt.toIso8601String(),
        'due_at': l.dueAt?.toIso8601String(),
        'status': l.status,
        'interest_rate': l.interestRate,
        'notes': l.notes,
        'created_at': l.createdAt?.toIso8601String(),
        'updated_at': l.updatedAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<List<AppNotification>> getNotifications() async {
    final db = await database;
    final rows = await db.query('notifications', orderBy: 'created_at DESC');
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['read'] = (r['read'] as int?) == 1;
      return AppNotification.fromMap(m);
    }).toList();
  }

  Future<void> upsertNotification(AppNotification n) async {
    final db = await database;
    await db.insert(
      'notifications',
      _notificationToRow(n),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNotification(String id) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllNotifications(List<AppNotification> notifications) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notifications');
      for (final n in notifications) {
        await txn.insert('notifications', _notificationToRow(n));
      }
    });
  }

  Map<String, dynamic> _notificationToRow(AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'type': n.type,
        'read': n.read ? 1 : 0,
        'created_at': n.createdAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
