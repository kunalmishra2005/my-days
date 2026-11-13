import 'dart:convert';

import 'package:brand_governance/core/data/supabase_data_gateway.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';

class SupabaseHumanReviewDecisionStorage
    implements HumanReviewDecisionStorage, CloudBackedStorage {
  const SupabaseHumanReviewDecisionStorage({
    required this.gateway,
    required this.workspaceId,
  });

  final SupabaseDataGateway gateway;
  final String workspaceId;

  @override
  Future<List<HumanReviewDecision>> loadAll() async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final rows = await gateway.select(
      'review_decisions',
      equals: {'workspace_id': workspaceId},
      orderBy: 'created_at',
      ascending: false,
    );
    return List<HumanReviewDecision>.unmodifiable(rows.map(_decisionFromRow));
  }

  @override
  Future<HumanReviewDecision?> loadForSubmission(String submissionId) async {
    final decisions = await loadAll();
    for (final decision in decisions) {
      if (decision.submissionId == submissionId) return decision;
    }
    return null;
  }

  @override
  Future<void> save(HumanReviewDecision decision) async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final reviewerId = gateway.authenticatedUserId;
    if (reviewerId == null) {
      throw StateError('An authenticated session is required.');
    }
    await gateway.insert('review_decisions', {
      'submission_id': decision.submissionId,
      'workspace_id': workspaceId,
      'reviewer_id': reviewerId,
      'decision': decision.decision.name,
      'notes': jsonEncode({
        'reviewerName': decision.reviewerName,
        'comments': decision.comments,
        'reason': decision.reason,
        'analysisStatus': decision.analysisStatus.name,
      }),
      'created_at': decision.decidedAt.toUtc().toIso8601String(),
    });
  }

  HumanReviewDecision _decisionFromRow(Map<String, Object?> row) {
    final submissionId = row['submission_id'];
    final decisionName = row['decision'];
    final notes = row['notes'];
    final createdAt = row['created_at'];
    if (submissionId is! String ||
        decisionName is! String ||
        notes is! String ||
        createdAt is! String) {
      throw const FormatException('Cloud review decision has invalid fields.');
    }
    final decision = ReviewDecision.values.where(
      (value) => value.name == decisionName,
    );
    if (decision.length != 1) {
      throw FormatException('Unknown cloud decision "$decisionName".');
    }
    final decoded = jsonDecode(notes);
    if (decoded is! Map) {
      throw const FormatException('Cloud decision notes are not an object.');
    }
    final details = Map<String, Object?>.from(decoded);
    final reviewerName = details['reviewerName'];
    final comments = details['comments'];
    final reason = details['reason'];
    final analysisStatusName = details['analysisStatus'];
    if (reviewerName is! String ||
        comments is! String ||
        reason is! String ||
        analysisStatusName is! String) {
      throw const FormatException('Cloud decision notes have invalid fields.');
    }
    final analysisStatus = AnalysisStatus.values.where(
      (value) => value.name == analysisStatusName,
    );
    if (analysisStatus.length != 1) {
      throw FormatException(
        'Unknown cloud analysis status "$analysisStatusName".',
      );
    }
    return HumanReviewDecision(
      submissionId: submissionId,
      decision: decision.single,
      reviewerName: reviewerName,
      comments: comments,
      reason: reason,
      decidedAt: DateTime.parse(createdAt).toUtc(),
      analysisStatus: analysisStatus.single,
    );
  }
}
