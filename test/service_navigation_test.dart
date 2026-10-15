import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/screens/dashboard.dart';

void main() {
  tearDown(() => AppLanguage.code.value = 'en');

  test('catalogue excludes the three removed services', () {
    expect(jobCatalog.map((job) => job.id), isNot(contains('cleaning')));
    expect(
      jobCatalog.map((job) => job.id),
      isNot(contains('air_conditioning')),
    );
    expect(jobCatalog.map((job) => job.id), isNot(contains('painting')));
  });

  testWidgets(
    'profile shortcut opens Profile and Settings has the requested order',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MyHomePage()));
      expect(find.byIcon(Icons.menu), findsNothing);
      await tester.tap(find.byKey(const Key('profile-shortcut')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final labels = [
        'Balance',
        'Language',
        'Dark mode',
        'Contact us',
        'Logout',
      ];
      for (var i = 0; i < labels.length - 1; i++) {
        expect(
          tester.getTopLeft(find.text(labels[i])).dy,
          lessThan(tester.getTopLeft(find.text(labels[i + 1])).dy),
        );
      }
      final lineY = tester.getTopLeft(find.byType(Divider)).dy;
      expect(lineY, greaterThan(tester.getTopLeft(find.text('Dark mode')).dy));
      expect(lineY, lessThan(tester.getTopLeft(find.text('Contact us')).dy));
    },
  );

  testWidgets('search finds services inside More in both languages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LanguageScope(child: const MyHomePage())),
    );
    await tester.enterText(find.byType(TextField), 'Gardener');
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Gardener',
      ),
      findsOneWidget,
    );
    expect(find.text('Builder'), findsNothing);

    AppLanguage.code.value = 'ar';
    await tester.enterText(find.byType(TextField), 'حدائق');
    await tester.pump();
    expect(find.text('تنسيق حدائق'), findsOneWidget);
    expect(find.text('Gardener'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
