import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sangbu_sangjo/core/app_theme.dart';
import 'package:sangbu_sangjo/data/local_store.dart';
import 'package:sangbu_sangjo/models/analytics.dart';
import 'package:sangbu_sangjo/providers/analytics_provider.dart';
import 'package:sangbu_sangjo/screens/analytics/analytics_screen.dart';
import 'package:sangbu_sangjo/widgets/amount_text.dart';
import 'package:sangbu_sangjo/widgets/app_shell.dart';
import 'package:sqflite/sqflite.dart';

class _ScreenProvider extends AnalyticsProvider {
  final summaryCalls = <DateTime>[];
  final categoryCalls = <({int? year, int? month, String type})>[];
  final trendCalls = <int>[];
  bool summaryLoading = false;
  bool categoryLoading = false;
  bool trendLoading = false;
  String? summaryFailure;
  String? categoryFailure;
  String? trendFailure;
  bool empty = false;
  double balance = -100000;

  @override
  bool get isLoading => summaryLoading;
  @override
  bool get isCatLoading => categoryLoading;
  @override
  bool get isTrendLoading => trendLoading;
  @override
  String? get summaryError => summaryFailure;
  @override
  String? get categoryError => categoryFailure;
  @override
  String? get trendError => trendFailure;
  @override
  AnalyticsSummary get summary => AnalyticsSummary(
    year: DateTime.now().year,
    month: DateTime.now().month,
    income: empty ? 0 : 300000,
    expense: empty ? 0 : 400000,
    balance: balance,
    incomeCount: empty ? 0 : 2,
    expenseCount: empty ? 0 : 3,
  );

  @override
  List<CategoryStat> get categoryStats => empty ? [] : [
    CategoryStat(
      id: 'wedding',
      name: '함께 축하한 결혼과 오래 기억할 마음',
      total: 300000,
      count: 2,
      ratio: .75,
    ),
  ];

  @override
  List<TrendPoint> get trends => [
    TrendPoint(
      year: DateTime.now().year,
      month: DateTime.now().month,
      income: empty ? 0 : 300000,
      expense: empty ? 0 : 400000,
    ),
  ];

  @override
  Future<void> fetchSummary({int? year, int? month}) async {
    summaryCalls.add(DateTime(year ?? DateTime.now().year,
        month ?? DateTime.now().month));
  }

  @override
  Future<void> fetchByCategory({
    int? year,
    int? month,
    String type = 'expense',
  }) async {
    categoryCalls.add((year: year, month: month, type: type));
  }

  @override
  Future<void> fetchTrends({int months = 6}) async => trendCalls.add(months);

  void update() => notifyListeners();
}

class _PendingQuery {
  final result = Completer<List<Map<String, Object?>>>();
}

class _ControlledDatabase {
  Completer<_PendingQuery>? requested;

  Future<_PendingQuery> get nextQuery {
    requested = Completer<_PendingQuery>();
    return requested!.future.timeout(const Duration(seconds: 5));
  }

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'openDatabase':
        return {'id': 1};
      case 'execute':
      case 'closeDatabase':
      case 'options':
        return null;
      case 'query':
        final arguments = call.arguments as Map;
        if ((arguments['sql'] as String).toLowerCase() == 'pragma user_version') {
          return [{'user_version': 1}];
        }
        final query = _PendingQuery();
        requested!.complete(query);
        requested = null;
        return query.result.future;
      default:
        throw StateError('Unexpected SQLite operation: ${call.method}');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDirectory = Platform.environment['UI_CAPTURE_DIR'];
  final fontPath = Platform.environment['UI_CAPTURE_FONT'];

