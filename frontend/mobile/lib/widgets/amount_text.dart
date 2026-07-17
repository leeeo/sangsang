import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final bool isExpense;
  final double fontSize;
  final FontWeight fontWeight;

  const AmountText({
    super.key,
    required this.amount,
    required this.isExpense,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,###', 'ko_KR').format(amount);
    final prefix = isExpense ? '-' : '+';
    final color = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return Text(
      '$prefix$formatted원',
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
    );
  }
}

String formatKRW(double amount) =>
    '${NumberFormat('#,###', 'ko_KR').format(amount)}원';
