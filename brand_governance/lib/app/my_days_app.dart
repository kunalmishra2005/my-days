import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/core/data/supabase_data_gateway.dart';
import 'package:brand_governance/features/auth/data/demo_auth_service.dart';
import 'package:brand_governance/features/auth/data/judge_demo_data.dart';
import 'package:brand_governance/features/auth/data/supabase_auth_service.dart';
import 'package:brand_governance/features/auth/presentation/auth_screen.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/data/supabase_human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/presentation/content_submission_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/presentation/brand_guidelines_screen.dart';
import 'package:brand_governance/features/review_history/presentation/review_analytics_screen.dart';
import 'package:brand_governance/features/review_history/presentation/review_history_screen.dart';
import 'package:brand_governance/features/workspaces/data/workspace_repository.dart';
import 'package:flutter/material.dart';

SupabaseAuthService? _cloudAuthService(AuthenticationService service) =>
    switch (service) {
      SupabaseAuthService supabase => supabase,
      DemoAuthenticationService demo =>
        demo.cloudAuthenticationService == null
            ? null
            : _cloudAuthService(demo.cloudAuthenticationService!),
      _ => null,
    };

class MyDaysApp extends StatelessWidget {
  const MyDaysApp({super.key, this.authService, this.workspaceRepository});

  final AuthenticationService? authService;
  final WorkspaceRepository? workspaceRepository;

  @override
  Widget build(BuildContext context) {
    final authentication = authService ?? SupabaseAuthService();
    return MaterialApp(
      title: "MY DAY'S | Brand Governance",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _AuthGate(
        authService: authentication,
        workspaceRepository: workspaceRepository,
      ),
    );
  }
}

class ConfigurationRequiredApp extends StatelessWidget {
  const ConfigurationRequiredApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "MY DAY'S | Configuration",
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_rounded, size: 44),
                const SizedBox(height: 16),
                const Text(
                  'Supabase configuration is incomplete',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$message To explore the fictional local judge demo, leave '
                  'both values unset. Never use a service-role key in this app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.authService,
    required this.workspaceRepository,
  });

  final AuthenticationService authService;
  final WorkspaceRepository? workspaceRepository;

  @override
  Widget build(BuildContext context) {
    final authentication = authService;
    final isDemoMode =
        authentication is DemoAuthenticationService &&
        authentication.isDemoMode;
    final cloudAuthService = _cloudAuthService(authentication);
    final repository = isDemoMode
        ? null
        : workspaceRepository ??
              (cloudAuthService == null
                  ? null
                  : SupabaseWorkspaceRepository(
                      AuthenticatedSupabaseDataGateway(cloudAuthService.client),
                    ));
    return StreamBuilder<AuthenticatedUser?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AuthStateError(
            message:
                'Authentication state could not be monitored. Refresh the '
                'page or restart the app.',
          );
        }

        final user = snapshot.data;
        if (user == null) {
          final demoAuthentication = authService;
          return AuthScreen(
            authService: authService,
            onDemoAccess: demoAuthentication is DemoAuthenticationService
                ? demoAuthentication.enterDemo
                : null,
            demoOnly:
                demoAuthentication is DemoAuthenticationService &&
                !demoAuthentication.hasCloudAuthentication,
          );
        }

        return _WorkspaceGate(
          key: ValueKey(user.id),
          userId: user.id,
          authService: authentication,
          repository: repository,
        );
      },
    );
  }
}

class _WorkspaceGate extends StatefulWidget {
  const _WorkspaceGate({
    super.key,
    required this.userId,
    required this.authService,
    required this.repository,
  });

  final String userId;
  final AuthenticationService authService;
  final WorkspaceRepository? repository;

