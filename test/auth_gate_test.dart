import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_project/screens/auth_gate.dart';
import 'package:mobile_app_project/screens/dashboard.dart';

void main() {
  testWidgets(
    'unconfigured app stays locked and starts with login/signup choices',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthGate()));
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
      expect(find.textContaining('Access stays locked'), findsOneWidget);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Full name'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Log in'))
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('SMS'), findsNothing);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
    },
  );

  test(
    'account reset clears all user-specific demo data including balance',
    () {
      AppState.setUserName('Previous user');
      AppState.setUserEmail('previous@example.com');
      AppState.setPhoneNumber('+201012345678');
      BookingState.userBalance = 12;
      BookingState.userLocation = 'Previous location';
      AppState.clearAccount();
      expect(AppState.getUserName(), isEmpty);
      expect(AppState.getUserEmail(), isEmpty);
      expect(AppState.getPhoneNumber(), isEmpty);
      expect(BookingState.userBalance, 0);
      expect(BookingState.userLocation, isNull);
      expect(OrdersManager.getOrders(), isEmpty);
    },
  );
}
