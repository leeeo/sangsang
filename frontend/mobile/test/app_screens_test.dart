import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sangbu_sangjo/core/app_theme.dart';
import 'package:sangbu_sangjo/models/analytics.dart';
import 'package:sangbu_sangjo/models/category.dart';
import 'package:sangbu_sangjo/models/relationship.dart';
import 'package:sangbu_sangjo/models/transaction.dart';
import 'package:sangbu_sangjo/models/user.dart';
import 'package:sangbu_sangjo/providers/analytics_provider.dart';
import 'package:sangbu_sangjo/providers/auth_provider.dart';
import 'package:sangbu_sangjo/providers/category_provider.dart';
import 'package:sangbu_sangjo/providers/relationship_provider.dart';
import 'package:sangbu_sangjo/providers/transaction_provider.dart';
import 'package:sangbu_sangjo/screens/auth/profile_setup_screen.dart';
import 'package:sangbu_sangjo/screens/backup/backup_screen.dart';
import 'package:sangbu_sangjo/screens/home/home_screen.dart';
import 'package:sangbu_sangjo/screens/relationships/relationship_form_screen.dart';
import 'package:sangbu_sangjo/screens/relationships/relationship_list_screen.dart';
import 'package:sangbu_sangjo/screens/transactions/transaction_form_screen.dart';
import 'package:sangbu_sangjo/screens/transactions/transaction_list_screen.dart';
import 'package:sangbu_sangjo/widgets/app_shell.dart';

final _fixtureDate = DateTime(2026, 10, 14);

class _Profile extends AuthProvider {
  @override
  User get user => User(id: 'qa', email: '', username: '민지', isActive: true,
      createdAt: _fixtureDate);
}

class _Categories extends CategoryProvider {
  final values = [
    Category(id: 'sys-01', name: '결혼 축의금', type: 'expense', isSystem: true),
    Category(id: 'sys-10', name: '결혼 축의금 수령', type: 'income', isSystem: true),
  ];
  @override
  List<Category> get expenseCategories => values.where((c) => c.type == 'expense').toList();
  @override
  List<Category> get incomeCategories => values.where((c) => c.type == 'income').toList();
  @override
  String nameById(String id) => values.firstWhere((c) => c.id == id).displayName;
  @override
  Future<void> fetchCategories() async {}
}

class _Records extends TransactionProvider {
  final values = [
    Transaction(id: 'sent', userId: 'qa', categoryId: 'sys-01', amount: 100000,
        type: 'expense', transactionDate: _fixtureDate, createdAt: _fixtureDate,
        counterpartyName: '김서연', eventType: 'wedding', memo: '대학 친구의 결혼식'),
    Transaction(id: 'received', userId: 'qa', categoryId: 'sys-10', amount: 150000,
        type: 'income', transactionDate: _fixtureDate, createdAt: _fixtureDate,
        counterpartyName: '박지훈', eventType: 'wedding', memo: '함께해 줘서 고마웠던 날'),
  ];
  String? lastType;
  String? failure;
  bool deleteSuccess = false;

  @override
  List<Transaction> get items => values.where((v) => lastType == null || v.type == lastType).toList();
  @override
  int get total => items.length;
  @override
  bool get hasMore => false;
  @override
  String? get error => failure;
  @override
  Future<void> fetchTransactions({
    int skip = 0, int limit = 20, String? type, bool append = false,
  }) async {
    lastType = type;
    notifyListeners();
  }

  @override
  Future<bool> deleteTransaction(String id) async {
    if (deleteSuccess) {
      values.removeWhere((record) => record.id == id);
      notifyListeners();
    }
    return deleteSuccess;
  }
}

class _Summary extends AnalyticsProvider {
  final bool empty;
  _Summary({this.empty = false});
  @override
  AnalyticsSummary get summary => AnalyticsSummary(
    year: DateTime.now().year, month: DateTime.now().month,
    income: empty ? 0 : 150000, expense: empty ? 0 : 100000,
    balance: empty ? 0 : 50000, incomeCount: empty ? 0 : 1, expenseCount: empty ? 0 : 1,
  );
  @override
  Future<void> fetchSummary({int? year, int? month}) async {}
}

