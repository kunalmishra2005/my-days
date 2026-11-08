import 'dart:convert';

import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class HumanReviewDecisionStorage {
  Future<List<HumanReviewDecision>> loadAll();

  Future<HumanReviewDecision?> loadForSubmission(String submissionId);

  Future<void> save(HumanReviewDecision decision);
}

class SharedPreferencesHumanReviewDecisionStorage
    implements HumanReviewDecisionStorage {
  const SharedPreferencesHumanReviewDecisionStorage();

  static const _storageKey = 'brand_governance.human_review_decisions.v1';

  @override
  Future<List<HumanReviewDecision>> loadAll() => _loadAll();

  @override
  Future<HumanReviewDecision?> loadForSubmission(String submissionId) async {
    final decisions = await _loadAll();
    for (final decision in decisions) {
      if (decision.submissionId == submissionId) return decision;
    }
    return null;
  }

  @override
  Future<void> save(HumanReviewDecision decision) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = await _loadAll();
    final updated = [
      decision,
      ...existing.where((item) => item.submissionId != decision.submissionId),
    ];
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Human review decision could not be saved locally.');
    }
  }

  Future<List<HumanReviewDecision>> _loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final storedJson = preferences.getString(_storageKey);
    if (storedJson == null) return const [];

    final decoded = jsonDecode(storedJson);
    if (decoded is! List<Object?>) {
      throw const FormatException('Saved review decisions are not a list.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'A saved review decision is not an object.',
        );
      }
      return HumanReviewDecision.fromJson(item);
    }).toList();
  }
}
