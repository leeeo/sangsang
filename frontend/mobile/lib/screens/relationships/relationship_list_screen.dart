import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/relationship_provider.dart';
import '../../models/relationship.dart';
import '../../widgets/amount_text.dart';
import 'relationship_form_screen.dart';

class RelationshipListScreen extends StatefulWidget {
  const RelationshipListScreen({super.key});

  @override
  State<RelationshipListScreen> createState() => _RelationshipListScreenState();
}

class _RelationshipListScreenState extends State<RelationshipListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RelationshipProvider>().fetchRelationships();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelationshipProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: const Text('관계 관리', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RelationshipFormScreen()),
              );
              if (result == true && context.mounted) {
                context.read<RelationshipProvider>().fetchRelationships();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<RelationshipProvider>().fetchRelationships(),
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.items.isEmpty
                ? _EmptyState(
                    onAdd: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const RelationshipFormScreen()),
                      );
                      if (result == true && context.mounted) {
                        context.read<RelationshipProvider>().fetchRelationships();
                      }
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.items.length,
                    itemBuilder: (_, i) => _RelationshipCard(rel: provider.items[i]),
                  ),
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  final Relationship rel;
  const _RelationshipCard({required this.rel});

  @override
  Widget build(BuildContext context) {
    final balanceAbs = rel.balance.abs();
    final iGaveMore = rel.iGaveMore;
    final balanceColor = iGaveMore ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final balanceLabel = iGaveMore ? '내가 더 줌' : '내가 더 받음';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withAlpha(30),
                  child: Text(
                    rel.counterpartyName.isNotEmpty ? rel.counterpartyName[0] : '?',
                    style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rel.counterpartyName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (rel.relationshipType != null)
                        Text(rel.relationshipType!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (balanceAbs > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatKRW(balanceAbs),
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: balanceColor)),
                      Text(balanceLabel,
                          style: TextStyle(fontSize: 11, color: balanceColor)),
                    ],
                  )
                else
                  const Text('정산 완료', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(label: '줌', value: formatKRW(rel.totalGiven), color: const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                _StatChip(label: '받음', value: formatKRW(rel.totalReceived), color: const Color(0xFF10B981)),
                const Spacer(),
                if (rel.lastTransactionDate != null)
                  Text(
                    '최근 ${DateFormat('yy.MM.dd').format(rel.lastTransactionDate!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('등록된 관계가 없습니다', style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('관계 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
