import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/record_tile.dart';
import 'transaction_form_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _selected = 'all';
  String? _deletingId;
  bool _categoryError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() => _categoryError = false);
    try {
      await Future.wait([
        context.read<TransactionProvider>().fetchTransactions(type: _selected == 'all' ? null : _selected),
        context.read<CategoryProvider>().fetchCategories(),
      ]);
    } catch (_) {
      if (mounted) setState(() => _categoryError = true);
    }
  }

  Future<void> _addRecord() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => TransactionFormScreen(
      initialType: _selected == 'all' ? 'expense' : _selected,
    )));
    if (mounted) await _reload();
  }

  Future<void> _delete(Transaction record) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 기록을 지울까요?'),
        content: Text('${record.counterpartyName ?? '이름 없이 남긴 기록'} · '
            '${formatKRW(record.amount)}\n삭제한 기록은 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('남겨두기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('기록 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = record.id);
    final ok = await context.read<TransactionProvider>().deleteTransaction(record.id);
    if (!mounted) return;
    setState(() => _deletingId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '기록을 삭제했어요.' : '삭제하지 못했어요. 기록은 그대로 있으니 다시 시도해 주세요.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<TransactionProvider>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('주고받은 기록')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('그날의 마음을 차곡차곡 모아두세요.',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [('all', '전체'), ('expense', '보낸 마음'), ('income', '받은 마음')]
                        .map((item) => ChoiceChip(
                          key: ValueKey('filter-${item.$1}'),
                          label: Text(item.$2),
                          selected: _selected == item.$1,
                          onSelected: (_) {
                            if (_selected == item.$1) return;
                            setState(() => _selected = item.$1);
                            _reload();
                          },
                        )).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(records.isLoading ? '기록을 불러오는 중' : '기록 ${records.total}건',
                      style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: records.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categoryError
                      ? AppErrorState(message: '분류 정보를 불러오지 못했어요.', onRetry: _reload)
                      : records.error != null && records.items.isEmpty
                      ? AppErrorState(message: records.error!, onRetry: _reload)
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView(
                            key: const ValueKey('record-list'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children: [
                              if (records.items.isEmpty)
                                AppEmptyState(
                                  icon: Icons.history_outlined,
                                  title: _selected == 'all' ? '아직 남긴 기록이 없어요' : '이 방향의 기록은 아직 없어요',
                                  message: '축하와 위로를 전한 날을 기억해 두세요.',
                                  actionLabel: '마음 기록',
                                  onAction: _addRecord,
                                ),
                              ...records.items.map((record) => RecordTile(
                                key: ValueKey(record.id),
                                record: record,
                                onDelete: _deletingId == record.id ? null : () => _delete(record),
                              )),
                              if (records.error != null && records.items.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(records.error!, style: TextStyle(color: colors.error)),
                                ),
                              if (records.isLoadingMore)
                                const Center(child: CircularProgressIndicator())
                              else if (records.hasMore)
                                OutlinedButton(
                                  key: const ValueKey('load-more-records'),
                                  onPressed: records.loadMore,
                                  child: Text('이전 기록 더 보기 (${records.items.length}/${records.total})'),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: records.items.isEmpty ? null : FloatingActionButton.extended(
        key: const ValueKey('list-add-record'),
        onPressed: _addRecord,
        icon: const Icon(Icons.add),
        label: const Text('마음 기록'),
      ),
      bottomNavigationBar: const AppNavigation(index: 1),
    );
  }
}
