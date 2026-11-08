import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/review_history/data/review_history_service.dart';
import 'package:brand_governance/features/review_history/domain/review_analytics.dart';
import 'package:flutter/material.dart';

class ReviewAnalyticsScreen extends StatefulWidget {
  const ReviewAnalyticsScreen({
    super.key,
    required this.submissionStorage,
    required this.decisionStorage,
    required this.guidelinesStorage,
  });

  final ContentSubmissionStorage submissionStorage;
  final HumanReviewDecisionStorage decisionStorage;
  final GuidelinesStorage guidelinesStorage;

  @override
  State<ReviewAnalyticsScreen> createState() => _ReviewAnalyticsScreenState();
}

class _ReviewAnalyticsScreenState extends State<ReviewAnalyticsScreen> {
  late final ReviewHistoryService _service;
  ReviewAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;
  bool _hasGuidelines = false;

  @override
  void initState() {
    super.initState();
    _service = ReviewHistoryService(
      submissionStorage: widget.submissionStorage,
      decisionStorage: widget.decisionStorage,
      guidelinesStorage: widget.guidelinesStorage,
      engine: const BrandAnalysisEngine(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _service.loadEntries();
      final guidelines = await widget.guidelinesStorage.load();
      if (!mounted) return;
      final analytics = ReviewAnalytics.fromEntries(entries);
      setState(() {
        _hasGuidelines = guidelines.brandName.trim().isNotEmpty;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load analytics from local records: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _AnalyticsError(message: _error!, onRetry: _load)
                : _buildDashboard(context, _analytics!),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, ReviewAnalytics analytics) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      children: [
        Text(
          'Review analytics',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.deepIndigo,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A snapshot of activity from submissions and human decisions saved '
          'on this device.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.deepIndigo.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        _metricGrid(analytics),
        const SizedBox(height: 20),
        _ActivityCard(points: analytics.activity),
        const SizedBox(height: 16),
        _ViolationCard(analytics: analytics, hasGuidelines: _hasGuidelines),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.deepIndigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analysis metrics are recalculated from saved submissions '
                    'using the currently saved guidelines. Historical analysis '
                    'snapshots are not stored. Records remain local to this '
                    'device.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricGrid(ReviewAnalytics analytics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final cards = [
          _MetricCard(
            key: const Key('metric_total'),
            label: 'Total submissions',
            value: '${analytics.totalSubmissions}',
            icon: Icons.article_outlined,
            color: AppTheme.deepIndigo,
          ),
          _MetricCard(
            key: const Key('metric_approved'),
            label: 'Approved',
            value: '${analytics.approvedSubmissions}',
            icon: Icons.check_circle_outline,
            color: const Color(0xFF287A53),
          ),
          _MetricCard(
            key: const Key('metric_rejected'),
            label: 'Rejected',
            value: '${analytics.rejectedSubmissions}',
            icon: Icons.cancel_outlined,
            color: AppTheme.coral,
          ),
          _MetricCard(
            key: const Key('metric_changes'),
            label: 'Changes requested',
            value: '${analytics.changesRequested}',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFFB36A00),
          ),
          _MetricCard(
            key: const Key('metric_pending'),
            label: 'Pending reviews',
            value: '${analytics.pendingReviews}',
            icon: Icons.pending_actions_rounded,
            color: Colors.blueGrey,
          ),
          _MetricCard(
            key: const Key('metric_critical'),
            label: 'Critical findings',
            value: analytics.hasAnalysisData
                ? '${analytics.criticalFindings}'
                : 'N/A',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.coral,
            helper: analytics.hasAnalysisData
                ? 'High-severity finding instances'
                : 'Analysis unavailable',
          ),
          _MetricCard(
            key: const Key('metric_high'),
            label: 'High findings',
            value: analytics.hasAnalysisData
                ? '${analytics.highFindings}'
                : 'N/A',
            icon: Icons.priority_high_rounded,
            color: AppTheme.coral,
            helper: analytics.hasAnalysisData ? null : 'Analysis unavailable',
          ),
          _MetricCard(
            key: const Key('metric_medium'),
            label: 'Medium findings',
            value: analytics.hasAnalysisData
                ? '${analytics.mediumFindings}'
                : 'N/A',
            icon: Icons.error_outline_rounded,
            color: const Color(0xFFB36A00),
            helper: analytics.hasAnalysisData ? null : 'Analysis unavailable',
          ),
          _MetricCard(
            key: const Key('metric_low'),
            label: 'Low findings',
            value: analytics.hasAnalysisData
                ? '${analytics.lowFindings}'
                : 'N/A',
            icon: Icons.info_outline_rounded,
            color: AppTheme.deepIndigo,
            helper: analytics.hasAnalysisData ? null : 'Analysis unavailable',
          ),
        ];
        return GridView.count(
          key: const Key('analyticsMetricGrid'),
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1
              ? 2.4
              : constraints.maxWidth > 900
              ? 2.3
              : 1.8,
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? helper;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  key: Key('value_$label'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.deepIndigo,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helper != null)
                  Text(helper!, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.points});
  final List<ReviewActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
      0,
      (maximum, point) => point.total > maximum ? point.total : maximum,
    );
    return Card(
      key: const Key('reviewActivityCard'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review activity · last 7 days',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.deepIndigo,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 16,
              children: [
                _LegendDot(color: AppTheme.deepIndigo, label: 'Submissions'),
                _LegendDot(color: AppTheme.coral, label: 'Decisions'),
              ],
            ),
            const SizedBox(height: 18),
            if (maxValue == 0)
              const Text('No submission or decision activity in this period.')
            else
              SizedBox(
                height: 156,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points)
                      Expanded(
                        child: _ActivityBar(point: point, maxValue: maxValue),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.point, required this.maxValue});
  final ReviewActivityPoint point;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final totalHeight = (point.total / maxValue * 110).clamp(0.0, 110.0);
    final submissionHeight = point.total == 0
        ? 2.0
        : totalHeight * point.submissions / point.total;
    final decisionHeight = point.total == 0
        ? 0.0
        : totalHeight * point.decisions / point.total;
    return Tooltip(
      message: '${point.submissions} submissions, ${point.decisions} decisions',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${point.total}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 110,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 18,
                      height: decisionHeight,
                      decoration: const BoxDecoration(
                        color: AppTheme.coral,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 18,
                      height: submissionHeight,
                      color: AppTheme.deepIndigo,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _weekday(point.date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _ViolationCard extends StatelessWidget {
  const _ViolationCard({required this.analytics, required this.hasGuidelines});
  final ReviewAnalytics analytics;
  final bool hasGuidelines;

  @override
  Widget build(BuildContext context) {
    final unavailable = !analytics.hasAnalysisData;
    final violations = analytics.commonViolations.take(5).toList();
    return Card(
      key: const Key('commonViolationsCard'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Common detected violations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.deepIndigo,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unavailable
                  ? hasGuidelines
                        ? 'No analysis records are available.'
                        : 'Unavailable until a brand profile is saved.'
                  : violations.isEmpty
                  ? 'No prohibited phrase findings in the available analysis.'
                  : 'Occurrences are counted from current guideline checks.',
            ),
            if (violations.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final violation in violations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.report_gmailerrorred_outlined,
                    color: AppTheme.coral,
                  ),
                  title: Text(violation.text),
                  trailing: Text(
                    '${violation.count}',
                    key: Key('violationCount_${violation.text}'),
                    style: const TextStyle(
                      color: AppTheme.deepIndigo,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.coral, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _weekday(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[value.weekday - 1];
}
