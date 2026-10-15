import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/file_download.dart';
import '../../data/local_store.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/delayed_spinner.dart';

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
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _exportJson() async {
    setState(() => _busy = true);
    try {
      final data = await LocalStore.instance.exportBackup();
      if (kIsWeb) {
        downloadTextFile('sangsang-backup-${_todayStamp()}.json',
            const JsonEncoder.withIndent('  ').convert(data), 'application/json');
        _snack('백업 파일을 내려받았습니다. 안전한 곳에 보관하세요.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sangsang-backup-${_todayStamp()}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '상부상조 백업',
        text: '상부상조 백업 파일입니다. 안전한 곳(드라이브/파일 앱)에 보관하세요.',
      );
    } catch (e) {
      debugPrint('Backup export failed: ${e.runtimeType}');
      _snack('백업 파일을 만들지 못했어요. 저장 공간을 확인하고 다시 시도해 주세요.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final csv = await LocalStore.instance.exportTransactionsCsv();
      if (kIsWeb) {
        downloadTextFile('sangsang-거래내역-${_todayStamp()}.csv', '\uFEFF$csv', 'text/csv;charset=utf-8');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sangsang-마음기록-${_todayStamp()}.csv');
      // BOM 추가 → 엑셀이 한글을 깨짐 없이 인식
      await file.writeAsString('\uFEFF$csv');
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '상부상조 주고받은 기록',
      );
    } catch (e) {
      debugPrint('CSV export failed: ${e.runtimeType}');
      _snack('기록 파일을 만들지 못했어요. 다시 시도해 주세요.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importJson() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: kIsWeb,
    );
    final file = picked?.files.single;
    // 웹은 경로가 없고 내용(bytes)만 온다.
    if (file == null || (kIsWeb ? file.bytes == null : file.path == null) || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('백업 복원'),
        content: const Text(
            '선택한 백업 파일의 내용을 현재 데이터에 복원합니다.\n같은 기록은 덮어쓰고, 새 기록은 추가됩니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('덮어쓰고 가져오기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // async gap 전에 context 의존 객체를 미리 확보
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final content = kIsWeb ? utf8.decode(file.bytes!) : await File(file.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final count = await LocalStore.instance.importBackup(data);
      await auth.fetchMe();
      if (!mounted) return;
      _snack('기록 $count건을 복원했어요.');
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
      appBar: AppBar(
        title: const Text('기록 보관'),
      ),
      body: PageBody(maxWidth: 640, child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Notice(),
              const SizedBox(height: 16),
              _Section(title: '내보내기', children: [
                _ActionTile(
                  icon: Icons.backup_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  title: '기록 백업 파일 만들기',
                  subtitle: '기기를 바꿔도 복원할 수 있는 JSON 파일',
                  onTap: _busy ? null : _exportJson,
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.table_chart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  title: '주고받은 기록 내려받기',
                  subtitle: '엑셀에서 보는 CSV 파일 · 앱 복원용은 아니에요',
                  onTap: _busy ? null : _exportCsv,
                ),
              ]),
              const SizedBox(height: 16),
              _Section(title: '가져오기', children: [
                _ActionTile(
                  icon: Icons.restore_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  title: '백업 파일로 복원하기',
                  subtitle: '내보낸 백업(.json)을 선택해 복원',
                  onTap: _busy ? null : _importJson,
                ),
              ]),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withAlpha(30),
              child: const Center(child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('백업 파일을 처리하는 중이에요.'),
                      SizedBox(height: 16),
                      DelayedSpinner(),
                    ],
                  ),
                ),
              )),
            ),
        ],
      )),
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
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '기록은 이 기기에만 저장돼요.\n앱 삭제·기기 변경 전에는\n백업 파일을 따로 보관해 주세요.',
              style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onPrimaryContainer, height: 1.5),
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
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
