class Transaction {
  final String id;
  final String userId;
  final String categoryId;
  final double amount;
  final String type; // income | expense
  final DateTime transactionDate;
  final String? counterpartyName;
  final String? memo;
  final String? eventType;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.counterpartyName,
    this.memo,
    this.eventType,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        userId: json['user_id'],
        categoryId: json['category_id'],
        amount: double.parse(json['amount'].toString()),
        type: json['type'],
        transactionDate: DateTime.parse(json['transaction_date']),
        counterpartyName: json['counterparty_name'],
        memo: json['memo'],
        eventType: json['event_type'],
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get isExpense => type == 'expense';
}

class TransactionListResponse {
  final List<Transaction> items;
  final int total;

  TransactionListResponse({required this.items, required this.total});

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) =>
      TransactionListResponse(
        items: (json['items'] as List).map((e) => Transaction.fromJson(e)).toList(),
        total: json['total'],
      );
}
