import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/heritage_detail_models.dart';
import '../../models/section_form_models.dart';
import '../../services/firebase_service.dart';
import '../section_form/section_data_list.dart';

class InspectionResultCard extends StatefulWidget {
  const InspectionResultCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.heritageId = '',
    this.heritageName = '',
  });

  final InspectionResult value;
  final ValueChanged<InspectionResult> onChanged;
  final String heritageId;
  final String heritageName;

  @override
  State<InspectionResultCard> createState() => _InspectionResultCardState();
}

class _InspectionResultCardState extends State<InspectionResultCard> {
  final _fb = FirebaseService();
  bool _isSaving = false;

  // 구조부 (Structural Part)
  late final TextEditingController _foundationController;
  late final TextEditingController _wallController;
  late final TextEditingController _roofController;
  
  // 기타부 (Other Parts)
  late final TextEditingController _coloringController;
  late final TextEditingController _pestDamageController;
  late final TextEditingController _otherController;
  
  // 추가 필드들
  late final TextEditingController _specialNotesController;
  late final TextEditingController _overallOpinionController;
  late final TextEditingController _gradeClassificationController;
  late final TextEditingController _investigationDateController;
  late final TextEditingController _investigatorController;

  @override
  void initState() {
    super.initState();
    _foundationController = TextEditingController(text: widget.value.foundation);
    _wallController = TextEditingController(text: widget.value.wall);
    _roofController = TextEditingController(text: widget.value.roof);
    _coloringController = TextEditingController();
    _pestDamageController = TextEditingController();
    _otherController = TextEditingController();
    
    // 추가 필드들
    _specialNotesController = TextEditingController();
    _overallOpinionController = TextEditingController();
    _gradeClassificationController = TextEditingController();
    _investigationDateController = TextEditingController();
    _investigatorController = TextEditingController();
    
    _foundationController.addListener(() => _handleChanged('foundation'));
    _wallController.addListener(() => _handleChanged('wall'));
    _roofController.addListener(() => _handleChanged('roof'));
  }