  @override
  State<_WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<_WorkspaceGate> {
  late Future<Workspace?> _workspaceFuture;

  @override
  void initState() {
    super.initState();
    _workspaceFuture = _resolveWorkspace();
  }

  Future<Workspace?> _resolveWorkspace() async {
    final repository = widget.repository;
    if (repository == null) {
      final authentication = widget.authService;
      if (authentication is DemoAuthenticationService &&
          authentication.isDemoMode) {
        await seedJudgeDemoData(
          guidelinesStorage: SharedPreferencesGuidelinesStorage(
            userId: widget.userId,
          ),
          submissionStorage: SharedPreferencesContentSubmissionStorage(
            userId: widget.userId,
          ),
          decisionStorage: SharedPreferencesHumanReviewDecisionStorage(
            userId: widget.userId,
          ),
        );
      }
      return null;
    }
    return repository.resolveCurrentWorkspace();
  }

  void _retry() {
    final workspaceFuture = _resolveWorkspace();
    setState(() {
      _workspaceFuture = workspaceFuture;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Workspace?>(
    future: _workspaceFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your workspace…'),
              ],
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        final hasNoWorkspace =
            snapshot.error is WorkspaceProvisioningBlockedException;
        final message = switch (snapshot.error) {
          WorkspaceProvisioningBlockedException() =>
            'No workspace membership is available for this account. Workspace '
                'creation is disabled until safe, atomic provisioning is '
                'configured.',
          StateError() =>
            'Workspace access is ambiguous or could not be verified. Contact '
                'the workspace administrator, then retry.',
          _ =>
            'The workspace could not be reached. Check the connection and '
                'your workspace access, then retry.',
        };
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasNoWorkspace
                        ? Icons.business_outlined
                        : Icons.cloud_off_rounded,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasNoWorkspace
                        ? 'No workspace linked yet'
                        : 'Workspace unavailable',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: widget.authService.signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final workspace = snapshot.data;
      final authentication = widget.authService;
      final isDemoMode =
          authentication is DemoAuthenticationService &&
          authentication.isDemoMode;
      final cloudAuthService = _cloudAuthService(authentication);
      final gateway = !isDemoMode && cloudAuthService != null
          ? AuthenticatedSupabaseDataGateway(cloudAuthService.client)
          : null;
      return _WorkspaceShell(
        userId: widget.userId,
        workspaceId: workspace?.id,
        gateway: gateway,
        authService: widget.authService,
      );
    },
  );
}

class _WorkspaceShell extends StatefulWidget {
  const _WorkspaceShell({
    required this.userId,
    required this.workspaceId,
    required this.gateway,
    required this.authService,
  });

  final String userId;
  final String? workspaceId;
  final SupabaseDataGateway? gateway;
  final AuthenticationService authService;

  @override
  State<_WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<_WorkspaceShell> {
  late final _guidelinesStorage = widget.gateway != null
      ? SupabaseGuidelinesStorage(
          gateway: widget.gateway!,
          workspaceId: widget.workspaceId!,
        )
      : SharedPreferencesGuidelinesStorage(userId: widget.userId);
  late final _submissionStorage = widget.gateway != null
      ? SupabaseContentSubmissionStorage(
          gateway: widget.gateway!,
          workspaceId: widget.workspaceId!,
        )
      : SharedPreferencesContentSubmissionStorage(userId: widget.userId);
  late final _decisionStorage = widget.gateway != null
      ? SupabaseHumanReviewDecisionStorage(
          gateway: widget.gateway!,
          workspaceId: widget.workspaceId!,
        )
      : SharedPreferencesHumanReviewDecisionStorage(userId: widget.userId);

  int _selectedIndex = 0;
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await widget.authService.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _openGuidelines() {
    setState(() => _selectedIndex = 0);
  }

  Widget _selectedScreen() {
    return switch (_selectedIndex) {
      0 => BrandGuidelinesScreen(storage: _guidelinesStorage),
      1 => ContentSubmissionScreen(
        key: const ValueKey('contentSubmissionScreen'),
        submissionStorage: _submissionStorage,
        guidelinesStorage: _guidelinesStorage,
        onOpenGuidelines: _openGuidelines,
        reviewDecisionStorage: _decisionStorage,
      ),
      2 => ReviewHistoryScreen(
        submissionStorage: _submissionStorage,
        decisionStorage: _decisionStorage,
        guidelinesStorage: _guidelinesStorage,
      ),
      _ => ReviewAnalyticsScreen(
        submissionStorage: _submissionStorage,
        decisionStorage: _decisionStorage,
        guidelinesStorage: _guidelinesStorage,
      ),
    };
  }

  Widget _pageTransition(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: _selectedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 800;

        final destinations = const [
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Guidelines',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            label: 'Submit content',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Review history',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_rounded),
            label: 'Analytics',
          ),
        ];

        if (wideLayout) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: true,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.deepIndigo,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.softWhite,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "MY DAY'S",
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.deepIndigo,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              'BRAND WORKSPACE',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.deepIndigo.withValues(
                                      alpha: 0.55,
                                    ),
                                    letterSpacing: 0.7,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.gateway == null
                              ? 'LOCAL DATA · ACCOUNT ISOLATED'
                              : 'SUPABASE · WORKSPACE SCOPED',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppTheme.deepIndigo.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        _signOutButton(),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_rounded),
                      label: Text('Guidelines'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.edit_note_rounded),
                      label: Text('Submit content'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_rounded),
                      label: Text('Review history'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.query_stats_rounded),
                      label: Text('Analytics'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pageTransition(context)),
              ],
            ),
          );
        }

        return Scaffold(
          body: _pageTransition(context),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  destinations: destinations,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _signOutButton(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _signOutButton() => TextButton.icon(
    key: const Key('signOutButton'),
    onPressed: _isSigningOut ? null : _signOut,
    icon: _isSigningOut
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.logout_rounded),
    label: Text(_isSigningOut ? 'Signing out…' : 'Sign out'),
  );
}

class _AuthStateError extends StatelessWidget {
  const _AuthStateError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Authentication state could not be monitored. Restart the app and '
          'try again.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
