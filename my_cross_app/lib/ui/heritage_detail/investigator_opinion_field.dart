import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';
import '../../theme.dart';
import '../widgets/section_title.dart';

class InvestigatorOpinionField extends StatefulWidget {
  const InvestigatorOpinionField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final InvestigatorOpinion value;
  final ValueChanged<InvestigatorOpinion> onChanged;

  @override
  State<InvestigatorOpinionField> createState() =>
      _InvestigatorOpinionFieldState();
}

class _InvestigatorOpinionFieldState extends State<InvestigatorOpinionField> {
  late final TextEditingController _opinionController;
  late final TextEditingController _dateController;
  late final TextEditingController _organizationController;
  late final TextEditingController _authorController;

  @override
  void initState() {
    super.initState();
    _opinionController = TextEditingController(text: widget.value.opinion)
      ..addListener(_handleOpinionChanged);
    _dateController = TextEditingController(text: widget.value.date ?? '')
      ..addListener(_handleMetaChanged);
    _organizationController = TextEditingController(
      text: widget.value.organization ?? '',
    )..addListener(_handleMetaChanged);
    _authorController = TextEditingController(text: widget.value.author ?? '')
      ..addListener(_handleMetaChanged);
  }

  @override
  void didUpdateWidget(covariant InvestigatorOpinionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_opinionController, widget.value.opinion);
    _syncController(_dateController, widget.value.date ?? '');
    _syncController(_organizationController, widget.value.organization ?? '');
    _syncController(_authorController, widget.value.author ?? '');
  }

  @override
  void dispose() {
    _opinionController.dispose();
    _dateController.dispose();
    _organizationController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: '조사자 의견',
              trailing: FilledButton.icon(
                onPressed: () {
                  // TODO: Hook up persistence to repository implementation.
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('저장'),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;
                final content = [
                  Expanded(
                    flex: 3,
                    child: _OpinionEditor(controller: _opinionController),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _MetaPanel(
                      dateController: _dateController,
                      organizationController: _organizationController,
                      authorController: _authorController,
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: content,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OpinionEditor(controller: _opinionController),
                    const SizedBox(height: 16),
                    _MetaPanel(
                      dateController: _dateController,
                      organizationController: _organizationController,
                      authorController: _authorController,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleOpinionChanged() {
    widget.onChanged(widget.value.copyWith(opinion: _opinionController.text));
  }

  void _handleMetaChanged() {
    widget.onChanged(
      widget.value.copyWith(
        date: _dateController.text.isEmpty ? null : _dateController.text,
        organization: _organizationController.text.isEmpty
            ? null
            : _organizationController.text,
        author: _authorController.text.isEmpty ? null : _authorController.text,
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      final selection = controller.selection;
      controller.text = value;
      controller.selection = selection;
    }
  }
}

class _OpinionEditor extends StatelessWidget {
  const _OpinionEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          maxLines: 10,
          minLines: 6,
          decoration: const InputDecoration(
            labelText: '조사자 종합 의견',
            hintText: '조사 내용을 정리해 주세요.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '조사 결과와 권고 사항을 서술해 주세요.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({
    required this.dateController,
    required this.organizationController,
    required this.authorController,
  });

  final TextEditingController dateController;
  final TextEditingController organizationController;
  final TextEditingController authorController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '메타 정보',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: dateController,
            decoration: const InputDecoration(
              labelText: '조사 일자',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: organizationController,
            decoration: const InputDecoration(
              labelText: '조사 기관',
              hintText: '기관명',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: authorController,
            decoration: const InputDecoration(
              labelText: '조사자',
              hintText: '성명',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
