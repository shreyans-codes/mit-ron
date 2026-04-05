import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitron/core/theme/app_theme_scope.dart';
import 'package:mitron/core/theme/theme_controller.dart';
import 'package:mitron/features/auth/login_page.dart';
import 'package:mitron/main.dart' show MitronApp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login screen shows Mitron branding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = await ThemeController.load();
    await tester.pumpWidget(MitronApp(themeController: themeController));
    await tester.pumpAndSettle();

    expect(find.text('Mitron'), findsWidgets);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Theme picker changes variant', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = await ThemeController.load();
    expect(themeController.variant.name, 'darkAcademia');

    await tester.pumpWidget(MitronApp(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Theme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parchment'));
    await tester.pumpAndSettle();

    expect(themeController.variant.name, 'parchmentLight');

    await tester.tap(find.byTooltip('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candlelit hall'));
    await tester.pumpAndSettle();

    expect(themeController.variant.name, 'candlelitHall');
  });

  testWidgets('LoginPage alone has MitronColors via Theme', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = await ThemeController.load();
    await tester.pumpWidget(
      AppThemeScope(
        controller: c,
        child: ListenableBuilder(
          listenable: c,
          builder: (_, _) => MaterialApp(
            theme: c.themeData,
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
