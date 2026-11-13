import 'package:brand_governance/app/my_days_app.dart';
import 'package:brand_governance/features/auth/data/demo_auth_service.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/workspaces/data/workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_authentication_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('judge demo is usable, fictional, and idempotently seeded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final demoAuth = DemoAuthenticationService();
    addTearDown(demoAuth.dispose);
    await tester.pumpWidget(MyDaysApp(authService: demoAuth));
    await tester.pumpAndSettle();

    expect(find.text('Judge sample workspace'), findsOneWidget);
    expect(find.byKey(const Key('enterJudgeDemoButton')), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);

    await tester.tap(find.byKey(const Key('enterJudgeDemoButton')));
    await tester.pumpAndSettle();
    expect(find.text('Northstar Community'), findsOneWidget);
    expect(find.text('LOCAL DATA · ACCOUNT ISOLATED'), findsOneWidget);

    await tester.tap(find.text('Submit content').first);
    await tester.pumpAndSettle();
    expect(find.text('Monthly workshop invitation'), findsOneWidget);
    await tester.ensureVisible(find.text('Monthly workshop invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly workshop invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Saved locally · Original draft unchanged'), findsWidgets);

    const userId = 'judge-demo-local-v1';
    const guidelines = SharedPreferencesGuidelinesStorage(userId: userId);
    const submissions = SharedPreferencesContentSubmissionStorage(
      userId: userId,
    );
    expect((await guidelines.load()).brandName, 'Northstar Community');
    expect(await submissions.loadAll(), hasLength(3));

    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enterJudgeDemoButton')));
    await tester.pumpAndSettle();
    expect(await submissions.loadAll(), hasLength(3));
  });

  testWidgets('sample demo remains available alongside cloud sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cloudAuth = FakeAuthenticationService(initialUser: null);
    addTearDown(cloudAuth.dispose);
    final auth = DemoAuthenticationService(cloudService: cloudAuth);
    addTearDown(auth.dispose);

    await tester.pumpWidget(MyDaysApp(authService: auth));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('enterJudgeDemoButton')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('enterJudgeDemoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enterJudgeDemoButton')));
    await tester.pumpAndSettle();
    expect(find.text('Northstar Community'), findsOneWidget);
    expect(auth.isDemoMode, isTrue);
    expect(cloudAuth.currentUser, isNull);
  });

  testWidgets('missing cloud workspace shows a clear empty state and retry', (
    tester,
  ) async {
    final auth = FakeAuthenticationService();
    addTearDown(auth.dispose);
    final repository = _NoWorkspaceRepository();
    await tester.pumpWidget(
      MyDaysApp(authService: auth, workspaceRepository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workspace linked yet'), findsOneWidget);
    expect(
      find.textContaining('Workspace creation is disabled'),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('No workspace linked yet'), findsNothing);
    expect(find.byKey(const Key('brandNameField')), findsOneWidget);
  });
}

class _NoWorkspaceRepository implements WorkspaceRepository {
  int calls = 0;

  @override
  Future<Workspace> resolveCurrentWorkspace() async {
    calls++;
    if (calls == 1) {
      throw const WorkspaceProvisioningBlockedException();
    }
    return const Workspace(id: 'test-workspace', name: 'Test workspace');
  }
}
