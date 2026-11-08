import 'package:brand_governance/app/my_days_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('application opens the brand guidelines workspace', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyDaysApp());
    await tester.pumpAndSettle();

    expect(find.text("MY DAY'S"), findsWidgets);
    expect(find.textContaining('Brand profile'), findsOneWidget);
    expect(find.textContaining('Tone and voice'), findsOneWidget);
  });

  testWidgets('workspace navigation opens Content Submission', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyDaysApp());
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

    await tester.pumpWidget(const MyDaysApp());
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
}
