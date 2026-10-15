import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/analytics.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/delayed_spinner.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _month;
  String _catType = 'expense';
  int _trendMonths = 6;
  bool _showTrends = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMonth();
      _loadTrends();
    });
  }

  Future<void> _loadMonth() async {
    final provider = context.read<AnalyticsProvider>();
    await Future.wait([
      provider.fetchSummary(year: _month.year, month: _month.month),
      _loadCategories(),
    ]);
  }

  Future<void> _loadCategories() =>
      context.read<AnalyticsProvider>().fetchByCategory(
        year: _month.year,
        month: _month.month,
        type: _catType,
      );

  Future<void> _loadTrends() =>
      context.read<AnalyticsProvider>().fetchTrends(months: _trendMonths);

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _loadMonth();
  }

  Future<void> _addRecord() async {
    await Navigator.pushNamed(context, '/transactions/new');
    if (!mounted) return;
    _loadMonth();
    _loadTrends();
  }

  Widget _empty(String message, {required String section}) => Card(
    key: ValueKey('analytics-$section-empty'),
    child: AppEmptyState(
      icon: Icons.auto_stories_outlined,
      title: '기억할 마음을 남겨보세요',
      message: message,
      actionLabel: '마음 기록',
      onAction: _addRecord,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('마음 돌아보기')),
      body: SafeArea(
        child: PageBody(
          child: RefreshIndicator(
            onRefresh: _showTrends ? _loadTrends : _loadMonth,
            child: ListView(
              key: const ValueKey('analytics-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
              Text('함께한 마음을 돌아봐요.',
                    style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('analytics-monthly-tab'),
                      label: const Text('월별 기록'),
                      selected: !_showTrends,
                      onSelected: (_) => setState(() => _showTrends = false),
                    ),
                    ChoiceChip(
                      key: const ValueKey('analytics-trends-tab'),
                      label: const Text('마음의 흐름'),
                      selected: _showTrends,
                      onSelected: (_) => setState(() => _showTrends = true),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_showTrends)
                  ..._trends(provider)
                else
                  ..._monthly(provider),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppNavigation(index: 3),
    );
  }

  List<Widget> _monthly(AnalyticsProvider provider) {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final summary = provider.summary;
    return [
      Row(
        children: [
          IconButton(
            key: const ValueKey('analytics-month-previous'),
            tooltip: '이전 달',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Semantics(
              key: const ValueKey('analytics-month-period'),
              label: '${_month.year}년 ${_month.month}월',
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Text('${_month.year}년', style: Theme.of(context).textTheme.titleLarge),
                    Text('${_month.month}월', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('analytics-month-next'),
            tooltip: '다음 달',
            onPressed: isCurrent ? null : () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      if (!isCurrent)
        Align(
          alignment: Alignment.center,
          child: TextButton(
            key: const ValueKey('analytics-month-current'),
            onPressed: () {
              setState(() => _month = DateTime(now.year, now.month));
              _loadMonth();
            },
            child: const Text('이번 달로'),
          ),
        ),
      const SizedBox(height: 16),
      if (provider.isLoading)
        const _LoadingSection(section: 'summary')
      else if (provider.summaryError != null)
        AppErrorState(
          key: const ValueKey('analytics-summary-error'),
          message: provider.summaryError!,
          onRetry: () => provider.fetchSummary(
            year: _month.year,
            month: _month.month,
          ),
        )
      else if (summary == null ||
          (summary.incomeCount == 0 && summary.expenseCount == 0))
        _empty('이 달에는 아직 주고받은 기록이 없어요.', section: 'summary')
      else
        _SummaryCard(summary: summary),
      const SizedBox(height: 32),
      Text('어떤 마음을 나눴나요',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in ['expense', 'income'])
            ChoiceChip(
              key: ValueKey('analytics-category-$type'),
              avatar: Icon(
                type == 'expense' ? Icons.north_east : Icons.south_west,
              ),
              label: Text(type == 'expense' ? '보낸 마음' : '받은 마음'),
              selected: _catType == type,
              onSelected: (_) {
                setState(() => _catType = type);
                _loadCategories();
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (provider.isCatLoading)
        const _LoadingSection(section: 'category')
      else if (provider.categoryError != null)
        AppErrorState(
          key: const ValueKey('analytics-category-error'),
          message: provider.categoryError!,
          onRetry: _loadCategories,
        )
      else if (provider.categoryStats.isEmpty)
        _empty('선택한 방향의 기록이 이 달에는 없어요.', section: 'category')
      else
        ...provider.categoryStats.map(
          (stat) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryCard(stat: stat, isExpense: _catType == 'expense'),
          ),
        ),
    ];
  }

  List<Widget> _trends(AnalyticsProvider provider) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - _trendMonths + 1);
    return [
      Text('월별 마음 기록',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        '${start.year}년 ${start.month}월 ~ ${now.year}년 ${now.month}월',
        key: const ValueKey('analytics-trend-period'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final months in [3, 6, 12])
            ChoiceChip(
              key: ValueKey('analytics-trend-$months'),
              label: Text('최근 $months개월'),
              selected: _trendMonths == months,
              onSelected: (_) {
                setState(() => _trendMonths = months);
                _loadTrends();
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (provider.isTrendLoading)
        const _LoadingSection(section: 'trend')
      else if (provider.trendError != null)
        AppErrorState(
          key: const ValueKey('analytics-trend-error'),
          message: provider.trendError!,
          onRetry: _loadTrends,
        )
      else if (provider.trends.isEmpty ||
          provider.trends.every((point) => point.income == 0 && point.expense == 0))
        _empty('선택한 기간에 주고받은 기록이 없어요.', section: 'trend')
      else
        ...provider.trends.reversed.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${point.year}년 ${point.month}월',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _Amounts(income: point.income, expense: point.expense),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _LoadingSection extends StatelessWidget {
  final String section;
  const _LoadingSection({required this.section});

  @override
  Widget build(BuildContext context) => Center(
    key: ValueKey('analytics-$section-loading'),
    child: SizedBox(
      height: section == 'summary' ? 320 : 136,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('기록을 불러오는 중이에요.'),
          SizedBox(height: 16),
          DelayedSpinner(),
        ],
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final AnalyticsSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final difference = summary.balance;
    final description = difference == 0
        ? '주고받은 금액이 같아요.'
        : '${difference > 0 ? '받은' : '보낸'} 마음이 더 많아요.\n'
            '차이 ${formatKRW(difference.abs())}';
    return Card(
      key: const ValueKey('analytics-summary'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Amounts(
              income: summary.income,
              expense: summary.expense,
              incomeCount: summary.incomeCount,
              expenseCount: summary.expenseCount,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('주고받은 차이', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              description,
              key: ValueKey(
                'analytics-difference-${difference.sign.toInt()}',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text('갚을 돈은 아니에요.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Amounts extends StatelessWidget {
  final double income;
  final double expense;
  final int? incomeCount;
  final int? expenseCount;

  const _Amounts({
    required this.income,
    required this.expense,
    this.incomeCount,
    this.expenseCount,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      // Keep a single reading column on phones and with large text.
      final sideBySide = constraints.maxWidth >= 640 * scale;
      final received = _amount(context, false, income, incomeCount);
      final sent = _amount(context, true, expense, expenseCount);
      return sideBySide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: received),
                const SizedBox(width: 24),
                Expanded(child: sent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                received,
                const SizedBox(height: 16),
                sent,
              ],
            );
    },
  );

  Widget _amount(BuildContext context, bool sent, double amount, int? count) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sent ? Icons.north_east : Icons.south_west,
                color: sent ? AppColors.sentOf(context) : AppColors.receivedOf(context),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(sent ? '보낸 마음' : '받은 마음')),
            ],
          ),
          const SizedBox(height: 8),
          AmountText(amount: amount, isExpense: sent, fontSize: 24),
          if (count != null) ...[
            const SizedBox(height: 4),
            Text('$count건', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

class _CategoryCard extends StatelessWidget {
  final CategoryStat stat;
  final bool isExpense;
  const _CategoryCard({required this.stat, required this.isExpense});

  @override
  Widget build(BuildContext context) {
    final color = isExpense
        ? AppColors.sentOf(context)
        : AppColors.receivedOf(context);
    final percentage = '${(stat.ratio * 100).toStringAsFixed(1)}%';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AmountText(amount: stat.total, isExpense: isExpense),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: ValueKey('analytics-category-progress-${stat.id}'),
              value: stat.ratio,
              semanticsLabel: '${stat.displayName} 비율',
              semanticsValue: (stat.ratio * 100).toStringAsFixed(1),
              color: color,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Text(
                  percentage,
                  key: ValueKey('analytics-category-percent-${stat.id}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text('${stat.count}건', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
