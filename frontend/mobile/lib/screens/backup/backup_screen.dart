import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/local_store.dart';
import '../../providers/auth_provider.dart';

/// 데이터 백업/복원 화면 (로컬 모드 전용).
/// - 전체 백업(JSON): 재설치·기기변경 대비 복원 가능한 파일
/// - 거래 CSV: 엑셀에서 열어보기용
/// - 가져오기(JSON): 백업 파일로 복원
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  String _todayStamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
    ));
  }

  Future<void> _exportJson() async {
    setState(() => _busy = true);
    try {
      final data = await LocalStore.instance.exportBackup();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sangsang-backup-${_todayStamp()}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '상부상조 백업',
        text: '상부상조 백업 파일입니다. 안전한 곳(드라이브/파일 앱)에 보관하세요.',
      );
    } catch (e) {
      _snack('백업 내보내기 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final csv = await LocalStore.instance.exportTransactionsCsv();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sangsang-거래내역-${_todayStamp()}.csv');
      // BOM 추가 → 엑셀이 한글을 깨짐 없이 인식
      await file.writeAsString('\uFEFF$csv');
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '상부상조 거래 내역',
      );
    } catch (e) {
      _snack('CSV 내보내기 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importJson() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('백업 복원'),
        content: const Text(
            '선택한 백업 파일의 내용을 현재 데이터에 복원합니다.\n같은 기록은 덮어쓰고, 새 기록은 추가됩니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('복원')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // async gap 전에 context 의존 객체를 미리 확보
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final content = await File(path).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final count = await LocalStore.instance.importBackup(data);
      await auth.fetchMe();
      if (!mounted) return;
      _snack('복원 완료 — 거래 $count건');
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      _snack('복원 실패: 올바른 상부상조 백업 파일인지 확인하세요', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: const Text('백업 / 복원', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Notice(),
              const SizedBox(height: 16),
              _Section(title: '내보내기', children: [
                _ActionTile(
                  icon: Icons.backup_outlined,
                  color: const Color(0xFF6366F1),
                  title: '전체 백업 (JSON)',
                  subtitle: '기기 변경·재설치 대비. 이 파일로 복원 가능',
                  onTap: _busy ? null : _exportJson,
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF10B981),
                  title: '거래 내역 (CSV)',
                  subtitle: '엑셀에서 열어보기용',
                  onTap: _busy ? null : _exportCsv,
                ),
              ]),
              const SizedBox(height: 16),
              _Section(title: '가져오기', children: [
                _ActionTile(
                  icon: Icons.restore_outlined,
                  color: const Color(0xFFF59E0B),
                  title: '백업 파일로 복원 (JSON)',
                  subtitle: '내보낸 백업(.json)을 선택해 복원',
                  onTap: _busy ? null : _importJson,
                ),
              ]),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withAlpha(30),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '모든 기록은 이 기기에만 저장됩니다.\n앱을 삭제하거나 기기를 바꾸면 데이터가 사라지니, 백업 파일을 드라이브·파일 앱 등에 보관하세요.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
      onTap: onTap,
    );
  }
}