class _People extends RelationshipProvider {
  @override
  List<Relationship> get items => [
    Relationship(id: 'seoyeon', userId: 'qa', counterpartyName: '김서연',
        relationshipType: 'friend', notes: '대학 친구', totalGiven: 100000,
        totalReceived: 0, balance: 100000, lastTransactionDate: _fixtureDate,
        createdAt: _fixtureDate),
    Relationship(id: 'jihoon', userId: 'qa', counterpartyName: '박지훈',
        relationshipType: 'family', totalGiven: 0, totalReceived: 150000,
        balance: -150000, lastTransactionDate: _fixtureDate, createdAt: _fixtureDate),
  ];
  @override
  Future<void> fetchRelationships() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['UI_CAPTURE_DIR'];
  final fontPath = Platform.environment['UI_CAPTURE_FONT'];
  final cases = <String, Widget>{
    'home': const HomeScreen(),
    'records': const TransactionListScreen(),
    'people': const RelationshipListScreen(),
    'record-form': const TransactionFormScreen(),
    'person-form': const RelationshipFormScreen(),
    'profile': const ProfileSetupScreen(),
    'backup': const BackupScreen(),
  };

  setUpAll(() async {
    if (fontPath != null) {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader('CaptureKorean')..addFont(
        Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader('MaterialIcons')..addFont(
        rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  Future<GlobalKey> mount(WidgetTester tester, Widget screen, {
    double width = 390, bool dark = false, double scale = 1,
    _Records? records, bool empty = false,
  }) async {
    tester.view.physicalSize = Size(width, width > 600 ? 1000 : 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme = dark ? AppTheme.dark : AppTheme.light;
    if (fontPath != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'CaptureKorean'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'CaptureKorean'),
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(TextStyle(
              fontFamily: 'CaptureKorean', fontSize: 16, fontWeight: FontWeight.w600,
            )),
          ),
        ),
      );
    }
    final captureKey = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _Profile()),
        ChangeNotifierProvider<CategoryProvider>.value(value: _Categories()),
        ChangeNotifierProvider<TransactionProvider>.value(value: records ?? _Records()),
        ChangeNotifierProvider<AnalyticsProvider>.value(value: _Summary(empty: empty)),
        ChangeNotifierProvider<RelationshipProvider>.value(value: _People()),
      ],
      child: RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return captureKey;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$directory/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final entry in cases.entries) {
    for (final width in [390.0, 1440.0]) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key} renders $width dark=$dark', (tester) async {
          final key = await mount(tester, entry.value, width: width, dark: dark);
          expect(tester.takeException(), isNull);
          final name = '${entry.key}-${width.toInt()}-${dark ? 'dark' : 'light'}';
          await capture(tester, key, name);
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            final position = tester.state<ScrollableState>(scroll.first).position;
            if (position.maxScrollExtent > 0) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pump();
              expect(tester.takeException(), isNull);
              await capture(tester, key, '$name-bottom');
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
    testWidgets('${entry.key} fits 320 at enlarged text size', (tester) async {
      await mount(tester, entry.value, width: 320, scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('empty home keeps a usable record action', (tester) async {
    final records = _Records()..values.clear();
    final key = await mount(tester, const HomeScreen(), records: records, empty: true);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byKey(const ValueKey('home-add-record')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'home-empty');
  });

  testWidgets('record read failure has retry instead of a misleading empty state', (tester) async {
    final records = _Records()..values.clear()..failure = '연결을 확인해 주세요.';
    final key = await mount(tester, const TransactionListScreen(), records: records);
    expect(find.byType(AppErrorState), findsOneWidget);
    await capture(tester, key, 'records-error');
  });

  testWidgets('record filter survives refresh and prefills new entry direction', (tester) async {
    final records = _Records();
    await mount(tester, const TransactionListScreen(), records: records);
    await tester.tap(find.byKey(const ValueKey('filter-income')));
    await tester.pumpAndSettle();
    expect(records.lastType, 'income');
    final refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    await refresh;
    expect(records.lastType, 'income');
    await tester.tap(find.byKey(const ValueKey('list-add-record')));
    await tester.pumpAndSettle();
    expect(tester.widget<TransactionFormScreen>(find.byType(TransactionFormScreen)).initialType, 'income');
  });

  testWidgets('failed deletion leaves the record visible and reports the failure', (tester) async {
    final records = _Records();
    await mount(tester, const TransactionListScreen(), records: records);
    await tester.tap(find.byKey(const ValueKey('delete-sent')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sent')), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(records.total, 2);
  });
}
