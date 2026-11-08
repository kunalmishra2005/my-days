import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentSubmission', () {
    test('round trips the original body and creation timestamp', () {
      final createdAt = DateTime.utc(2026, 11, 6, 14, 30);
      const originalBody = '  Launching soon!\n\nKeep this exact draft.  ';
      final submission = ContentSubmission.create(
        title: '  Winter launch  ',
        type: ContentType.email,
        body: originalBody,
        createdAt: createdAt,
      );

      final restored = ContentSubmission.fromJson(submission.toJson());

      expect(submission.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(submission.title, 'Winter launch');
      expect(submission.body, originalBody);
      expect(submission.type, ContentType.email);
      expect(submission.createdAt, createdAt);
      expect(restored.id, submission.id);
      expect(restored.body, originalBody);
      expect(restored.createdAt, createdAt);
    });

    test('generates a distinct identifier for each submission', () {
      final submissions = List.generate(
        10,
        (index) => ContentSubmission.create(
          title: 'Draft $index',
          type: ContentType.blog,
          body: 'Draft body',
        ),
      );

      expect(submissions.map((item) => item.id).toSet(), hasLength(10));
    });

    test('rejects unknown content types in persisted data', () {
      expect(
        () => ContentSubmission.fromJson({
          'id': 'id',
          'title': 'Title',
          'type': 'video',
          'body': 'Body',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });
}
