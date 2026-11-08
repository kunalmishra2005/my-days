import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';

class AiReviewRequest {
  const AiReviewRequest({required this.submission, required this.guidelines});

  final ContentSubmission submission;
  final BrandGuidelines guidelines;

  Map<String, Object?> toJson() => {
    'submission': {
      'id': submission.id,
      'title': submission.title,
      'type': submission.type.name,
      'body': submission.body,
    },
    'guidelines': {
      'brandName': guidelines.brandName,
      'description': guidelines.description,
      'tone': guidelines.tone.name,
      'customTone': guidelines.customTone,
      'approvedTerms': guidelines.approvedTerms,
      'requiredTerms': guidelines.requiredTerms,
      'prohibitedTerms': guidelines.prohibitedTerms,
      'verifiedFacts': guidelines.verifiedFacts,
    },
  };
}

class AiReviewFinding {
  const AiReviewFinding({
    required this.title,
    required this.severity,
    required this.explanation,
    required this.matchedText,
    required this.relatedGuideline,
    required this.requiresHumanVerification,
    this.suggestedCorrection,
    this.startOffset,
    this.endOffset,
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

  factory AiReviewFinding.fromJson(
    Object? value, {
    required String sourceText,
  }) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('AI finding must be a JSON object.');
    }
    final title = _requiredString(value, 'title');
    final severityValue = _requiredString(value, 'severity').toLowerCase();
    AnalysisSeverity? severity;
    for (final candidate in AnalysisSeverity.values) {
      if (candidate.name == severityValue) {
        severity = candidate;
        break;
      }
    }
    if (severity == null) {
      throw FormatException('Unknown AI finding severity "$severityValue".');
    }

    final startOffset = _optionalInt(value, 'startOffset');
    final endOffset = _optionalInt(value, 'endOffset');
    if ((startOffset == null) != (endOffset == null)) {
      throw const FormatException(
        'AI finding offsets must both be provided or both be omitted.',
      );
    }
    final matchedText = _requiredString(value, 'matchedText');
    if (startOffset != null &&
        (startOffset < 0 ||
            endOffset! < startOffset ||
            endOffset > sourceText.length ||
            sourceText.substring(startOffset, endOffset) != matchedText)) {
      throw const FormatException(
        'AI finding offsets do not match the submitted source text.',
      );
    }
    final requiresHumanVerification = value['requiresHumanVerification'];
    if (requiresHumanVerification is! bool) {
      throw const FormatException(
        'AI finding requiresHumanVerification must be a boolean.',
      );
    }
    if (!requiresHumanVerification) {
      throw const FormatException(
        'AI findings must require human verification.',
      );
    }
    final correction = value['suggestedCorrection'];
    final String? suggestedCorrection;
    if (correction == null) {
      suggestedCorrection = null;
    } else if (correction is String) {
      suggestedCorrection = correction;
    } else {
      throw const FormatException(
        'AI finding suggestedCorrection must be a string or null.',
      );
    }

    return AiReviewFinding(
      title: title,
      severity: severity,
      explanation: _requiredString(value, 'explanation'),
      matchedText: matchedText,
      relatedGuideline: _requiredString(value, 'relatedGuideline'),
      requiresHumanVerification: requiresHumanVerification,
      suggestedCorrection: suggestedCorrection,
      startOffset: startOffset,
      endOffset: endOffset,
    );
  }
}

class AiReviewResponse {
  AiReviewResponse({required List<AiReviewFinding> findings})
    : findings = List.unmodifiable(findings);

  final List<AiReviewFinding> findings;

  factory AiReviewResponse.fromJson(
    Object? value, {
    required String sourceText,
  }) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('AI review response must be a JSON object.');
    }
    final findingsValue = value['findings'];
    if (findingsValue is! List<Object?>) {
      throw const FormatException('AI response findings must be a list.');
    }
    return AiReviewResponse(
      findings: findingsValue
          .map(
            (finding) =>
                AiReviewFinding.fromJson(finding, sourceText: sourceText),
          )
          .toList(),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('AI response field "$key" must be a string.');
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('AI response field "$key" must be an integer.');
}
