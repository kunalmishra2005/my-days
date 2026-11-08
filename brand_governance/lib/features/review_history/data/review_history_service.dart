import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/review_history/domain/review_history_entry.dart';

class ReviewHistoryService {
  const ReviewHistoryService({
    required this.submissionStorage,
    required this.decisionStorage,
    required this.guidelinesStorage,
    required this.engine,
  });

  final ContentSubmissionStorage submissionStorage;
  final HumanReviewDecisionStorage decisionStorage;
  final GuidelinesStorage guidelinesStorage;
  final BrandAnalysisEngine engine;

  Future<List<ReviewHistoryEntry>> loadEntries() async {
    final submissionsFuture = submissionStorage.loadAll();
    final decisionsFuture = decisionStorage.loadAll();
    final guidelinesFuture = guidelinesStorage.load();
    final submissions = await submissionsFuture;
    final decisions = await decisionsFuture;
    final guidelines = await guidelinesFuture;
    final decisionsById = <String, HumanReviewDecision>{
      for (final decision in decisions) decision.submissionId: decision,
    };
    final hasGuidelines = guidelines.brandName.trim().isNotEmpty;

    return submissions
        .map((submission) {
          final decision = decisionsById[submission.id];
          final BrandAnalysisResult? analysis = hasGuidelines
              ? engine.analyze(submission: submission, guidelines: guidelines)
              : null;
          return ReviewHistoryEntry(
            submission: submission,
            decision: decision,
            analysis: analysis,
          );
        })
        .toList(growable: false);
  }
}
