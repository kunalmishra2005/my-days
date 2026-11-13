import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';

const judgeDemoGuidelines = BrandGuidelines(
  brandName: 'Northstar Community',
  description: 'A fictional community learning brand for product demos.',
  tone: BrandTone.friendly,
  approvedTerms: ['learn together'],
  requiredTerms: ['Northstar'],
  prohibitedTerms: ['guaranteed results'],
  verifiedFacts: ['Free monthly community workshop'],
);

final judgeDemoSubmissions = [
  ContentSubmission(
    id: 'd1b3d3f0-6a80-4c36-a001-000000000001',
    title: 'Monthly workshop invitation',
    type: ContentType.email,
    body:
        'Join Northstar for our free monthly community workshop. '
        'We learn together and share practical ideas.',
    createdAt: DateTime.utc(2026, 10, 12, 9),
  ),
  ContentSubmission(
    id: 'd1b3d3f0-6a80-4c36-a001-000000000002',
    title: 'A promise to avoid',
    type: ContentType.socialMedia,
    body:
        'Northstar offers guaranteed results for everyone. Join our '
        'community and learn together.',
    createdAt: DateTime.utc(2026, 10, 15, 14),
  ),
  ContentSubmission(
    id: 'd1b3d3f0-6a80-4c36-a001-000000000003',
    title: 'New member welcome',
    type: ContentType.blog,
    body:
        'Welcome to Northstar. Explore a friendly place to learn together '
        'at your own pace.',
    createdAt: DateTime.utc(2026, 10, 18, 11),
  ),
];

Future<void> seedJudgeDemoData({
  required GuidelinesStorage guidelinesStorage,
  required ContentSubmissionStorage submissionStorage,
  required HumanReviewDecisionStorage decisionStorage,
}) async {
  final guidelines = await guidelinesStorage.load();
  if (guidelines.brandName.isEmpty) {
    await guidelinesStorage.save(judgeDemoGuidelines);
  }

  final existingSubmissions = await submissionStorage.loadAll();
  final existingIds = existingSubmissions.map((item) => item.id).toSet();
  for (final submission in judgeDemoSubmissions) {
    if (!existingIds.contains(submission.id)) {
      await submissionStorage.save(submission);
    }
  }

  if (await decisionStorage.loadForSubmission(judgeDemoSubmissions.first.id) ==
      null) {
    await decisionStorage.save(
      HumanReviewDecision(
        submissionId: judgeDemoSubmissions.first.id,
        decision: ReviewDecision.approve,
        reviewerName: 'Demo Reviewer',
        comments: 'Clear, welcoming and aligned with the sample guidance.',
        reason: 'No prohibited phrase detected.',
        decidedAt: DateTime.utc(2026, 10, 13, 10),
        analysisStatus: AnalysisStatus.passed,
      ),
    );
  }
}
