import 'package:brand_governance/app/my_days_app.dart';
import 'package:brand_governance/features/auth/data/supabase_auth_service.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_authentication_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('application opens the brand guidelines workspace', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthenticationService();
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text("MY DAY'S"), findsWidgets);
    expect(find.textContaining('Brand profile'), findsOneWidget);
    expect(find.textContaining('Tone and voice'), findsOneWidget);
  });

  testWidgets('workspace navigation opens Content Submission', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthenticationService();
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit content').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Give your next idea a thoughtful review.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('submissionTitleField')), findsOneWidget);
  });

  testWidgets('workspace navigation opens history and analytics', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authService = FakeAuthenticationService();
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review history').first);
    await tester.pumpAndSettle();
    expect(find.text('Review history'), findsWidgets);

    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();
    expect(find.text('Review analytics'), findsOneWidget);

    await tester.tap(find.text('Submit content').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Give your next idea a thoughtful review.'),
      findsOneWidget,
    );
  });

  testWidgets('sign out returns the user to the authentication screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthenticationService();
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('signup reports when email confirmation is required', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthenticationService(initialUser: null);
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Check your email and confirm your address'),
      findsOneWidget,
    );
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('sign-in errors are shown to the user', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authService = FakeAuthenticationService(
      initialUser: null,
      signInError: Exception('Invalid email or password.'),
    );
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('account changes reopen the workspace with the new identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const userOneGuidelines = SharedPreferencesGuidelinesStorage(
      userId: 'user-one',
    );
    const userTwoGuidelines = SharedPreferencesGuidelinesStorage(
      userId: 'user-two',
    );
    await userOneGuidelines.save(const BrandGuidelines(brandName: 'Brand One'));
    await userTwoGuidelines.save(const BrandGuidelines(brandName: 'Brand Two'));
    final authService = FakeAuthenticationService(
      initialUser: const AuthenticatedUser(id: 'user-one'),
    );
    addTearDown(authService.dispose);
    await tester.pumpWidget(MyDaysApp(authService: authService));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('brandNameField')))
          .controller
          ?.text,
      'Brand One',
    );

    authService.switchUser(
      const AuthenticatedUser(id: 'user-two', email: 'other@example.com'),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('brandNameField')))
          .controller
          ?.text,
      'Brand Two',
    );
    expect(find.byKey(const Key('signOutButton')), findsOneWidget);
  });
}
