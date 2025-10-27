import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  // 1.2 보존 사항 컨트롤러들
  late final TextEditingController _foundationBaseController;
  late final TextEditingController _foundationBasePhotoController;
  late final TextEditingController _foundationCornerstonePhotoController;
  late final TextEditingController _shaftVerticalMembersController;
  late final TextEditingController _shaftVerticalMembersPhotoController;
  late final TextEditingController _shaftLintelTiebeamController;
  late final TextEditingController _shaftLintelTiebeamPhotoController;
  late final TextEditingController _shaftBracketSystemController;
  late final TextEditingController _shaftBracketSystemPhotoController;
  late final TextEditingController _shaftWallGomagiController;
  late final TextEditingController _shaftWallGomagiPhotoController;
  late final TextEditingController _shaftOndolFloorController;
  late final TextEditingController _shaftOndolFloorPhotoController;
  late final TextEditingController _shaftWindowsRailingsController;
  late final TextEditingController _shaftWindowsRailingsPhotoController;
  late final TextEditingController _roofFramingMembersController;
  late final TextEditingController _roofFramingMembersPhotoController;
  late final TextEditingController _roofRaftersPuyeonController;
  late final TextEditingController _roofRaftersPuyeonPhotoController;
  late final TextEditingController _roofRoofTilesController;
  late final TextEditingController _roofRoofTilesPhotoController;
  late final TextEditingController _roofCeilingDanjipController;
  late final TextEditingController _roofCeilingDanjipPhotoController;
  late final TextEditingController _otherSpecialNotesController;
  late final TextEditingController _otherSpecialNotesPhotoController;

  // 사진 관련 상태 변수들
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, Uint8List?> _preservationPhotos = {};
  Map<String, String?> _preservationPhotoUrls = {};

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

    // 1.2 보존 사항 컨트롤러들 초기화
    _foundationBaseController = TextEditingController();
    _foundationBasePhotoController = TextEditingController();
    _foundationCornerstonePhotoController = TextEditingController();
    _shaftVerticalMembersController = TextEditingController();
    _shaftVerticalMembersPhotoController = TextEditingController();
    _shaftLintelTiebeamController = TextEditingController();
    _shaftLintelTiebeamPhotoController = TextEditingController();
    _shaftBracketSystemController = TextEditingController();
    _shaftBracketSystemPhotoController = TextEditingController();
    _shaftWallGomagiController = TextEditingController();
    _shaftWallGomagiPhotoController = TextEditingController();
    _shaftOndolFloorController = TextEditingController();
    _shaftOndolFloorPhotoController = TextEditingController();
    _shaftWindowsRailingsController = TextEditingController();
    _shaftWindowsRailingsPhotoController = TextEditingController();
    _roofFramingMembersController = TextEditingController();
    _roofFramingMembersPhotoController = TextEditingController();
    _roofRaftersPuyeonController = TextEditingController();
    _roofRaftersPuyeonPhotoController = TextEditingController();
    _roofRoofTilesController = TextEditingController();
    _roofRoofTilesPhotoController = TextEditingController();
    _roofCeilingDanjipController = TextEditingController();
    _roofCeilingDanjipPhotoController = TextEditingController();
    _otherSpecialNotesController = TextEditingController();
    _otherSpecialNotesPhotoController = TextEditingController();
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

    // 1.2 보존 사항 컨트롤러들 해제
    _foundationBaseController.dispose();
    _foundationBasePhotoController.dispose();
    _foundationCornerstonePhotoController.dispose();
    _shaftVerticalMembersController.dispose();
    _shaftVerticalMembersPhotoController.dispose();
    _shaftLintelTiebeamController.dispose();
    _shaftLintelTiebeamPhotoController.dispose();
    _shaftBracketSystemController.dispose();
    _shaftBracketSystemPhotoController.dispose();
    _shaftWallGomagiController.dispose();
    _shaftWallGomagiPhotoController.dispose();
    _shaftOndolFloorController.dispose();
    _shaftOndolFloorPhotoController.dispose();
    _shaftWindowsRailingsController.dispose();
    _shaftWindowsRailingsPhotoController.dispose();
    _roofFramingMembersController.dispose();
    _roofFramingMembersPhotoController.dispose();
    _roofRaftersPuyeonController.dispose();
    _roofRaftersPuyeonPhotoController.dispose();
    _roofRoofTilesController.dispose();
    _roofRoofTilesPhotoController.dispose();
    _roofCeilingDanjipController.dispose();
    _roofCeilingDanjipPhotoController.dispose();
    _otherSpecialNotesController.dispose();
    _otherSpecialNotesPhotoController.dispose();
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
            '1.1 조사 결과',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildInspectionTable(),
          const SizedBox(height: 32),
          
          // 1.2 보존 사항 섹션
          const Text(
            '1.2 보존 사항',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildPreservationTable(),
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
              sectionTitle: '1.1 조사 결과',
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
          // 기타부 섹션
          _buildTableSection('기타부', [
            _buildTableRow('채색 (단청, 벽화)', _coloringController),
            _buildTableRow('충해', _pestDamageController),
            _buildTableRow('기타', _otherController),
          ]),
          // 조사 정보 섹션
          _buildTableSection('조사 정보', [
            _buildTableRow('특기사항', _specialNotesController),
            _buildTableRow('조사 종합의견', _overallOpinionController),
            _buildTableRow('등급분류', _gradeClassificationController),
            _buildTableRow('조사일시', _investigationDateController),
            _buildTableRow('조사자', _investigatorController),
          ]),
        ],
      ),
    );
  }

  Widget _buildPreservationTable() {
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
                    '구분',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '부재',
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
                    '조사내용(현상)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '사진/위치',
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
          // ① 기단부 섹션
          _buildPreservationTableSection('① 기단부', [
            _buildPreservationTableRow('기단부', '기단', _foundationBaseController, _foundationBasePhotoController, 
              surveyContent: '조사내용에서는 부재/위치/현상 순으로 내용을 기입한다.\n해당 현상을 촬영한 사진을 첨부하고, 사진/위치 란에 사진번호를 기입한다.\n사진번호는 부재명과 번호를 같이 기입한다.'),
            _buildPreservationTableRow('', '초석', TextEditingController(), _foundationCornerstonePhotoController),
          ]),
          // ② 축부(벽체부) 섹션
          _buildPreservationTableSection('② 축부(벽체부)', [
            _buildPreservationTableRow('축부(벽체부)', '기둥 등 수직재 (기둥 등 수직으로 하중을 받는 모든 부재)', 
              _shaftVerticalMembersController, _shaftVerticalMembersPhotoController),
            _buildPreservationTableRow('', '인방(引枋: 기둥과 기둥 사이에 놓이는 부재)/창방 등', 
              _shaftLintelTiebeamController, _shaftLintelTiebeamPhotoController),
            _buildPreservationTableRow('', '공포', _shaftBracketSystemController, _shaftBracketSystemPhotoController),
            _buildPreservationTableRow('', '벽체/고막이', _shaftWallGomagiController, _shaftWallGomagiPhotoController),
            _buildPreservationTableRow('', '구들/마루', _shaftOndolFloorController, _shaftOndolFloorPhotoController),
            _buildPreservationTableRow('', '창호/난간', _shaftWindowsRailingsController, _shaftWindowsRailingsPhotoController),
          ]),
          // ③ 지붕부 섹션
          _buildPreservationTableSection('③ 지붕부', [
            _buildPreservationTableRow('지붕부', '지붕 가구재', _roofFramingMembersController, _roofFramingMembersPhotoController,
              surveyContent: '보 부재 등의 조사내용을 기입한다.'),
            _buildPreservationTableRow('', '서까래/부연 (처마 서까래의 끝에 덧없는 네모지고 짧은 서까래)', 
              _roofRaftersPuyeonController, _roofRaftersPuyeonPhotoController),
            _buildPreservationTableRow('', '지붕/기와', _roofRoofTilesController, _roofRoofTilesPhotoController),
            _buildPreservationTableRow('', '천장/단집', _roofCeilingDanjipController, _roofCeilingDanjipPhotoController),
          ]),
          // 기타사항 섹션
          _buildPreservationTableSection('기타사항', [
            _buildPreservationTableRow('기타사항', '특기사항', _otherSpecialNotesController, _otherSpecialNotesPhotoController),
          ]),
        ],
      ),
    );
  }

  Widget _buildPreservationTableSection(String sectionTitle, List<Widget> rows) {
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

  Widget _buildPreservationTableRow(String category, String component, TextEditingController surveyController, TextEditingController photoController, {String? surveyContent}) {
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
          // 구분 컬럼
          Expanded(
            flex: 1,
            child: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          // 부재 컬럼
          Expanded(
            flex: 2,
            child: Text(
              component,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          // 조사내용(현상) 컬럼
          Expanded(
            flex: 3,
            child: TextField(
              controller: surveyController,
              decoration: InputDecoration(
                hintText: surveyContent ?? '내용을 입력하세요',
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
              maxLines: surveyContent != null ? 5 : 2,
              readOnly: false,
              style: const TextStyle(
                fontSize: 13, 
                color: Color(0xFF374151)
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 사진/위치 컬럼
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // 사진 첨부 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(_getPhotoKey(photoController)),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('사진 첨부', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2A44),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 사진 URL 표시 및 보기
                GestureDetector(
                  onTap: () => _showImageDialog(_getPhotoKey(photoController)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(6),
                      color: photoController.text.isNotEmpty ? const Color(0xFFF0F9FF) : Colors.white,
                    ),
                    child: Text(
                      photoController.text.isNotEmpty ? '사진 보기' : '사진 없음',
                      style: TextStyle(
                        fontSize: 12,
                        color: photoController.text.isNotEmpty ? const Color(0xFF1E2A44) : Colors.grey.shade600,
                        fontWeight: photoController.text.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  // 컨트롤러를 기반으로 사진 키 반환
  String _getPhotoKey(TextEditingController controller) {
    if (controller == _foundationBasePhotoController) return 'foundationBase';
    if (controller == _foundationCornerstonePhotoController) return 'foundationCornerstone';
    if (controller == _shaftVerticalMembersPhotoController) return 'shaftVerticalMembers';
    if (controller == _shaftLintelTiebeamPhotoController) return 'shaftLintelTiebeam';
    if (controller == _shaftBracketSystemPhotoController) return 'shaftBracketSystem';
    if (controller == _shaftWallGomagiPhotoController) return 'shaftWallGomagi';
    if (controller == _shaftOndolFloorPhotoController) return 'shaftOndolFloor';
    if (controller == _shaftWindowsRailingsPhotoController) return 'shaftWindowsRailings';
    if (controller == _roofFramingMembersPhotoController) return 'roofFramingMembers';
    if (controller == _roofRaftersPuyeonPhotoController) return 'roofRaftersPuyeon';
    if (controller == _roofRoofTilesPhotoController) return 'roofRoofTiles';
    if (controller == _roofCeilingDanjipPhotoController) return 'roofCeilingDanjip';
    if (controller == _otherSpecialNotesPhotoController) return 'otherSpecialNotes';
    return 'unknown';
  }

  // 사진 첨부 함수
  Future<void> _pickImage(String photoKey) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        setState(() {
          _preservationPhotos[photoKey] = imageBytes;
        });
        
        // Firebase에 사진 업로드
        await _uploadPhotoToFirebase(photoKey, imageBytes);
      }
    } catch (e) {
      print('사진 선택 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // Firebase에 사진 업로드
  Future<void> _uploadPhotoToFirebase(String photoKey, Uint8List imageBytes) async {
    try {
      final String downloadUrl = await _fb.uploadImage(
        heritageId: widget.heritageId,
        folder: 'preservation_photos',
        bytes: imageBytes,
      );
      
      setState(() {
        _preservationPhotoUrls[photoKey] = downloadUrl;
      });
      
      // 해당 컨트롤러에 사진 URL 업데이트
      _updatePhotoController(photoKey, downloadUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진이 성공적으로 업로드되었습니다.')),
      );
    } catch (e) {
      print('사진 업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 업로드 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 사진 컨트롤러 업데이트
  void _updatePhotoController(String photoKey, String url) {
    switch (photoKey) {
      case 'foundationBase':
        _foundationBasePhotoController.text = url;
        break;
      case 'foundationCornerstone':
        _foundationCornerstonePhotoController.text = url;
        break;
      case 'shaftVerticalMembers':
        _shaftVerticalMembersPhotoController.text = url;
        break;
      case 'shaftLintelTiebeam':
        _shaftLintelTiebeamPhotoController.text = url;
        break;
      case 'shaftBracketSystem':
        _shaftBracketSystemPhotoController.text = url;
        break;
      case 'shaftWallGomagi':
        _shaftWallGomagiPhotoController.text = url;
        break;
      case 'shaftOndolFloor':
        _shaftOndolFloorPhotoController.text = url;
        break;
      case 'shaftWindowsRailings':
        _shaftWindowsRailingsPhotoController.text = url;
        break;
      case 'roofFramingMembers':
        _roofFramingMembersPhotoController.text = url;
        break;
      case 'roofRaftersPuyeon':
        _roofRaftersPuyeonPhotoController.text = url;
        break;
      case 'roofRoofTiles':
        _roofRoofTilesPhotoController.text = url;
        break;
      case 'roofCeilingDanjip':
        _roofCeilingDanjipPhotoController.text = url;
        break;
      case 'otherSpecialNotes':
        _otherSpecialNotesPhotoController.text = url;
        break;
    }
  }

  // 사진 크게 보기 다이얼로그
  void _showImageDialog(String photoKey) {
    final String? imageUrl = _preservationPhotoUrls[photoKey];
    final Uint8List? imageBytes = _preservationPhotos[photoKey];
    
    if (imageUrl == null && imageBytes == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                title: Text('사진 보기'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.contain)
                      : imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.contain)
                          : Container(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveInspectionResult() async {
    print('🚨 _saveInspectionResult 호출됨!');
    debugPrint('🚨 _saveInspectionResult 호출됨!');
    
    if (widget.heritageId.isEmpty) {
      print('❌ HeritageId가 비어있음');
      debugPrint('❌ HeritageId가 비어있음');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문화유산 정보가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('✅ HeritageId 확인됨: ${widget.heritageId}');
    debugPrint('✅ HeritageId 확인됨: ${widget.heritageId}');

    setState(() => _isSaving = true);

    try {
      // 모든 필드의 내용을 하나의 문서로 통합 저장
      final title = '1.1 조사 결과 - ${DateTime.now().toString().substring(0, 16)}';
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
      
      // 기타부 섹션
      content.writeln('\n기타부:');
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
      
      // 1.2 보존 사항 섹션
      content.writeln('\n1.2 보존 사항:');
      content.writeln('기단부:');
      if (_foundationBaseController.text.trim().isNotEmpty) {
        content.writeln('  - 기단: ${_foundationBaseController.text.trim()}');
      }
      if (_foundationBasePhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 기단 사진: ${_foundationBasePhotoController.text.trim()}');
      }
      if (_foundationCornerstonePhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 초석 사진: ${_foundationCornerstonePhotoController.text.trim()}');
      }
      
      content.writeln('\n축부(벽체부):');
      if (_shaftVerticalMembersController.text.trim().isNotEmpty) {
        content.writeln('  - 기둥 등 수직재: ${_shaftVerticalMembersController.text.trim()}');
      }
      if (_shaftVerticalMembersPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 기둥 등 수직재 사진: ${_shaftVerticalMembersPhotoController.text.trim()}');
      }
      if (_shaftLintelTiebeamController.text.trim().isNotEmpty) {
        content.writeln('  - 인방/창방 등: ${_shaftLintelTiebeamController.text.trim()}');
      }
      if (_shaftLintelTiebeamPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 인방/창방 등 사진: ${_shaftLintelTiebeamPhotoController.text.trim()}');
      }
      if (_shaftBracketSystemController.text.trim().isNotEmpty) {
        content.writeln('  - 공포: ${_shaftBracketSystemController.text.trim()}');
      }
      if (_shaftBracketSystemPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 공포 사진: ${_shaftBracketSystemPhotoController.text.trim()}');
      }
      if (_shaftWallGomagiController.text.trim().isNotEmpty) {
        content.writeln('  - 벽체/고막이: ${_shaftWallGomagiController.text.trim()}');
      }
      if (_shaftWallGomagiPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 벽체/고막이 사진: ${_shaftWallGomagiPhotoController.text.trim()}');
      }
      if (_shaftOndolFloorController.text.trim().isNotEmpty) {
        content.writeln('  - 구들/마루: ${_shaftOndolFloorController.text.trim()}');
      }
      if (_shaftOndolFloorPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 구들/마루 사진: ${_shaftOndolFloorPhotoController.text.trim()}');
      }
      if (_shaftWindowsRailingsController.text.trim().isNotEmpty) {
        content.writeln('  - 창호/난간: ${_shaftWindowsRailingsController.text.trim()}');
      }
      if (_shaftWindowsRailingsPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 창호/난간 사진: ${_shaftWindowsRailingsPhotoController.text.trim()}');
      }
      
      content.writeln('\n지붕부:');
      if (_roofFramingMembersController.text.trim().isNotEmpty) {
        content.writeln('  - 지붕 가구재: ${_roofFramingMembersController.text.trim()}');
      }
      if (_roofFramingMembersPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 지붕 가구재 사진: ${_roofFramingMembersPhotoController.text.trim()}');
      }
      if (_roofRaftersPuyeonController.text.trim().isNotEmpty) {
        content.writeln('  - 서까래/부연: ${_roofRaftersPuyeonController.text.trim()}');
      }
      if (_roofRaftersPuyeonPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 서까래/부연 사진: ${_roofRaftersPuyeonPhotoController.text.trim()}');
      }
      if (_roofRoofTilesController.text.trim().isNotEmpty) {
        content.writeln('  - 지붕/기와: ${_roofRoofTilesController.text.trim()}');
      }
      if (_roofRoofTilesPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 지붕/기와 사진: ${_roofRoofTilesPhotoController.text.trim()}');
      }
      if (_roofCeilingDanjipController.text.trim().isNotEmpty) {
        content.writeln('  - 천장/단집: ${_roofCeilingDanjipController.text.trim()}');
      }
      if (_roofCeilingDanjipPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 천장/단집 사진: ${_roofCeilingDanjipPhotoController.text.trim()}');
      }
      
      content.writeln('\n기타사항:');
      if (_otherSpecialNotesController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_otherSpecialNotesController.text.trim()}');
      }
      if (_otherSpecialNotesPhotoController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항 사진: ${_otherSpecialNotesPhotoController.text.trim()}');
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

      print('📝 SectionFormData 생성 중...');
      debugPrint('📝 SectionFormData 생성 중...');
      
      final formData = SectionFormData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionType: SectionType.inspection,
        title: title,
        content: content.toString().trim(),
        createdAt: DateTime.now(),
        author: '현재 사용자',
      );

      print('✅ SectionFormData 생성 완료');
      debugPrint('✅ SectionFormData 생성 완료');
      debugPrint('  - ID: ${formData.id}');
      debugPrint('  - SectionType: ${formData.sectionType}');
      debugPrint('  - Title: ${formData.title}');
      debugPrint('  - Content 길이: ${formData.content.length}');
      debugPrint('  - Author: ${formData.author}');

      print('🔥 Firebase 저장 시작...');
      debugPrint('🔥 Firebase 저장 시작...');
      
      await _fb.saveSectionForm(
        heritageId: widget.heritageId,
        sectionType: SectionType.inspection,
        formData: formData,
      );
      
      print('✅ Firebase 저장 완료!');
      debugPrint('✅ Firebase 저장 완료!');

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
      
      // 1.2 보존 사항 필드 초기화
      _foundationBaseController.clear();
      _foundationBasePhotoController.clear();
      _foundationCornerstonePhotoController.clear();
      _shaftVerticalMembersController.clear();
      _shaftVerticalMembersPhotoController.clear();
      _shaftLintelTiebeamController.clear();
      _shaftLintelTiebeamPhotoController.clear();
      _shaftBracketSystemController.clear();
      _shaftBracketSystemPhotoController.clear();
      _shaftWallGomagiController.clear();
      _shaftWallGomagiPhotoController.clear();
      _shaftOndolFloorController.clear();
      _shaftOndolFloorPhotoController.clear();
      _shaftWindowsRailingsController.clear();
      _shaftWindowsRailingsPhotoController.clear();
      _roofFramingMembersController.clear();
      _roofFramingMembersPhotoController.clear();
      _roofRaftersPuyeonController.clear();
      _roofRaftersPuyeonPhotoController.clear();
      _roofRoofTilesController.clear();
      _roofRoofTilesPhotoController.clear();
      _roofCeilingDanjipController.clear();
      _roofCeilingDanjipPhotoController.clear();
      _otherSpecialNotesController.clear();
      _otherSpecialNotesPhotoController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 1.1 조사 결과가 저장되었습니다'),
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
