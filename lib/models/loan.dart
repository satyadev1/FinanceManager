/// Money borrowed (loan). Synced via loans.csv on Google Drive.
class Loan {
  final String? id;
  final String lenderName;
  final double amount;
  final String currency;
  final DateTime takenAt;
  final DateTime? dueAt;
  final String status; // active, closed
  final double? interestRate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Loan({
    this.id,
    required this.lenderName,
    required this.amount,
    this.currency = 'INR',
    required this.takenAt,
    this.dueAt,
    this.status = 'active',
    this.interestRate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as String?,
      lenderName: map['lender_name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      takenAt: map['taken_at'] != null ? DateTime.parse(map['taken_at'] as String) : DateTime.now(),
      dueAt: map['due_at'] != null ? DateTime.tryParse(map['due_at'] as String) : null,
      status: map['status'] as String? ?? 'active',
      interestRate: map['interest_rate'] != null ? (map['interest_rate'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'lender_name': lenderName,
      'amount': amount,
      'currency': currency,
      'taken_at': takenAt.toIso8601String(),
      if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
      'status': status,
      if (interestRate != null) 'interest_rate': interestRate,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
