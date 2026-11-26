import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangbu_sangjo/data/backup_format.dart';
import 'package:sangbu_sangjo/data/ledger_import.dart';
import 'package:sangbu_sangjo/models/category.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List xlsx(String rows, {String strings = '<sst/>', String? target}) {
  final zip = Archive();
  void add(String name, String value) =>
      zip.add(ArchiveFile.bytes(name, bytes(value)));
  add(
    'xl/workbook.xml',
    '<workbook xmlns:r="urn:relationships"><sheets><sheet r:id="rId1"/></sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships><Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="${target ?? 'worksheets/custom.xml'}"/></Relationships>',
  );
  add('xl/sharedStrings.xml', strings);
  add(
    'xl/worksheets/custom.xml',
    '<worksheet><sheetData>$rows</sheetData></worksheet>',
  );
  return ZipEncoder().encodeBytes(zip);
}

String get xlsxHeader =>
    '<row r="1">${LedgerImport.headers.map((s) => '<c t="inlineStr"><is><t>$s</t></is></c>').join()}</row>';

Map<String, dynamic> blankBackup() => {
  'app': 'sangbu-sangjo',
  'schema': 1,
  'profile': [],
  'categories': [],
  'transactions': [],
  'relationships': [],
};

void main() {
  test('CSV BOM, 쉼표, 큰따옴표, 줄바꿈을 값으로 취급한다', () {
    final rows = LedgerImport.parse(
      bytes(
        '\uFEFF${LedgerImport.template}'
        '2026-11-26,합성 이름,"50,000",보냄,,"두 줄,\r\n""테스트"""\r\n',
      ),
      'csv',
      [],
      {},
    );
    expect(rows.single.memo, '두 줄,\r\n"테스트"');
    expect(rows.single.key?.amount, 50000);
    expect(rows.single.categoryId, 'sys-14');
  });

  test('잘못된 날짜·금액·방향·열·분류에 행별 한국어 오류를 표시한다', () {
    final rows = LedgerImport.parse(
      bytes(
        '${LedgerImport.template}'
        '2026-02-29,가,1,받음,,\n2026-02-28,가,-1,받음,,\n'
        '2026-02-28,가,1,돈,,\n2026-02-28,가,1,받음,보낸 분류,\n'
        '2026-02-28,가,1,받음\n',
      ),
      'csv',
      [Category(id: 'x', name: '보낸 분류', type: 'expense', isSystem: false)],
      {},
    );
    expect(rows.map((r) => r.error!.split(' ').first), [
      '날짜를',
      '금액은',
      '방향에',
      '방향에',
      '쉼표와',
    ]);
  });

  test('날짜·이름·금액·방향으로 기존/파일 내부 중복을 구분한다', () {
    final existing = {ledgerKey('2026-11-26T15:00', '테스트 A', 100, 'income')};
    final rows = LedgerImport.parse(
      bytes(
        '${LedgerImport.template}'
        '2026-11-26,테스트 a,100,받음,,\n2026-11-26,테스트 A,100,보냄,,\n'
        '2026-11-26,테스트 A,100,보냄,,두 번째\n',
      ),
      'csv',
      [],
      existing,
    );
    expect(rows.map((r) => r.duplicate), [true, false, true]);
  });

  test('CSV 제목·잘린 따옴표·크기·행 수 제한', () {
    for (final input in [
      '잘못된 제목\n',
      '${LedgerImport.template}"닫히지 않음',
      '${LedgerImport.template}${'2026-11-26,가,100,받음,,\n' * 1001}',
    ]) {
      expect(
        () => LedgerImport.parse(bytes(input), 'csv', [], {}),
        throwsFormatException,
      );
    }
    expect(
      () => LedgerImport.parse(
        Uint8List(LedgerImport.maxBytes + 1),
        'xlsx',
        [],
        {},
      ),
      throwsFormatException,
    );
  });

  test('XLSX 첫 번째 워크시트의 Excel 날짜·공유문자열과 수식 제외', () {
    final input = xlsx(
      '$xlsxHeader<row r="2"><c r="A2"><v>46352</v></c>'
      '<c r="B2" t="s"><v>0</v></c><c r="C2"><v>100</v></c>'
      '<c r="D2" t="inlineStr"><is><t>받음</t></is></c></row>'
      '<row r="3"><c r="C3"><f>100+2</f><v>102</v></c></row>',
      strings: '<sst><si><r><t>가짜</t></r><r><t> 이름</t></r></si></sst>',
    );
    final rows = LedgerImport.parse(input, 'xlsx', [], {});
    expect(rows.first.key?.date, '2026-11-26');
    expect(rows.first.person, '가짜 이름');
    expect(rows.first.error, isNull);
    expect(rows.last.error, contains('수식'));
  });

  test('XLSX는 외부 링크, DTD, 과대 압축, 잘린 ZIP을 거부한다', () {
    final zip = xlsx(xlsxHeader);
    for (final input in [
      xlsx(xlsxHeader, target: 'https://example.invalid/sheet.xml'),
      xlsx(xlsxHeader, strings: '<!DOCTYPE sst [<!ENTITY x "가">]><sst/>'),
      xlsx(xlsxHeader, strings: 'a' * (8 * 1024 * 1024 + 1)),
      Uint8List.sublistView(zip, 0, zip.length - 8),
    ]) {
      expect(
        () => LedgerImport.parse(input, 'xlsx', [], {}),
        throwsFormatException,
      );
    }
  });

  test('CSV는 수식 접두어를 무력화하고 CR·쉼표·따옴표를 이스케이프한다', () {
    for (final prefix in ['=', '+', '-', '@', '\t', '  =', '＝']) {
      expect(spreadsheetCsvCell('${prefix}SUM'), "'${prefix}SUM");
    }
    expect(spreadsheetCsvCell('\rSUM'), '"\'\rSUM"');
    expect(spreadsheetCsvCell('abc\r"a",b'), '"abc\r""a"",b"');
    expect(spreadsheetCsvCell(1000), '1000');
  });

  test('JSON 제한: 파일 크기, 깊이, 항목 수, 스키마 및 필드 자료형', () {
    expect(
      BackupFormat.decode(bytes(jsonEncode(blankBackup()))),
      blankBackup(),
    );
    expect(
      () => BackupFormat.decode(Uint8List(BackupFormat.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => BackupFormat.decode(bytes('{"rows":[{"memo":[[]]}]}')),
      throwsFormatException,
    );
    final data = blankBackup()
      ..['transactions'] = List.filled(BackupFormat.maxRows + 1, {});
    expect(
      () => BackupFormat.decode(bytes(jsonEncode(data))),
      throwsFormatException,
    );
    expect(
      () => BackupFormat.validate(blankBackup()..['schema'] = 2),
      throwsFormatException,
    );
    expect(
      () => BackupFormat.validate(
        blankBackup()
          ..['profile'] = [
            {'id': 'local-user', 'name': 42, 'created_at': '2026-11-26'},
          ],
      ),
      throwsFormatException,
    );
  });
}
