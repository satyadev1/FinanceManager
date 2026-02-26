import '../engine/sms_classifier.dart';
import '../models/sms_message.dart';
import '../models/transaction.dart';

/// Result of SMS import: parsed transactions, detected accounts, and raw messages.
class SmsImportResult {
  final List<Transaction> transactions;
  final List<DetectedAccount> detectedAccounts;
  final List<SmsMessageModel> messages;
  final bool permissionDenied;
  final bool notSupported;
  final String? error;
  final int messageCount;
  final Map<SmsCategory, int>? classificationCounts;

  const SmsImportResult({
    this.transactions = const [],
    this.detectedAccounts = const [],
    this.messages = const [],
    this.permissionDenied = false,
    this.notSupported = false,
    this.error,
    this.messageCount = 0,
    this.classificationCounts,
  });
}
