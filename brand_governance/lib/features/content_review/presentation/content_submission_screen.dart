import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/content_review/ai/ai_review_provider.dart';
import 'package:brand_governance/features/content_review/data/content_submission_storage.dart';
import 'package:brand_governance/features/content_review/data/human_review_decision_storage.dart';
import 'package:brand_governance/features/content_review/domain/brand_analysis_engine.dart';
import 'package:brand_governance/features/content_review/domain/content_submission.dart';
import 'package:brand_governance/features/content_review/presentation/analysis_results_screen.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContentSubmissionScreen extends StatefulWidget {
  const ContentSubmissionScreen({
    super.key,
    required this.submissionStorage,
    required this.guidelinesStorage,
    required this.onOpenGuidelines,
    this.reviewDecisionStorage =
        const SharedPreferencesHumanReviewDecisionStorage(),
    this.aiReviewProvider = const AdaptionLabsReviewProvider(),
  });

  final ContentSubmissionStorage submissionStorage;
  final GuidelinesStorage guidelinesStorage;
  final VoidCallback onOpenGuidelines;
  final HumanReviewDecisionStorage reviewDecisionStorage;
  final AiReviewProvider aiReviewProvider;

  @override
  State<ContentSubmissionScreen> createState() =>
      _ContentSubmissionScreenState();
}

class _ContentSubmissionScreenState extends State<ContentSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  ContentType _contentType = ContentType.socialMedia;
  List<ContentSubmission> _submissions = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasBrandProfile = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final guidelinesFuture = widget.guidelinesStorage.load();
      final submissionsFuture = widget.submissionStorage.loadAll();
      final guidelines = await guidelinesFuture;
      final submissions = await submissionsFuture;
      if (!mounted) return;
      setState(() {
        _hasBrandProfile = guidelines.brandName.trim().isNotEmpty;
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load local data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final submission = ContentSubmission.create(
      title: _titleController.text,
      type: _contentType,
      body: _bodyController.text,
    );

    setState(() => _isSaving = true);
    try {
      await widget.submissionStorage.save(submission);
      if (!mounted) return;
      setState(() {
        _submissions = [submission, ..._submissions];
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content saved for review.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save submission: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _LoadErrorView(message: _loadError!, onRetry: _loadData)
            : _buildScreen(context),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PageHeader(),
                    const SizedBox(height: 32),
                    Text(
                      'Give your next idea a thoughtful review.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.deepIndigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share a draft before it goes out. Your original text '
                      'will be kept exactly as submitted.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.deepIndigo.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_hasBrandProfile) ...[
                      _BrandProfileNotice(
                        onOpenGuidelines: widget.onOpenGuidelines,
                      ),
                      const SizedBox(height: 20),
                    ],
                    const _DemoStorageNotice(),
                    const SizedBox(height: 24),
                    _SubmissionForm(
                      formKey: _formKey,
                      titleController: _titleController,
                      bodyController: _bodyController,
                      contentType: _contentType,
                      isSaving: _isSaving,
                      onTypeChanged: (type) =>
                          setState(() => _contentType = type),
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 32),
                    _SubmissionList(
                      submissions: _submissions,
                      onAnalyze: _openAnalysis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAnalysis(ContentSubmission submission) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisResultsScreen(
          submission: submission,
          guidelinesStorage: widget.guidelinesStorage,
          engine: const BrandAnalysisEngine(),
          reviewDecisionStorage: widget.reviewDecisionStorage,
          aiReviewProvider: widget.aiReviewProvider,
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.deepIndigo,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.softWhite,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MY DAY'S",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.deepIndigo,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'BRAND WORKSPACE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.deepIndigo.withValues(alpha: 0.58),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandProfileNotice extends StatelessWidget {
  const _BrandProfileNotice({required this.onOpenGuidelines});

  final VoidCallback onOpenGuidelines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.coral.withValues(alpha: 0.28)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.deepIndigo),
          const SizedBox(
            width: 440,
            child: Text(
              'No brand profile yet. You can still save a draft, but add your '
              'brand guidelines for a more useful review workflow.',
            ),
          ),
          TextButton(
            onPressed: onOpenGuidelines,
            child: const Text('Set up brand guidelines'),
          ),
        ],
      ),
    );
  }
}

class _DemoStorageNotice extends StatelessWidget {
  const _DemoStorageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.deepIndigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.phonelink_lock_outlined, color: AppTheme.deepIndigo),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Local demo storage · Drafts stay on this device. '
              'No AI analysis or publishing is performed.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionForm extends StatelessWidget {
  const _SubmissionForm({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.contentType,
    required this.isSaving,
    required this.onTypeChanged,
    required this.onSubmit,
  });

  static const titleLimit = 120;
  static const bodyLimit = 5000;

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final ContentType contentType;
  final bool isSaving;
  final ValueChanged<ContentType> onTypeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.deepIndigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your content',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.deepIndigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleField = TextFormField(
                    key: const Key('submissionTitleField'),
                    controller: titleController,
                    maxLength: titleLimit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Content title',
                      hintText: 'Give this draft a clear name',
                      prefixIcon: Icon(Icons.title_rounded),
                      counterText: '',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a content title.'
                        : null,
                  );
                  final typeField = DropdownButtonFormField<ContentType>(
                    key: const Key('submissionTypeField'),
                    initialValue: contentType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Content type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: ContentType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onTypeChanged(value);
                    },
                  );

                  if (constraints.maxWidth < 640) {
                    return Column(
                      children: [
                        titleField,
                        const SizedBox(height: 16),
                        typeField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleField),
                      const SizedBox(width: 16),
                      Expanded(child: typeField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('submissionBodyField'),
                controller: bodyController,
                minLines: 8,
                maxLines: 14,
                maxLength: bodyLimit,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Content body',
                  hintText: 'Write or paste the content you want reviewed…',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the content you want to submit.'
                    : null,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: bodyController,
                builder: (context, value, _) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${value.text.length} / $bodyLimit characters',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.deepIndigo.withValues(alpha: 0.65),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('submitContentButton'),
                    onPressed: isSaving ? null : onSubmit,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(isSaving ? 'Saving…' : 'Submit for review'),
                  ),
                  Text(
                    'Your original content will not be edited.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.deepIndigo.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionList extends StatelessWidget {
  const _SubmissionList({required this.submissions, required this.onAnalyze});

  final List<ContentSubmission> submissions;
  final ValueChanged<ContentSubmission> onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submitted drafts',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.deepIndigo,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (submissions.isEmpty)
          Card(
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  'Your saved submissions will appear here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.deepIndigo.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          )
        else
          for (final submission in submissions)
            Card(
              key: Key('submission_${submission.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x142A1E5C),
                  foregroundColor: AppTheme.deepIndigo,
                  child: Icon(Icons.description_outlined),
                ),
                title: Text(
                  submission.title,
                  style: const TextStyle(
                    color: AppTheme.deepIndigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${submission.type.label} · ${_formatDate(submission.createdAt)}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      submission.body,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Saved locally · Original draft unchanged',
                          style: TextStyle(
                            color: AppTheme.deepIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: Key('analyze_${submission.id}'),
                          onPressed: () => onAnalyze(submission),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Analyze Content'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.coral, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
