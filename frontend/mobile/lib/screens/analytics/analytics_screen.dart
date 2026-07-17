import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../models/analytics.dart';
import '../../widgets/amount_text.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _now = DateTime.now();
  late int _selectedYear;
  late int _selectedMonth;
  String _catType = 'expense';
  int _trendMonths = 6;

  @override
  void initState() {
    super.initState();
    _selectedYear = _now.year;
    _selectedMonth = _now.month;
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void _loadAll() {
    final p = context.read<AnalyticsProvider>();
    p.fetchSummary(year: _selectedYear, month: _selectedMonth);
    p.fetchTrends(months: _trendMonths);
    p.fetchByCategory(year: _selectedYear, month: _selectedMonth, type: _catType);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: const Text('분석', style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: '월별 요약'), Tab(text: '트렌드')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlySummaryTab(
            year: _selectedYear,
            month: _selectedMonth,
            catType: _catType,
            onMonthChanged: (y, m) {
              setState(() { _selectedYear = y; _selectedMonth = m; });
              final p = context.read<AnalyticsProvider>();
              p.fetchSummary(year: y, month: m);
              p.fetchByCategory(year: y, month: m, type: _catType);
            },
            onTypeChanged: (t) {
              setState(() => _catType = t);
              context.read<AnalyticsProvider>().fetchByCategory(
                  year: _selectedYear, month: _selectedMonth, type: t);
            },
          ),
          _TrendTab(
            months: _trendMonths,
            onMonthsChanged: (m) {
              setState(() => _trendMonths = m);
              context.read<AnalyticsProvider>().fetchTrends(months: m);
            },
          ),
        ],
      ),
    );
  }
}

// ─── 월별 요약 탭 ────────────────────────────────────────────────────────────

class _MonthlySummaryTab extends StatelessWidget {
  final int year;
  final int month;
  final String catType;
  final void Function(int, int) onMonthChanged;
  final void Function(String) onTypeChanged;

  const _MonthlySummaryTab({
    required this.year,
    required this.month,
    required this.catType,
    required this.onMonthChanged,
    required this.onTypeChanged,
  });

  void _prevMonth(int y, int m) {
    if (m == 1) { onMonthChanged(y - 1, 12); }
    else { onMonthChanged(y, m - 1); }
  }

  void _nextMonth(int y, int m) {
    final now = DateTime.now();
    if (y > now.year || (y == now.year && m >= now.month)) { return; }
    if (m == 12) { onMonthChanged(y + 1, 1); }
    else { onMonthChanged(y, m + 1); }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return RefreshIndicator(
      onRefresh: () async {
        final ap = context.read<AnalyticsProvider>();
        await Future.wait([
          ap.fetchSummary(year: year, month: month),
          ap.fetchByCategory(year: year, month: month, type: catType),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 월 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _prevMonth(year, month),
              ),
              Text(
                '$year년 $month월',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: isCurrentMonth ? Colors.grey.shade300 : null),
                onPressed: isCurrentMonth ? null : () => _nextMonth(year, month),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 수입/지출 요약 카드
          if (p.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (p.summary != null)
            _SummaryCards(summary: p.summary!),

          const SizedBox(height: 20),

          // 카테고리별 분석
          Row(
            children: [
              const Text('카테고리별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              _TypeToggle(selected: catType, onChanged: onTypeChanged),
            ],
          ),
          const SizedBox(height: 12),
          if (p.isCatLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (p.categoryStats.isEmpty)
            _EmptyCard(text: '해당 기간 데이터가 없습니다')
          else
            ...p.categoryStats.map((c) => _CategoryBar(stat: c, type: catType)),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AnalyticsSummary summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _InfoCard(label: '수입', amount: summary.income, count: summary.incomeCount, color: const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _InfoCard(label: '지출', amount: summary.expense, count: summary.expenseCount, color: const Color(0xFFEF4444)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('순 잔액', style: TextStyle(fontSize: 14, color: Colors.grey)),
              AmountText(
                amount: summary.balance.abs(),
                isExpense: summary.balance < 0,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final Color color;
  const _InfoCard({required this.label, required this.amount, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
            const SizedBox(height: 8),
            Text(formatKRW(amount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text('$count건', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryStat stat;
  final String type;
  const _CategoryBar({required this.stat, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = stat.color != null
        ? _parseColor(stat.color!)
        : (type == 'expense' ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(formatKRW(stat.total),
                  style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.ratio / 100,
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${stat.ratio}% · ${stat.count}건', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

class _TypeToggle extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ToggleBtn(label: '지출', value: 'expense', selected: selected, onTap: onChanged),
          _ToggleBtn(label: '수입', value: 'income', selected: selected, onTap: onChanged),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _ToggleBtn({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ─── 트렌드 탭 ────────────────────────────────────────────────────────────────

class _TrendTab extends StatelessWidget {
  final int months;
  final void Function(int) onMonthsChanged;
  const _TrendTab({required this.months, required this.onMonthsChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();

    return RefreshIndicator(
      onRefresh: () => context.read<AnalyticsProvider>().fetchTrends(months: months),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 기간 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [3, 6, 12].map((m) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text('$m개월'),
                selected: months == m,
                onSelected: (_) => onMonthsChanged(m),
                selectedColor: const Color(0xFF6366F1),
                labelStyle: TextStyle(
                    color: months == m ? Colors.white : Colors.grey,
                    fontSize: 12),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),

          if (p.isTrendLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (p.trends.isEmpty)
            _EmptyCard(text: '트렌드 데이터가 없습니다')
          else
            ...p.trends.reversed.map((t) => _TrendRow(point: t)),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final TrendPoint point;
  const _TrendRow({required this.point});

  @override
  Widget build(BuildContext context) {
    final net = point.income - point.expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(point.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                (net >= 0 ? '+' : '') + formatKRW(net.abs()),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _BarStat(label: '수입', amount: point.income, color: const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _BarStat(label: '지출', amount: point.expense, color: const Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _BarStat({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(formatKRW(amount), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey))),
    );
  }
}
