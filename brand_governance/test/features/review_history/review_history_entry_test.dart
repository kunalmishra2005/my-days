import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/review_history/domain/review_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oldest = _entry(
    'Old campaign',
    DateTime.utc(2026, 1, 1),
    decision: ReviewDecision.approve,
    status: AnalysisStatus.passed,
  );
  final newest = _entry(
    'New campaign',
    DateTime.utc(2026, 3, 1),
    decision: ReviewDecision.requestChanges,
    status: AnalysisStatus.criticalIssues,
  );
  final pending = _entry(
    'Pending welcome',
    DateTime.utc(2026, 2, 1),
    status: AnalysisStatus.needsReview,
  );
  final entries = [oldest, newest, pending];

  test('searches title without regard to case', () {
    final results = const ReviewHistoryQuery(search: 'WELCOME').apply(entries);
    expect(results.map((entry) => entry.submission.title), ['Pending welcome']);
  });

  test('filters by human decision and analysis status', () {
    final results = const ReviewHistoryQuery(
      decision: ReviewDecision.requestChanges,
      analysisStatus: AnalysisStatus.criticalIssues,
    ).apply(entries);
    expect(results, [newest]);
  });

  test('sorts newest first and oldest first', () {
    expect(
      const ReviewHistoryQuery().apply(entries).first.submission.title,
      'New campaign',
    );
    expect(
      const ReviewHistoryQuery(sort: ReviewHistorySort.oldestFirst)
          .apply(entries)
          .first
          .submission
          .title,
      'Old campaign',
    );
  });
}

ReviewHistoryEntry _entry(
  String title,
  DateTime createdAt, {
  ReviewDecision? decision,
  required AnalysisStatus status,
}) {
  return ReviewHistoryEntry(
    submission: ContentSubmission(
      id: title,
      title: title,
      type: ContentType.email,
      body: 'Saved content.',
      createdAt: createdAt,
    ),
    decision: decision == null
        ? null
        : HumanReviewDecision(
            submissionId: title,
            decision: decision,
            reviewerName: 'Reviewer',
            comments: '',
            reason: 'Reviewed.',
            decidedAt: createdAt,
            analysisStatus: status,
          ),
    analysis: null,
  );
}
