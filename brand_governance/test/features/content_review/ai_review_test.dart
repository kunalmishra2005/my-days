import 'dart:async';

import 'package:brand_governance/features/content_review/ai/ai_review_models.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_provider.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_service.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = AiReviewRequest(
    submission: ContentSubmission.create(
      title: 'Launch email',
      type: ContentType.email,
      body: 'Welcome, community.',
      createdAt: DateTime.utc(2026, 11, 1),
    ),
    guidelines: const BrandGuidelines(
      brandName: 'Northstar',
      requiredTerms: ['community'],
      prohibitedTerms: ['guaranteed results'],
    ),
  );
  final responseJson = <String, Object?>{
    'findings': [
      <String, Object?>{
        'title': 'Context needs review',
        'severity': 'medium',
        'explanation': 'Check the phrase against the campaign context.',
        'matchedText': 'community',
        'relatedGuideline': 'Required brand terms',
        'suggestedCorrection': null,
        'startOffset': 9,
        'endOffset': 18,
        'requiresHumanVerification': true,
      },
    ],
  };

  test('serializes only content and guidelines in the review request', () {
    final json = request.toJson();
    expect(json['submission'], containsPair('title', 'Launch email'));
    expect(json['guidelines'], containsPair('requiredTerms', ['community']));
    expect(json.toString(), isNot(contains('apiKey')));
  });

  test('validates structured findings and source offsets', () {
    final response = AiReviewResponse.fromJson(
      responseJson,
      sourceText: request.submission.body,
    );
    expect(response.findings, hasLength(1));
    expect(response.findings.single.severity, AnalysisSeverity.medium);
    expect(response.findings.single.requiresHumanVerification, isTrue);
    expect(response.findings.single.startOffset, 9);

    final invalid = {
      'findings': [
        {
          ...(responseJson['findings'] as List<Object?>).first
              as Map<String, Object?>,
          'startOffset': 1,
        },
      ],
    };
    expect(
      () => AiReviewResponse.fromJson(
        invalid,
        sourceText: request.submission.body,
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown severity and malformed response fields', () {
    final invalidSeverity = {
      'findings': [
        {
          ...(responseJson['findings'] as List<Object?>).first
              as Map<String, Object?>,
          'severity': 'extreme',
        },
      ],
    };
    expect(
      () => AiReviewResponse.fromJson(
        invalidSeverity,
        sourceText: request.submission.body,
      ),
      throwsFormatException,
    );
    expect(
      () => AiReviewResponse.fromJson({
        'findings': 'not-a-list',
      }, sourceText: request.submission.body),
      throwsFormatException,
    );
  });

  test('rejects AI findings that bypass required human verification', () {
    final invalid = {
      'findings': [
        {
          ...(responseJson['findings'] as List<Object?>).first
              as Map<String, Object?>,
          'requiresHumanVerification': false,
        },
      ],
    };
    expect(
      () => AiReviewResponse.fromJson(
        invalid,
        sourceText: request.submission.body,
      ),
      throwsFormatException,
    );
  });

  test('does not call an Adaption gateway when unconfigured', () async {
    const provider = AdaptionLabsReviewProvider();
    expect(provider.isConfigured, isFalse);
    await expectLater(
      const AiReviewService(provider: provider).review(request),
      throwsA(isA<AiReviewNotConfiguredException>()),
    );
  });

  test(
    'adapts a configured gateway response without endpoint assumptions',
    () async {
      final gateway = _FixtureGateway(responseJson);
      final provider = AdaptionLabsReviewProvider(gateway: gateway);
      final adapted = await provider.review(request);
      expect(provider.isConfigured, isTrue);
      expect(provider.statusLabel, 'BACKEND ADAPTER INJECTED');
      expect(gateway.receivedRequest, same(request));
      expect(adapted.findings.single.title, 'Context needs review');
    },
  );

  test(
    'returns supplied mock fixture and reports timeout distinctly',
    () async {
      final fixture = AiReviewResponse.fromJson(
        responseJson,
        sourceText: request.submission.body,
      );
      final mock = MockFixtureAiReviewProvider(fixture: fixture);
      final outcome = await AiReviewService(provider: mock).review(request);
      expect(outcome.providerName, contains('simulated'));
      expect(outcome.response.findings, hasLength(1));

      final timed = AiReviewService(
        provider: _NeverCompletingProvider(),
        timeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        timed.review(request),
        throwsA(isA<AiReviewTimeoutException>()),
      );
      expect(mock.isConfigured, isTrue);
    },
  );
}

class _FixtureGateway implements AdaptionReviewGateway {
  _FixtureGateway(this.response);
  final Object? response;
  AiReviewRequest? receivedRequest;

  @override
  Future<Object?> requestReview(AiReviewRequest request) async {
    receivedRequest = request;
    return response;
  }
}

class _NeverCompletingProvider implements AiReviewProvider {
  @override
  String get displayName => 'Test provider';

  @override
  String get statusLabel => 'TEST';

  @override
  bool get isConfigured => true;

  @override
  Future<AiReviewResponse> review(AiReviewRequest request) =>
      Completer<AiReviewResponse>().future;
}
