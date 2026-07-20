import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_config.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../models/transaction.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().fetchSummary();
      context.read<TransactionProvider>().fetchTransactions(limit: 5);
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final analytics = context.watch<AnalyticsProvider>();
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('안녕하세요, ${user?.displayName ?? ''}님', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(DateFormat('yyyy년 MM월').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          // 로컬 모드에는 계정 개념이 없어 로그아웃을 노출하지 않는다 (서버 모드 전용)
          if (!AppConfig.isLocal)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final analytics = context.read<AnalyticsProvider>();
          final tx = context.read<TransactionProvider>();
          await Future.wait([
            analytics.fetchSummary(),
            tx.fetchTransactions(limit: 5),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요약 카드
              _SummaryCard(analytics: analytics),
              const SizedBox(height: 20),

              // 빠른 메뉴
              Row(
                children: [
                  _QuickMenu(
                    icon: Icons.people_outline,
                    label: '관계 관리',
                    onTap: () => Navigator.pushNamed(context, '/relationships'),
                  ),
                  const SizedBox(width: 12),
                  _QuickMenu(
                    icon: Icons.bar_chart_outlined,
                    label: '분석',
                    onTap: () => Navigator.pushNamed(context, '/analytics'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 최근 거래
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('최근 거래', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/transactions'),
                    child: const Text('전체 보기', style: TextStyle(color: Color(0xFF6366F1))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (txProvider.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (txProvider.items.isEmpty)
                _EmptyTransactions()
              else
                ...txProvider.items.map((tx) => _TransactionTile(tx: tx)),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(child: BannerAdWidget()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/transactions/new');
          if (!context.mounted) return;
          context.read<AnalyticsProvider>().fetchSummary();
          context.read<TransactionProvider>().fetchTransactions(limit: 5);
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('거래 등록'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AnalyticsProvider analytics;
  const _SummaryCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final s = analytics.summary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: analytics.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이번 달 잔액', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  s != null ? formatKRW(s.balance) : '-',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _StatItem(label: '수입', amount: s?.income ?? 0, color: const Color(0xFFD1FAE5))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatItem(label: '지출', amount: s?.expense ?? 0, color: const Color(0xFFFFEDED))),
                  ],
                ),
              ],
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _StatItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(formatKRW(amount), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final catName = context.read<CategoryProvider>().nameById(tx.categoryId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tx.isExpense ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tx.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.counterpartyName ?? catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(DateFormat('MM.dd').format(tx.transactionDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          AmountText(amount: tx.amount, isExpense: tx.isExpense, fontSize: 15),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('아직 거래 내역이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickMenu({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
