import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HumanReviewDecision makeDecision({
    required String submissionId,
    required ReviewDecision decision,
  }) {
    return HumanReviewDecision(
      submissionId: submissionId,
      decision: decision,
      reviewerName: 'Avery Reviewer',
      comments: 'Please update the wording.',
      reason: 'The current draft does not match the guidelines.',
      decidedAt: DateTime.utc(2026, 11, 6),
      analysisStatus: AnalysisStatus.needsReview,
    );
  }

  test('saves and reloads a review decision for its submission', () async {
    const storage = SharedPreferencesHumanReviewDecisionStorage();
    final decision = makeDecision(
      submissionId: 'submission-1',
      decision: ReviewDecision.requestChanges,
    );

    await storage.save(decision);
    final restored = await storage.loadForSubmission('submission-1');

    expect(restored, isNotNull);
    expect(restored!.decision, ReviewDecision.requestChanges);
    expect(restored.reviewerName, 'Avery Reviewer');
    expect(restored.comments, 'Please update the wording.');
    expect(restored.reason, decision.reason);
    expect(restored.decidedAt, decision.decidedAt);
    expect(restored.analysisStatus, AnalysisStatus.needsReview);
    expect(await storage.loadForSubmission('unknown'), isNull);
  });

  test('stores only the latest decision for a submission', () async {
    const storage = SharedPreferencesHumanReviewDecisionStorage();
    await storage.save(
      makeDecision(
        submissionId: 'submission-1',
        decision: ReviewDecision.approve,
      ),
    );
    await storage.save(
      makeDecision(
        submissionId: 'submission-1',
        decision: ReviewDecision.reject,
      ),
    );

    expect(
      (await storage.loadForSubmission('submission-1'))?.decision,
      ReviewDecision.reject,
    );
  });
}
