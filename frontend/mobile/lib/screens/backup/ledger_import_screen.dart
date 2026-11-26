import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/file_download.dart';
import '../../core/import_file.dart';
import '../../data/ledger_import.dart';
import '../../data/local_store.dart';
import '../../models/category.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/delayed_spinner.dart';

class LedgerImportScreen extends StatefulWidget {
  const LedgerImportScreen({super.key});

  @override
  State<LedgerImportScreen> createState() => _LedgerImportScreenState();
}

class _LedgerImportScreenState extends State<LedgerImportScreen> {
  static const _pageSize = 10;
  // Leave room for the row number and Material table margins at 320dp.
  static const _statusColumnWidth = 184.0;
  List<ImportRow>? _rows;
  ({int added, int skipped, int invalid})? _result;
  String? _error;
  bool _busy = false;
  bool _skip = true;
  int _page = 0;

  Future<void> _run(Future<void> Function() work, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _template() => _run(() async {
    const name = 'sangsang-import-template.csv';
    final data = '\uFEFF${LedgerImport.template}';
    if (kIsWeb) {
      downloadTextFile(name, data, 'text/csv;charset=utf-8');
    } else {
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/$name').writeAsString(data);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
    }
  }, '양식을 내려받지 못했어요. 다시 시도해 주세요.');

  Future<void> _pick() => _run(() async {
    final file = await pickImportFile(['xlsx', 'csv']);
    if (!mounted || file == null) return;
    setState(() {
      _rows = null;
      _result = null;
      _skip = true;
      _page = 0;
    });
    final bytes = await readImportFile(
      file,
      LedgerImport.maxBytes,
      LedgerImport.tooLarge,
    );
    final store = LocalStore.instance;
    final categories = (await store.listCategories())
        .map(Category.fromJson)
        .toList();
    final keys = await store.existingLedgerKeys();
    final rows = LedgerImport.parse(
      bytes,
      file.extension ?? '',
      categories,
      keys,
    );
    if (mounted) setState(() => _rows = rows);
  }, '파일을 열지 못했어요. 다시 선택해 주세요.');

  Future<void> _save() => _run(() async {
    final result = await LocalStore.instance.importLedger(
      _rows!,
      skipDuplicates: _skip,
    );
    if (!mounted) return;
    setState(() {
      _rows = null;
      _result = result;
    });
  }, '기록을 저장하지 못했어요. 장부에 반영하지 않았으니 다시 시도해 주세요.');

  String _display(ImportRow row, int index) {
    if (row.cells.length <= index || row.cells[index].isEmpty) return '—';
    final value = row.cells[index];
    if (value.length > 2048) return '내용이 너무 길어요';
    return value.length > 100 ? '${value.characters.take(100)}…' : value;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final result = _result;
    final theme = Theme.of(context);
    final invalid = rows?.where((r) => r.error != null).length ?? 0;
    final duplicates = rows?.where((r) => r.duplicate).length ?? 0;
    final eligible = (rows?.length ?? 0) - invalid - (_skip ? duplicates : 0);
    final pageCount = ((rows?.length ?? 0) / _pageSize).ceil();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('엑셀·CSV 가져오기')),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('파일로 기록 옮기기', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('파일은 이 기기에서만 읽어요. 내용을 확인한 뒤 장부에 저장할 수 있어요.'),
                      const SizedBox(height: 8),
                      const Text(
                        '양식을 엑셀로 열어 첫 시트에 작성하세요.\n'
                        '날짜는 YYYY-MM-DD, 방향은 보냄 또는 받음으로 적어 주세요.\n'
                        '이름·분류·메모는 비워도 돼요.',
                      ),
                      const SizedBox(height: 8),
                      const Text('엑셀(.xlsx) 또는 UTF-8 CSV · 최대 2MB, 1,000행'),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _template,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('CSV 양식 받기'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.file_open_outlined),
                            label: const Text('파일 선택'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: DelayedSpinner()),
                ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              if (result != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('가져오기 결과', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            '추가 ${result.added}건 · 중복 건너뜀 ${result.skipped}건 · 오류 제외 ${result.invalid}건',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (rows != null) ...[
                const SizedBox(height: 24),
                Text('저장 전 미리보기', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  const Text('제목 아래에 가져올 기록이 없어요.')
                else ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '${rows.length}행 · 오류 $invalid행 · 중복 $duplicates행',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('중복 기록 건너뛰기'),
                    subtitle: const Text('날짜·이름·금액·방향이 모두 같은 기존 또는 파일 안 기록'),
                    value: _skip,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _skip = value ?? true),
                  ),
                  const SizedBox(height: 8),
                  const Text('표의 나머지 열은 가로로 스크롤해 확인할 수 있어요.'),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMaxHeight: double.infinity,
                        columns: [
                          const DataColumn(label: Text('행')),
                          const DataColumn(label: Text('상태')),
                          for (final heading in LedgerImport.headers)
                            DataColumn(label: Text(heading)),
                        ],
                        rows: [
                          for (final row
                              in rows.skip(_page * _pageSize).take(_pageSize))
                            DataRow(
                              cells: [
                                DataCell(Text('${row.number}')),
                                DataCell(
                                  SizedBox(
                                    width: _statusColumnWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        row.error ??
                                            (row.duplicate
                                                ? (_skip
                                                      ? '중복 · 건너뜀'
                                                      : '중복 · 추가 예정')
                                                : '추가 가능'),
                                        style: row.error == null
                                            ? null
                                            : TextStyle(
                                                color: theme.colorScheme.error,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                for (
                                  var i = 0;
                                  i < LedgerImport.headers.length;
                                  i++
                                )
                                  DataCell(Text(_display(row, i), maxLines: 1)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (pageCount > 1)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _page == 0 || _busy
                              ? null
                              : () => setState(() => _page--),
                          child: const Text('이전'),
                        ),
                        Text('${_page + 1} / $pageCount'),
                        TextButton(
                          onPressed: _page + 1 == pageCount || _busy
                              ? null
                              : () => setState(() => _page++),
                          child: const Text('다음'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || eligible == 0 ? null : _save,
                      child: Text('장부에 $eligible건 추가'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
