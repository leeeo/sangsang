import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_config.dart';
import '../../models/record_query.dart';
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
  final _name = TextEditingController();
  String? _categoryId;
  DateTimeRange? _period;
  RecordOrder _order = RecordOrder.newest;
  int _resetVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _name.clear();
    _selected = 'all';
    _categoryId = null;
    _period = null;
    _order = RecordOrder.newest;
    _resetVersion++;
  });

  Future<void> _selectPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _period,
    );
    if (mounted && picked != null) setState(() => _period = picked);
  }

  Future<void> _reload() async {
    setState(() => _categoryError = false);
    try {
      await Future.wait([
        // Filtering and totals must use the full ledger, not just the first page.
        AppConfig.isLocal
            ? context.read<TransactionProvider>().fetchTransactions(limit: -1)
            : context.read<TransactionProvider>().fetchTransactions(
                type: _selected == 'all' ? null : _selected,
              ),
        context.read<CategoryProvider>().fetchCategories(),
      ]);
    } catch (_) {
      if (mounted) setState(() => _categoryError = true);
    }
  }

  Future<void> _addRecord() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          initialType: _selected == 'all' ? 'expense' : _selected,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _delete(Transaction record) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 기록을 지울까요?'),
        content: Text(
          '${record.counterpartyName ?? '이름 없이 남긴 기록'} · '
          '${formatKRW(record.amount)}\n삭제한 기록은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('남겨두기'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('기록 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = record.id);
    final ok = await context.read<TransactionProvider>().deleteTransaction(
      record.id,
    );
    if (!mounted) return;
    setState(() => _deletingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '기록을 삭제했어요.' : '삭제하지 못했어요. 기록은 그대로 있으니 다시 시도해 주세요.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<TransactionProvider>();
    final local = AppConfig.isLocal;
    final categories = context.watch<CategoryProvider>().categories;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final colors = Theme.of(context).colorScheme;
    final query = RecordQuery(
      name: _name.text,
      type: _selected,
      categoryId: _categoryId,
      start: _period?.start,
      end: _period?.end,
      order: _order,
    );
    final result = local ? query.apply(records.items) : null;
    final visible = result?.items ?? records.items;
    final filtered =
        _name.text.trim().isNotEmpty ||
        _selected != 'all' ||
        _categoryId != null ||
        _period != null;
    final usable =
        !records.isLoading && !_categoryError && records.error == null;
    final filters = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (local) ...[
          TextField(
            key: const ValueKey('record-name-filter'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '이름으로 찾기',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              const [('all', '전체'), ('expense', '보낸 마음'), ('income', '받은 마음')]
                  .map(
                    (item) => ChoiceChip(
                      key: ValueKey('filter-${item.$1}'),
                      label: Text(item.$2),
                      selected: _selected == item.$1,
                      onSelected: (_) {
                        if (_selected == item.$1) return;
                        setState(() => _selected = item.$1);
                        if (!local) _reload();
                      },
                    ),
                  )
                  .toList(),
        ),
        if (local) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('record-filter-category-$_resetVersion'),
                  decoration: const InputDecoration(labelText: '장부 분류'),
                  isExpanded: true,
                  initialValue: _categoryId ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('모든 분류')),
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _categoryId = value == '' ? null : value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<RecordOrder>(
                  key: ValueKey('record-order-$_resetVersion'),
                  decoration: const InputDecoration(labelText: '정렬'),
                  isExpanded: true,
                  initialValue: _order,
                  items: const [
                    DropdownMenuItem(
                      value: RecordOrder.newest,
                      child: Text('최근순'),
                    ),
                    DropdownMenuItem(
                      value: RecordOrder.oldest,
                      child: Text('오래된순'),
                    ),
                    DropdownMenuItem(
                      value: RecordOrder.largest,
                      child: Text('큰 금액순'),
                    ),
                    DropdownMenuItem(
                      value: RecordOrder.smallest,
                      child: Text('작은 금액순'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _order = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _selectPeriod,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _period == null
                      ? '기간: 전체'
                      : '${dateFormat.format(_period!.start)} ~ ${dateFormat.format(_period!.end)}',
                ),
              ),
              if (filtered || _order != RecordOrder.newest)
                TextButton(onPressed: _reset, child: const Text('초기화')),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (usable && result != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결과 ${visible.length}건 · 합계 ${formatKRW(result.total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('보냄 ${formatKRW(result.sent)}'),
                      Text('받음 ${formatKRW(result.received)}'),
                    ],
                  ),
                  if (visible.any(
                    (record) => result.sameNameNumbers.containsKey(record.id),
                  )) ...[
                    const SizedBox(height: 8),
                    const Text('같은 이름은 날짜·분류·메모로 구분해 보세요.'),
                  ],
                ],
              ),
            ),
          )
        else if (usable)
          Text('기록 ${records.total}건'),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('주고받은 기록'),
        actions: [
          if (records.items.isNotEmpty)
            IconButton(
              key: const ValueKey('list-add-record'),
              onPressed: _addRecord,
              tooltip: '경조사비 기록',
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            key: const ValueKey('record-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(child: filters),
              ),
              if (records.isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: '기록을 불러오는 중',
                    ),
                  ),
                )
              else if (_categoryError ||
                  (records.error != null && visible.isEmpty))
                SliverToBoxAdapter(
                  child: AppErrorState(
                    message: _categoryError
                        ? '분류 정보를 불러오지 못했어요.'
                        : records.error!,
                    onRetry: _reload,
                  ),
                )
              else if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.history_outlined,
                    title: filtered ? '조건에 맞는 기록이 없어요' : '아직 남긴 기록이 없어요',
                    message: filtered
                        ? '검색어나 필터를 바꿔 보세요.'
                        : '축하와 위로를 전한 날을 기억해 두세요.',
                    actionLabel: local && filtered ? '필터 초기화' : '경조사비 기록',
                    onAction: local && filtered ? _reset : _addRecord,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) {
                      final record = visible[index];
                      return RecordTile(
                        key: ValueKey(record.id),
                        record: record,
                        sameNameNumber: result?.sameNameNumbers[record.id],
                        onDelete: _deletingId == record.id
                            ? null
                            : () => _delete(record),
                      );
                    },
                  ),
                ),
              if (records.error != null && visible.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      records.error!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              if (records.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!local && records.hasMore)
                SliverToBoxAdapter(
                  child: OutlinedButton(
                    key: const ValueKey('load-more-records'),
                    onPressed: records.loadMore,
                    child: Text(
                      '이전 기록 더 보기 (${records.items.length}/${records.total})',
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigation(index: 1),
    );
  }
}
