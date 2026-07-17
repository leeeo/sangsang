class AnalyticsSummary {
  final int year;
  final int month;
  final double income;
  final double expense;
  final double balance;
  final int incomeCount;
  final int expenseCount;

  AnalyticsSummary({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
    required this.incomeCount,
    required this.expenseCount,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => AnalyticsSummary(
        year: json['year'],
        month: json['month'],
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
        incomeCount: json['income_count'],
        expenseCount: json['expense_count'],
      );
}

class TrendPoint {
  final int year;
  final int month;
  final double income;
  final double expense;

  TrendPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        year: json['year'],
        month: json['month'],
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
      );

  String get label {
    final m = month.toString().padLeft(2, '0');
    return '$year.$m';
  }
}

class CategoryStat {
  final String id;
  final String name;
  final String? color;
  final double total;
  final int count;
  final double ratio;

  CategoryStat({
    required this.id,
    required this.name,
    this.color,
    required this.total,
    required this.count,
    required this.ratio,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) => CategoryStat(
        id: json['id'],
        name: json['name'],
        color: json['color'],
        total: (json['total'] as num).toDouble(),
        count: json['count'],
        ratio: (json['ratio'] as num).toDouble(),
      );
}
