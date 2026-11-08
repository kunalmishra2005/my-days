import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_models.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_provider.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_service.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_result.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/human_review_decision.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter/material.dart';

class AnalysisResultsScreen extends StatefulWidget {
  const AnalysisResultsScreen({
    super.key,
    required this.submission,
    required this.guidelinesStorage,
    required this.engine,
    this.reviewDecisionStorage =
        const SharedPreferencesHumanReviewDecisionStorage(),
    this.backLabel = 'Back to submissions',
    this.aiReviewProvider = const AdaptionLabsReviewProvider(),
  });

  final ContentSubmission submission;
  final GuidelinesStorage guidelinesStorage;
  final BrandAnalysisEngine engine;
  final HumanReviewDecisionStorage reviewDecisionStorage;
  final String backLabel;
  final AiReviewProvider aiReviewProvider;

  @override
  State<AnalysisResultsScreen> createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> {
  final _reviewFormKey = GlobalKey<FormState>();
  final _reviewerNameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _commentsController = TextEditingController();
  bool _isLoading = true;
  bool _isSavingDecision = false;
  bool _missingGuidelines = false;
  String? _errorMessage;
  String? _decisionLoadError;
  BrandAnalysisResult? _result;
  HumanReviewDecision? _savedDecision;
  BrandGuidelines? _guidelines;
  AiReviewOutcome? _aiOutcome;
  String? _aiError;
  bool _isAiReviewing = false;
  ReviewDecision _selectedDecision = ReviewDecision.approve;

  @override
  void dispose() {
    _reviewerNameController.dispose();
    _reasonController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _isLoading = true;
      _missingGuidelines = false;
      _errorMessage = null;
      _decisionLoadError = null;
      _result = null;
      _aiOutcome = null;
      _aiError = null;
    });

    try {
      final guidelines = await widget.guidelinesStorage.load();
      if (!mounted) return;
      if (guidelines.brandName.trim().isEmpty) {
        setState(() {
          _missingGuidelines = true;
          _isLoading = false;
        });
        return;
      }

      final result = widget.engine.analyze(
        submission: widget.submission,
        guidelines: guidelines,
      );
      if (!mounted) return;
      setState(() {
        _guidelines = guidelines;
        _result = result;
        _isLoading = false;
      });
      await _loadSavedDecision();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not analyze this submission: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedDecision() async {
    try {
      final decision = await widget.reviewDecisionStorage.loadForSubmission(
        widget.submission.id,
      );
      if (!mounted) return;
      setState(() {
        _savedDecision = decision;
        if (decision != null) {
          _selectedDecision = decision.decision;
          _reviewerNameController.text = decision.reviewerName;
          _reasonController.text = decision.reason;
          _commentsController.text = decision.comments;
        }
        _decisionLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _decisionLoadError = 'Could not load the saved human decision: $error';
      });
    }
  }

  Future<void> _saveDecision() async {
    if (!_reviewFormKey.currentState!.validate()) return;
    final result = _result;
    if (result == null) return;

    final decision = HumanReviewDecision(
      submissionId: widget.submission.id,
      decision: _selectedDecision,
      reviewerName: _reviewerNameController.text.trim(),
      comments: _commentsController.text.trim(),
      reason: _reasonController.text.trim(),
      decidedAt: DateTime.now().toUtc(),
      analysisStatus: result.status,
    );

    setState(() => _isSavingDecision = true);
    try {
      await widget.reviewDecisionStorage.save(decision);
      if (!mounted) return;
      setState(() {
        _savedDecision = decision;
        _isSavingDecision = false;
        _decisionLoadError = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${decision.decision.label} decision saved.')),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingDecision = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save review decision: $error')),
        );
    }
  }

