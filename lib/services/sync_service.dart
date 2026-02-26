import '../models/transaction.dart';

/// Placeholder sync service. Data will sync via Google Drive CSV (see DriveSyncService when implemented).
/// For now returns empty data so the app runs after Google Sign-In.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Future<List<Transaction>> getTransactions() async {
    return [];
  }

  Future<Transaction> addTransaction(Transaction t) async {
    return t;
  }

  void subscribeToTransactions(void Function(List<Transaction>) onData) {
    onData([]);
  }
}
