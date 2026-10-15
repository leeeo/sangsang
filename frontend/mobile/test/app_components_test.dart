import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangbu_sangjo/core/app_theme.dart';
import 'package:sangbu_sangjo/widgets/app_shell.dart';
import 'package:sangbu_sangjo/widgets/amount_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDirectory = Platform.environment['UI_CAPTURE_DIR'];
  final fontPath = Platform.environment['UI_CAPTURE_FONT'];

  testWidgets('currency is announced once instead of repeating child semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AmountText(amount: 100000, isExpense: true)),
      ));
      final label = tester.getSemantics(find.byType(AmountText)).label;
      expect(RegExp('100,000').allMatches(label).length, 1);
    } finally {
      semantics.dispose();
    }
  });

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

  for (final width in [390.0, 800.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('components render at $width with dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final captureKey = GlobalKey();
        var theme = dark ? AppTheme.dark : AppTheme.light;
        if (fontPath != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'CaptureKorean'),
            primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'CaptureKorean'),
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'CaptureKorean', fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }
        var retries = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Scaffold(
                appBar: AppBar(title: const Text('주고받은 마음')),
                body: PageBody(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('함께 기억하는 기록', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(labelText: '이름', hintText: '함께한 사람'),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(onPressed: () {}, child: const Text('마음 기록')),
                          const FilledButton(onPressed: null, child: Text('저장 중')),
                          const ChoiceChip(label: Text('보낸 마음'), selected: true),
                          const ChoiceChip(label: Text('받은 마음'), selected: false),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const AppEmptyState(
                        icon: Icons.volunteer_activism_outlined,
                        title: '첫 마음을 남겨보세요',
                        message: '기억하고 싶은 사람과 경조사를 함께 기록해요.',
                      ),
                      AppErrorState(
                        message: '기록은 그대로 있어요. 다시 불러와 주세요.',
                        onRetry: () => retries++,
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: const AppNavigation(index: 0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final retry = find.descendant(
          of: find.byType(AppErrorState),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(retries, 1);
        expect(tester.takeException(), isNull);
        if (captureDirectory != null) {
          await tester.runAsync(() async {
            final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('$captureDirectory/components-${width.toInt()}-${dark ? 'dark' : 'light'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('navigation opens the selected destination without stacking', (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/home',
      routes: {
        '/home': (_) => const Scaffold(bottomNavigationBar: AppNavigation(index: 0)),
        '/transactions': (_) => const Scaffold(
          body: SizedBox(key: ValueKey('record-destination')),
          bottomNavigationBar: AppNavigation(index: 1),
        ),
      },
    ));
    await tester.tap(find.byKey(const ValueKey('nav-records')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-destination')), findsOneWidget);
    expect(find.byType(AppNavigation), findsOneWidget);
    final context = tester.element(find.byType(AppNavigation));
    expect(Navigator.of(context).canPop(), isFalse);
  });
}
