import 'transaction.dart';

enum RecordOrder { newest, oldest, largest, smallest }

class RecordQuery {
  final String name;
  final String type;
  final String? categoryId;
  final DateTime? start;
  final DateTime? end;
  final RecordOrder order;

  const RecordQuery({
    this.name = '',
    this.type = 'all',
    this.categoryId,
    this.start,
    this.end,
    this.order = RecordOrder.newest,
  });

  static String _nameKey(String? value) => (value ?? '').trim().toLowerCase();

  static int _day(DateTime value) =>
      value.year * 10000 + value.month * 100 + value.day;

  RecordResults apply(List<Transaction> records) {
    final needle = _nameKey(name);
    final firstDay = start == null ? null : _day(start!);
    final lastDay = end == null ? null : _day(end!);
    final matches = records.where((record) {
      final day = _day(record.transactionDate);
      return (type == 'all' || record.type == type) &&
          (categoryId == null || record.categoryId == categoryId) &&
          _nameKey(record.counterpartyName).contains(needle) &&
          (firstDay == null || day >= firstDay) &&
          (lastDay == null || day <= lastDay);
    }).toList();
    matches.sort((a, b) {
      final date = _day(b.transactionDate).compareTo(_day(a.transactionDate));
      final primary = switch (order) {
        RecordOrder.newest => date,
        RecordOrder.oldest => -date,
        RecordOrder.largest => b.amount.compareTo(a.amount),
        RecordOrder.smallest => a.amount.compareTo(b.amount),
      };
      if (primary != 0) return primary;
      if (date != 0) return date;
      final created = b.createdAt.compareTo(a.createdAt);
      return created != 0 ? created : a.id.compareTo(b.id);
    });

    final byName = <String, List<String>>{};
    for (final record in records) {
      final key = _nameKey(record.counterpartyName);
      if (key.isNotEmpty) (byName[key] ??= []).add(record.id);
    }
    final sameNameNumbers = <String, int>{};
    for (final ids in byName.values.where((ids) => ids.length > 1)) {
      ids.sort();
      for (var i = 0; i < ids.length; i++) {
        sameNameNumbers[ids[i]] = i + 1;
      }
    }

    var sent = 0.0;
    var received = 0.0;
    for (final record in matches) {
      if (record.isExpense) {
        sent += record.amount;
      } else {
        received += record.amount;
      }
    }
    return RecordResults(matches, sent, received, sameNameNumbers);
  }
}

class RecordResults {
  final List<Transaction> items;
  final double sent;
  final double received;

  // These identify entries within a name, not people or durable record IDs.
  final Map<String, int> sameNameNumbers;

  const RecordResults(
    this.items,
    this.sent,
    this.received,
    this.sameNameNumbers,
  );

  double get total => sent + received;
}
