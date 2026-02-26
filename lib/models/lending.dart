/// Money lent to others. Synced via lending.csv on Google Drive.
class Lending {
  final String? id;
  final String contactName;
  final double amount;
  final String currency;
  final DateTime givenAt;
  final DateTime? dueAt;
  final String status; // pending, partial_returned, returned
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lending({
    this.id,
    required this.contactName,
    required this.amount,
    this.currency = 'INR',
    required this.givenAt,
    this.dueAt,
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Lending.fromMap(Map<String, dynamic> map) {
    return Lending(
      id: map['id'] as String?,
      contactName: map['contact_name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      givenAt: map['given_at'] != null ? DateTime.parse(map['given_at'] as String) : DateTime.now(),
      dueAt: map['due_at'] != null ? DateTime.tryParse(map['due_at'] as String) : null,
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'contact_name': contactName,
      'amount': amount,
      'currency': currency,
      'given_at': givenAt.toIso8601String(),
      if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
      'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
