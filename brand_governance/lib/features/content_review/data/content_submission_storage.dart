import 'dart:convert';

import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ContentSubmissionStorage {
  Future<List<ContentSubmission>> loadAll();

  Future<void> save(ContentSubmission submission);
}

class SharedPreferencesContentSubmissionStorage
    implements ContentSubmissionStorage {
  const SharedPreferencesContentSubmissionStorage();

  static const _storageKey = 'brand_governance.content_submissions.v1';

  @override
  Future<List<ContentSubmission>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final storedJson = preferences.getString(_storageKey);
    if (storedJson == null) return const [];

    final decoded = jsonDecode(storedJson);
    if (decoded is! List<Object?>) {
      throw const FormatException('Saved content submissions are not a list.');
    }

    return List<ContentSubmission>.unmodifiable(
      decoded.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'A saved content submission is not an object.',
          );
        }
        return ContentSubmission.fromJson(item);
      }),
    );
  }

  @override
  Future<void> save(ContentSubmission submission) async {
    final preferences = await SharedPreferences.getInstance();
    final submissions = await loadAll();
    if (submissions.any((existing) => existing.id == submission.id)) {
      throw StateError(
        'A submission with ID "${submission.id}" already exists.',
      );
    }

    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(
        [submission, ...submissions].map((item) => item.toJson()).toList(),
      ),
    );
    if (!saved) {
      throw StateError('Content submission could not be saved locally.');
    }
  }
}
