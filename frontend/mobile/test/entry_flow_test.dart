import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sangbu_sangjo/core/app_theme.dart';
import 'package:sangbu_sangjo/main.dart';
import 'package:sangbu_sangjo/models/category.dart';
import 'package:sangbu_sangjo/models/relationship.dart';
import 'package:sangbu_sangjo/providers/auth_provider.dart';
import 'package:sangbu_sangjo/providers/category_provider.dart';
import 'package:sangbu_sangjo/providers/relationship_provider.dart';
import 'package:sangbu_sangjo/providers/transaction_provider.dart';
import 'package:sangbu_sangjo/screens/auth/profile_setup_screen.dart';
import 'package:sangbu_sangjo/screens/relationships/relationship_form_screen.dart';
import 'package:sangbu_sangjo/screens/relationships/relationship_list_screen.dart';
import 'package:sangbu_sangjo/screens/transactions/transaction_form_screen.dart';
import 'package:sangbu_sangjo/widgets/app_shell.dart';
import 'package:sangbu_sangjo/widgets/delayed_spinner.dart';

class _Categories extends CategoryProvider {
  bool fail = false;
  int requests = 0;
  final values = [
    Category(id: 'sent', name: '축의금', type: 'expense', isSystem: false),
    Category(id: 'received', name: '축하금', type: 'income', isSystem: false),
  ];

  @override
  List<Category> get expenseCategories =>
      values.where((value) => value.type == 'expense').toList();
  @override
  List<Category> get incomeCategories =>
      values.where((value) => value.type == 'income').toList();
  @override
  Future<void> fetchCategories() async {
    requests++;
    if (fail) throw StateError('Unavailable');
  }
}

class _Records extends TransactionProvider {
  final calls = <Map<String, Object?>>[];
  Completer<bool> completion = Completer<bool>();
  Completer<void> submitted = Completer<void>();

  @override
  Future<bool> createTransaction({
    required String categoryId,
    required double amount,
    required String type,
    required String transactionDate,
    String? counterpartyName,
    String? memo,
    String? eventType,
  }) {
    calls.add({
      'categoryId': categoryId,
      'amount': amount,
      'type': type,
      'date': transactionDate,
      'person': counterpartyName,
      'memo': memo,
      'eventType': eventType,
    });
    if (!submitted.isCompleted) submitted.complete();
    return completion.future;
  }
}

