import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:sangbu_sangjo/data/local_store.dart';
import 'package:sangbu_sangjo/models/analytics.dart';
import 'package:sangbu_sangjo/models/category.dart';
import 'package:sangbu_sangjo/models/relationship.dart';
import 'package:sangbu_sangjo/models/transaction.dart';
import 'package:sangbu_sangjo/models/user.dart';

/// LocalStore가 반환하는 JSON이 실제 모델 fromJson과 호환되는지,
/// 그리고 집계(관계/분석) 수치가 정확한지 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalStore.overridePathForTest = inMemoryDatabasePath;
  });

  setUp(() async {
    // 인메모리 DB: 연결을 닫으면 초기화되므로 테스트마다 새로 연다.
    await LocalStore.instance.resetForTest();
  });

  final store = LocalStore.instance;

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  group('시드/카테고리', () {
    test('시스템 카테고리 15개가 시드되고 Category 모델로 파싱된다', () async {
      final raw = await store.listCategories();
      expect(raw.length, 15);
      final cats = raw.map(Category.fromJson).toList();
      expect(cats.where((c) => c.type == 'expense').length, 10);
      expect(cats.where((c) => c.type == 'income').length, 5);
      expect(cats.every((c) => c.isSystem), isTrue);
      expect(cats.first.name, '결혼 축의금');
    });
  });

  group('프로필', () {
    test('없으면 null, 생성 후 User 모델로 파싱된다', () async {
      expect(await store.hasProfile(), isFalse);
      await store.createProfile('  홍길동  ');
      final json = await store.getProfile();
      final user = User.fromJson(json!);
      expect(user.displayName, '홍길동');
      expect(user.isActive, isTrue);
    });
  });

  group('거래', () {
    test('생성 → 목록/총계, Transaction 모델 파싱, 빈 문자열은 null 처리', () async {
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 100000,
        type: 'expense',
        transactionDate: today(),
        counterpartyName: '김민수',
        memo: '',
        eventType: '',
      );
      final list = await store.listTransactions();
      expect(list['total'], 1);
      final tx = Transaction.fromJson((list['items'] as List).first);
      expect(tx.amount, 100000);
      expect(tx.counterpartyName, '김민수');
      expect(tx.memo, isNull); // '' → null
      expect(tx.isExpense, isTrue);
    });

    test('type 필터와 페이지네이션', () async {
      for (var i = 0; i < 5; i++) {
        await store.createTransaction(
          categoryId: 'sys-01',
          amount: 1000.0 * (i + 1),
          type: i.isEven ? 'expense' : 'income',
          transactionDate: today(),
        );
      }
      final expenses = await store.listTransactions(type: 'expense');
      expect(expenses['total'], 3);
      final page = await store.listTransactions(skip: 1, limit: 2);
      expect((page['items'] as List).length, 2);
      expect(page['total'], 5);
    });

    test('삭제하면 목록/집계에서 빠진다', () async {
      final created = await store.createTransaction(
        categoryId: 'sys-01',
        amount: 50000,
        type: 'expense',
        transactionDate: today(),
        counterpartyName: '박서연',
      );
      await store.deleteTransaction(created['id'] as String);
      expect((await store.listTransactions())['total'], 0);
      final rels = await store.listRelationships();
      final rel = Relationship.fromJson(rels.first);
      expect(rel.totalGiven, 0); // 거래 삭제 → 집계 0 (관계 행은 유지)
    });
  });

  group('관계 집계 (핵심 비즈니스 로직)', () {
    test('거래 생성 시 관계 자동 생성 + expense→given/income→received/balance', () async {
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 100000,
        type: 'expense',
        transactionDate: today(),
        counterpartyName: '김민수',
      );
      await store.createTransaction(
        categoryId: 'sys-10',
        amount: 30000,
        type: 'income',
        transactionDate: today(),
        counterpartyName: '김민수',
      );
      final rels = await store.listRelationships();
      expect(rels.length, 1);
      final rel = Relationship.fromJson(rels.first);
      expect(rel.counterpartyName, '김민수');
      expect(rel.totalGiven, 100000);
      expect(rel.totalReceived, 30000);
      expect(rel.balance, 70000);
      expect(rel.iGaveMore, isTrue);
      expect(rel.lastTransactionDate, isNotNull);
    });

    test('명시적 관계 생성 + 수정, 중복 이름은 예외', () async {
      final created = await store.createRelationship(
        counterpartyName: '이하늘',
        relationshipType: 'friend',
      );
      final rel = Relationship.fromJson(created);
      expect(rel.totalGiven, 0);
      expect(rel.relationshipType, 'friend');

      final updated = await store.updateRelationship(
        rel.id,
        relationshipType: 'family',
        notes: '사촌',
      );
      final rel2 = Relationship.fromJson(updated);
      expect(rel2.relationshipType, 'family');
      expect(rel2.notes, '사촌');

      expect(
        () => store.createRelationship(counterpartyName: '이하늘'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('분석', () {
    test('summary: 해당 월만 집계된다', () async {
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 100000,
        type: 'expense',
        transactionDate: today(),
      );
      await store.createTransaction(
        categoryId: 'sys-10',
        amount: 250000,
        type: 'income',
        transactionDate: today(),
      );
      // 다른 달 거래는 제외돼야 함
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 999999,
        type: 'expense',
        transactionDate: '2020-01-15',
      );
      final now = DateTime.now();
      final s = AnalyticsSummary.fromJson(await store.summary());
      expect(s.year, now.year);
      expect(s.month, now.month);
      expect(s.income, 250000);
      expect(s.expense, 100000);
      expect(s.balance, 150000);
      expect(s.incomeCount, 1);
      expect(s.expenseCount, 1);
    });

    test('trends: 빈 달은 0으로 채워 과거→현재 N개월을 반환한다', () async {
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 40000,
        type: 'expense',
        transactionDate: today(),
      );
      final raw = await store.trends(months: 6);
      final points =
          (raw['trends'] as List).map((e) => TrendPoint.fromJson(e)).toList();
      expect(points.length, 6);
      final now = DateTime.now();
      expect(points.last.year, now.year);
      expect(points.last.month, now.month);
      expect(points.last.expense, 40000);
      expect(points.first.expense, 0); // 5개월 전 = 거래 없음
    });

    test('byCategory: 합계와 비율(ratio 합=1)', () async {
      await store.createTransaction(
        categoryId: 'sys-01',
        amount: 75000,
        type: 'expense',
        transactionDate: today(),
      );
      await store.createTransaction(
        categoryId: 'sys-02',
        amount: 25000,
        type: 'expense',
        transactionDate: today(),
      );
      final raw = await store.byCategory(type: 'expense');
      expect((raw['total'] as num).toDouble(), 100000);
      final stats = (raw['categories'] as List)
          .map((e) => CategoryStat.fromJson(e))
          .toList();
      expect(stats.length, 2);
      expect(stats.first.total, 75000); // 내림차순
      expect(stats.first.ratio, closeTo(0.75, 1e-9));
      expect(stats.fold<double>(0, (a, s) => a + s.ratio), closeTo(1.0, 1e-9));
    });

    test('데이터 없으면 전부 0 (division by zero 없음)', () async {
      final s = AnalyticsSummary.fromJson(await store.summary());
      expect(s.income, 0);
      expect(s.expense, 0);
      final cat = await store.byCategory();
      expect((cat['categories'] as List), isEmpty);
      expect((cat['total'] as num).toDouble(), 0);
    });
  });
}
