import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';

void main() {
  tearDown(() => AppLanguage.code.value = 'en');
  test('English and Arabic translations preserve emails and dynamic values', () {
    expect(translateText('Add funds', 'ar'), 'إضافة رصيد');
    expect(translateText('Add funds', 'en'), 'Add funds');
    expect(translateText('EGP', 'ar'), 'ج.م');
    expect(translateText('Not verified', 'ar'), 'غير مؤكّد');
    expect(
      translateText(
        'Open the verification link sent to student@example.com. Then return here to continue.',
        'ar',
      ),
      contains('student@example.com'),
    );
    expect(translateText('Electrician, Plumber', 'ar'), 'كهربائي، سبّاك');
    expect(translateText('Unmodified user text', 'ar'), 'Unmodified user text');
  });
  test('language choice survives preference reload', () async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.initialize();
    await AppLanguage.select('ar');
    AppLanguage.code.value = 'en';
    await AppLanguage.initialize();
    expect(AppLanguage.code.value, 'ar');
  });
  testWidgets('existing text changes language without duplicate Text widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LanguageScope(child: const AppText('Settings'))),
    );
    expect(find.text('Settings'), findsOneWidget);
    AppLanguage.code.value = 'ar';
    await tester.pump();
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });
}
