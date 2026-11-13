import 'dart:convert';

import 'package:brand_governance/core/data/account_storage_key.dart';
import 'package:brand_governance/core/data/supabase_data_gateway.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ContentSubmissionStorage {
  Future<List<ContentSubmission>> loadAll();

  Future<void> save(ContentSubmission submission);
}

class SharedPreferencesContentSubmissionStorage
    implements ContentSubmissionStorage {
  const SharedPreferencesContentSubmissionStorage({this.userId})
    : assert(userId == null || userId != '');

  final String? userId;

  static const _legacyStorageKey = 'brand_governance.content_submissions.v1';
  String get _storageKey => accountScopedStorageKey(_legacyStorageKey, userId);

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

class SupabaseContentSubmissionStorage
    implements ContentSubmissionStorage, CloudBackedStorage {
  const SupabaseContentSubmissionStorage({
    required this.gateway,
    required this.workspaceId,
  });

  final SupabaseDataGateway gateway;
  final String workspaceId;

  @override
  Future<List<ContentSubmission>> loadAll() async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final rows = await gateway.select(
      'content_submissions',
      equals: {'workspace_id': workspaceId},
      orderBy: 'created_at',
      ascending: false,
    );
    return List<ContentSubmission>.unmodifiable(rows.map(_submissionFromRow));
  }

  @override
  Future<void> save(ContentSubmission submission) async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final userId = gateway.authenticatedUserId;
    if (userId == null) {
      throw StateError('An authenticated session is required.');
    }
    await gateway.insert('content_submissions', {
      'id': submission.id,
      'workspace_id': workspaceId,
      'submitted_by': userId,
      'title': submission.title,
      'channel': submission.type.name,
      'body': submission.body,
      'created_at': submission.createdAt.toUtc().toIso8601String(),
    });
  }

  ContentSubmission _submissionFromRow(Map<String, Object?> row) {
    final id = row['id'];
    final title = row['title'];
    final channel = row['channel'];
    final body = row['body'];
    final createdAt = row['created_at'];
    if (id is! String ||
        title is! String ||
        channel is! String ||
        body is! String ||
        createdAt is! String) {
      throw const FormatException('Cloud submission has invalid fields.');
    }
    final type = ContentType.values.where((value) => value.name == channel);
    if (type.length != 1) {
      throw FormatException('Unknown cloud submission channel "$channel".');
    }
    return ContentSubmission(
      id: id,
      title: title,
      type: type.single,
      body: body,
      createdAt: DateTime.parse(createdAt).toUtc(),
    );
  }
}
