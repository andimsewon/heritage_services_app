import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';
import '../../theme.dart';
import '../components/section_card.dart';
import '../components/section_button.dart';

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
  late final TextEditingController _structuralController;
  late final TextEditingController _othersController;
  late final TextEditingController _notesController;
  late final TextEditingController _opinionController;
  late final TextEditingController _dateController;
  late final TextEditingController _organizationController;
  late final TextEditingController _authorController;

  @override
  void initState() {
    super.initState();
    _structuralController = TextEditingController(text: widget.value.structural)
      ..addListener(_handleFieldChanged);
    _othersController = TextEditingController(text: widget.value.others)
      ..addListener(_handleFieldChanged);
    _notesController = TextEditingController(text: widget.value.notes)
      ..addListener(_handleFieldChanged);
    _opinionController = TextEditingController(text: widget.value.opinion)
      ..addListener(_handleFieldChanged);
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
    _syncController(_structuralController, widget.value.structural);
    _syncController(_othersController, widget.value.others);
    _syncController(_notesController, widget.value.notes);
    _syncController(_opinionController, widget.value.opinion);
    _syncController(_dateController, widget.value.date ?? '');
    _syncController(_organizationController, widget.value.organization ?? '');
    _syncController(_authorController, widget.value.author ?? '');
  }

  @override
  void dispose() {
    _structuralController.dispose();
    _othersController.dispose();
    _notesController.dispose();
    _opinionController.dispose();
    _dateController.dispose();
    _organizationController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '조사자 의견',
      action: SectionButton.filled(
        label: '저장',
        onPressed: () {
          // TODO: Hook up persistence to repository implementation.
        },
        icon: Icons.save_outlined,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          final content = [
            Expanded(
              flex: 3,
              child: _TotalOpinionSection(
                structuralController: _structuralController,
                othersController: _othersController,
                notesController: _notesController,
                opinionController: _opinionController,
              ),
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
              _TotalOpinionSection(
                structuralController: _structuralController,
                othersController: _othersController,
                notesController: _notesController,
                opinionController: _opinionController,
              ),
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
    );
  }

  void _handleFieldChanged() {
    widget.onChanged(
      widget.value.copyWith(
        structural: _structuralController.text,
        others: _othersController.text,
        notes: _notesController.text,
        opinion: _opinionController.text,
      ),
    );
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

class _TotalOpinionSection extends StatelessWidget {
  const _TotalOpinionSection({
    required this.structuralController,
    required this.othersController,
    required this.notesController,
    required this.opinionController,
  });

  final TextEditingController structuralController;
  final TextEditingController othersController;
  final TextEditingController notesController;
  final TextEditingController opinionController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          label: '구조부',
          hint: '예: 균열, 변형 등의 구조적 손상 평가',
          controller: structuralController,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildField(
          label: '기타부',
          hint: '예: 비구조적 손상, 오염, 마감재 상태 등',
          controller: othersController,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildField(
          label: '특기사항',
          hint: '예: 긴급 보수 필요 부위, 비고 사항 등',
          controller: notesController,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildField(
          label: '조사자 종합의견',
          hint: '전체 평가 및 개선 제안',
          controller: opinionController,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines - 1 : 1,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
          ),
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
