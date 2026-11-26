import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

typedef SheetRow = ({int number, List<String> cells, bool hasFormula});

/// Reads values only, from the first worksheet. No file extraction, formula
/// evaluation, cached formula values, or resolution outside the workbook.
List<SheetRow> xlsxRows(Uint8List bytes, int maxRows, int columns) {
  final zip = _WorkbookZip(bytes);
  final workbook = zip.xml('xl/workbook.xml');
  final rels = zip.xml('xl/_rels/workbook.xml.rels');
  final sheet = _elements(workbook, 'sheet').firstOrNull;
  final relId = sheet?.attributes
      .where((attr) => attr.name.local == 'id' && attr.name.prefix != null)
      .firstOrNull
      ?.value;
  if (relId == null) throw const FormatException('첫 번째 시트가 없어요.');
  final relation = _elements(
    rels,
    'Relationship',
  ).where((item) => item.getAttribute('Id') == relId).single;
  final target = relation.getAttribute('Target') ?? '';
  final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  if (relation.getAttribute('TargetMode') == 'External' ||
      !(relation.getAttribute('Type') ?? '').endsWith('/worksheet') ||
      !RegExp(r'^xl/worksheets/[a-zA-Z0-9_.-]+\.xml$').hasMatch(path)) {
    throw const FormatException('일반 엑셀 워크시트만 가져올 수 있어요.');
  }
  final base1904 = const {'1', 'true'}.contains(
    _elements(workbook, 'workbookPr').firstOrNull?.getAttribute('date1904'),
  );
  final strings = zip.contains('xl/sharedStrings.xml')
      ? _elements(zip.xml('xl/sharedStrings.xml'), 'si').map(_richText).toList()
      : const <String>[];
  final result = <SheetRow>[];
  final data = _elements(zip.xml(path), 'sheetData').single;
  var previous = 0;
  for (final row in data.childElements.where((e) => e.name.local == 'row')) {
    final number = int.tryParse(row.getAttribute('r') ?? '') ?? (previous + 1);
    if (number <= previous || number > maxRows + 1 || result.length > maxRows) {
      throw FormatException('첫 번째 시트는 제목 아래 $maxRows행까지 가져올 수 있어요.');
    }
    previous = number;
    final cells = List.filled(columns, '');
    var formula = false;
    var previousColumn = -1;
    for (final cell in row.childElements.where((e) => e.name.local == 'c')) {
      final ref = cell.getAttribute('r');
      final match = ref == null
          ? null
          : RegExp(r'^([A-Z]{1,3})[1-9][0-9]*$').firstMatch(ref);
      if (ref != null && match == null) {
        throw const FormatException('엑셀 셀 위치가 올바르지 않아요.');
      }
      var column = previousColumn + 1;
      if (match != null) {
        column = 0;
        for (final char in match[1]!.codeUnits) {
          column = column * 26 + char - 64;
        }
        column--;
      }
      if (column <= previousColumn) {
        throw const FormatException('엑셀 열 순서가 올바르지 않아요.');
      }
      previousColumn = column;
      final hasFormula = _child(cell, 'f') != null;
      formula |= hasFormula;
      final type = cell.getAttribute('t');
      final value = _child(cell, 'v')?.innerText ?? '';
      final String text;
      if (hasFormula) {
        text = '';
      } else if (type == 's') {
        final index = int.tryParse(value);
        if (index == null || index < 0 || index >= strings.length) {
          throw const FormatException('엑셀 셀의 문자열 참조가 올바르지 않아요.');
        }
        text = strings[index];
      } else if (type == 'inlineStr') {
        text = _richText(_child(cell, 'is') ?? cell);
      } else if (column == 0 && number != 1 && (type == null || type == 'n')) {
        text = _serialDate(value, base1904);
      } else {
        text = value;
      }
      if (column < columns) {
        cells[column] = text;
      } else if (text.length > 2048 || text.trim().isNotEmpty) {
        throw const FormatException('양식에 없는 열에 값이 있어요.');
      }
    }
    result.add((number: number, cells: cells, hasFormula: formula));
  }
  return result;
}

String _serialDate(String value, bool base1904) {
  final serial = double.tryParse(value);
  if (serial == null ||
      !serial.isFinite ||
      serial < 0 ||
      serial > 73500 ||
      (!base1904 && serial.floor() == 60)) {
    return value;
  }
  final day = serial.floor();
  final start = base1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 31);
  final date = start.add(Duration(days: day - (!base1904 && day > 60 ? 1 : 0)));
  return date.toIso8601String().substring(0, 10);
}

Iterable<XmlElement> _elements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);

