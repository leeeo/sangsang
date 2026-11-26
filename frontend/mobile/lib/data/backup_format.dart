import 'dart:convert';
import 'dart:typed_data';

abstract final class BackupFormat {
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRows = 20000;
  static const tooLarge = '백업 파일은 8MB 이하만 복원할 수 있어요.';
  static const invalid = FormatException('올바른 상부상조 JSON 백업 파일이 아니에요.');
  static const _tooDeep = FormatException('백업 파일 구조가 너무 복잡해요.');
  static const _tooMany = FormatException('백업 파일의 항목이 20,000개를 넘어요.');

  static Map<String, dynamic> decode(Uint8List bytes) {
    if (bytes.length > maxBytes) throw const FormatException(tooLarge);
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw invalid;
    }
    var depth = 0;
    var separators = 0;
    var string = false;
    var escaped = false;
    // Bound work and nesting before handing untrusted text to jsonDecode.
    for (final c in text.codeUnits) {
      if (string) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          string = false;
        }
      } else if (c == 34) {
        string = true;
      } else if (c == 91 || c == 123) {
        if (++depth > 3) throw _tooDeep;
      } else if (c == 93 || c == 125) {
        if (--depth < 0) throw invalid;
      } else if (c == 44 && ++separators > maxRows * 10) {
        throw _tooMany;
      }
    }
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw invalid;
    }
    if (data is! Map<String, dynamic>) throw invalid;
    validate(data);
    return data;
  }

  static const _required = {
    'profile': {'id', 'name', 'created_at'},
    'categories': {'id', 'name', 'type', 'is_system'},
    'transactions': {
      'id',
      'category_id',
      'amount',
      'type',
      'transaction_date',
      'created_at',
    },
    'relationships': {'id', 'counterparty_name', 'created_at'},
  };
  static const _optional = {
    'profile': <String>{},
    'categories': {'icon', 'color'},
    'transactions': {'counterparty_name', 'memo', 'event_type'},
    'relationships': {'relationship_type', 'notes'},
  };

  static void validate(Map<String, dynamic> data) {
    if (data['app'] != 'sangbu-sangjo' ||
        data['schema'] != 1 ||
        (data['exported_at'] != null && !_date(data['exported_at'])) ||
        data.keys.any(
          (k) =>
              !const {'app', 'schema', 'exported_at'}.contains(k) &&
              !_required.containsKey(k),
        )) {
      throw invalid;
    }
    var total = 0;
    for (final entry in _required.entries) {
      final rows = data[entry.key];
      if (rows is! List || (entry.key == 'profile' && rows.length > 1)) {
        throw invalid;
      }
      total += rows.length;
      if (total > maxRows) throw _tooMany;
      for (final row in rows) {
        if (row is! Map || !entry.value.every(row.containsKey)) throw invalid;
        for (final field in row.entries) {
          final value = field.value;
          final key = field.key;
          if (_optional[entry.key]!.contains(key)) {
            if (value != null && !_text(value)) throw invalid;
          } else if (!entry.value.contains(key)) {
            throw invalid;
          } else {
            final valid = switch (key) {
              'type' => value == 'expense' || value == 'income',
              'is_system' => value is int && value == 0,
              'amount' => value is num && value.isFinite && value > 0,
              'created_at' || 'transaction_date' => _date(value),
              'id' || 'category_id' =>
                _text(value, 128) && (value as String).isNotEmpty,
              _ => _text(value),
            };
            if (!valid) throw invalid;
          }
        }
        if (entry.key == 'profile' && row['id'] != 'local-user') throw invalid;
      }
    }
  }

  static bool _text(Object? v, [int max = 16384]) =>
      v is String && v.length <= max && !v.contains('\u0000');
  static bool _date(Object? v) =>
      v is String && v.length <= 64 && DateTime.tryParse(v) != null;
}

String spreadsheetCsvCell(Object? value) {
  var text = (value ?? '').toString();
  if (RegExp(r'^[ \uFEFF]*[=+\-@\t\r\n＝＋－＠]').hasMatch(text)) {
    text = "'$text";
  }
  if (text.contains(RegExp(r'[,"\n\r]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
