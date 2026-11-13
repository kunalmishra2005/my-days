import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guidelines are isolated by authenticated user ID', () async {
    const accountA = SharedPreferencesGuidelinesStorage(userId: 'user-a');
    const accountB = SharedPreferencesGuidelinesStorage(userId: 'user-b');

    await accountA.save(const BrandGuidelines(brandName: 'Brand A'));
    expect((await accountB.load()).brandName, isEmpty);

    await accountB.save(const BrandGuidelines(brandName: 'Brand B'));
    expect((await accountA.load()).brandName, 'Brand A');
    expect((await accountB.load()).brandName, 'Brand B');
  });

  test('submissions are isolated by authenticated user ID', () async {
    const accountA = SharedPreferencesContentSubmissionStorage(
      userId: 'user-a',
    );
    const accountB = SharedPreferencesContentSubmissionStorage(
      userId: 'user-b',
    );
    final submissionA = _submission('Shared submission ID', 'User A draft');
    final submissionB = _submission('Shared submission ID', 'User B draft');

    await accountA.save(submissionA);
    expect(await accountB.loadAll(), isEmpty);

    await accountB.save(submissionB);
    expect((await accountA.loadAll()).single.body, 'User A draft');
    expect((await accountB.loadAll()).single.body, 'User B draft');
  });

  test('review decisions are isolated by authenticated user ID', () async {
    const accountA = SharedPreferencesHumanReviewDecisionStorage(
      userId: 'user-a',
    );
    const accountB = SharedPreferencesHumanReviewDecisionStorage(
      userId: 'user-b',
    );
    final decisionA = _decision('shared-submission', 'Reviewer A');
    final decisionB = _decision('shared-submission', 'Reviewer B');

    await accountA.save(decisionA);
    expect(await accountB.loadForSubmission('shared-submission'), isNull);

    await accountB.save(decisionB);
    expect(
      (await accountA.loadForSubmission('shared-submission'))?.reviewerName,
      'Reviewer A',
    );
    expect(
      (await accountB.loadForSubmission('shared-submission'))?.reviewerName,
      'Reviewer B',
    );
  });

  test('legacy unscoped records remain unchanged and unassigned', () async {
    const legacyGuidelines = SharedPreferencesGuidelinesStorage();
    const accountStorage = SharedPreferencesGuidelinesStorage(
      userId: 'first-user',
    );
    const legacyContent = SharedPreferencesContentSubmissionStorage();
    const accountContent = SharedPreferencesContentSubmissionStorage(
      userId: 'first-user',
    );
    const legacyDecisions = SharedPreferencesHumanReviewDecisionStorage();
    const accountDecisions = SharedPreferencesHumanReviewDecisionStorage(
      userId: 'first-user',
    );
    final submission = _submission('Legacy submission', 'Legacy body');
    final decision = _decision(submission.id, 'Legacy reviewer');
    final preferences = await SharedPreferences.getInstance();

    await legacyGuidelines.save(
      const BrandGuidelines(brandName: 'Legacy brand'),
    );
    await legacyContent.save(submission);
    await legacyDecisions.save(decision);
    final originalGuidelines = preferences.getString(
      'brand_governance.guidelines.v1',
    );
    final originalContent = preferences.getString(
      'brand_governance.content_submissions.v1',
    );
    final originalDecisions = preferences.getString(
      'brand_governance.human_review_decisions.v1',
    );

    expect((await accountStorage.load()).brandName, isEmpty);
    expect(await accountContent.loadAll(), isEmpty);
    expect(await accountDecisions.loadForSubmission(submission.id), isNull);

    expect((await legacyGuidelines.load()).brandName, 'Legacy brand');
    expect((await legacyContent.loadAll()).single.id, submission.id);
    expect(
      (await legacyDecisions.loadForSubmission(submission.id))?.reviewerName,
      'Legacy reviewer',
    );
    expect(
      preferences.getString('brand_governance.guidelines.v1'),
      originalGuidelines,
    );
    expect(
      preferences.getString('brand_governance.content_submissions.v1'),
      originalContent,
    );
    expect(
      preferences.getString('brand_governance.human_review_decisions.v1'),
      originalDecisions,
    );
  });
}

ContentSubmission _submission(String id, String body) => ContentSubmission(
  id: id,
  title: id,
  type: ContentType.blog,
  body: body,
  createdAt: DateTime.utc(2026, 11, 13),
);

HumanReviewDecision _decision(String submissionId, String reviewerName) =>
    HumanReviewDecision(
      submissionId: submissionId,
      decision: ReviewDecision.approve,
      reviewerName: reviewerName,
      comments: '',
      reason: 'Reviewed.',
      decidedAt: DateTime.utc(2026, 11, 13),
      analysisStatus: AnalysisStatus.passed,
    );
