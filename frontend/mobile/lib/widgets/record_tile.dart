import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/transaction.dart';
import '../providers/category_provider.dart';
import 'amount_text.dart';

class RecordTile extends StatelessWidget {
  final Transaction record;
  final VoidCallback? onDelete;

  const RecordTile({super.key, required this.record, this.onDelete});

  static IconData eventIcon(String? type) => switch (type) {
    'wedding' => Icons.favorite_outline,
    'funeral' => Icons.local_florist_outlined,
    'birthday' => Icons.cake_outlined,
    'baby' => Icons.child_care_outlined,
    'housewarming' => Icons.home_outlined,
    _ => Icons.volunteer_activism_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final category = context.watch<CategoryProvider>().nameById(record.categoryId);
    final colors = Theme.of(context).colorScheme;
    final direction = record.isExpense ? '보낸 마음' : '받은 마음';
    final color = record.isExpense ? AppColors.sentOf(context) : AppColors.receivedOf(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(record.counterpartyName ?? '이름 없이 남긴 기록',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Text('$direction · ${formatKRW(record.amount)}',
                      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text('$category · ${DateFormat('yyyy년 M월 d일').format(record.transactionDate)}'),
                  if (record.memo != null && record.memo!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SelectableText(record.memo!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('닫기')),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(eventIcon(record.eventType), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.counterpartyName ?? '이름 없이 남긴 기록',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      key: ValueKey('delete-${record.id}'),
                      tooltip: '기록 삭제',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    )
                  else
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text('$category · ${DateFormat('yyyy.MM.dd').format(record.transactionDate)}',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  ExcludeSemantics(
                    child: Text(direction, style: TextStyle(color: color, fontSize: 14)),
                  ),
                  AmountText(amount: record.amount, isExpense: record.isExpense, fontSize: 18),
                ],
              ),
              if (record.memo != null && record.memo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(record.memo!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
