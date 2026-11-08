import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/presentation/content_submission_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onOpenGuidelines,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ContentSubmissionScreen(
          submissionStorage: const SharedPreferencesContentSubmissionStorage(),
          guidelinesStorage: const SharedPreferencesGuidelinesStorage(),
          onOpenGuidelines: onOpenGuidelines ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('warns when no brand profile exists and links to setup', (
    tester,
  ) async {
    var openedGuidelines = false;
    await pumpScreen(tester, onOpenGuidelines: () => openedGuidelines = true);

    expect(find.textContaining('No brand profile yet.'), findsOneWidget);
    await tester.tap(find.text('Set up brand guidelines'));
    expect(openedGuidelines, isTrue);
  });

  testWidgets('validates required title and content fields', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('submitContentButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a content title.'), findsOneWidget);
    expect(find.text('Enter the content you want to submit.'), findsOneWidget);
  });

  testWidgets('submits unchanged content and reports local saved state', (
    tester,
  ) async {
    const guidelinesStorage = SharedPreferencesGuidelinesStorage();
    await guidelinesStorage.save(
      const BrandGuidelines(brandName: 'Northstar Studio'),
    );
    await pumpScreen(tester);

    expect(find.textContaining('No brand profile yet.'), findsNothing);

    const originalBody = '  A launch draft.\n\nKeep this text unchanged.  ';
    await tester.enterText(
      find.byKey(const Key('submissionTitleField')),
      'Launch announcement',
    );
    await tester.enterText(
      find.byKey(const Key('submissionBodyField')),
      originalBody,
    );
    await tester.tap(find.byKey(const Key('submitContentButton')));
    await tester.pumpAndSettle();

    expect(find.text('Content saved for review.'), findsOneWidget);

    final saved = await const SharedPreferencesContentSubmissionStorage()
        .loadAll();
    expect(saved, hasLength(1));
    expect(saved.single.body, originalBody);
    expect(saved.single.title, 'Launch announcement');
    expect(saved.single.id, isNotEmpty);
    expect(saved.single.createdAt, isA<DateTime>());

    final submissionCard = find.byKey(Key('submission_${saved.single.id}'));
    await tester.tap(
      find.descendant(of: submissionCard, matching: find.byType(ExpansionTile)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      originalBody,
    );
    expect(
      find.text('Saved locally · Original draft unchanged'),
      findsOneWidget,
    );
  });

  testWidgets('shows body character count and enforces the content limit', (
    tester,
  ) async {
    await pumpScreen(tester);

    final bodyField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('submissionBodyField')),
        matching: find.byType(TextField),
      ),
    );
    expect(bodyField.maxLength, 5000);
    await tester.enterText(
      find.byKey(const Key('submissionBodyField')),
      'A short draft',
    );
    await tester.pump();

    expect(find.text('13 / 5000 characters'), findsOneWidget);
  });
}
