import 'package:flutter_test/flutter_test.dart';
import 'package:sangbu_sangjo/data/local_store.dart';
import 'package:sangbu_sangjo/providers/transaction_provider.dart';
import 'package:sangbu_sangjo/providers/relationship_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalStore.overridePathForTest = inMemoryDatabasePath;
  });

  setUp(() => store.resetForTest());
  tearDownAll(() => store.resetForTest());

  test('local people loading includes names beyond the former fifty-person cap', () async {
    for (var i = 0; i < 51; i++) {
      await store.createRelationship(counterpartyName: '검증 이름 $i');
    }
    final provider = RelationshipProvider();
    addTearDown(provider.dispose);

    await provider.fetchRelationships();

    expect(provider.items.length, 51);
    expect(provider.items.any((person) => person.counterpartyName == '검증 이름 0'), isTrue);
  });

  test('saving the opposite direction preserves the active record filter', () async {
    await store.createTransaction(categoryId: 'sys-10', amount: 50000,
        type: 'income', transactionDate: '2026-10-14');
    final provider = TransactionProvider();
    addTearDown(provider.dispose);
    await provider.fetchTransactions(type: 'income');

    final saved = await provider.createTransaction(
      categoryId: 'sys-01', amount: 100000,
      type: 'expense', transactionDate: '2026-10-14',
    );

    expect(saved, isTrue);
    expect(provider.total, 1);
    expect(provider.items.single.type, 'income');
    expect((await store.listTransactions())['total'], 2);
  });

  test('more records retain the direction and expose every page', () async {
    for (var i = 0; i < 7; i++) {
      await store.createTransaction(categoryId: 'sys-10', amount: 50000 + i.toDouble(),
          type: 'income', transactionDate: '2026-10-14');
    }
    await store.createTransaction(categoryId: 'sys-01', amount: 100000,
        type: 'expense', transactionDate: '2026-10-14');
    final provider = TransactionProvider();
    addTearDown(provider.dispose);
    await provider.fetchTransactions(type: 'income', limit: 3);

    await provider.loadMore();
    expect(provider.items.length, 6);
    expect(provider.hasMore, isTrue);
    await provider.loadMore();

    expect(provider.total, 7);
    expect(provider.items.length, 7);
    expect(provider.items.map((record) => record.id).toSet().length, 7);
    expect(provider.items.every((record) => record.type == 'income'), isTrue);
    expect(provider.hasMore, isFalse);
    expect(provider.isLoadingMore, isFalse);
  });

  test('refresh keeps the selected direction and resets pagination', () async {
    for (var i = 0; i < 3; i++) {
      await store.createTransaction(categoryId: 'sys-01', amount: 50000,
          type: 'expense', transactionDate: '2026-10-14');
    }
    final provider = TransactionProvider();
    addTearDown(provider.dispose);
    await provider.fetchTransactions(type: 'expense', limit: 2);
    await provider.loadMore();

    await provider.refresh();

    expect(provider.items.length, 2);
    expect(provider.total, 3);
    expect(provider.items.every((record) => record.isExpense), isTrue);
    expect(provider.hasMore, isTrue);
  });

  test('deleting a record updates the visible count without changing stored types', () async {
    await store.createTransaction(categoryId: 'sys-01', amount: 50000,
        type: 'expense', transactionDate: '2026-10-14');
    final provider = TransactionProvider();
    addTearDown(provider.dispose);
    await provider.fetchTransactions(type: 'expense');

    final deleted = await provider.deleteTransaction(provider.items.single.id);

    expect(deleted, isTrue);
    expect(provider.total, 0);
    expect(provider.items, isEmpty);
    expect((await store.listTransactions())['total'], 0);
  });
}