  Future<void> _runAiReview() async {
    final guidelines = _guidelines;
    if (guidelines == null || !widget.aiReviewProvider.isConfigured) return;
    setState(() {
      _isAiReviewing = true;
      _aiError = null;
      _aiOutcome = null;
    });
    try {
      final outcome = await AiReviewService(provider: widget.aiReviewProvider)
          .review(
            AiReviewRequest(
              submission: widget.submission,
              guidelines: guidelines,
            ),
          );
      if (!mounted) return;
      setState(() {
        _aiOutcome = outcome;
        _isAiReviewing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI review could not be completed: $error';
        _isAiReviewing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: widget.backLabel,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Analysis results'),
        backgroundColor: AppTheme.softWhite,
        foregroundColor: AppTheme.deepIndigo,
        actions: [
          IconButton(
            key: const Key('refreshAnalysisButton'),
            tooltip: 'Refresh analysis with saved guidelines',
            onPressed: _isLoading ? null : _analyze,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking your saved brand guidelines…'),
                  ],
                ),
              )
            : _missingGuidelines
            ? _MessageState(
                icon: Icons.menu_book_outlined,
                title: 'Brand guidelines needed',
                message:
                    'Save a brand profile before analyzing content. '
                    'Your submission is still saved and unchanged.',
                actionLabel: 'Back to submissions',
                onAction: () => Navigator.of(context).maybePop(),
              )
            : _errorMessage != null
            ? _MessageState(
                icon: Icons.error_outline_rounded,
                title: 'Analysis could not be completed',
                message: _errorMessage!,
                actionLabel: 'Try again',
                onAction: _analyze,
              )
            : _buildResults(context, _result!),
      ),
    );
  }

