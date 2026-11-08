import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saves and reloads submissions without changing their original body',
    () async {
      const storage = SharedPreferencesContentSubmissionStorage();
      const originalBody = 'Draft with spacing. \nKeep every character.';
      final submission = ContentSubmission.create(
        title: 'Campaign email',
        type: ContentType.email,
        body: originalBody,
      );

      await storage.save(submission);
      final restored = await storage.loadAll();

      expect(restored, hasLength(1));
      expect(restored.single.id, submission.id);
      expect(restored.single.title, 'Campaign email');
      expect(restored.single.type, ContentType.email);
      expect(restored.single.body, originalBody);
      expect(restored.single.createdAt, submission.createdAt);
    },
  );

  test('keeps multiple submissions in newest-first order', () async {
    const storage = SharedPreferencesContentSubmissionStorage();
    final first = ContentSubmission.create(
      title: 'First',
      type: ContentType.blog,
      body: 'First draft',
      createdAt: DateTime.utc(2026, 11, 1),
    );
    final second = ContentSubmission.create(
      title: 'Second',
      type: ContentType.socialMedia,
      body: 'Second draft',
      createdAt: DateTime.utc(2026, 11, 2),
    );

    await storage.save(first);
    await storage.save(second);

    expect((await storage.loadAll()).map((submission) => submission.id), [
      second.id,
      first.id,
    ]);
  });
}
