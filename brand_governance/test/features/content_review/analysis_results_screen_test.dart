import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_models.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_provider.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
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

  Future<void> prepareSubmission({
    required ContentSubmission submission,
    BrandGuidelines guidelines = const BrandGuidelines(),
  }) async {
    await const SharedPreferencesContentSubmissionStorage().save(submission);
    await const SharedPreferencesGuidelinesStorage().save(guidelines);
  }

  Future<void> openAnalysis(
    WidgetTester tester, {
    HumanReviewDecisionStorage reviewStorage =
        const SharedPreferencesHumanReviewDecisionStorage(),
    AiReviewProvider aiReviewProvider = const AdaptionLabsReviewProvider(),
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ContentSubmissionScreen(
          submissionStorage: SharedPreferencesContentSubmissionStorage(),
          guidelinesStorage: SharedPreferencesGuidelinesStorage(),
          onOpenGuidelines: _noop,
          reviewDecisionStorage: reviewStorage,
          aiReviewProvider: aiReviewProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submission =
        (await const SharedPreferencesContentSubmissionStorage().loadAll())
            .single;
    await tester.tap(
      find.descendant(
        of: find.byKey(Key('submission_${submission.id}')),
        matching: find.byType(ExpansionTile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('analyze_${submission.id}')));
    await tester.pumpAndSettle();
  }

  testWidgets('opens analysis from a saved submission and uses saved rules', (
    tester,
  ) async {
    final submission = ContentSubmission.create(
      title: 'Launch email',
      type: ContentType.email,
      body: 'Our guaranteed launch is here.',
    );
    await prepareSubmission(
      submission: submission,
      guidelines: const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed'],
        approvedTerms: ['community'],
      ),
    );

    await openAnalysis(tester);

    expect(find.text('Analysis results'), findsOneWidget);
    expect(find.text('Launch email'), findsOneWidget);
    expect(
      find.text(
        'Email · Submitted content analyzed against saved brand guidelines.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('analysisStatus')), findsOneWidget);
    expect(find.text('Critical Issues'), findsOneWidget);
    expect(find.text('Prohibited language found'), findsOneWidget);
    expect(find.text('guaranteed'), findsWidgets);
    expect(find.textContaining('Prohibited words and phrases'), findsOneWidget);
    expect(
      find.textContaining('replace it with a substantiated alternative'),
      findsOneWidget,
    );
    expect(_countFor(tester, 'severityCount_total'), '2');
    expect(_countFor(tester, 'severityCount_critical'), '1');
    expect(_countFor(tester, 'severityCount_high'), '0');
    expect(_countFor(tester, 'severityCount_medium'), '0');
    expect(_countFor(tester, 'severityCount_low'), '1');
    expect(
      find.textContaining('Approved terminology not used'),
      findsOneWidget,
    );
  });

  testWidgets(
    'detects persisted multiword prohibited phrase in the submitted draft',
    (tester) async {
      final submission = ContentSubmission.create(
        title: 'Launch campaign',
        type: ContentType.advertisement,
        body: 'We deliver guaranteed results to every customer.',
      );
      await prepareSubmission(
        submission: submission,
        guidelines: const BrandGuidelines(
          brandName: 'Northstar',
          prohibitedTerms: ['guaranteed results'],
        ),
      );

      await openAnalysis(tester);

      expect(find.text('Critical Issues'), findsOneWidget);
      expect(find.text('Prohibited language found'), findsOneWidget);
      expect(find.text('guaranteed results'), findsWidgets);
      expect(_countFor(tester, 'severityCount_critical'), '1');
      expect(find.textContaining('Character positions'), findsOneWidget);
    },
  );

  testWidgets('refreshes analysis after saved guidelines change', (
    tester,
  ) async {
    final submission = ContentSubmission.create(
      title: 'Launch campaign',
      type: ContentType.advertisement,
      body: 'We deliver guaranteed results.',
    );
    await prepareSubmission(
      submission: submission,
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    await openAnalysis(tester);
    expect(find.text('Needs Review'), findsOneWidget);

    await const SharedPreferencesGuidelinesStorage().save(
      const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed results'],
      ),
    );
    await tester.tap(find.byKey(const Key('refreshAnalysisButton')));
    await tester.pumpAndSettle();

    expect(find.text('Critical Issues'), findsOneWidget);
    expect(_countFor(tester, 'severityCount_critical'), '1');
  });

  testWidgets('AI integration is clearly unavailable by default', (
    tester,
  ) async {
    await prepareSubmission(
      submission: ContentSubmission.create(
        title: 'Welcome note',
        type: ContentType.email,
        body: 'Welcome to the community.',
      ),
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    await openAnalysis(tester);

    expect(find.byKey(const Key('aiReviewCard')), findsOneWidget);
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    expect(find.textContaining('no external request is made'), findsOneWidget);
    expect(find.byKey(const Key('runAiReviewButton')), findsNothing);
  });

  testWidgets(
    'renders injected AI fixture separately from deterministic results',
    (tester) async {
      await prepareSubmission(
        submission: ContentSubmission.create(
          title: 'Welcome note',
          type: ContentType.email,
          body: 'Welcome to the community.',
        ),
        guidelines: const BrandGuidelines(brandName: 'Northstar'),
      );
      final provider = MockFixtureAiReviewProvider(
        fixture: AiReviewResponse(
          findings: const [
            AiReviewFinding(
              title: 'Contextual tone may be too casual',
              severity: AnalysisSeverity.low,
              explanation: 'This is a supplied local test fixture.',
              matchedText: 'Welcome',
              relatedGuideline: 'Tone and voice',
              requiresHumanVerification: true,
              suggestedCorrection: 'Review the opening with a human editor.',
              startOffset: 0,
              endOffset: 7,
            ),
          ],
        ),
      );
      await openAnalysis(tester, aiReviewProvider: provider);

      await tester.tap(find.byKey(const Key('runAiReviewButton')));
      await tester.pumpAndSettle();

      expect(find.text('Contextual tone may be too casual'), findsOneWidget);
      expect(find.textContaining('simulated'), findsWidgets);
      expect(
        find.textContaining('AI output is advisory and must be verified'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('humanReviewCard')), findsOneWidget);
    },
  );

  testWidgets('shows provider errors without hiding deterministic results', (
    tester,
  ) async {
    await prepareSubmission(
      submission: ContentSubmission.create(
        title: 'Welcome note',
        type: ContentType.email,
        body: 'Welcome to our community.',
      ),
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    await openAnalysis(tester, aiReviewProvider: _FailingAiReviewProvider());
    await tester.tap(find.byKey(const Key('runAiReviewButton')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('AI review could not be completed'),
      findsOneWidget,
    );
    expect(find.text('Passed'), findsOneWidget);
    expect(find.byKey(const Key('humanReviewCard')), findsOneWidget);
  });

  testWidgets('shows clean state without claiming full compliance', (
    tester,
  ) async {
    await prepareSubmission(
      submission: ContentSubmission.create(
        title: 'Welcome note',
        type: ContentType.socialMedia,
        body: 'Welcome to our community.',
      ),
      guidelines: const BrandGuidelines(
        brandName: 'Northstar',
        approvedTerms: ['community'],
        prohibitedTerms: ['guaranteed'],
      ),
    );

    await openAnalysis(tester);

    expect(find.text('Passed'), findsOneWidget);
    expect(
      find.textContaining('No configured prohibited phrases were detected.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not establish that all facts are true'),
      findsOneWidget,
    );
    expect(find.text('Positive checks'), findsOneWidget);
  });

  testWidgets('explains missing guidelines and returns to submissions', (
    tester,
  ) async {
    final submission = ContentSubmission.create(
      title: 'Saved draft',
      type: ContentType.blog,
      body: 'Original untouched draft.',
    );
    await prepareSubmission(submission: submission);

    await openAnalysis(tester);

    expect(find.text('Brand guidelines needed'), findsOneWidget);
    expect(
      find.textContaining('Your submission is still saved and unchanged'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back to submissions'));
    await tester.pumpAndSettle();

    expect(find.text('Submitted drafts'), findsOneWidget);
    expect(find.text('Saved draft'), findsOneWidget);
    final saved =
        (await const SharedPreferencesContentSubmissionStorage().loadAll())
            .single;
    expect(saved.body, 'Original untouched draft.');
    expect(saved.id, submission.id);
  });

  testWidgets('shows storage errors with a retry action', (tester) async {
    final submission = ContentSubmission.create(
      title: 'Saved draft',
      type: ContentType.blog,
      body: 'Draft body.',
    );
    await const SharedPreferencesContentSubmissionStorage().save(submission);

    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ContentSubmissionScreen(
          submissionStorage: const SharedPreferencesContentSubmissionStorage(),
          guidelinesStorage: _FailingGuidelinesStorage(),
          onOpenGuidelines: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(Key('submission_${submission.id}')),
        matching: find.byType(ExpansionTile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('analyze_${submission.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Analysis could not be completed'), findsOneWidget);
    expect(find.textContaining('guidelines unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('saves a human decision and shows it when revisiting', (
    tester,
  ) async {
    final submission = ContentSubmission.create(
      title: 'Review me',
      type: ContentType.email,
      body: 'Our guaranteed launch is ready.',
    );
    const originalBody = 'Our guaranteed launch is ready.';
    await prepareSubmission(
      submission: submission,
      guidelines: const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed'],
      ),
    );
    const reviewStorage = SharedPreferencesHumanReviewDecisionStorage();
    await openAnalysis(tester, reviewStorage: reviewStorage);

    await _scrollToReview(tester);
    await tester.enterText(
      find.byKey(const Key('reviewerNameField')),
      'Avery Reviewer',
    );
    await tester.tap(find.byKey(const Key('reviewDecision_requestChanges')));
    await tester.enterText(
      find.byKey(const Key('reviewReasonField')),
      'Remove the prohibited phrase before approval.',
    );
    await tester.enterText(
      find.byKey(const Key('reviewCommentsField')),
      'Please use a more measured description.',
    );
    await tester.tap(find.byKey(const Key('saveReviewDecisionButton')));
    await tester.pumpAndSettle();

    expect(find.text('Request Changes decision saved.'), findsOneWidget);
    expect(find.text('Saved decision: Request Changes'), findsOneWidget);
    final savedDecision = await reviewStorage.loadForSubmission(submission.id);
    expect(savedDecision?.decision, ReviewDecision.requestChanges);
    expect(savedDecision?.reviewerName, 'Avery Reviewer');
    expect(savedDecision?.analysisStatus, AnalysisStatus.criticalIssues);
    expect(
      (await const SharedPreferencesContentSubmissionStorage().loadAll())
          .single
          .body,
      originalBody,
    );

    await tester.tap(find.byTooltip('Back to submissions'));
    await tester.pumpAndSettle();
    final submissionCard = find.byKey(Key('submission_${submission.id}'));
    await tester.tap(
      find.descendant(of: submissionCard, matching: find.byType(ExpansionTile)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('analyze_${submission.id}')));
    await tester.pumpAndSettle();
    await _scrollToReview(tester);

    expect(find.text('Saved decision: Request Changes'), findsOneWidget);
    expect(find.textContaining('by Avery Reviewer'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('reviewerNameField')))
          .controller
          ?.text,
      'Avery Reviewer',
    );
  });

  testWidgets('validates required reviewer and decision reason', (
    tester,
  ) async {
    await prepareSubmission(
      submission: ContentSubmission.create(
        title: 'Review me',
        type: ContentType.blog,
        body: 'A draft.',
      ),
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    await openAnalysis(tester);
    await _scrollToReview(tester);
    await tester.tap(find.byKey(const Key('saveReviewDecisionButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter the reviewer name.'), findsOneWidget);
    expect(find.text('Add a reason for the decision.'), findsOneWidget);
  });

  testWidgets('shows review storage load and save failures', (tester) async {
    await prepareSubmission(
      submission: ContentSubmission.create(
        title: 'Review me',
        type: ContentType.blog,
        body: 'A draft.',
      ),
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    final storage = _ReviewStorageWithErrors();
    await openAnalysis(tester, reviewStorage: storage);
    await _scrollToReview(tester);
    expect(find.textContaining('review storage offline'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reviewerNameField')), 'Avery');
    await tester.enterText(
      find.byKey(const Key('reviewReasonField')),
      'Reason for this decision.',
    );
    await tester.tap(find.byKey(const Key('saveReviewDecisionButton')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not save review decision'),
      findsOneWidget,
    );
  });
}

void _noop() {}

class _FailingGuidelinesStorage implements GuidelinesStorage {
  var _loadCount = 0;

  @override
  Future<BrandGuidelines> load() async {
    _loadCount++;
    if (_loadCount == 1) return const BrandGuidelines(brandName: 'Northstar');
    throw StateError('guidelines unavailable');
  }

  @override
  Future<void> save(BrandGuidelines guidelines) async {}
}

class _ReviewStorageWithErrors implements HumanReviewDecisionStorage {
  @override
  Future<List<HumanReviewDecision>> loadAll() =>
      Future.error(StateError('review storage offline'));

  @override
  Future<HumanReviewDecision?> loadForSubmission(String submissionId) =>
      Future.error(StateError('review storage offline'));

  @override
  Future<void> save(HumanReviewDecision decision) =>
      Future.error(StateError('review storage offline'));
}

class _FailingAiReviewProvider implements AiReviewProvider {
  @override
  String get displayName => 'Failing test provider';

  @override
  String get statusLabel => 'BACKEND ADAPTER INJECTED';

  @override
  bool get isConfigured => true;

  @override
  Future<AiReviewResponse> review(AiReviewRequest request) =>
      Future.error(StateError('backend unavailable'));
}

Future<void> _scrollToReview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('humanReviewCard')),
    400,
    scrollable: find.byType(Scrollable).last,
  );
}

String? _countFor(WidgetTester tester, String key) {
  return tester
      .widget<Text>(
        find
            .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
            .first,
      )
      .data;
}
