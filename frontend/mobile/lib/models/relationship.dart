class Relationship {
  final String id;
  final String userId;
  final String counterpartyName;
  final String? counterpartyId;
  final String? relationshipType;
  final String? notes;
  final double totalGiven;
  final double totalReceived;
  final double balance;
  final DateTime? lastTransactionDate;
  final DateTime createdAt;

  Relationship({
    required this.id,
    required this.userId,
    required this.counterpartyName,
    this.counterpartyId,
    this.relationshipType,
    this.notes,
    required this.totalGiven,
    required this.totalReceived,
    required this.balance,
    this.lastTransactionDate,
    required this.createdAt,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
        id: json['id'],
        userId: json['user_id'],
        counterpartyName: json['counterparty_name'],
        counterpartyId: json['counterparty_id'],
        relationshipType: json['relationship_type'],
        notes: json['notes'],
        totalGiven: (json['total_given'] as num).toDouble(),
        totalReceived: (json['total_received'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
        lastTransactionDate: json['last_transaction_date'] != null
            ? DateTime.tryParse(json['last_transaction_date'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );

  /// 양수: 내가 더 줌 / 음수: 내가 더 받음
  bool get iGaveMore => balance > 0;
}
