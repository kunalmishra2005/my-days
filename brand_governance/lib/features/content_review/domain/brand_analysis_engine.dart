import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';

class BrandAnalysisEngine {
  const BrandAnalysisEngine();

  static const _factVerificationLimitation =
      'Deterministic checks can recognize configured statements and flag '
      'claim patterns, but cannot independently establish whether a factual '
      'claim is true.';
  static const _toneLimitation =
      'Tone checks are conservative and only flag a small set of informal '
      'markers when Formal tone is selected; nuance requires human review.';

  static final _potentiallyMisleadingPattern = RegExp(
    r'\b(?:guarantee(?:d|s)?|risk[- ]free|no risk|always|never)\b',
    caseSensitive: false,
  );
  static final _unsupportedClaimPattern = RegExp(
    r'\b(?:best|leading|first|only|proven|number one)\b|#1\b|'
    r'\b\d+(?:[,.]\d+)*(?:\s?%|\s+(?:million|billion|thousand|users|'
    r'customers|years|days|hours))\b',
    caseSensitive: false,
  );
  static final _informalTonePattern = RegExp(
    r"\b(?:hey|lol|awesome|cool)\b|\b[A-Za-z]+(?:n't|'re|'ve|'ll|'m)\b",
    caseSensitive: false,
  );

  BrandAnalysisResult analyze({
    required ContentSubmission submission,
    required BrandGuidelines guidelines,
  }) {
    final content = submission.body;
    final issues = <BrandAnalysisIssue>[];
    final positiveChecks = <String>[];
    final protectedRanges = <({int start, int end})>[];

    if (content.trim().isEmpty) {
      return BrandAnalysisResult(
        issues: const [
          BrandAnalysisIssue(
            title: 'No content to analyze',
            severity: AnalysisSeverity.low,
            explanation: 'Add content before running a brand guideline check.',
            matchedText: '',
            relatedGuideline: 'Content submission',
          ),
        ],
        positiveChecks: positiveChecks,
        limitations: const [_factVerificationLimitation, _toneLimitation],
      );
    }

    var prohibitedMatchCount = 0;
    final seenProhibitedTerms = <String>{};
    for (final configuredTerm in guidelines.prohibitedTerms) {
      final term = configuredTerm.trim();
      if (term.isEmpty || !seenProhibitedTerms.add(term.toLowerCase())) {
        continue;
      }

      for (final match in _wholePhraseMatches(content, term)) {
        prohibitedMatchCount++;
        protectedRanges.add((start: match.start, end: match.end));
        issues.add(
          BrandAnalysisIssue(
            title: 'Prohibited language found',
            severity: AnalysisSeverity.critical,
            explanation:
                'This phrase is explicitly prohibited by the saved brand '
                'guidelines. The finding identifies wording, not intent.',
            matchedText: content.substring(match.start, match.end),
            relatedGuideline: 'Prohibited words and phrases: "$term"',
            suggestedCorrection:
                'Remove the phrase or replace it with a substantiated '
                'alternative approved by your brand team.',
            startOffset: match.start,
            endOffset: match.end,
          ),
        );
      }
    }
    if (prohibitedMatchCount == 0) {
      positiveChecks.add('No prohibited words or phrases found.');
    }

    final seenApprovedTerms = <String>{};
    for (final configuredTerm in guidelines.approvedTerms) {
      final term = configuredTerm.trim();
      if (term.isEmpty || !seenApprovedTerms.add(term.toLowerCase())) continue;

      final matches = _wholePhraseMatches(content, term);
      if (matches.isNotEmpty) {
        positiveChecks.add('Approved terminology used: "$term".');
      } else {
        issues.add(
          BrandAnalysisIssue(
            title: 'Approved terminology not used',
            severity: AnalysisSeverity.low,
            explanation:
                'The approved term "$term" was not found. This is an '
                'advisory, not a violation; no alternative is inferred.',
            matchedText: '',
            relatedGuideline: 'Approved terminology: "$term"',
          ),
        );
      }
    }

    final seenRequiredTerms = <String>{};
    for (final configuredTerm in guidelines.requiredTerms) {
      final term = configuredTerm.trim();
      if (term.isEmpty || !seenRequiredTerms.add(term.toLowerCase())) continue;

      final matches = _wholePhraseMatches(content, term);
      if (matches.isEmpty) {
        issues.add(
          BrandAnalysisIssue(
            title: 'Required brand term missing',
            severity: AnalysisSeverity.medium,
            explanation:
                'This term is configured as required and was not found using '
                'case-insensitive whole-phrase matching.',
            matchedText: '',
            relatedGuideline: 'Required brand terms: "$term"',
            suggestedCorrection:
                'Consider including "$term" where it fits the message.',
          ),
        );
      } else {
        positiveChecks.add('Required brand term found: "$term".');
      }
    }

    final seenVerifiedFacts = <String>{};
    var recognizedFactCount = 0;
    for (final configuredFact in guidelines.verifiedFacts) {
      final fact = configuredFact.trim();
      if (fact.isEmpty || !seenVerifiedFacts.add(fact.toLowerCase())) continue;

      final match = _findExactStatement(content, fact);
      if (match != null) {
        recognizedFactCount++;
        positiveChecks.add('Verified brand statement found: "$fact".');
      }
    }
    if (guidelines.verifiedFacts.isNotEmpty && recognizedFactCount == 0) {
      issues.add(
        const BrandAnalysisIssue(
          title: 'No configured verified statement found',
          severity: AnalysisSeverity.informational,
          explanation:
              'None of the configured verified statements were recognized. '
              'This does not mean other claims are false or that every '
              'message must include a verified statement.',
          matchedText: '',
          relatedGuideline: 'Verified brand facts',
          requiresHumanVerification: true,
        ),
      );
    } else if (guidelines.verifiedFacts.isEmpty) {
      positiveChecks.add('No verified facts are configured for comparison.');
    }

    _addClaimFindings(
      content: content,
      pattern: _potentiallyMisleadingPattern,
      title: 'Absolute or potentially misleading phrasing',
      severity: AnalysisSeverity.high,
      explanation:
          'Absolute language can imply an unconditional outcome. This '
          'pattern-based check cannot determine whether the statement is '
          'accurate in context.',
      guideline: 'Verified brand facts and claims',
      protectedRanges: protectedRanges,
      issues: issues,
    );
    _addClaimFindings(
      content: content,
      pattern: _unsupportedClaimPattern,
      title: 'Claim may need substantiation',
      severity: AnalysisSeverity.medium,
      explanation:
          'A superlative or measurable claim was detected. The wording alone '
          'does not establish whether it is supported or inaccurate.',
      guideline: 'Verified brand facts and claims',
      protectedRanges: protectedRanges,
      issues: issues,
    );

    if (guidelines.tone == BrandTone.formal) {
      for (final match in _informalTonePattern.allMatches(content)) {
        if (_overlapsProtectedRange(match, protectedRanges)) continue;
        issues.add(
          BrandAnalysisIssue(
            title: 'Potentially informal wording',
            severity: AnalysisSeverity.low,
            explanation:
                'A limited informal-language marker was found while the '
                'selected brand tone is Formal. Review the sentence in context.',
            matchedText: content.substring(match.start, match.end),
            relatedGuideline: 'Tone and voice: Formal',
            startOffset: match.start,
            endOffset: match.end,
            requiresHumanVerification: true,
          ),
        );
      }
    }

    return BrandAnalysisResult(
      issues: issues,
      positiveChecks: positiveChecks,
      limitations: const [_factVerificationLimitation, _toneLimitation],
    );
  }

