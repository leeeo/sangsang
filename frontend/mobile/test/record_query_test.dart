import 'package:flutter_test/flutter_test.dart';
import 'package:sangbu_sangjo/models/record_query.dart';
import 'package:sangbu_sangjo/models/transaction.dart';

Transaction _record(
  String id,
  String? name,
  int day,
  double amount, {
  String type = 'expense',
  String category = 'wedding',
  int createdHour = 0,
}) => Transaction(
  id: id,
  userId: 'test',
  categoryId: category,
  amount: amount,
  type: type,
  transactionDate: DateTime(2026, 11, day, 13),
  createdAt: DateTime(2026, 11, day, createdHour),
  counterpartyName: name,
);

void main() {
  final ledger = [
    _record('a', 'Kim', 1, 30000),
    _record('b', 'Kim', 5, 20000, type: 'income'),
    _record('c', 'Kim', 5, 50000, category: 'funeral'),
    _record('d', 'Lee', 2, 100000),
    _record('e', 'Kim', 6, 200000),
    _record('f', 'Kim (work)', 5, 70000),
    _record('g', null, 5, 5000),
  ];

  test('intersects name, dates, category and direction before totaling', () {
    final result = RecordQuery(
      name: ' KiM ',
      categoryId: 'wedding',
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 5),
      order: RecordOrder.largest,
    ).apply(ledger);
    expect(result.items.map((record) => record.id), ['f', 'a', 'b']);
    expect(result.sent, 100000);
    expect(result.received, 20000);
    expect(result.total, 120000);
    final onlyReceived = const RecordQuery(type: 'income').apply(ledger);
    expect(onlyReceived.items.single.id, 'b');
  });

  test('sorts in all orders with latest entry then ID as tie breaks', () {
    final records = [
      _record('z', 'Kim', 2, 5, createdHour: 2),
      _record('m', 'Kim', 2, 5, createdHour: 2),
      _record('a', 'Kim', 2, 8),
      _record('b', 'Kim', 1, 5),
    ];
    final expected = {
      RecordOrder.newest: ['m', 'z', 'a', 'b'],
      RecordOrder.oldest: ['b', 'm', 'z', 'a'],
      RecordOrder.largest: ['a', 'm', 'z', 'b'],
      RecordOrder.smallest: ['m', 'z', 'b', 'a'],
    };
    for (final entry in expected.entries) {
      final result = RecordQuery(order: entry.key).apply(records);
      expect(result.items.map((record) => record.id), entry.value);
    }
    expect(records.first.id, 'z');
  });

  test(
    'keeps exact same names separate across filters and aliases distinct',
    () {
      final all = const RecordQuery(name: 'Kim').apply(ledger);
      final onlyReceived = const RecordQuery(type: 'income').apply(ledger);
      expect(
        all.items.where((record) => record.counterpartyName == 'Kim'),
        hasLength(4),
      );
      expect(all.sameNameNumbers, {'a': 1, 'b': 2, 'c': 3, 'e': 4});
      expect(onlyReceived.sameNameNumbers['b'], all.sameNameNumbers['b']);
      final alias = const RecordQuery(name: '(work)').apply(ledger);
      expect(alias.items.single.id, 'f');
      expect(alias.sameNameNumbers['f'], isNull);
    },
  );

  test('empty results total zero', () {
    final result = const RecordQuery(name: 'not found').apply(ledger);
    expect(result.items, isEmpty);
    expect(result.total, 0);
  });
}