  setUpAll(() async {
    if (fontPath != null) {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader('CaptureKorean')
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
  });

  Future<void> mount(
    WidgetTester tester,
    _ScreenProvider provider, {
    double width = 390,
    bool dark = false,
    GlobalKey? captureKey,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme = dark ? AppTheme.dark : AppTheme.light;
    if (fontPath != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'CaptureKorean'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'CaptureKorean'),
      );
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<AnalyticsProvider>.value(
        value: provider,
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: const AnalyticsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (captureDirectory == null) return;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$captureDirectory/analytics-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> reveal(WidgetTester tester, Finder target, {bool upward = false}) async {
    await tester.scrollUntilVisible(
      target, upward ? -300 : 300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('analytics-scroll')),
        matching: find.byType(Scrollable),
      ).first,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('analytics renders $width dark=$dark at text scale 1.5',
          (tester) async {
        final provider = _ScreenProvider();
        final key = GlobalKey();
        await mount(tester, provider, width: width, dark: dark, captureKey: key);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<AppNavigation>(find.byType(AppNavigation)).index, 3);
        await capture(tester, key, '${width.toInt()}-$dark-month');

        final bar = find.byKey(
          const ValueKey('analytics-category-progress-wedding'),
        );
        await reveal(tester, bar);
        await tester.pumpAndSettle();
        expect(tester.widget<LinearProgressIndicator>(bar).value, .75);
        expect(double.parse(tester.widget<LinearProgressIndicator>(bar).semanticsValue!), 75);
        final percentage = tester.widget<Text>(find.byKey(
          const ValueKey('analytics-category-percent-wedding'),
        )).data!;
        expect(double.parse(percentage.replaceAll('%', '')), 75);
        expect(tester.takeException(), isNull);
        await capture(tester, key, '${width.toInt()}-$dark-category');

        final trends = find.byKey(const ValueKey('analytics-trends-tab'));
        await reveal(tester, trends, upward: true);
        await tester.tap(trends);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('analytics-trend-period')), findsOneWidget);
        await capture(tester, key, '${width.toInt()}-$dark-trends');
      });
    }
  }

  testWidgets('period and direction controls preserve API enum and filters',
      (tester) async {
    final provider = _ScreenProvider();
    await mount(tester, provider);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final previous = DateTime(now.year, now.month - 1);
    final next = find.byKey(const ValueKey('analytics-month-next'));
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('analytics-month-previous')));
    await tester.pumpAndSettle();
    expect(provider.summaryCalls.last, previous);
    expect(provider.categoryCalls.last.month, previous.month);
    expect(provider.categoryCalls.last.year, previous.year);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    final income = find.byKey(const ValueKey('analytics-category-income'));
    await reveal(tester, income);
    await tester.tap(income);
    await tester.pumpAndSettle();
    expect(provider.categoryCalls.last.type, 'income');
    expect(provider.categoryCalls.last.month, previous.month);
    final currentButton = find.byKey(const ValueKey('analytics-month-current'));
    await reveal(tester, currentButton, upward: true);
    await tester.tap(currentButton);
    await tester.pumpAndSettle();
    expect(provider.summaryCalls.last, current);
    expect(provider.categoryCalls.last.type, 'income');
    await reveal(tester, find.byKey(const ValueKey('analytics-trends-tab')), upward: true);
    await tester.tap(find.byKey(const ValueKey('analytics-trends-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analytics-trend-12')));
    await tester.pumpAndSettle();
    expect(provider.trendCalls.last, 12);
    expect(tester.widget<ChoiceChip>(find.byKey(
      const ValueKey('analytics-trend-12'),
    )).selected, isTrue);
  });

  testWidgets('sections expose independent loading failure retry and empty states',
      (tester) async {
    final provider = _ScreenProvider()
      ..summaryFailure = 'summary unavailable'
      ..categoryLoading = true;
    await mount(tester, provider, width: 1440);
    expect(find.byKey(const ValueKey('analytics-summary-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-category-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-summary-empty')), findsNothing);
    final retry = find.descendant(
      of: find.byKey(const ValueKey('analytics-summary-error')),
      matching: find.byType(FilledButton),
    );
    await tester.tap(retry);
    expect(provider.summaryCalls.length, 2);
    provider
      ..summaryFailure = null
      ..summaryLoading = true
      ..categoryLoading = false
      ..categoryFailure = 'category unavailable'
      ..update();
    await tester.pump();
    expect(find.byKey(const ValueKey('analytics-summary-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-category-error')), findsOneWidget);
    provider
      ..summaryLoading = false
      ..categoryFailure = null
      ..empty = true
      ..update();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analytics-summary-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-category-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analytics-trends-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analytics-trend-empty')), findsOneWidget);
    provider
      ..trendLoading = true
      ..update();
    await tester.pump();
    expect(find.byKey(const ValueKey('analytics-trend-loading')), findsOneWidget);
    provider
      ..trendLoading = false
      ..trendFailure = 'trend unavailable'
      ..update();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analytics-trend-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-trend-empty')), findsNothing);
  });

  for (final difference in [-100000.0, 0.0, 100000.0]) {
    testWidgets('difference direction $difference is separate from amount semantics',
        (tester) async {
      await mount(tester, _ScreenProvider()..balance = difference);
      final explanation = find.byKey(
        ValueKey('analytics-difference-${difference.sign.toInt()}'),
      );
      expect(explanation, findsOneWidget);
      expect(find.descendant(of: explanation, matching: find.byType(AmountText)),
          findsNothing);
    });
  }

  group('provider read lifecycle through LocalStore', () {
    late _ControlledDatabase database;
    late AnalyticsProvider provider;
    DatabaseFactory? previousFactory;

    setUpAll(() {
      previousFactory = databaseFactoryOrNull;
      databaseFactory = databaseFactorySqflitePlugin;
    });

    tearDownAll(() {
      databaseFactoryOrNull = previousFactory;
      LocalStore.overridePathForTest = null;
    });

    setUp(() async {
      await LocalStore.instance.resetForTest();
      database = _ControlledDatabase();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), database.handle);
      LocalStore.overridePathForTest = inMemoryDatabasePath;
      provider = AnalyticsProvider();
    });

    tearDown(() async {
      provider.dispose();
      await LocalStore.instance.resetForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), null);
    });

    final summaryRows = <Map<String, Object?>>[
      {'income': 300000, 'expense': 400000, 'income_count': 2, 'expense_count': 3},
    ];
    final categoryRows = <Map<String, Object?>>[
      {'id': 'a', 'name': 'A', 'color': null, 'total': 300000, 'count': 2},
      {'id': 'b', 'name': 'B', 'color': null, 'total': 100000, 'count': 1},
    ];

    test('latest summary wins and failed reads clear stale data', () async {
      final firstStarted = database.nextQuery;
      final first = provider.fetchSummary(year: 2026, month: 1);
      final firstQuery = await firstStarted;
      final secondStarted = database.nextQuery;
      final second = provider.fetchSummary(year: 2026, month: 2);
      firstQuery.result.completeError(StateError('old request failed'));
      await first;
      expect(provider.isLoading, isTrue);
      final secondQuery = await secondStarted;
      secondQuery.result.complete(summaryRows);
      await second;
      expect(provider.summary!.month, 2);
      expect(provider.summaryError, isNull);
      expect(provider.isLoading, isFalse);

      final thirdStarted = database.nextQuery;
      final third = provider.fetchSummary(year: 2026, month: 3);
      expect(provider.summary, isNull);
      expect(provider.isLoading, isTrue);
      (await thirdStarted).result.completeError(StateError('read failed'));
      await third;
      expect(provider.summaryError, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.summary, isNull);
    });

    test('category ratio and overlap use the current request only', () async {
      final firstStarted = database.nextQuery;
      final first = provider.fetchByCategory(type: 'expense');
      final firstQuery = await firstStarted;
      final secondStarted = database.nextQuery;
      final second = provider.fetchByCategory(type: 'income');
      firstQuery.result.complete([]);
      await first;
      expect(provider.isCatLoading, isTrue);
      final secondQuery = await secondStarted;
      secondQuery.result.complete(categoryRows);
      await second;
      expect(provider.categoryStats.first.ratio, .75);
      expect(provider.categoryTotal, 400000);

      final failureStarted = database.nextQuery;
      final failure = provider.fetchByCategory();
      expect(provider.categoryStats, isEmpty);
      expect(provider.categoryTotal, 0);
      (await failureStarted).result.completeError(StateError('read failed'));
      await failure;
      expect(provider.categoryError, isNotNull);
      expect(provider.isCatLoading, isFalse);
      expect(provider.summaryError, isNull);
    });

    test('trend period is not overwritten and failures finish loading', () async {
      final firstStarted = database.nextQuery;
      final first = provider.fetchTrends(months: 3);
      final firstQuery = await firstStarted;
      final secondStarted = database.nextQuery;
      final second = provider.fetchTrends(months: 12);
      firstQuery.result.complete([]);
      await first;
      expect(provider.isTrendLoading, isTrue);
      final secondQuery = await secondStarted;
      secondQuery.result.complete([]);
      await second;
      expect(provider.trends.length, 12);
      final failureStarted = database.nextQuery;
      final failure = provider.fetchTrends(months: 6);
      expect(provider.trends, isEmpty);
      (await failureStarted).result.completeError(StateError('read failed'));
      await failure;
      expect(provider.trendError, isNotNull);
      expect(provider.isTrendLoading, isFalse);
    });
  });
}
