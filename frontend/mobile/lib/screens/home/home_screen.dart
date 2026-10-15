import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/analytics.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/record_tile.dart';
import '../../widgets/delayed_spinner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    setState(() => _loadError = null);
    try {
      await Future.wait([
        context.read<AnalyticsProvider>().fetchSummary(year: now.year, month: now.month),
        context.read<TransactionProvider>().fetchTransactions(limit: 5),
        context.read<CategoryProvider>().fetchCategories(),
      ]);
    } catch (_) {
      if (mounted) setState(() => _loadError = '분류 정보를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<void> _addRecord() async {
    await Navigator.pushNamed(context, '/transactions/new');
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final analytics = context.watch<AnalyticsProvider>();
    final records = context.watch<TransactionProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('상부상조'),
        actions: [
          if (AppConfig.isLocal)
            IconButton(
              tooltip: '기록 백업',
              icon: const Icon(Icons.backup_outlined),
              onPressed: () => Navigator.pushNamed(context, '/backup'),
            ),
          if (!AppConfig.isLocal)
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout_outlined),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
            ),
        ],
      ),
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text('${user?.displayName ?? '나'}님의 마음 기록',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('챙겨준 마음도, 전한 마음도 잊지 않도록.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Text(DateFormat('yyyy년 M월').format(DateTime.now()),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/analytics'),
                    child: const Text('월별 보기'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (analytics.isLoading)
                const _MonthOverview(summary: null)
              else if (analytics.summaryError != null)
                AppErrorState(message: analytics.summaryError!, onRetry: _refresh)
              else if (analytics.summary != null)
                _MonthOverview(summary: analytics.summary!),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('home-add-record'),
                onPressed: _addRecord,
                icon: const Icon(Icons.add),
                label: const Text('마음 기록'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Text('최근 주고받은 마음',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/transactions'),
                    child: const Text('전체 보기'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadError != null)
                AppErrorState(message: _loadError!, onRetry: _refresh)
              else if (records.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (records.error != null)
                AppErrorState(message: records.error!, onRetry: _refresh)
              else if (records.items.isEmpty)
                const Card(child: AppEmptyState(
                  icon: Icons.volunteer_activism_outlined,
                  title: '첫 마음을 남겨보세요',
                  message: '함께한 사람과 경조사를 기록하면\n'
                      '다음에 챙길 때 꺼내볼 수 있어요.',
                ))
              else
                ...records.items.map((record) => RecordTile(record: record)),
              if (AppConfig.isLocal) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/backup'),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('소중한 기록, 백업으로 지켜두세요'),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [BannerAdWidget(), AppNavigation(index: 0)],
      ),
    );
  }
}

class _MonthOverview extends StatelessWidget {
  final AnalyticsSummary? summary;
  const _MonthOverview({required this.summary});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final stack = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
        (constraints.maxWidth < 500 && ((summary?.income ?? 0) >= 100000000 || (summary?.expense ?? 0) >= 100000000));
    final received = _MindTotal(label: '받은 마음', amount: summary?.income,
        count: summary?.incomeCount, color: AppColors.receivedOf(context), icon: Icons.call_received);
    final sent = _MindTotal(label: '보낸 마음', amount: summary?.expense,
        count: summary?.expenseCount, color: AppColors.sentOf(context), icon: Icons.call_made);
    return stack
        ? Column(children: [received, const SizedBox(height: 12), sent])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: received), const SizedBox(width: 12), Expanded(child: sent),
          ]);
  });
}

class _MindTotal extends StatelessWidget {
  final String label;
  final double? amount;
  final int? count;
  final Color color;
  final IconData icon;
  const _MindTotal({required this.label, required this.amount, required this.count,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 15)))]),
          const SizedBox(height: 16),
          if (amount == null)
            const Row(children: [
              Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              SizedBox(width: 12),
              DelayedSpinner(),
            ])
          else
            Text(formatKRW(amount!), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Text(count == null ? '불러오는 중' : '$count건의 마음',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    ),
  );
}
