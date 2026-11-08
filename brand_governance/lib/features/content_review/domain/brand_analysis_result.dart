enum AnalysisSeverity {
  critical,
  high,
  medium,
  low,
  informational;

  String get label => switch (this) {
    AnalysisSeverity.critical => 'Critical',
    AnalysisSeverity.high => 'High',
    AnalysisSeverity.medium => 'Medium',
    AnalysisSeverity.low => 'Low',
    AnalysisSeverity.informational => 'Informational',
  };
}

enum AnalysisStatus {
  passed,
  needsReview,
  criticalIssues;

  String get label => switch (this) {
    AnalysisStatus.passed => 'Passed',
    AnalysisStatus.needsReview => 'Needs Review',
    AnalysisStatus.criticalIssues => 'Critical Issues',
  };
}

class BrandAnalysisIssue {
  const BrandAnalysisIssue({
    required this.title,
    required this.severity,
    required this.explanation,
    required this.matchedText,
    required this.relatedGuideline,
    this.suggestedCorrection,
    this.startOffset,
    this.endOffset,
    this.requiresHumanVerification = false,
  });

  final String title;
  final AnalysisSeverity severity;
  final String explanation;
  final String matchedText;
  final String relatedGuideline;
  final String? suggestedCorrection;
  final int? startOffset;
  final int? endOffset;
  final bool requiresHumanVerification;
}

class BrandAnalysisResult {
  BrandAnalysisResult({
    required List<BrandAnalysisIssue> issues,
    required List<String> positiveChecks,
    required List<String> limitations,
  }) : issues = List.unmodifiable(issues),
       positiveChecks = List.unmodifiable(positiveChecks),
       limitations = List.unmodifiable(limitations);

  final List<BrandAnalysisIssue> issues;
  final List<String> positiveChecks;
  final List<String> limitations;

  Map<AnalysisSeverity, int> get severityCounts => Map.unmodifiable({
    for (final severity in AnalysisSeverity.values)
      severity: issues.where((issue) => issue.severity == severity).length,
  });

  List<BrandAnalysisIssue> get actionableIssues => List.unmodifiable(
    issues.where((issue) => issue.severity != AnalysisSeverity.informational),
  );

  AnalysisStatus get status {
    if (severityCounts[AnalysisSeverity.critical]! > 0) {
      return AnalysisStatus.criticalIssues;
    }
    if (actionableIssues.isNotEmpty) return AnalysisStatus.needsReview;
    return AnalysisStatus.passed;
  }
}
