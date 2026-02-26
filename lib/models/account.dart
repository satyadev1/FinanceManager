/// Account: bank or card. Synced via accounts.csv on Google Drive.
class Account {
  final String? id;
  final String name;
  final String type; // 'bank' | 'card'
  final double balance;
  final String currency;
  final String? bankName;
  final String? lastFour;
  final String? scheme; // visa, mastercard, rupay, amex (for cards)
  final double? limitAmount;
  final String? limitPeriod; // 'monthly' | 'total'
  final DateTime? createdAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.balance = 0,
    this.currency = 'INR',
    this.bankName,
    this.lastFour,
    this.scheme,
    this.limitAmount,
    this.limitPeriod,
    this.createdAt,
  });

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'bank',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      bankName: map['bank_name'] as String?,
      lastFour: map['last_four'] as String?,
      scheme: map['scheme'] as String?,
      limitAmount: map['limit_amount'] != null ? (map['limit_amount'] as num).toDouble() : null,
      limitPeriod: map['limit_period'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      if (bankName != null) 'bank_name': bankName,
      if (lastFour != null) 'last_four': lastFour,
      if (scheme != null) 'scheme': scheme,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (limitPeriod != null) 'limit_period': limitPeriod,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  String get displayLabel {
    if (type == 'card' && scheme != null && lastFour != null) {
      return '$scheme ****$lastFour';
    }
    return name;
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    String? currency,
    String? bankName,
    String? lastFour,
    String? scheme,
    double? limitAmount,
    String? limitPeriod,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      lastFour: lastFour ?? this.lastFour,
      scheme: scheme ?? this.scheme,
      limitAmount: limitAmount ?? this.limitAmount,
      limitPeriod: limitPeriod ?? this.limitPeriod,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
