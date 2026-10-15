import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';

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
    final color = isExpense ? AppColors.sentOf(context) : AppColors.receivedOf(context);
    return Semantics(
      label: '${isExpense ? '보낸 마음' : '받은 마음'} $formatted원',
      excludeSemantics: true,
      child: Text(
        '$formatted원',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

String formatKRW(double amount) =>
    '${NumberFormat('#,###', 'ko_KR').format(amount)}원';