  void _addClaimFindings({
    required String content,
    required RegExp pattern,
    required String title,
    required AnalysisSeverity severity,
    required String explanation,
    required String guideline,
    required List<({int start, int end})> protectedRanges,
    required List<BrandAnalysisIssue> issues,
  }) {
    for (final match in pattern.allMatches(content)) {
      if (_overlapsProtectedRange(match, protectedRanges)) continue;
      issues.add(
        BrandAnalysisIssue(
          title: title,
          severity: severity,
          explanation: explanation,
          matchedText: content.substring(match.start, match.end),
          relatedGuideline: guideline,
          suggestedCorrection:
              'Verify this claim against an approved source or revise it to '
              'wording that can be substantiated.',
          startOffset: match.start,
          endOffset: match.end,
          requiresHumanVerification: true,
        ),
      );
    }
  }

  bool _overlapsProtectedRange(
    RegExpMatch match,
    List<({int start, int end})> ranges,
  ) =>
      ranges.any((range) => match.start < range.end && match.end > range.start);

  List<Match> _wholePhraseMatches(String content, String phrase) {
    final trimmedPhrase = phrase.trim();
    if (trimmedPhrase.isEmpty) return const [];

    final normalizedWhitespace = trimmedPhrase
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    final startsWithWordCharacter = _isWordCharacter(trimmedPhrase[0]);
    final endsWithWordCharacter = _isWordCharacter(
      trimmedPhrase[trimmedPhrase.length - 1],
    );
    final pattern = StringBuffer();
    if (startsWithWordCharacter) pattern.write(r'(?<![A-Za-z0-9_])');
    pattern.write(normalizedWhitespace);
    if (endsWithWordCharacter) pattern.write(r'(?![A-Za-z0-9_])');

    return RegExp(
      pattern.toString(),
      caseSensitive: false,
    ).allMatches(content).toList();
  }

  RegExpMatch? _findExactStatement(String content, String statement) {
    if (statement.isEmpty) return null;
    return RegExp(
      RegExp.escape(statement),
      caseSensitive: false,
    ).firstMatch(content);
  }

  bool _isWordCharacter(String character) =>
      RegExp(r'^[A-Za-z0-9_]$').hasMatch(character);
}