  Widget _buildResults(BuildContext context, BrandAnalysisResult result) {
    final theme = Theme.of(context);
    final statusColor = switch (result.status) {
      AnalysisStatus.passed => const Color(0xFF287A53),
      AnalysisStatus.needsReview => AppTheme.deepIndigo,
      AnalysisStatus.criticalIssues => AppTheme.coral,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            Text(
              widget.submission.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.deepIndigo,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.submission.type.label} · Submitted content analyzed '
              'against saved brand guidelines.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.deepIndigo.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 20),
            _StatusCard(
              status: result.status,
              color: statusColor,
              totalIssues: result.issues.length,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 3 : 2;
                final counts = result.severityCounts;
                final cards = [
                  _CountCard(
                    label: 'Total issues',
                    count: result.issues.length,
                    color: AppTheme.deepIndigo,
                    key: const Key('severityCount_total'),
                  ),
                  _CountCard(
                    label: 'Critical',
                    count: counts[AnalysisSeverity.critical]!,
                    color: AppTheme.coral,
                    key: const Key('severityCount_critical'),
                  ),
                  _CountCard(
                    label: 'High',
                    count: counts[AnalysisSeverity.high]!,
                    color: const Color(0xFFB36A00),
                    key: const Key('severityCount_high'),
                  ),
                  _CountCard(
                    label: 'Medium',
                    count: counts[AnalysisSeverity.medium]!,
                    color: const Color(0xFF8A5A00),
                    key: const Key('severityCount_medium'),
                  ),
                  _CountCard(
                    label: 'Low',
                    count: counts[AnalysisSeverity.low]!,
                    color: AppTheme.deepIndigo.withValues(alpha: 0.7),
                    key: const Key('severityCount_low'),
                  ),
                  _CountCard(
                    label: 'Informational',
                    count: counts[AnalysisSeverity.informational]!,
                    color: Colors.blueGrey,
                    key: const Key('severityCount_informational'),
                  ),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth >= 700 ? 2.2 : 1.7,
                  children: cards,
                );
              },
            ),
            const SizedBox(height: 24),
            if (result.actionableIssues.isEmpty) const _CleanContentState(),
            if (result.issues.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                result.actionableIssues.isEmpty
                    ? 'Informational notes'
                    : 'Findings',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final issue in result.issues) _FindingCard(issue: issue),
            ],
            if (result.positiveChecks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _TextListCard(
                title: 'Positive checks',
                icon: Icons.check_circle_outline_rounded,
                items: result.positiveChecks,
              ),
            ],
            if (result.limitations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LimitationsCard(items: result.limitations),
            ],
            const SizedBox(height: 20),
            _AiReviewCard(
              provider: widget.aiReviewProvider,
              outcome: _aiOutcome,
              error: _aiError,
              isLoading: _isAiReviewing,
              onRun: _runAiReview,
            ),
            const SizedBox(height: 24),
            _buildHumanReviewCard(context, result),
          ],
        ),
      ),
    );
  }

  Widget _buildHumanReviewCard(
    BuildContext context,
    BrandAnalysisResult result,
  ) {
    final theme = Theme.of(context);
    final savedDecision = _savedDecision;

    return Card(
      key: const Key('humanReviewCard'),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _reviewFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppTheme.deepIndigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Human review',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.deepIndigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Review the findings above, then record a human decision. '
                'This local demo does not publish content.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              if (_decisionLoadError != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _decisionLoadError!),
                TextButton(
                  onPressed: _loadSavedDecision,
                  child: const Text('Retry loading decision'),
                ),
              ],
              if (savedDecision != null) ...[
                const SizedBox(height: 16),
                _SavedDecisionCard(decision: savedDecision),
              ],
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('reviewerNameField'),
                controller: _reviewerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Reviewer name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the reviewer name.'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Decision',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReviewDecision.values.map((decision) {
                  return ChoiceChip(
                    key: Key('reviewDecision_${decision.name}'),
                    label: Text(decision.label),
                    selected: _selectedDecision == decision,
                    onSelected: _isSavingDecision
                        ? null
                        : (_) => setState(() => _selectedDecision = decision),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('reviewReasonField'),
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason for this decision',
                  hintText: 'Explain why you chose this decision.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a reason for the decision.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('reviewCommentsField'),
                controller: _commentsController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Comments or feedback (optional)',
                  hintText: 'Share actionable feedback with the creator.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('saveReviewDecisionButton'),
                onPressed: _isSavingDecision ? null : _saveDecision,
                icon: _isSavingDecision
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSavingDecision ? 'Saving…' : 'Save human decision',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Saved decision is linked to analysis status: ${result.status.label}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.deepIndigo.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiReviewCard extends StatelessWidget {
  const _AiReviewCard({
    required this.provider,
    required this.outcome,
    required this.error,
    required this.isLoading,
    required this.onRun,
  });

  final AiReviewProvider provider;
  final AiReviewOutcome? outcome;
  final String? error;
  final bool isLoading;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = provider.isConfigured;
    return Card(
      key: const Key('aiReviewCard'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppTheme.coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Contextual AI review',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.deepIndigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SeverityBadge(
                  label: provider.statusLabel,
                  color: configured ? AppTheme.deepIndigo : Colors.blueGrey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              !configured
                  ? 'No AI backend or credentials are configured. Deterministic '
                        'checks above remain available; no external request is made.'
                  : provider.statusLabel == 'SIMULATED'
                  ? 'Provider: ${provider.displayName}. This uses only a '
                        'caller-supplied fixture and makes no network request.'
                  : 'Provider: ${provider.displayName}. A host-injected backend '
                        'adapter is present, but connection and credentials are '
                        'not verified by this app. Running review sends the '
                        'draft and guideline data to that adapter.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: error!),
            ],
            if (configured)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: FilledButton.tonalIcon(
                  key: const Key('runAiReviewButton'),
                  onPressed: isLoading ? null : onRun,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    isLoading ? 'Reviewing…' : 'Run contextual review',
                  ),
                ),
              ),
            if (outcome != null) ...[
              const Divider(height: 28),
              Text(
                '${outcome!.response.findings.length} AI finding'
                '${outcome!.response.findings.length == 1 ? '' : 's'} · '
                '${outcome!.providerName} · ${outcome!.providerStatus}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (outcome!.response.findings.isEmpty)
                const Text(
                  'The configured provider returned no findings. Human review '
                  'is still required.',
                )
              else
                for (final finding in outcome!.response.findings)
                  _AiFinding(finding: finding),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiFinding extends StatelessWidget {
  const _AiFinding({required this.finding});

  final AiReviewFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = switch (finding.severity) {
      AnalysisSeverity.critical => const Color(0xFFB42318),
      AnalysisSeverity.high => AppTheme.coral,
      AnalysisSeverity.medium => const Color(0xFFB36A00),
      AnalysisSeverity.low => AppTheme.deepIndigo,
      AnalysisSeverity.informational => Colors.blueGrey,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.deepIndigo.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      finding.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.deepIndigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _SeverityBadge(
                    label: finding.severity.label.toUpperCase(),
                    color: color,
                  ),
                ],
              ),
              if (finding.matchedText.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  finding.matchedText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 8),
              Text(finding.explanation),
              const SizedBox(height: 8),
              Text(
                'Guideline: ${finding.relatedGuideline}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (finding.suggestedCorrection != null) ...[
                const SizedBox(height: 8),
                Text('Suggestion: ${finding.suggestedCorrection}'),
              ],
              const SizedBox(height: 8),
              const Text(
                'AI output is advisory and must be verified by a human reviewer.',
                style: TextStyle(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.color,
    required this.totalIssues,
  });

  final AnalysisStatus status;
  final Color color;
  final int totalIssues;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              status == AnalysisStatus.passed
                  ? Icons.check_circle_rounded
                  : Icons.rule_rounded,
              color: color,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    key: const Key('analysisStatus'),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$totalIssues ${totalIssues == 1 ? 'issue' : 'issues'} found',
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            Text(label, style: const TextStyle(color: AppTheme.deepIndigo)),
          ],
        ),
      ),
    );
  }
}

