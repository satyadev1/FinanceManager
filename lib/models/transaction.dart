/// Transaction (credit/debit). Synced via transactions.csv on Google Drive.
class Transaction {
  final String? id;
  final String title;
  final double amount;
  final String type; // 'credit' | 'debit'
  final DateTime date;
  final String? category;
  final String source; // 'manual' | 'sms' | 'import'
  final String? accountId;
  final DateTime? createdAt;

  const Transaction({
    this.id,
    required this.title,
    required this.amount,
    this.type = 'debit',
    required this.date,
    this.category,
    this.source = 'manual',
    this.accountId,
    this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String?,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] as String? ?? 'debit',
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      category: map['category'] as String?,
      source: map['source'] as String? ?? 'manual',
      accountId: map['account_id'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      if (category != null) 'category': category,
      'source': source,
      if (accountId != null) 'account_id': accountId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
