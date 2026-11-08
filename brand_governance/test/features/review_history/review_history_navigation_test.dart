import 'package:brand_governance/app/my_days_app.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:brand_governance/features/review_history/presentation/review_analytics_screen.dart';
import 'package:brand_governance/features/review_history/presentation/review_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> sizeForDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openHistory(WidgetTester tester) async {
    await sizeForDesktop(tester);
    await tester.pumpWidget(const MyDaysApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review history').first);
    await tester.pumpAndSettle();
  }

  testWidgets('empty history has a helpful empty state', (tester) async {
    await openHistory(tester);
    expect(find.text('No submissions yet'), findsOneWidget);
    expect(find.byType(ReviewHistoryScreen), findsOneWidget);
  });

  testWidgets('history and analytics remain usable on a mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyDaysApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review history').first);
    await tester.pumpAndSettle();
    expect(find.text('No submissions yet'), findsOneWidget);
    expect(find.byKey(const Key('historySearchField')), findsOneWidget);

    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewAnalyticsScreen), findsOneWidget);
    expect(find.byKey(const Key('analyticsMetricGrid')), findsOneWidget);
  });

  testWidgets('searches and filters history, then opens saved details', (
    tester,
  ) async {
    final now = DateTime.now();
    final old = _submission(
      'Old campaign',
      now.subtract(const Duration(days: 3)),
    );
    final latest = _submission(
      'Latest welcome',
      now.subtract(const Duration(days: 1)),
    );
    final other = _submission('Other post', now);
    final submissions = const SharedPreferencesContentSubmissionStorage();
    final decisions = const SharedPreferencesHumanReviewDecisionStorage();
    await submissions.save(old);
    await submissions.save(latest);
    await submissions.save(other);
    await const SharedPreferencesGuidelinesStorage().save(
      const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed'],
      ),
    );
    await decisions.save(_decision(latest, ReviewDecision.requestChanges, now));
    await decisions.save(_decision(other, ReviewDecision.reject, now));

    await openHistory(tester);
    expect(find.text('Old campaign'), findsOneWidget);
    expect(find.text('Decision: Request Changes'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('historySearchField')),
      'WELCOME',
    );
    await tester.pumpAndSettle();
    expect(find.text('Latest welcome'), findsOneWidget);
    expect(find.text('Old campaign'), findsNothing);
    await tester.enterText(find.byKey(const Key('historySearchField')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('historyDecisionFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(find.text('Other post'), findsOneWidget);
    expect(find.text('Old campaign'), findsNothing);
    await tester.tap(find.byKey(Key('openHistory_${other.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Analysis results'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('humanReviewCard')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Saved decision: Reject'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to history'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewHistoryScreen), findsOneWidget);
  });

  testWidgets('sort selection updates the visible date order', (tester) async {
    final now = DateTime.now();
    final older = _submission(
      'Older entry',
      now.subtract(const Duration(days: 2)),
    );
    final newer = _submission('Newer entry', now);
    await const SharedPreferencesContentSubmissionStorage().save(older);
    await const SharedPreferencesContentSubmissionStorage().save(newer);
    await openHistory(tester);
    expect(
      tester.getTopLeft(find.text('Newer entry')).dy,
      lessThan(tester.getTopLeft(find.text('Older entry')).dy),
    );

    await tester.tap(find.byKey(const Key('historySortFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Older entry')).dy,
      lessThan(tester.getTopLeft(find.text('Newer entry')).dy),
    );
  });

  testWidgets('analytics shows metrics from locally saved records', (
    tester,
  ) async {
    final now = DateTime.now();
    final submission = _submission(
      'Launch post',
      now,
      body: 'Our guaranteed launch is here.',
    );
    await const SharedPreferencesContentSubmissionStorage().save(submission);
    await const SharedPreferencesGuidelinesStorage().save(
      const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed'],
      ),
    );
    await const SharedPreferencesHumanReviewDecisionStorage().save(
      _decision(submission, ReviewDecision.approve, now),
    );

    await openHistory(tester);
    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewAnalyticsScreen), findsOneWidget);
    expect(find.byKey(const Key('metric_total')), findsOneWidget);
    expect(find.byKey(const Key('metric_approved')), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('guaranteed'), findsOneWidget);
    expect(find.text('Critical findings'), findsOneWidget);
  });

  testWidgets('history shows retry when local storage is invalid', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'brand_governance.content_submissions.v1': '{invalid',
    });
    await openHistory(tester);
    expect(
      find.textContaining('Could not load review history'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load analytics from local records'),
      findsOneWidget,
    );
  });
}

ContentSubmission _submission(
  String title,
  DateTime createdAt, {
  String body = 'A saved draft.',
}) => ContentSubmission(
  id: title.toLowerCase().replaceAll(' ', '-'),
  title: title,
  type: ContentType.socialMedia,
  body: body,
  createdAt: createdAt,
);

HumanReviewDecision _decision(
  ContentSubmission submission,
  ReviewDecision decision,
  DateTime decidedAt,
) => HumanReviewDecision(
  submissionId: submission.id,
  decision: decision,
  reviewerName: 'Morgan Reviewer',
  comments: 'Review note.',
  reason: 'Reason provided.',
  decidedAt: decidedAt,
  analysisStatus: AnalysisStatus.criticalIssues,
);