class _CleanContentState extends StatelessWidget {
  const _CleanContentState();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEAF5EF),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF287A53)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No configured prohibited phrases were detected. '
                'This deterministic check is limited to the guidelines '
                'provided; it does not establish that all facts are true or '
                'that the content is fully compliant.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.deepIndigo, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.issue});

  final BrandAnalysisIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = switch (issue.severity) {
      AnalysisSeverity.critical => const Color(0xFFB42318),
      AnalysisSeverity.high => AppTheme.coral,
      AnalysisSeverity.medium => const Color(0xFFB36A00),
      AnalysisSeverity.low => AppTheme.deepIndigo.withValues(alpha: 0.72),
      AnalysisSeverity.informational => Colors.blueGrey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  issue.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.deepIndigo,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _SeverityBadge(
                  label: issue.severity.label.toUpperCase(),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (issue.matchedText.isNotEmpty) ...[
              _DetailLabel(label: 'Matched text'),
              const SizedBox(height: 4),
              SelectableText(
                issue.matchedText,
                style: const TextStyle(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (issue.startOffset != null && issue.endOffset != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Character positions ${issue.startOffset! + 1}–'
                    '${issue.endOffset}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
            ],
            _DetailLabel(label: 'Why this was flagged'),
            const SizedBox(height: 4),
            Text(issue.explanation),
            const SizedBox(height: 12),
            _DetailLabel(label: 'Related guideline'),
            const SizedBox(height: 4),
            Text(issue.relatedGuideline),
            if (issue.suggestedCorrection case final correction?) ...[
              const SizedBox(height: 12),
              _DetailLabel(label: 'Suggested correction'),
              const SizedBox(height: 4),
              Text(correction),
            ],
            if (issue.requiresHumanVerification) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_search_outlined,
                    size: 18,
                    color: AppTheme.deepIndigo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Human verification required',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.deepIndigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: AppTheme.deepIndigo, fontWeight: FontWeight.w700),
    );
  }
}

class _TextListCard extends StatelessWidget {
  const _TextListCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.deepIndigo),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.deepIndigo,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LimitationsCard extends StatelessWidget {
  const _LimitationsCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.deepIndigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis limitations',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.deepIndigo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppTheme.deepIndigo,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppTheme.coral, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.deepIndigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedDecisionCard extends StatelessWidget {
  const _SavedDecisionCard({required this.decision});

  final HumanReviewDecision decision;

  @override
  Widget build(BuildContext context) {
    final color = switch (decision.decision) {
      ReviewDecision.approve => const Color(0xFF287A53),
      ReviewDecision.requestChanges => const Color(0xFFB36A00),
      ReviewDecision.reject => AppTheme.coral,
    };

    return Container(
      key: const Key('savedReviewDecision'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Saved decision: ${decision.decision.label}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              Text(
                'by ${decision.reviewerName} · ${decision.analysisStatus.label}',
                style: const TextStyle(color: AppTheme.deepIndigo),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: ${decision.reason}',
            style: const TextStyle(color: AppTheme.deepIndigo),
          ),
          if (decision.comments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Feedback: ${decision.comments}',
              style: const TextStyle(color: AppTheme.deepIndigo),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Saved ${_formatDecisionDate(decision.decidedAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppTheme.deepIndigo.withValues(alpha: 0.66)),
          ),
        ],
      ),
    );
  }

  static String _formatDecisionDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: AppTheme.deepIndigo)),
    );
  }
}
