import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BrandAnalysisEngine();

  ContentSubmission submission(String body) => ContentSubmission.create(
    title: 'Test draft',
    type: ContentType.blog,
    body: body,
  );

  group('BrandAnalysisEngine', () {
    test('detects prohibited phrases and explains the related guideline', () {
      final result = engine.analyze(
        submission: submission('Our product is a guaranteed success.'),
        guidelines: const BrandGuidelines(prohibitedTerms: ['guaranteed']),
      );

      expect(result.issues, hasLength(1));
      final issue = result.issues.single;
      expect(issue.title, 'Prohibited language found');
      expect(issue.severity, AnalysisSeverity.critical);
      expect(issue.matchedText, 'guaranteed');
      expect(issue.startOffset, 17);
      expect(issue.endOffset, 27);
      expect(issue.requiresHumanVerification, isFalse);
      expect(issue.relatedGuideline, contains('guaranteed'));
      expect(issue.explanation, isNotEmpty);
      expect(issue.suggestedCorrection, contains('Remove the phrase'));
      expect(result.status, AnalysisStatus.criticalIssues);
      expect(result.severityCounts[AnalysisSeverity.critical], 1);
    });

    test('matches prohibited terms without regard to case', () {
      final result = engine.analyze(
        submission: submission('GUARANTEED results, guaranteed.'),
        guidelines: const BrandGuidelines(prohibitedTerms: ['guaranteed']),
      );

      expect(result.issues.map((issue) => issue.matchedText), [
        'GUARANTEED',
        'guaranteed',
      ]);
    });

    test('matches whole words and phrases without partial-word matches', () {
      final result = engine.analyze(
        submission: submission(
          'Our free trial works; a carefree trial is different. '
          'The free trials are not the exact phrase.',
        ),
        guidelines: const BrandGuidelines(prohibitedTerms: ['free trial']),
      );

      expect(result.issues, hasLength(1));
      expect(result.issues.single.matchedText, 'free trial');
    });

    test('reports every occurrence of a prohibited phrase', () {
      final result = engine.analyze(
        submission: submission('No risk. No risk, and no risk!'),
        guidelines: const BrandGuidelines(prohibitedTerms: ['no risk']),
      );

      expect(result.issues, hasLength(3));
      expect(result.issues.map((issue) => issue.matchedText), [
        'No risk',
        'No risk',
        'no risk',
      ]);
      expect(result.severityCounts[AnalysisSeverity.critical], 3);
    });

    test('reports absent approved terminology as a low advisory only', () {
      final result = engine.analyze(
        submission: submission('We welcome you to our platform.'),
        guidelines: const BrandGuidelines(approvedTerms: ['community']),
      );

      expect(result.issues, hasLength(1));
      expect(result.issues.single.severity, AnalysisSeverity.low);
      expect(result.issues.single.title, 'Approved terminology not used');
      expect(result.issues.single.matchedText, isEmpty);
      expect(result.issues.single.suggestedCorrection, isNull);
      expect(result.issues.single.explanation, contains('not a violation'));
      expect(result.status, AnalysisStatus.needsReview);
    });

    test('recognizes approved terminology and records a positive check', () {
      final result = engine.analyze(
        submission: submission('Our community helps everyone.'),
        guidelines: const BrandGuidelines(approvedTerms: ['community']),
      );

      expect(result.issues, isEmpty);
      expect(
        result.positiveChecks,
        contains('Approved terminology used: "community".'),
      );
      expect(result.status, AnalysisStatus.passed);
    });

    test(
      'recognizes exact verified statements without rejecting other facts',
      () {
        final result = engine.analyze(
          submission: submission(
            'Founded in 2018 in Bengaluru. We now serve many customers.',
          ),
          guidelines: const BrandGuidelines(
            verifiedFacts: ['Founded in 2018 in Bengaluru.'],
          ),
        );

        expect(result.issues, isEmpty);
        expect(
          result.positiveChecks,
          contains(
            'Verified brand statement found: "Founded in 2018 in Bengaluru.".',
          ),
        );
        expect(
          result.limitations.any(
            (item) => item.contains('cannot independently establish'),
          ),
          isTrue,
        );
        expect(result.status, AnalysisStatus.passed);
      },
    );

    test('does not claim an unlisted factual statement is false', () {
      final result = engine.analyze(
        submission: submission('We have served 10 million customers.'),
        guidelines: const BrandGuidelines(
          verifiedFacts: ['Founded in 2018 in Bengaluru.'],
        ),
      );

      expect(
        result.issues.any(
          (issue) => issue.title == 'Claim may need substantiation',
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (issue) => issue.severity == AnalysisSeverity.informational,
        ),
        isTrue,
      );
      expect(result.status, AnalysisStatus.needsReview);
      expect(
        result.limitations.any(
          (item) => item.contains('cannot independently establish'),
        ),
        isTrue,
      );
    });

    test('treats empty content as unable to pass analysis', () {
      final result = engine.analyze(
        submission: submission(' \n '),
        guidelines: const BrandGuidelines(),
      );

      expect(result.issues, hasLength(1));
      expect(result.issues.single.title, 'No content to analyze');
      expect(result.issues.single.severity, AnalysisSeverity.low);
      expect(result.status, AnalysisStatus.needsReview);
    });

    test(
      'passes content with no violations and summarizes positive checks',
      () {
        final result = engine.analyze(
          submission: submission('Our community can grow together.'),
          guidelines: const BrandGuidelines(
            approvedTerms: ['community'],
            prohibitedTerms: ['guaranteed'],
            verifiedFacts: ['Founded in Bengaluru.'],
          ),
        );

        expect(result.actionableIssues, isEmpty);
        expect(result.status, AnalysisStatus.passed);
        expect(result.severityCounts, {
          AnalysisSeverity.critical: 0,
          AnalysisSeverity.high: 0,
          AnalysisSeverity.medium: 0,
          AnalysisSeverity.low: 0,
          AnalysisSeverity.informational: 1,
        });
        expect(
          result.positiveChecks,
          contains('No prohibited words or phrases found.'),
        );
        expect(
          result.positiveChecks,
          contains('Approved terminology used: "community".'),
        );
        expect(
          result.issues.single.title,
          'No configured verified statement found',
        );
      },
    );

    test('returns distinct status labels and immutable result collections', () {
      final result = engine.analyze(
        submission: submission('This is fine.'),
        guidelines: const BrandGuidelines(),
      );

      expect(AnalysisStatus.passed.label, 'Passed');
      expect(AnalysisStatus.needsReview.label, 'Needs Review');
      expect(AnalysisStatus.criticalIssues.label, 'Critical Issues');
      expect(
        () => result.issues.add(
          const BrandAnalysisIssue(
            title: 'x',
            severity: AnalysisSeverity.low,
            explanation: 'x',
            matchedText: '',
            relatedGuideline: 'x',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  test('matches the complete saved multiword prohibited phrase', () {
    final result = engine.analyze(
      submission: submission('We deliver guaranteed results.'),
      guidelines: const BrandGuidelines(
        brandName: 'Northstar',
        prohibitedTerms: ['guaranteed results'],
      ),
    );

    expect(result.status, AnalysisStatus.criticalIssues);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.matchedText, 'guaranteed results');
    expect(result.issues.single.startOffset, 11);
    expect(result.issues.single.endOffset, 29);
  });

  test('flags absent required terms without changing approved term advice', () {
    final result = engine.analyze(
      submission: submission('Our community is growing.'),
      guidelines: const BrandGuidelines(
        approvedTerms: ['community'],
        requiredTerms: ['Made for creators'],
      ),
    );

    expect(result.issues, hasLength(1));
    expect(result.issues.single.title, 'Required brand term missing');
    expect(result.issues.single.severity, AnalysisSeverity.medium);
    expect(
      result.issues.single.relatedGuideline,
      contains('Made for creators'),
    );
    expect(
      result.positiveChecks,
      contains('Approved terminology used: "community".'),
    );
  });

  test('flags claim patterns as advisory requiring human verification', () {
    final result = engine.analyze(
      submission: submission('We are the leading service for 2 million users.'),
      guidelines: const BrandGuidelines(brandName: 'Northstar'),
    );
    expect(
      result.issues.map((issue) => issue.title),
      containsAll(['Claim may need substantiation']),
    );
    expect(
      result.issues.every((issue) => issue.requiresHumanVerification),
      isTrue,
    );
    expect(result.status, AnalysisStatus.needsReview);
    expect(result.issues.first.startOffset, isNotNull);
  });

  test('flags limited informal markers for a Formal tone only', () {
    final result = engine.analyze(
      submission: submission("Hey, we're here!"),
      guidelines: const BrandGuidelines(tone: BrandTone.formal),
    );
    expect(
      result.issues.map((issue) => issue.title),
      contains('Potentially informal wording'),
    );
    expect(
      result.issues
          .where((issue) => issue.title == 'Potentially informal wording')
          .every((issue) => issue.requiresHumanVerification),
      isTrue,
    );
  });
}
