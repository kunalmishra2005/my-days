import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/content_review/presentation/analysis_results_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/review_history/data/review_history_service.dart';
import 'package:brand_governance/features/review_history/domain/review_history_entry.dart';
import 'package:flutter/material.dart';

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({
    super.key,
    required this.submissionStorage,
    required this.decisionStorage,
    required this.guidelinesStorage,
  });

  final ContentSubmissionStorage submissionStorage;
  final HumanReviewDecisionStorage decisionStorage;
  final GuidelinesStorage guidelinesStorage;

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  final _searchController = TextEditingController();
  late final ReviewHistoryService _service;
  List<ReviewHistoryEntry> _entries = const [];
  ReviewDecision? _decisionFilter;
  AnalysisStatus? _statusFilter;
  ReviewHistorySort _sort = ReviewHistorySort.newestFirst;
  bool _isLoading = true;
  String? _error;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _service.loadEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load review history: $error';
        _isLoading = false;
      });
    }
  }

  List<ReviewHistoryEntry> get _visibleEntries => ReviewHistoryQuery(
    search: _searchController.text,
    decision: _decisionFilter,
    analysisStatus: _statusFilter,
    sort: _sort,
  ).apply(_entries);

  Future<void> _openSubmission(ContentSubmission submission) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisResultsScreen(
          submission: submission,
          guidelinesStorage: widget.guidelinesStorage,
          engine: const BrandAnalysisEngine(),
          reviewDecisionStorage: widget.decisionStorage,
          backLabel: 'Back to history',
        ),
      ),
    );
    if (mounted) await _load();
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
                ? _HistoryError(message: _error!, onRetry: _load)
                : _buildHistory(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _visibleEntries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      children: [
        Text(
          'Review history',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.deepIndigo,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find previous submissions, analysis, and human decisions.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.deepIndigo.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('historySearchField'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search by content title',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final filterFields = [
              _DecisionFilter(
                value: _decisionFilter,
                onChanged: (value) => setState(() => _decisionFilter = value),
              ),
              _StatusFilter(
                value: _statusFilter,
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              _SortFilter(
                value: _sort,
                onChanged: (value) => setState(() => _sort = value),
              ),
            ];
            if (constraints.maxWidth >= 700) {
              return Row(
                children: [
                  for (var index = 0; index < filterFields.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(child: filterFields[index]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (final field in filterFields) ...[
                  field,
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (_entries.isEmpty)
          const _HistoryEmpty(
            title: 'No submissions yet',
            message:
                'Content saved for review will appear here with its analysis '
                'and any human decision.',
          )
        else if (entries.isEmpty)
          const _HistoryEmpty(
            title: 'No matching reviews',
            message:
                'Try changing your search or clearing the selected filters.',
          )
        else ...[
          Text(
            '${entries.length} ${entries.length == 1 ? 'submission' : 'submissions'}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.deepIndigo.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            _HistoryEntryCard(
              entry: entry,
              onOpen: () => _openSubmission(entry.submission),
            ),
        ],
      ],
    );
  }
}

class _DecisionFilter extends StatelessWidget {
  const _DecisionFilter({required this.value, required this.onChanged});
  final ReviewDecision? value;
  final ValueChanged<ReviewDecision?> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<ReviewDecision?>(
        key: const Key('historyDecisionFilter'),
        isExpanded: true,
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Review decision'),
        items: [
          const DropdownMenuItem<ReviewDecision?>(
            value: null,
            child: Text('All decisions'),
          ),
          for (final decision in ReviewDecision.values)
            DropdownMenuItem<ReviewDecision?>(
              value: decision,
              child: Text(decision.label),
            ),
        ],
        onChanged: onChanged,
      );
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});
  final AnalysisStatus? value;
  final ValueChanged<AnalysisStatus?> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<AnalysisStatus?>(
        key: const Key('historyStatusFilter'),
        isExpanded: true,
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Analysis status'),
        items: [
          const DropdownMenuItem<AnalysisStatus?>(
            value: null,
            child: Text('All statuses'),
          ),
          for (final status in AnalysisStatus.values)
            DropdownMenuItem<AnalysisStatus?>(
              value: status,
              child: Text(status.label),
            ),
        ],
        onChanged: onChanged,
      );
}

class _SortFilter extends StatelessWidget {
  const _SortFilter({required this.value, required this.onChanged});
  final ReviewHistorySort value;
  final ValueChanged<ReviewHistorySort> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<ReviewHistorySort>(
        key: const Key('historySortFilter'),
        isExpanded: true,
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Sort by submission date'),
        items: const [
          DropdownMenuItem(
            value: ReviewHistorySort.newestFirst,
            child: Text('Newest first'),
          ),
          DropdownMenuItem(
            value: ReviewHistorySort.oldestFirst,
            child: Text('Oldest first'),
          ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.onOpen});
  final ReviewHistoryEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final decision = entry.decision;
    final status = entry.analysisStatus;
    return Card(
      key: Key('history_${entry.submission.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.article_outlined, color: AppTheme.deepIndigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.submission.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.deepIndigo,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.submission.type.label} · Submitted '
                        '${_formatDate(entry.submission.createdAt)}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('openHistory_${entry.submission.id}'),
                  tooltip: 'Open review details',
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  label: 'Current analysis: ${status?.label ?? 'Unavailable'}',
                  color: status == AnalysisStatus.criticalIssues
                      ? AppTheme.coral
                      : AppTheme.deepIndigo,
                ),
                _InfoPill(
                  label: 'Decision: ${decision?.decision.label ?? 'Pending'}',
                  color: decision == null
                      ? Colors.blueGrey
                      : decision.decision == ReviewDecision.reject
                      ? AppTheme.coral
                      : AppTheme.deepIndigo,
                ),
              ],
            ),
            if (decision != null) ...[
              const SizedBox(height: 10),
              Text(
                'Reviewer: ${decision.reviewerName} · Decided '
                '${_formatDate(decision.decidedAt)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Analysis status at decision: '
                '${decision.analysisStatus.label}',
              ),
              if (decision.reason.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Reason: ${decision.reason}'),
              ],
              if (decision.comments.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Comments: ${decision.comments}'),
              ],
            ],
            if (status == null) ...[
              const SizedBox(height: 8),
              Text(
                'Analysis is unavailable because no saved brand profile is '
                'available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 38,
            color: AppTheme.deepIndigo,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepIndigo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});
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

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = value.toLocal();
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
