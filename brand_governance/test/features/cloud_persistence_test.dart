import 'package:brand_governance/core/data/supabase_data_gateway.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/supabase_human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:brand_governance/features/workspaces/data/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseWorkspaceRepository', () {
    test('resolves and verifies the authenticated user workspace', () async {
      final gateway = _FakeGateway()
        ..seed('workspace_members', [
          {'workspace_id': 'workspace-a', 'user_id': 'user-a', 'role': 'owner'},
        ])
        ..seed('workspaces', [
          {'id': 'workspace-a', 'name': 'Brand'},
        ]);

      final workspace = await SupabaseWorkspaceRepository(gateway)
          .resolveCurrentWorkspace();

      expect(workspace.id, 'workspace-a');
      expect(workspace.name, 'Brand');
    });

    test('blocks unsafe workspace provisioning when membership is absent', () {
      expect(
        () =>
            SupabaseWorkspaceRepository(_FakeGateway())
                .resolveCurrentWorkspace(),
        throwsA(isA<WorkspaceProvisioningBlockedException>()),
      );
    });

    test('rejects duplicate workspace memberships', () {
      final gateway = _FakeGateway()
        ..seed('workspace_members', [
          {'workspace_id': 'workspace-a', 'user_id': 'user-a'},
          {'workspace_id': 'workspace-a', 'user_id': 'user-a'},
        ]);
      expect(
        () => SupabaseWorkspaceRepository(gateway).resolveCurrentWorkspace(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SupabaseGuidelinesStorage', () {
    test(
      'round-trips JSON guidelines and updates by the row primary key',
      () async {
        final gateway = _workspaceGateway()
          ..seed('brand_guidelines', [
            {
              'id': 'guidelines-a',
              'workspace_id': 'workspace-a',
              'brand_name': 'Old name',
              'guidelines': const BrandGuidelines().toJson(),
            },
          ]);
        const expected = BrandGuidelines(
          brandName: 'Acme',
          description: 'A trusted brand',
          tone: BrandTone.formal,
          customTone: 'Precise',
          approvedTerms: ['approved'],
          requiredTerms: ['required'],
          prohibitedTerms: ['prohibited'],
          verifiedFacts: ['fact'],
        );
        final storage = SupabaseGuidelinesStorage(
          gateway: gateway,
          workspaceId: 'workspace-a',
        );

        await storage.save(expected);

        final loaded = await storage.load();
        expect(loaded.toJson(), expected.toJson());
        expect(gateway.rows('brand_guidelines').single['brand_name'], 'Acme');
      },
    );

    test(
      'does not insert a guideline when no safe unique identity exists',
      () async {
        final gateway = _workspaceGateway();
        final storage = SupabaseGuidelinesStorage(
          gateway: gateway,
          workspaceId: 'workspace-a',
        );

        await expectLater(
          storage.save(const BrandGuidelines(brandName: 'Acme')),
          throwsA(isA<StateError>()),
        );
        expect(gateway.rows('brand_guidelines'), isEmpty);
      },
    );

    test('rejects access when membership is not verified', () async {
      final storage = SupabaseGuidelinesStorage(
        gateway: _FakeGateway(),
        workspaceId: 'workspace-b',
      );
      await expectLater(storage.load(), throwsA(isA<StateError>()));
    });
  });

  group('SupabaseContentSubmissionStorage', () {
    test(
      'persists and loads unmodified body scoped to the workspace',
      () async {
        final gateway = _workspaceGateway();
        final storage = SupabaseContentSubmissionStorage(
          gateway: gateway,
          workspaceId: 'workspace-a',
        );
        final submission = ContentSubmission.create(
          title: 'Launch',
          type: ContentType.email,
          body: '  Original body\nunchanged  ',
          createdAt: DateTime.utc(2026, 1, 2),
        );

        await storage.save(submission);
        final loaded = await storage.loadAll();

        expect(loaded.single.id, submission.id);
        expect(loaded.single.body, submission.body);
        expect(
          gateway.rows('content_submissions').single['workspace_id'],
          'workspace-a',
        );
        expect(
          gateway.rows('content_submissions').single['submitted_by'],
          'user-a',
        );
      },
    );

    test('does not allow reading a workspace without membership', () async {
      final storage = SupabaseContentSubmissionStorage(
        gateway: _FakeGateway(),
        workspaceId: 'workspace-b',
      );
      await expectLater(storage.loadAll(), throwsA(isA<StateError>()));
    });
  });

  group('SupabaseHumanReviewDecisionStorage', () {
    test(
      'inserts decision history without replacing earlier decisions',
      () async {
        final gateway = _workspaceGateway();
        final storage = SupabaseHumanReviewDecisionStorage(
          gateway: gateway,
          workspaceId: 'workspace-a',
        );
        final first = _decision(
          ReviewDecision.requestChanges,
          DateTime.utc(2026),
        );
        final second = _decision(
          ReviewDecision.approve,
          DateTime.utc(2026, 1, 2),
        );

        await storage.save(first);
        await storage.save(second);

        final history = await storage.loadAll();
        expect(history.map((item) => item.decision).toList(), [
          second.decision,
          first.decision,
        ]);
        expect(history.map((item) => item.comments).toList(), [
          second.comments,
          first.comments,
        ]);
        expect(gateway.rows('review_decisions'), hasLength(2));
        expect(gateway.rows('review_decisions').last['reviewer_id'], 'user-a');
      },
    );
  });

  test(
    'surfaces network and permission errors without swallowing them',
    () async {
      final gateway = _workspaceGateway()
        ..failure = Exception('network unavailable');
      final storage = SupabaseContentSubmissionStorage(
        gateway: gateway,
        workspaceId: 'workspace-a',
      );
      await expectLater(storage.loadAll(), throwsException);
    },
  );
}

HumanReviewDecision _decision(ReviewDecision decision, DateTime time) =>
    HumanReviewDecision(
      submissionId: 'submission-a',
      decision: decision,
      reviewerName: 'Reviewer',
      comments: 'Comment',
      reason: 'Reason',
      decidedAt: time,
      analysisStatus: AnalysisStatus.needsReview,
    );

_FakeGateway _workspaceGateway() => _FakeGateway()
  ..seed('workspace_members', [
    {'workspace_id': 'workspace-a', 'user_id': 'user-a', 'role': 'owner'},
  ]);

class _FakeGateway implements SupabaseDataGateway {
  final Map<String, List<Map<String, Object?>>> _tables = {};
  Object? failure;

  void seed(String table, List<Map<String, Object?>> rows) {
    _tables[table] = rows.map(Map<String, Object?>.of).toList();
  }

  List<Map<String, Object?>> rows(String table) =>
      List.unmodifiable(_tables[table] ?? const []);

  @override
  String get authenticatedUserId => 'user-a';

  @override
  Future<List<Map<String, Object?>>> select(
    String table, {
    Map<String, Object?> equals = const {},
    String? orderBy,
    bool ascending = true,
  }) async {
    _throwFailure();
    final result = (_tables[table] ?? const <Map<String, Object?>>[])
        .where(
          (row) =>
              equals.entries.every((entry) => row[entry.key] == entry.value),
        )
        .map(Map<String, Object?>.of)
        .toList();
    if (orderBy != null) {
      result.sort((left, right) {
        final comparison = '${left[orderBy]}'.compareTo('${right[orderBy]}');
        return ascending ? comparison : -comparison;
      });
    }
    return result;
  }

  @override
  Future<void> insert(String table, Map<String, Object?> values) async {
    _throwFailure();
    (_tables[table] ??= []).add(Map<String, Object?>.of(values));
  }

  @override
  Future<void> update(
    String table, {
    required String idColumn,
    required String id,
    required Map<String, Object?> values,
  }) async {
    _throwFailure();
    final rows = _tables[table] ?? const <Map<String, Object?>>[];
    final matches = rows.where((row) => row[idColumn] == id);
    if (matches.length != 1) throw StateError('Expected one row to update.');
    matches.single.addAll(values);
  }

  void _throwFailure() {
    final error = failure;
    if (error != null) throw error;
  }
}
