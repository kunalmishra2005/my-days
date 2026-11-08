import 'package:brand_governance/app/theme/app_theme.dart';
import 'package:brand_governance/features/guidelines/data/guidelines_storage.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter/material.dart';

class BrandGuidelinesScreen extends StatefulWidget {
  const BrandGuidelinesScreen({super.key, required this.storage});

  final GuidelinesStorage storage;

  @override
  State<BrandGuidelinesScreen> createState() => _BrandGuidelinesScreenState();
}

class _BrandGuidelinesScreenState extends State<BrandGuidelinesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customToneController = TextEditingController();
  BrandGuidelines _guidelines = const BrandGuidelines();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadGuidelines();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _descriptionController.dispose();
    _customToneController.dispose();
    super.dispose();
  }

  Future<void> _loadGuidelines() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final saved = await widget.storage.load();
      if (!mounted) return;
      _guidelines = saved;
      _brandNameController.text = saved.brandName;
      _descriptionController.text = saved.description;
      _customToneController.text = saved.customTone;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load local guidelines: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGuidelines() async {
    final form = _formKey.currentState;
    if (form == null) {
      _showSaveMessage(
        'Could not validate brand guidelines. Please try again.',
      );
      return;
    }
    if (!form.validate()) {
      _showSaveMessage('Please fix the highlighted fields before saving.');
      return;
    }

    final guidelines = _guidelines.copyWith(
      brandName: _brandNameController.text.trim(),
      description: _descriptionController.text.trim(),
      customTone: _customToneController.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      await widget.storage.save(guidelines);
      if (!mounted) return;
      setState(() {
        _guidelines = guidelines;
        _isSaving = false;
      });
      _showSaveMessage('Brand guidelines saved on this device.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSaveMessage('Could not save local guidelines: $error');
    }
  }

  void _showSaveMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateList(String field, List<String> values) {
    setState(() {
      _guidelines = switch (field) {
        'approvedTerms' => _guidelines.copyWith(approvedTerms: values),
        'requiredTerms' => _guidelines.copyWith(requiredTerms: values),
        'prohibitedTerms' => _guidelines.copyWith(prohibitedTerms: values),
        'verifiedFacts' => _guidelines.copyWith(verifiedFacts: values),
        _ => _guidelines,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _LoadErrorView(message: _loadError!, onRetry: _loadGuidelines)
            : _buildEditor(context),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageHeader(onSave: _saveGuidelines, isSaving: _isSaving),
                      const SizedBox(height: 32),
                      Text(
                        'Build a voice that feels unmistakably yours.',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.deepIndigo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set the foundations your team can use to keep every '
                        'message on brand.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.deepIndigo.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _LocalStorageNotice(),
                      const SizedBox(height: 24),
                      _SectionCard(
                        step: '01',
                        title: 'Brand profile',
                        subtitle: 'Start with the essentials.',
                        icon: Icons.auto_awesome_outlined,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 640;
                            final nameField = TextFormField(
                              key: const Key('brandNameField'),
                              controller: _brandNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Brand name',
                                hintText: 'e.g. Northstar Studio',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a brand name to continue.'
                                  : null,
                            );
                            final descriptionField = TextFormField(
                              key: const Key('brandDescriptionField'),
                              controller: _descriptionController,
                              minLines: 1,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Brand description',
                                hintText:
                                    'What do you do, and who do you serve?',
                                prefixIcon: Icon(Icons.notes_outlined),
                                alignLabelWithHint: true,
                              ),
                            );
                            if (!wide) {
                              return Column(
                                children: [
                                  nameField,
                                  const SizedBox(height: 16),
                                  descriptionField,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: nameField),
                                const SizedBox(width: 16),
                                Expanded(child: descriptionField),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 760) {
                            return Column(
                              children: [
                                _buildToneSection(),
                                const SizedBox(height: 18),
                                _buildApprovedTermsSection(),
                                const SizedBox(height: 18),
                                _buildRequiredTermsSection(),
                                const SizedBox(height: 18),
                                _buildProhibitedTermsSection(),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildToneSection(),
                                    const SizedBox(height: 18),
                                    _buildApprovedTermsSection(),
                                    const SizedBox(height: 18),
                                    _buildRequiredTermsSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(child: _buildProhibitedTermsSection()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        step: '06',
                        title: 'Verified brand facts',
                        subtitle: 'Add factual statements your team can safely rely on.',
                        icon: Icons.verified_outlined,
                        child: _GuidelineListEditor(
                          key: const Key('verifiedFactsEditor'),
                          label: 'Verified fact',
                          hint: 'e.g. Founded in 2018 in Bengaluru',
                          addLabel: 'Add fact',
                          emptyLabel: 'No verified facts added yet.',
                          values: _guidelines.verifiedFacts,
                          multiline: true,
                          onChanged: (values) =>
                              _updateList('verifiedFacts', values),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const Key('saveGuidelinesButton'),
                          onPressed: _isSaving ? null : _saveGuidelines,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _isSaving ? 'Saving…' : 'Save guidelines',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToneSection() {
    return _SectionCard(
      step: '02',
      title: 'Tone and voice',
      subtitle: 'How should your brand sound?',
      icon: Icons.record_voice_over_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BrandTone.values.map((tone) {
              return ChoiceChip(
                key: Key('tone_${tone.name}'),
                label: Text(tone.label),
                selected: _guidelines.tone == tone,
                onSelected: (_) {
                  setState(() {
                    _guidelines = _guidelines.copyWith(tone: tone);
                  });
                },
              );
            }).toList(),
          ),
          if (_guidelines.tone == BrandTone.custom) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('customToneField'),
              controller: _customToneController,
              decoration: const InputDecoration(
                labelText: 'Describe your custom tone',
                hintText: 'e.g. Optimistic, curious, and down-to-earth',
              ),
              validator: (value) =>
                  _guidelines.tone == BrandTone.custom &&
                      (value == null || value.trim().isEmpty)
                  ? 'Describe your custom tone.'
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovedTermsSection() {
    return _SectionCard(
      step: '03',
      title: 'Approved terminology',
      subtitle: 'Words and phrases you prefer.',
      icon: Icons.add_circle_outline_rounded,
      child: _GuidelineListEditor(
        key: const Key('approvedTermsEditor'),
        label: 'Approved term',
        hint: 'e.g. members',
        addLabel: 'Add term',
        emptyLabel: 'No approved terms added yet.',
        values: _guidelines.approvedTerms,
        onChanged: (values) => _updateList('approvedTerms', values),
      ),
    );
  }

  Widget _buildProhibitedTermsSection() {
    return _SectionCard(
      step: '05',
      title: 'Prohibited words and phrases',
      subtitle: 'Language your brand avoids.',
      icon: Icons.block_outlined,
      child: _GuidelineListEditor(
        key: const Key('prohibitedTermsEditor'),
        label: 'Prohibited term',
        hint: 'e.g. guaranteed',
        addLabel: 'Add term',
        emptyLabel: 'No prohibited terms added yet.',
        values: _guidelines.prohibitedTerms,
        onChanged: (values) => _updateList('prohibitedTerms', values),
        accent: AppTheme.coral,
      ),
    );
  }

  Widget _buildRequiredTermsSection() {
    return _SectionCard(
      step: '04',
      title: 'Required brand terms',
      subtitle: 'Words or phrases every relevant message must include.',
      icon: Icons.rule_rounded,
      child: _GuidelineListEditor(
        key: const Key('requiredTermsEditor'),
        label: 'Required term',
        hint: 'e.g. Made for everyday creators',
        addLabel: 'Add required term',
        emptyLabel: 'No required terms added yet.',
        values: _guidelines.requiredTerms,
        onChanged: (values) => _updateList('requiredTerms', values),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onSave, required this.isSaving});

  final VoidCallback onSave;
  final bool isSaving;

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
        OutlinedButton.icon(
          key: const Key('headerSaveGuidelinesButton'),
          onPressed: isSaving ? null : onSave,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _LocalStorageNotice extends StatelessWidget {
  const _LocalStorageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.deepIndigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.deepIndigo.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phonelink_lock_outlined, color: AppTheme.deepIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.deepIndigo, height: 1.5),
                children: [
                  TextSpan(
                    text: 'Local demo storage\n',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.deepIndigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Guidelines are saved on this device only. This is not '
                        'multi-user cloud storage.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.deepIndigo.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppTheme.deepIndigo, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$step  $title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.deepIndigo,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.deepIndigo.withValues(alpha: 0.64),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _GuidelineListEditor extends StatefulWidget {
  const _GuidelineListEditor({
    super.key,
    required this.label,
    required this.hint,
    required this.addLabel,
    required this.emptyLabel,
    required this.values,
    required this.onChanged,
    this.multiline = false,
    this.accent = AppTheme.deepIndigo,
  });

  final String label;
  final String hint;
  final String addLabel;
  final String emptyLabel;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final bool multiline;
  final Color accent;

  @override
  State<_GuidelineListEditor> createState() => _GuidelineListEditorState();
}

class _GuidelineListEditorState extends State<_GuidelineListEditor> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addValue() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(
        () => _errorText = 'Enter a non-empty ${widget.label.toLowerCase()}.',
      );
      return;
    }
    if (widget.values.any(
      (existing) => existing.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() => _errorText = 'This entry has already been added.');
      return;
    }
    widget.onChanged([...widget.values, value]);
    _controller.clear();
    setState(() => _errorText = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: Key('input_${widget.label}'),
                controller: _controller,
                minLines: 1,
                maxLines: widget.multiline ? 3 : 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  errorText: _errorText,
                  alignLabelWithHint: widget.multiline,
                ),
                onSubmitted: (_) => _addValue(),
                textInputAction: widget.multiline
                    ? TextInputAction.newline
                    : TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                key: Key('add_${widget.label}'),
                tooltip: widget.addLabel,
                onPressed: _addValue,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.values.isEmpty)
          Text(
            widget.emptyLabel,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppTheme.deepIndigo.withValues(alpha: 0.55)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < widget.values.length; index++)
                InputChip(
                  key: Key('${widget.key}_item_$index'),
                  label: Text(widget.values[index]),
                  onDeleted: () {
                    final updated = [...widget.values]..removeAt(index);
                    widget.onChanged(updated);
                  },
                  deleteButtonTooltipMessage: 'Remove ${widget.values[index]}',
                  backgroundColor: widget.accent.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: AppTheme.deepIndigo,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
      ],
    );
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
