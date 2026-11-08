import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HumanReviewDecision', () {
    test('round trips the human decision and analysis status', () {
      final decidedAt = DateTime.utc(2026, 11, 6, 15, 20);
      final decision = HumanReviewDecision(
        submissionId: 'submission-123',
        decision: ReviewDecision.requestChanges,
        reviewerName: 'Avery Reviewer',
        comments: 'Please simplify the headline.',
        reason: 'One prohibited phrase needs to be removed.',
        decidedAt: decidedAt,
        analysisStatus: AnalysisStatus.criticalIssues,
      );

      final restored = HumanReviewDecision.fromJson(decision.toJson());

      expect(restored.submissionId, decision.submissionId);
      expect(restored.decision, ReviewDecision.requestChanges);
      expect(restored.reviewerName, 'Avery Reviewer');
      expect(restored.comments, 'Please simplify the headline.');
      expect(restored.reason, decision.reason);
      expect(restored.decidedAt, decidedAt);
      expect(restored.analysisStatus, AnalysisStatus.criticalIssues);
    });

    test('provides labels for the available human decisions', () {
      expect(ReviewDecision.approve.label, 'Approve');
      expect(ReviewDecision.requestChanges.label, 'Request Changes');
      expect(ReviewDecision.reject.label, 'Reject');
    });

    test('rejects unknown decision and analysis status values', () {
      final valid = {
        'submissionId': 'submission-123',
        'decision': 'approve',
        'reviewerName': 'Avery',
        'comments': '',
        'reason': 'Approved.',
        'decidedAt': DateTime.utc(2026).toIso8601String(),
        'analysisStatus': 'passed',
      };

      expect(
        () => HumanReviewDecision.fromJson({...valid, 'decision': 'maybe'}),
        throwsFormatException,
      );
      expect(
        () => HumanReviewDecision.fromJson({
          ...valid,
          'analysisStatus': 'unknown',
        }),
        throwsFormatException,
      );
    });
  });
}
