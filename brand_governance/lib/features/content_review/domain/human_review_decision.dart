import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';

enum ReviewDecision {
  approve,
  requestChanges,
  reject;

  String get label => switch (this) {
    ReviewDecision.approve => 'Approve',
    ReviewDecision.requestChanges => 'Request Changes',
    ReviewDecision.reject => 'Reject',
  };
}

class HumanReviewDecision {
  const HumanReviewDecision({
    required this.submissionId,
    required this.decision,
    required this.reviewerName,
    required this.comments,
    required this.reason,
    required this.decidedAt,
    required this.analysisStatus,
  });

  final String submissionId;
  final ReviewDecision decision;
  final String reviewerName;
  final String comments;
  final String reason;
  final DateTime decidedAt;
  final AnalysisStatus analysisStatus;

  Map<String, Object?> toJson() => {
    'submissionId': submissionId,
    'decision': decision.name,
    'reviewerName': reviewerName,
    'comments': comments,
    'reason': reason,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
    'analysisStatus': analysisStatus.name,
  };

  factory HumanReviewDecision.fromJson(Map<String, Object?> json) {
    return HumanReviewDecision(
      submissionId: _readString(json, 'submissionId'),
      decision: ReviewDecision.values.firstWhere(
        (value) => value.name == json['decision'],
        orElse: () => throw FormatException(
          'Unknown review decision "${json['decision']}".',
        ),
      ),
      reviewerName: _readString(json, 'reviewerName'),
      comments: _readString(json, 'comments'),
      reason: _readString(json, 'reason'),
      decidedAt: DateTime.parse(_readString(json, 'decidedAt')).toUtc(),
      analysisStatus: AnalysisStatus.values.firstWhere(
        (value) => value.name == json['analysisStatus'],
        orElse: () => throw FormatException(
          'Unknown analysis status "${json['analysisStatus']}".',
        ),
      ),
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string.');
  }
}
