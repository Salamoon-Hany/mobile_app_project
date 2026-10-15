import 'package:flutter/material.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_project/screens/welcome.dart';

void main() {
  setUp(() => AppLanguage.code.value = 'ar');
  tearDown(() => AppLanguage.code.value = 'en');
  testWidgets('intro advances and completion is called once', (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onComplete: () => completions++)),
    );
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('يلا نبدأ'), findsOneWidget);
    await tester.tap(find.text('يلا نبدأ'));
    await tester.tap(find.text('يلا نبدأ'));
    expect(completions, 1);
  });
  testWidgets('skip ends intro without going through all pages', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onComplete: () => completed = true)),
    );
    await tester.tap(find.text('تخطي'));
    expect(completed, isTrue);
  });
  testWidgets('small viewport supports larger text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: WelcomeScreen(onComplete: () {}),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('تخطي'));
  });
}
