import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/review_history/domain/review_analytics.dart';
import 'package:brand_governance/features/review_history/domain/review_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates review metrics and detected violations from entries', () {
    final today = DateTime.now();
    final entries = [
      _entry(
        'approved',
        decision: _decision('approved', ReviewDecision.approve, today),
        analysis: _analysis([
          _issue('Guaranteed', AnalysisSeverity.critical),
          _issue('guaranteed', AnalysisSeverity.critical),
        ]),
        today: today,
      ),
      _entry(
        'rejected',
        decision: _decision('rejected', ReviewDecision.reject, today),
        analysis: _analysis([_issue('Instant results', AnalysisSeverity.high)]),
        today: today,
      ),
      _entry(
        'changes',
        decision: _decision('changes', ReviewDecision.requestChanges, today),
        analysis: _analysis([_issue('polished', AnalysisSeverity.low)]),
        today: today,
      ),
      _entry(
        'pending',
        today: today,
        analysis: _analysis([
          _issue('limited offer', AnalysisSeverity.high),
          _issue('best offer', AnalysisSeverity.medium),
        ]),
      ),
    ];

    final analytics = ReviewAnalytics.fromEntries(entries, now: today);
    expect(analytics.totalSubmissions, 4);
    expect(analytics.approvedSubmissions, 1);
    expect(analytics.rejectedSubmissions, 1);
    expect(analytics.changesRequested, 1);
    expect(analytics.pendingReviews, 1);
    expect(analytics.criticalFindings, 2);
    expect(analytics.highFindings, 2);
    expect(analytics.mediumFindings, 1);
    expect(analytics.lowFindings, 1);
    expect(analytics.hasAnalysisData, isTrue);
    expect(analytics.commonViolations.first.text, 'guaranteed');
    expect(analytics.commonViolations.first.count, 2);
    expect(analytics.activity.last.submissions, 4);
    expect(analytics.activity.last.decisions, 3);
  });

  test('handles no records and marks analysis as unavailable', () {
    final analytics = ReviewAnalytics.fromEntries(const []);
    expect(analytics.totalSubmissions, 0);
    expect(analytics.approvedSubmissions, 0);
    expect(analytics.rejectedSubmissions, 0);
    expect(analytics.changesRequested, 0);
    expect(analytics.pendingReviews, 0);
    expect(analytics.criticalFindings, 0);
    expect(analytics.hasAnalysisData, isFalse);
    expect(analytics.commonViolations, isEmpty);
    expect(analytics.activity, hasLength(7));
    expect(analytics.activity.every((point) => point.total == 0), isTrue);
  });
}

ReviewHistoryEntry _entry(
  String id, {
  HumanReviewDecision? decision,
  BrandAnalysisResult? analysis,
  required DateTime today,
}) {
  return ReviewHistoryEntry(
    submission: ContentSubmission(
      id: id,
      title: id,
      type: ContentType.blog,
      body: 'Draft body.',
      createdAt: today,
    ),
    decision: decision,
    analysis: analysis,
  );
}

HumanReviewDecision _decision(
  String id,
  ReviewDecision decision,
  DateTime today,
) {
  return HumanReviewDecision(
    submissionId: id,
    decision: decision,
    reviewerName: 'Reviewer',
    comments: '',
    reason: 'Reviewed.',
    decidedAt: today,
    analysisStatus: AnalysisStatus.needsReview,
  );
}

BrandAnalysisResult _analysis(List<BrandAnalysisIssue> issues) =>
    BrandAnalysisResult(
      issues: issues,
      positiveChecks: const [],
      limitations: const [],
    );

BrandAnalysisIssue _issue(String text, AnalysisSeverity severity) =>
    BrandAnalysisIssue(
      title: 'Prohibited language found',
      severity: severity,
      explanation: 'Configured phrase.',
      matchedText: text,
      relatedGuideline: 'Prohibited phrase',
    );