class _People extends RelationshipProvider {
  int requests = 0;
  String? failure;
  final values = [
    Relationship(
      id: 'minsu', userId: 'local', counterpartyName: '김민수',
      relationshipType: 'friend', totalGiven: 50000, totalReceived: 50000,
      balance: 0, createdAt: DateTime(2026, 1, 1),
    ),
    Relationship(
      id: 'jieun', userId: 'local', counterpartyName: '이지은',
      relationshipType: 'family', totalGiven: 0, totalReceived: 0,
      balance: 0, createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  List<Relationship> get items => values;
  @override
  String? get error => failure;
  @override
  Future<void> fetchRelationships() async {
    requests++;
    notifyListeners();
  }
}

class _Auth extends AuthProvider {
  final names = <String>[];
  Completer<void> completion = Completer<void>();

  @override
  Future<void> createLocalProfile(String name) {
    names.add(name);
    return completion.future;
  }
}

class _StartupAuth extends AuthProvider {
  Completer<void> completion = Completer<void>();
  int requests = 0;

  @override
  Future<void> fetchMe() {
    requests++;
    return completion.future;
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  _Categories? categories,
  _Records? records,
  _People? people,
  _Auth? auth,
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CategoryProvider>.value(
            value: categories ?? _Categories()),
        ChangeNotifierProvider<TransactionProvider>.value(
            value: records ?? _Records()),
        ChangeNotifierProvider<RelationshipProvider>.value(
            value: people ?? _People()),
        ChangeNotifierProvider<AuthProvider>.value(value: auth ?? _Auth()),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routes: {
          '/home': (_) => const Scaffold(
              body: SizedBox(key: ValueKey('home-destination'))),
        },
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _selectCategory(WidgetTester tester, String id) async {
  await _tap(tester, _key('record-category'));
  await tester.pumpAndSettle();
  final item = find.byWidgetPredicate(
      (widget) => widget is DropdownMenuItem<String> && widget.value == id);
  await tester.tap(find.descendant(
    of: item, matching: find.byType(Text),
  ).hitTestable().last);
  await tester.pumpAndSettle();
}

FormFieldState<String> _field(WidgetTester tester, String key) =>
    tester.state<FormFieldState<String>>(_key(key));

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('startup read failure can retry without resetting user data', (tester) async {
    final auth = _StartupAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: const SangbuSangjoApp(),
    ));
    auth.completion.completeError(StateError('Read failed'));
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorState), findsOneWidget);
    auth.completion = Completer<void>();
    await tester.tap(find.descendant(
      of: find.byType(AppErrorState), matching: find.byType(FilledButton),
    ));
    await tester.pump();
    auth.completion.complete();
    await tester.pumpAndSettle();
    expect(auth.requests, 2);
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);
  });

  testWidgets('loading delay changes only the indicator not its layout size', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DelayedSpinner())));
    final before = tester.getSize(find.byType(DelayedSpinner));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The one-second delay itself is the behavior under test.
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(DelayedSpinner)), before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final entry in <String, Widget>{
    'record-person': const TransactionFormScreen(),
    'person-name': const RelationshipFormScreen(),
  }.entries) {
    testWidgets('${entry.key} protects edited fields on system back', (tester) async {
      await _mount(tester, Scaffold(body: Builder(
        builder: (context) => FilledButton(
          key: const ValueKey('open-guarded-form'),
          onPressed: () => Navigator.push<void>(
            context, MaterialPageRoute(builder: (_) => entry.value),
          ),
          child: const Icon(Icons.add),
        ),
      )));
      await _tap(tester, _key('open-guarded-form'));
      await tester.pumpAndSettle();
      await tester.enterText(_key(entry.key), '김민수');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _tap(tester, _key('discard-stay'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(_key(entry.key)).controller!.text, '김민수');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, _key('discard-leave'));
      await tester.pumpAndSettle();
      expect(_key('open-guarded-form'), findsOneWidget);
      expect(_key(entry.key), findsNothing);
    });
  }

  testWidgets('direction resets category state and preserves person prefill',
      (tester) async {
    await _mount(tester, const TransactionFormScreen(
      initialCounterpartyName: '김민수', initialType: 'income',
    ));
    expect(tester.widget<TextFormField>(_key('record-person')).controller!.text,
        '김민수');
    expect(tester.widget<ChoiceChip>(_key('record-direction-income')).selected,
        isTrue);
    await _selectCategory(tester, 'received');
    expect(_field(tester, 'record-category').value, 'received');
    await _tap(tester, _key('record-direction-expense'));
    expect(_field(tester, 'record-category').value, isNull);
    expect(_field(tester, 'record-category').validate(), isFalse);
    await _selectCategory(tester, 'sent');
    expect(_field(tester, 'record-category').value, 'sent');
    expect(tester.takeException(), isNull);
  });

  testWidgets('amount requires positive finite integer KRW within limit',
      (tester) async {
    final records = _Records();
    await _mount(tester, const TransactionFormScreen(), records: records);
    await _selectCategory(tester, 'sent');
    for (final invalid in [
      '', '0', '-1', '1.5', 'NaN', 'Infinity', '1,00', '1000000000000',
      List.filled(400, '9').join(),
    ]) {
      await tester.ensureVisible(_key('record-amount'));
      await tester.enterText(_key('record-amount'), invalid);
      await _tap(tester, _key('record-save'));
      expect(_field(tester, 'record-amount').hasError, isTrue,
          reason: 'Rejected input: $invalid');
      expect(records.calls, isEmpty);
    }
    for (final valid in ['1', '50,000', '999999999999']) {
      await tester.ensureVisible(_key('record-amount'));
      await tester.enterText(_key('record-amount'), valid);
      await tester.pump();
      expect(_field(tester, 'record-amount').hasError, isFalse);
      expect(_field(tester, 'record-amount').validate(), isTrue);
    }
  });

  testWidgets('saving locks duplicate submits and failure preserves retry data',
      (tester) async {
    final records = _Records();
    await _mount(tester, const TransactionFormScreen(
      initialCounterpartyName: '김민수',
    ), records: records);
    await _selectCategory(tester, 'sent');
    await tester.enterText(_key('record-amount'), '50,000');
    final submitted = records.submitted.future;
    await _tap(tester, _key('record-save'));
    await submitted;
    expect(tester.widget<FilledButton>(_key('record-save')).onPressed, isNull);
    await tester.tap(_key('record-save'));
    expect(records.calls.length, 1);
    expect(records.calls.single['amount'], 50000);
    expect(records.calls.single['person'], '김민수');
    expect(records.calls.single['type'], 'expense');
    expect(records.calls.single['categoryId'], 'sent');
    records.completion.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_key('record-save')).onPressed, isNotNull);
    expect(tester.widget<TextFormField>(_key('record-amount')).controller!.text,
        '50,000');
    records.completion = Completer<bool>();
    records.submitted = Completer<void>();
    final retried = records.submitted.future;
    await _tap(tester, _key('record-save'));
    await retried;
    expect(records.calls.length, 2);
    records.completion.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('people search opens record with the selected name',
      (tester) async {
    final people = _People();
    await _mount(tester, const RelationshipListScreen(), people: people);
    expect(tester.widget<AppNavigation>(find.byType(AppNavigation)).index, 2);
    await tester.enterText(_key('people-search'), '이지은');
    await tester.pumpAndSettle();
    expect(_key('person-minsu'), findsNothing);
    expect(_key('person-jieun'), findsOneWidget);
    await _tap(tester, _key('person-record-jieun'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_key('record-person')).controller!.text,
        '이지은');
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful record retains event value and returns to caller',
      (tester) async {
    final records = _Records();
    await _mount(tester, Scaffold(
      body: Builder(builder: (context) => FilledButton(
        key: const ValueKey('open-record'),
        onPressed: () => Navigator.push<bool>(context, MaterialPageRoute(
          builder: (_) => const TransactionFormScreen(initialType: 'income'),
        )),
        child: const Icon(Icons.add),
      )),
    ), records: records);
    await _tap(tester, _key('open-record'));
    await tester.pumpAndSettle();
    await _selectCategory(tester, 'received');
    await tester.enterText(_key('record-amount'), '100000');
    await _tap(tester, _key('record-event'));
    await tester.pumpAndSettle();
    final event = find.byWidgetPredicate(
      (widget) => widget is DropdownMenuItem<String> && widget.value == 'wedding',
    );
    await tester.tap(find.descendant(
      of: event, matching: find.byType(Text),
    ).hitTestable().last);
    await tester.pumpAndSettle();
    final submitted = records.submitted.future;
    await _tap(tester, _key('record-save'));
    await submitted;
    expect(records.calls.single['eventType'], 'wedding');
    expect(records.calls.single['type'], 'income');
    expect(records.calls.single['categoryId'], 'received');
    records.completion.complete(true);
    await tester.pumpAndSettle();
    expect(_key('open-record'), findsOneWidget);
    expect(find.byType(TransactionFormScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('people load failure exposes retry instead of empty content',
      (tester) async {
    final people = _People()..failure = 'Unavailable';
    await _mount(tester, const RelationshipListScreen(), people: people);
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(_key('person-minsu'), findsNothing);
    people.failure = null;
    await _tap(tester, find.descendant(
      of: find.byType(AppErrorState), matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(people.requests, 2);
    expect(find.byType(AppErrorState), findsNothing);
    expect(_key('person-minsu'), findsOneWidget);
  });

  testWidgets('profile keyboard submission recovers after failure',
      (tester) async {
    final auth = _Auth();
    await _mount(tester, const ProfileSetupScreen(), auth: auth);
    await tester.enterText(_key('profile-name'), '  민수  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.names, ['민수']);
    expect(tester.widget<FilledButton>(_key('profile-start')).onPressed, isNull);
    auth.completion.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<FilledButton>(_key('profile-start')).onPressed, isNotNull);
    auth.completion = Completer<void>();
    await _tap(tester, _key('profile-start'));
    auth.completion.complete();
    await tester.pumpAndSettle();
    expect(auth.names, ['민수', '민수']);
    expect(_key('home-destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final screen in <String, Widget>{
    'record': const TransactionFormScreen(),
    'people': const RelationshipListScreen(),
    'person': const RelationshipFormScreen(),
    'profile': const ProfileSetupScreen(),
  }.entries) {
    testWidgets('${screen.key} supports narrow dark layout and large text',
        (tester) async {
      await _mount(tester, screen.value, width: 320, scale: 1.5, dark: true);
      expect(tester.takeException(), isNull);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
