import 'dart:async';

import 'package:brand_governance/features/content_review/ai/ai_review_models.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_provider.dart';

class AiReviewOutcome {
  const AiReviewOutcome({
    required this.providerName,
    required this.providerStatus,
    required this.response,
    required this.completedAt,
  });

  final String providerName;
  final String providerStatus;
  final AiReviewResponse response;
  final DateTime completedAt;
}

class AiReviewService {
  const AiReviewService({
    required this.provider,
    this.timeout = const Duration(seconds: 30),
  });

  final AiReviewProvider provider;
  final Duration timeout;

  Future<AiReviewOutcome> review(AiReviewRequest request) async {
    if (!provider.isConfigured) {
      throw const AiReviewNotConfiguredException(
        'AI review is unavailable until a secure backend and provider are '
        'configured. Deterministic checks remain available.',
      );
    }

    try {
      final response = await provider.review(request).timeout(timeout);
      return AiReviewOutcome(
        providerName: provider.displayName,
        providerStatus: provider.statusLabel,
        response: response,
        completedAt: DateTime.now().toUtc(),
      );
    } on TimeoutException {
      throw AiReviewTimeoutException(timeout);
    }
  }
}

class AiReviewTimeoutException implements Exception {
  const AiReviewTimeoutException(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'AI review timed out after ${timeout.inSeconds} seconds. Try again later.';
}
