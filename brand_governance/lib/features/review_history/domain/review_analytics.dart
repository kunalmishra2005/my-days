import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/review_history/domain/review_history_entry.dart';

class ReviewActivityPoint {
  const ReviewActivityPoint({
    required this.date,
    required this.submissions,
    required this.decisions,
  });

  final DateTime date;
  final int submissions;
  final int decisions;
  int get total => submissions + decisions;
}

class CommonViolation {
  const CommonViolation({required this.text, required this.count});

  final String text;
  final int count;
}

class ReviewAnalytics {
  ReviewAnalytics._({
    required this.totalSubmissions,
    required this.approvedSubmissions,
    required this.rejectedSubmissions,
    required this.changesRequested,
    required this.pendingReviews,
    required this.criticalFindings,
    required this.highFindings,
    required this.mediumFindings,
    required this.lowFindings,
    required this.hasAnalysisData,
    required this.commonViolations,
    required this.activity,
  });

  factory ReviewAnalytics.fromEntries(
    List<ReviewHistoryEntry> entries, {
    DateTime? now,
  }) {
    final decisions = entries
        .map((entry) => entry.decision)
        .whereType<HumanReviewDecision>()
        .toList();
    final analyses = entries
        .map((entry) => entry.analysis)
        .whereType<BrandAnalysisResult>()
        .toList();
    final violations = <String, int>{};
    var criticalFindings = 0;
    var highFindings = 0;
    var mediumFindings = 0;
    var lowFindings = 0;
    for (final analysis in analyses) {
      for (final issue in analysis.issues) {
        switch (issue.severity) {
          case AnalysisSeverity.critical:
            criticalFindings++;
          case AnalysisSeverity.high:
            highFindings++;
          case AnalysisSeverity.medium:
            mediumFindings++;
          case AnalysisSeverity.low:
            lowFindings++;
          case AnalysisSeverity.informational:
            break;
        }
        if (issue.severity == AnalysisSeverity.critical ||
            issue.severity == AnalysisSeverity.high) {
          final key = issue.matchedText.trim().toLowerCase();
          if (key.isNotEmpty) {
            violations.update(key, (count) => count + 1, ifAbsent: () => 1);
          }
        }
      }
    }

    final currentDay = now ?? DateTime.now();
    final today = DateTime(currentDay.year, currentDay.month, currentDay.day);
    final dayBuckets = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day - (6 - index)),
    );
    final submissionsByDay = <DateTime, int>{};
    final decisionsByDay = <DateTime, int>{};
    for (final entry in entries) {
      final date = _dateOnly(entry.submission.createdAt.toLocal());
      if (dayBuckets.contains(date)) {
        submissionsByDay.update(date, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    for (final decision in decisions) {
      final date = _dateOnly(decision.decidedAt.toLocal());
      if (dayBuckets.contains(date)) {
        decisionsByDay.update(date, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    return ReviewAnalytics._(
      totalSubmissions: entries.length,
      approvedSubmissions: decisions
          .where((decision) => decision.decision == ReviewDecision.approve)
          .length,
      rejectedSubmissions: decisions
          .where((decision) => decision.decision == ReviewDecision.reject)
          .length,
      changesRequested: decisions
          .where(
            (decision) => decision.decision == ReviewDecision.requestChanges,
          )
          .length,
      pendingReviews: entries.where((entry) => entry.decision == null).length,
      criticalFindings: criticalFindings,
      highFindings: highFindings,
      mediumFindings: mediumFindings,
      lowFindings: lowFindings,
      hasAnalysisData: analyses.isNotEmpty,
      commonViolations:
          violations.entries
              .map(
                (entry) => CommonViolation(text: entry.key, count: entry.value),
              )
              .toList()
            ..sort((a, b) {
              final countOrder = b.count.compareTo(a.count);
              return countOrder != 0 ? countOrder : a.text.compareTo(b.text);
            }),
      activity: dayBuckets
          .map(
            (date) => ReviewActivityPoint(
              date: date,
              submissions: submissionsByDay[date] ?? 0,
              decisions: decisionsByDay[date] ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  final int totalSubmissions;
  final int approvedSubmissions;
  final int rejectedSubmissions;
  final int changesRequested;
  final int pendingReviews;
  final int criticalFindings;
  final int highFindings;
  final int mediumFindings;
  final int lowFindings;
  final bool hasAnalysisData;
  final List<CommonViolation> commonViolations;
  final List<ReviewActivityPoint> activity;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
