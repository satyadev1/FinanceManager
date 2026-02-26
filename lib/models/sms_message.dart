import '../engine/sms_classifier.dart';

/// Raw SMS message stored for viewing in the app.
class SmsMessageModel {
  final String address;
  final String body;
  final DateTime date;
  final SmsCategory category;
  final String? bankName;
  final String? accountLast4;
  final String? accountType;
  final double? amount;
  final String? transactionType;

  const SmsMessageModel({
    required this.address,
    required this.body,
    required this.date,
    required this.category,
    this.bankName,
    this.accountLast4,
    this.accountType,
    this.amount,
    this.transactionType,
  });
}

/// Account detected from SMS messages, before user confirms.
class DetectedAccount {
  String id;
  String? lastFour;
  String type;
  String? subType;
  String? bankName;
  String name;
  double? balance;
  int transactionCount;
  bool selected;

  DetectedAccount({
    required this.id,
    this.lastFour,
    this.type = 'bank',
    this.subType,
    this.bankName,
    this.name = '',
    this.balance,
    this.transactionCount = 0,
    this.selected = true,
  });

  String get displayName {
    if (name.isNotEmpty) return name;
    final parts = <String>[];
    if (bankName != null) parts.add(bankName!);
    if (subType == 'credit_card') {
      parts.add('Credit Card');
    } else if (subType == 'debit_card') {
      parts.add('Debit Card');
    } else if (type == 'card') {
      parts.add('Card');
    } else {
      parts.add('Account');
    }
    if (lastFour != null) parts.add('****$lastFour');
    return parts.join(' ');
  }

  String get key => '${lastFour ?? "unknown"}_${bankName?.toLowerCase() ?? "unknown"}';
}
