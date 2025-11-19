import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/ui/components/section_button.dart';
import 'package:my_cross_app/core/ui/components/section_card.dart';
import 'package:my_cross_app/core/ui/section_form/section_data_list.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';
import 'package:my_cross_app/models/section_form_models.dart';

class InvestigatorOpinionField extends StatefulWidget {
  const InvestigatorOpinionField({
    super.key,
    this.sectionNumber,
    required this.value,
    required this.onChanged,
    this.heritageId = '',
    this.heritageName = '',
  });

  final int? sectionNumber;
  final InvestigatorOpinion value;
  final ValueChanged<InvestigatorOpinion> onChanged;
  final String heritageId;
  final String heritageName;

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

  final _fb = FirebaseService();
  bool _isSaving = false;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          sectionNumber: widget.sectionNumber,
          title: '조사자 의견',
          sectionDescription: '조사자의 종합적인 의견을 기록합니다',
          action: SectionButton.filled(
            label: _isSaving ? '저장 중...' : '저장',
            onPressed: _isSaving ? () {} : () => _handleSave(),
            icon: Icons.save_outlined,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 제약 조건이 무한대인 경우 MediaQuery 사용
              final availableWidth = constraints.maxWidth.isFinite 
                  ? constraints.maxWidth 
                  : MediaQuery.of(context).size.width;
              final isWide = availableWidth >= 920;
              
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

              if (isWide && constraints.maxWidth.isFinite) {
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
        ),
        // 저장된 데이터 리스트 표시 추가
        if (widget.heritageId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SectionDataList(
              heritageId: widget.heritageId,
              sectionType: SectionType.opinion,
              sectionTitle: '조사자 의견',
            ),
          ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (widget.heritageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문화유산 정보가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 조사자 의견 데이터를 하나의 제목과 내용으로 결합
      final title = '조사자 의견 - ${DateTime.now().toString().substring(0, 16)}';
      final content = StringBuffer();
      
      if (_structuralController.text.trim().isNotEmpty) {
        content.writeln('구조부: ${_structuralController.text.trim()}');
      }
      if (_othersController.text.trim().isNotEmpty) {
        content.writeln('기타부: ${_othersController.text.trim()}');
      }
      if (_notesController.text.trim().isNotEmpty) {
        content.writeln('특기사항: ${_notesController.text.trim()}');
      }
      if (_opinionController.text.trim().isNotEmpty) {
        content.writeln('조사자 종합의견: ${_opinionController.text.trim()}');
      }
      
      content.writeln('');
      if (_dateController.text.trim().isNotEmpty) {
        content.writeln('조사일: ${_dateController.text.trim()}');
      }
      if (_organizationController.text.trim().isNotEmpty) {
        content.writeln('소속기관: ${_organizationController.text.trim()}');
      }
      if (_authorController.text.trim().isNotEmpty) {
        content.writeln('조사자: ${_authorController.text.trim()}');
      }

      if (content.toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('입력된 내용이 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final formData = SectionFormData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionType: SectionType.opinion,
        title: title,
        content: content.toString().trim(),
        createdAt: DateTime.now(),
        author: _authorController.text.trim().isNotEmpty 
            ? _authorController.text.trim() 
            : '현재 사용자',
      );

      await _fb.saveSectionForm(
        heritageId: widget.heritageId,
        sectionType: SectionType.opinion,
        formData: formData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 조사자 의견이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
