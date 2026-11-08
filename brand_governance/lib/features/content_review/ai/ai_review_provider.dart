import 'package:brand_governance/features/content_review/ai/ai_review_models.dart';

abstract interface class AiReviewProvider {
  String get displayName;

  String get statusLabel;

  bool get isConfigured;

  Future<AiReviewResponse> review(AiReviewRequest request);
}

abstract interface class AdaptionReviewGateway {
  Future<Object?> requestReview(AiReviewRequest request);
}

class AdaptionLabsReviewProvider implements AiReviewProvider {
  const AdaptionLabsReviewProvider({this.gateway});

  final AdaptionReviewGateway? gateway;

  @override
  String get displayName => 'Adaption Labs';

  @override
  String get statusLabel =>
      gateway == null ? 'NOT CONNECTED' : 'BACKEND ADAPTER INJECTED';

  @override
  bool get isConfigured => gateway != null;

  @override
  Future<AiReviewResponse> review(AiReviewRequest request) async {
    final configuredGateway = gateway;
    if (configuredGateway == null) {
      throw const AiReviewNotConfiguredException(
        'Adaption Labs backend integration is not configured.',
      );
    }
    final rawResponse = await configuredGateway.requestReview(request);
    return AiReviewResponse.fromJson(
      rawResponse,
      sourceText: request.submission.body,
    );
  }
}

class MockFixtureAiReviewProvider implements AiReviewProvider {
  const MockFixtureAiReviewProvider({required this.fixture});

  final AiReviewResponse fixture;

  @override
  String get displayName => 'Local fixture provider (simulated)';

  @override
  String get statusLabel => 'SIMULATED';

  @override
  bool get isConfigured => true;

  @override
  Future<AiReviewResponse> review(AiReviewRequest request) async => fixture;
}

class AiReviewNotConfiguredException implements Exception {
  const AiReviewNotConfiguredException(this.message);

  final String message;

  @override
  String toString() => message;
}
