import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/presentation/content_submission_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/presentation/brand_guidelines_screen.dart';
import 'package:brand_governance/features/review_history/presentation/review_analytics_screen.dart';
import 'package:brand_governance/features/review_history/presentation/review_history_screen.dart';
import 'package:flutter/material.dart';

class MyDaysApp extends StatelessWidget {
  const MyDaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MY DAY'S | Brand Governance",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _WorkspaceShell(),
    );
  }
}

class _WorkspaceShell extends StatefulWidget {
  const _WorkspaceShell();

  @override
  State<_WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<_WorkspaceShell> {
  static const _guidelinesStorage = SharedPreferencesGuidelinesStorage();
  static const _submissionStorage = SharedPreferencesContentSubmissionStorage();
  static const _decisionStorage = SharedPreferencesHumanReviewDecisionStorage();

  int _selectedIndex = 0;

  void _openGuidelines() {
    setState(() => _selectedIndex = 0);
  }

  Widget _selectedScreen() {
    return switch (_selectedIndex) {
      0 => const BrandGuidelinesScreen(storage: _guidelinesStorage),
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
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'LOCAL DEMO · PRIVATE TO THIS DEVICE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.deepIndigo.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
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
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: destinations,
          ),
        );
      },
    );
  }
}
