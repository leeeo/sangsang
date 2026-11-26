import 'dart:convert';
import 'dart:typed_data';

import '../models/category.dart';
import 'xlsx_rows.dart';

typedef LedgerKey = ({
  String date,
  String person,
  double amount,
  String direction,
});

LedgerKey ledgerKey(
  String date,
  String? person,
  num amount,
  String direction,
) => (
  date: date.split('T').first,
  person: (person ?? '').trim().toLowerCase(),
  amount: amount.toDouble(),
  direction: direction,
);

LedgerKey ledgerKeyFromRow(Map<String, Object?> row) => ledgerKey(
  row['transaction_date'] as String,
  row['counterparty_name'] as String?,
  row['amount'] as num,
  row['type'] as String,
);

class ImportRow {
  final int number;
  final List<String> cells;
  final String? error;
  final LedgerKey? key;
  final String? categoryId;
  final bool duplicate;

  const ImportRow(
    this.number,
    this.cells, {
    this.error,
    this.key,
    this.categoryId,
    this.duplicate = false,
  });

  String get person => cells[1].trim();
  String get memo => cells[5].trim();
}

abstract final class LedgerImport {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxRows = 1000;
  static const tooLarge = '2MB 이하의 엑셀 또는 CSV 파일을 선택해 주세요.';
  static const headers = ['날짜', '이름', '금액', '방향', '장부 분류', '메모'];
  static String get template => '${headers.join(',')}\r\n';

  static List<ImportRow> parse(
    Uint8List bytes,
    String extension,
    List<Category> categories,
    Set<LedgerKey> existing,
  ) {
    if (bytes.length > maxBytes) throw const FormatException(tooLarge);
    final List<SheetRow> rows;
    try {
      rows = switch (extension.toLowerCase()) {
        'csv' => _csvRows(utf8.decode(bytes)),
        'xlsx' => xlsxRows(bytes, maxRows, headers.length),
        _ => throw const FormatException('.xlsx 또는 UTF-8 CSV 파일을 선택해 주세요.'),
      };
    } on FormatException catch (e) {
      if (e.source == null && e.message.isNotEmpty) rethrow;
      throw const FormatException(
        '파일을 읽을 수 없어요. 엑셀(.xlsx) 또는 UTF-8 CSV인지 확인해 주세요.',
      );
    } catch (_) {
      throw const FormatException('파일 구조를 읽을 수 없어요. 양식과 첫 번째 시트를 확인해 주세요.');
    }
    if (rows.isEmpty ||
        rows.first.number != 1 ||
        rows.first.hasFormula ||
        rows.first.cells.length != headers.length ||
        Iterable<int>.generate(headers.length).any(
          (i) =>
              rows.first.cells[i].length > 2048 ||
              rows.first.cells[i].trim() != headers[i],
        )) {
      throw const FormatException('첫 행의 열 제목과 순서를 내려받은 양식과 같게 맞춰 주세요.');
    }
    final seen = {...existing};
    return [
      for (final row in rows.skip(1))
        if (row.hasFormula ||
            row.cells.any((s) => s.length > 2048 || s.trim().isNotEmpty))
          _validate(row, categories, seen),
    ];
  }

  static ImportRow _validate(
    SheetRow row,
    List<Category> categories,
    Set<LedgerKey> seen,
  ) {
    final cells = row.cells;
    ImportRow bad(String message) =>
        ImportRow(row.number, cells, error: message);
    if (row.hasFormula) return bad('수식은 값으로 바꿔 주세요.');
    if (cells.length != headers.length) return bad('쉼표와 열 개수(6개)를 확인해 주세요.');
    if (cells.any((s) => s.length > 2048)) {
      return bad('셀에 입력한 내용이 너무 길어요.');
    }
    final [date, person, value, direction, category, memo] = cells
        .map((s) => s.trim())
        .toList();
    final day = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        day == null ||
        day.year < 1900 ||
        day.year > 2100 ||
        day.toIso8601String().substring(0, 10) != date) {
      return bad('날짜를 YYYY-MM-DD로 입력해 주세요.');
    }
    if (person.length > 100 ||
        memo.length > 1000 ||
        cells.any((s) => s.contains('\u0000'))) {
      return bad('이름은 100자, 메모는 1,000자 이내로 입력해 주세요.');
    }
    final amount = int.tryParse(value.replaceAll(',', ''));
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(value) ||
        amount == null ||
        amount < 1 ||
        amount > 1000000000) {
      return bad('금액은 1~10억 원 사이의 정수로 입력해 주세요.');
    }
    final type = switch (direction) {
      '보냄' || '보낸 마음' => 'expense',
      '받음' || '받은 마음' => 'income',
      _ => null,
    };
    if (type == null) return bad('방향에 ‘보냄’ 또는 ‘받음’을 입력해 주세요.');
    final categoryId = category.isEmpty
        ? (type == 'expense' ? 'sys-14' : 'sys-15')
        : categories
              .where(
                (c) =>
                    c.type == type &&
                    (c.displayName == category || c.name == category),
              )
              .singleOrNull
              ?.id;
    if (categoryId == null) return bad('방향에 맞는 장부 분류 이름을 입력하거나 비워 주세요.');
    final key = ledgerKey(date, person, amount, type);
    return ImportRow(
      row.number,
      cells,
      key: key,
      categoryId: categoryId,
      duplicate: !seen.add(key),
    );
  }

  static List<SheetRow> _csvRows(String text) {
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final rows = <SheetRow>[];
    var cells = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    void addField() {
      if (cells.length >= 64) throw const FormatException('CSV에 너무 많은 열이 있어요.');
      cells.add(field.toString());
      field = StringBuffer();
      closed = false;
    }

    void addRow() {
      addField();
      if (rows.length > maxRows) {
        throw const FormatException('제목 아래 1,000행까지 가져올 수 있어요.');
      }
      rows.add((number: rows.length + 1, cells: cells, hasFormula: false));
      cells = [];
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write(c);
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == ',') {
        addField();
      } else if (c == '\r' || c == '\n') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        addRow();
      } else if (!closed && c == '"' && field.isEmpty) {
        quoted = true;
      } else if (closed || c == '"') {
        throw FormatException('CSV ${rows.length + 1}행의 따옴표가 올바르지 않아요.');
      } else {
        field.write(c);
      }
    }
    if (quoted) {
      throw FormatException('CSV ${rows.length + 1}행의 따옴표가 닫히지 않았어요.');
    }
    if (field.isNotEmpty || closed || cells.isNotEmpty) addRow();
    return rows;
  }
}
