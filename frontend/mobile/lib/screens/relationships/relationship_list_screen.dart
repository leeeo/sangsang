import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/relationship.dart';
import '../../providers/relationship_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_shell.dart';
import '../transactions/transaction_form_screen.dart';
import 'relationship_form_screen.dart';

class RelationshipListScreen extends StatefulWidget {
  const RelationshipListScreen({super.key});

  @override
  State<RelationshipListScreen> createState() => _RelationshipListScreenState();
}

class _RelationshipListScreenState extends State<RelationshipListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RelationshipProvider>().fetchRelationships();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPerson() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RelationshipFormScreen()),
    );
    if (result == true && mounted) {
      await context.read<RelationshipProvider>().fetchRelationships();
    }
  }

  Future<void> _addRecord(Relationship person) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionFormScreen(
        initialCounterpartyName: person.counterpartyName,
      )),
    );
    if (mounted) {
      await context.read<RelationshipProvider>().fetchRelationships();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelationshipProvider>();
    final query = _searchCtrl.text.trim().toLowerCase();
    final people = provider.items.where((person) =>
        person.counterpartyName.toLowerCase().contains(query)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('함께한 사람'),
        actions: [
          IconButton(
            key: const ValueKey('people-add'),
            tooltip: '사람 추가',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addPerson,
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigation(index: 2),
      body: SafeArea(
        child: PageBody(
          child: RefreshIndicator(
            onRefresh: provider.fetchRelationships,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('마음은 사람 곁에 남아요.',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text('함께한 사람을 찾아 다음 마음을 기록해 보세요.'),
                        const SizedBox(height: 24),
                        TextField(
                          key: const ValueKey('people-search'),
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: '이름으로 찾기',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: query.isEmpty ? null : IconButton(
                              tooltip: '검색 지우기',
                              onPressed: () => setState(_searchCtrl.clear),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (provider.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      message: '사람 목록을 불러오지 못했어요. 다시 시도해 주세요.',
                      onRetry: provider.fetchRelationships,
                    ),
                  )
                else if (provider.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.people_outline,
                      title: '기억하고 싶은 사람을 남겨 보세요',
                      message: '사람을 추가하면 주고받은 마음을 한곳에서 볼 수 있어요.',
                      actionLabel: '첫 사람 추가하기',
                      onAction: _addPerson,
                    ),
                  )
                else if (people.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.search_off,
                      title: '찾는 이름이 없어요',
                      message: '이름을 다시 확인하거나 새 사람을 추가해 주세요.',
                      actionLabel: '검색 지우기',
                      onAction: () => setState(_searchCtrl.clear),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList.builder(
                      itemCount: people.length,
                      itemBuilder: (_, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RelationshipCard(
                          rel: people[index],
                          onRecord: () => _addRecord(people[index]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  final Relationship rel;
  final VoidCallback onRecord;

  const _RelationshipCard({required this.rel, required this.onRecord});

  String? get _relationshipLabel {
    final value = rel.relationshipType;
    if (value == null || value.isEmpty) return null;
    return const {
      'family': '가족',
      'friend': '친구',
      'colleague': '직장동료',
      'coworker': '직장동료',
      'acquaintance': '지인',
      'other': '기타',
    }[value] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAmounts = rel.totalGiven != 0 || rel.totalReceived != 0;
    final summary = !hasAmounts
        ? '아직 주고받은 금액이 없어요.'
        : rel.balance == 0
            ? '보낸 마음과 받은 마음의 금액이 같아요.'
            : '${rel.balance > 0 ? '보낸 마음' : '받은 마음'}이 '
                '${formatKRW(rel.balance.abs())} 더 많아요.';
    return Card(
      key: ValueKey('person-${rel.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rel.counterpartyName, style: theme.textTheme.titleMedium),
                      if (_relationshipLabel != null)
                        Text(_relationshipLabel!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('보낸 마음 ${formatKRW(rel.totalGiven)}',
                    style: TextStyle(color: AppColors.sentOf(context))),
                Text('받은 마음 ${formatKRW(rel.totalReceived)}',
                    style: TextStyle(color: AppColors.receivedOf(context))),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: theme.textTheme.bodySmall),
            if (rel.lastTransactionDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '최근 기록 ${DateFormat('yyyy.MM.dd').format(rel.lastTransactionDate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: ValueKey('person-record-${rel.id}'),
              onPressed: onRecord,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('이 사람과 마음 기록'),
            ),
          ],
        ),
      ),
    );
  }
}