XmlElement? _child(XmlElement node, String name) =>
    node.childElements.where((e) => e.name.local == name).firstOrNull;

String _richText(XmlElement node) => node.childElements.map((e) {
  if (e.name.local == 't') return e.innerText;
  if (e.name.local == 'r') return _child(e, 't')?.innerText ?? '';
  return '';
}).join();

/// A small ZIP index reader keeps decompression restricted to the XML parts
/// that are actually consumed. Only ordinary single-disk ZIP with stored or
/// deflated XML parts is supported; archive supplies deflate and CRC32.
class _WorkbookZip {
  final Uint8List bytes;
  final ByteData _data;
  final _entries =
      <String, ({int offset, int size, int packed, int crc, int method})>{};
  static const _expandedLimit = 8 * 1024 * 1024;

  _WorkbookZip(this.bytes) : _data = ByteData.sublistView(bytes) {
    const invalid = FormatException('엑셀 압축 구조가 올바르지 않아요.');
    var end = bytes.length - 22;
    for (; end >= 0 && end >= bytes.length - 22 - 65535; end--) {
      if (_u32(end) == 0x06054b50 &&
          end + 22 + _u16(end + 20) == bytes.length) {
        break;
      }
    }
    if (end < 0 || end < bytes.length - 22 - 65535) throw invalid;
    final count = _u16(end + 10);
    final start = _u32(end + 16);
    if (_u16(end + 4) != 0 ||
        _u16(end + 6) != 0 ||
        _u16(end + 8) != count ||
        count > 128 ||
        start + _u32(end + 12) != end) {
      throw invalid;
    }
    var pos = start;
    var expanded = 0;
    for (var i = 0; i < count; i++) {
      if (pos + 46 > end || _u32(pos) != 0x02014b50) throw invalid;
      final nameLength = _u16(pos + 28);
      final next = pos + 46 + nameLength + _u16(pos + 30) + _u16(pos + 32);
      final local = _u32(pos + 42);
      final size = _u32(pos + 24);
      final packed = _u32(pos + 20);
      final method = _u16(pos + 10);
      expanded += size;
      if (expanded > _expandedLimit) {
        throw const FormatException('엑셀 압축을 풀면 8MB를 넘어요.');
      }
      if (next > end ||
          local + 30 > start ||
          _u32(local) != 0x04034b50 ||
          _u16(pos + 34) != 0 ||
          (_u16(pos + 8) & 1) != 0 ||
          _u16(local + 6) != _u16(pos + 8) ||
          _u16(local + 8) != method) {
        throw invalid;
      }
      final offset = local + 30 + _u16(local + 26) + _u16(local + 28);
      final name = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLength));
      if (offset + packed > start ||
          _u16(local + 26) != nameLength ||
          utf8.decode(bytes.sublist(local + 30, local + 30 + nameLength)) !=
              name ||
          _entries.containsKey(name)) {
        throw invalid;
      }
      _entries[name] = (
        offset: offset,
        size: size,
        packed: packed,
        crc: _u32(pos + 16),
        method: method,
      );
      pos = next;
    }
    if (pos != end) throw invalid;
  }

  int _u16(int at) => _data.getUint16(at, Endian.little);
  int _u32(int at) => _data.getUint32(at, Endian.little);
  bool contains(String part) => _entries.containsKey(part);

  XmlDocument xml(String part) {
    final entry = _entries[part];
    if (entry == null || (entry.method != 0 && entry.method != 8)) {
      throw const FormatException('엑셀 문서의 필수 부분을 열 수 없어요.');
    }
    final packed = Uint8List.sublistView(
      bytes,
      entry.offset,
      entry.offset + entry.packed,
    );
    final value = entry.method == 0
        ? packed
        : const ZLibDecoder().decodeBytes(
            packed,
            raw: true,
            throwOnError: true,
            maxOutputSize: entry.size,
          );
    if (value.length != entry.size || getCrc32(value) != entry.crc) {
      throw const FormatException('손상된 엑셀 파일이에요.');
    }
    final text = utf8.decode(value);
    var depth = 0;
    var nodes = 0;
    for (final event in parseEvents(text, validateNesting: true)) {
      if (event is XmlDoctypeEvent || ++nodes > 120000) {
        throw const FormatException('지원하지 않는 엑셀 문서 구조예요.');
      }
      if (event is XmlStartElementEvent && !event.isSelfClosing) depth++;
      if (event is XmlEndElementEvent) depth--;
      if (depth > 32) throw const FormatException('엑셀 문서 구조가 너무 복잡해요.');
    }
    return XmlDocument.parse(text);
  }
}
