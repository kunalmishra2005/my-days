import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';

enum ReviewHistorySort { newestFirst, oldestFirst }

class ReviewHistoryQuery {
  const ReviewHistoryQuery({
    this.search = '',
    this.decision,
    this.analysisStatus,
    this.sort = ReviewHistorySort.newestFirst,
  });

  final String search;
  final ReviewDecision? decision;
  final AnalysisStatus? analysisStatus;
  final ReviewHistorySort sort;

  List<ReviewHistoryEntry> apply(List<ReviewHistoryEntry> entries) {
    final normalizedSearch = search.trim().toLowerCase();
    final filtered = entries.where((entry) {
      if (normalizedSearch.isNotEmpty &&
          !entry.submission.title.toLowerCase().contains(normalizedSearch)) {
        return false;
      }
      if (decision != null && entry.decision?.decision != decision) {
        return false;
      }
      if (analysisStatus != null && entry.analysisStatus != analysisStatus) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      final order = a.submission.createdAt.compareTo(b.submission.createdAt);
      return sort == ReviewHistorySort.newestFirst ? -order : order;
    });
    return filtered;
  }
}

class ReviewHistoryEntry {
  const ReviewHistoryEntry({
    required this.submission,
    required this.decision,
    required this.analysis,
  });

  final ContentSubmission submission;
  final HumanReviewDecision? decision;
  final BrandAnalysisResult? analysis;

  AnalysisStatus? get analysisStatus =>
      analysis?.status ?? decision?.analysisStatus;

  AnalysisStatus? get decisionAnalysisStatus => decision?.analysisStatus;
}