  @override
  void didUpdateWidget(covariant InspectionResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.foundation != widget.value.foundation) {
      _foundationController.text = widget.value.foundation;
    }
    if (oldWidget.value.wall != widget.value.wall) {
      _wallController.text = widget.value.wall;
    }
    if (oldWidget.value.roof != widget.value.roof) {
      _roofController.text = widget.value.roof;
    }
  }

  @override
  void dispose() {
    _foundationController.dispose();
    _wallController.dispose();
    _roofController.dispose();
    _coloringController.dispose();
    _pestDamageController.dispose();
    _otherController.dispose();
    
    // 추가 필드들
    _specialNotesController.dispose();
    _overallOpinionController.dispose();
    _gradeClassificationController.dispose();
    _investigationDateController.dispose();
    _investigatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '주요 점검 결과',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildInspectionTable(),
          const SizedBox(height: 20),
          
          // 저장 버튼
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Align(
                alignment: isMobile ? Alignment.center : Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveInspectionResult,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? '저장 중...' : '저장'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2A44),
                    minimumSize: isMobile
                        ? const Size(double.infinity, 44)
                        : const Size(120, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 저장된 데이터 리스트 표시
          if (widget.heritageId.isNotEmpty)
            SectionDataList(
              heritageId: widget.heritageId,
              sectionType: SectionType.inspection,
              sectionTitle: '주요 점검 결과',
            ),
        ],
      ),
    );
  }

  Widget _buildInspectionTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 테이블 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '분류',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '내용',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 구조부 섹션
          _buildTableSection('구조부', [
            _buildTableRow('기단부', _foundationController),
            _buildTableRow('축부(벽체부)', _wallController),
            _buildTableRow('지붕부', _roofController),
          ]),
          // 조사결과 기타부 섹션
          _buildTableSection('조사결과 기타부', [
            _buildTableRow('채색 (단청, 벽화)', _coloringController),
            _buildTableRow('충해', _pestDamageController),
            _buildTableRow('기타', _otherController),
          ]),
          // 특기사항
          _buildTableRow('특기사항', _specialNotesController),
          // 조사 종합의견
          _buildTableRow('조사 종합의견', _overallOpinionController),
          // 등급분류
          _buildTableRow('등급분류', _gradeClassificationController),
          // 조사일시
          _buildTableRow('조사일시', _investigationDateController),
          // 조사자
          _buildTableRow('조사자', _investigatorController),
        ],
      ),
    );
  }

  Widget _buildTableSection(String sectionTitle, List<Widget> rows) {
    return Column(
      children: [
        // 섹션 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            border: Border(
              top: BorderSide(color: Color(0xFFE5E7EB)),
              bottom: BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 섹션 내용
        ...rows,
      ],
    );
  }

  Widget _buildTableRow(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '내용을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
                fillColor: Colors.white,
                filled: true,
              ),
              maxLines: label == '특기사항' || label == '조사 종합의견' ? 4 : 2,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTextArea(String label, TextEditingController controller, {String hint = '조사 결과를 입력하세요'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E2A44)),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            fillColor: Colors.white,
            filled: true,
          ),
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
      ],
    );
  }


  Widget _dividerLine() {
    return Container(
      height: 1,
      color: const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  void _handleChanged(String key) {
    final updated = widget.value.copyWith(
      foundation: key == 'foundation'
          ? _foundationController.text
          : widget.value.foundation,
      wall: key == 'wall' ? _wallController.text : widget.value.wall,
      roof: key == 'roof' ? _roofController.text : widget.value.roof,
    );
    widget.onChanged(updated);
  }

  Future<void> _saveInspectionResult() async {
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
      // 모든 필드의 내용을 하나의 문서로 통합 저장
      final title = '주요 점검 결과 - ${DateTime.now().toString().substring(0, 16)}';
      final content = StringBuffer();
      
      // 구조부 섹션
      content.writeln('구조부:');
      if (_foundationController.text.trim().isNotEmpty) {
        content.writeln('  - 기단부: ${_foundationController.text.trim()}');
      }
      if (_wallController.text.trim().isNotEmpty) {
        content.writeln('  - 축부(벽체부): ${_wallController.text.trim()}');
      }
      if (_roofController.text.trim().isNotEmpty) {
        content.writeln('  - 지붕부: ${_roofController.text.trim()}');
      }
      
      // 조사결과 기타부 섹션
      content.writeln('\n조사결과 기타부:');
      if (_coloringController.text.trim().isNotEmpty) {
        content.writeln('  - 채색 (단청, 벽화): ${_coloringController.text.trim()}');
      }
      if (_pestDamageController.text.trim().isNotEmpty) {
        content.writeln('  - 충해: ${_pestDamageController.text.trim()}');
      }
      if (_otherController.text.trim().isNotEmpty) {
        content.writeln('  - 기타: ${_otherController.text.trim()}');
      }
      
      // 특기사항
      if (_specialNotesController.text.trim().isNotEmpty) {
        content.writeln('\n특기사항: ${_specialNotesController.text.trim()}');
      }
      
      // 조사 종합의견
      if (_overallOpinionController.text.trim().isNotEmpty) {
        content.writeln('\n조사 종합의견: ${_overallOpinionController.text.trim()}');
      }
      
      // 등급분류
      if (_gradeClassificationController.text.trim().isNotEmpty) {
        content.writeln('\n등급분류: ${_gradeClassificationController.text.trim()}');
      }
      
      // 조사일시
      if (_investigationDateController.text.trim().isNotEmpty) {
        content.writeln('\n조사일시: ${_investigationDateController.text.trim()}');
      }
      
      // 조사자
      if (_investigatorController.text.trim().isNotEmpty) {
        content.writeln('\n조사자: ${_investigatorController.text.trim()}');
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
        sectionType: SectionType.inspection,
        title: title,
        content: content.toString().trim(),
        createdAt: DateTime.now(),
        author: '현재 사용자',
      );

      await _fb.saveSectionForm(
        heritageId: widget.heritageId,
        sectionType: SectionType.inspection,
        formData: formData,
      );

      // 입력 필드 초기화
      _foundationController.clear();
      _wallController.clear();
      _roofController.clear();
      _coloringController.clear();
      _pestDamageController.clear();
      _otherController.clear();
      _specialNotesController.clear();
      _overallOpinionController.clear();
      _gradeClassificationController.clear();
      _investigationDateController.clear();
      _investigatorController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 주요 점검 결과가 저장되었습니다'),
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
}
