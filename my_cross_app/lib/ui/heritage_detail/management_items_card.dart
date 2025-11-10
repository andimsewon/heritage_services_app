import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/section_form_models.dart';
import '../../services/firebase_service.dart';
import '../section_form/section_data_list.dart';

class ManagementItemsCard extends StatefulWidget {
  const ManagementItemsCard({
    super.key,
    this.heritageId = '',
    this.heritageName = '',
  });

  final String heritageId;
  final String heritageName;

  @override
  State<ManagementItemsCard> createState() => _ManagementItemsCardState();
}

class _ManagementItemsCardState extends State<ManagementItemsCard> {
  final _fb = FirebaseService();
  bool _isSaving = false;

  // 소방 및 안전관리
  bool _hasDisasterManual = false;
  bool _hasFireTruckAccess = false;
  bool _hasFireLine = false;
  bool _hasEvacTargets = false;
  bool _hasTraining = false;
  late final TextEditingController _specialNotesController;

  // 소방 및 안전시설 관리상태
  bool _hasExtinguisher = false;
  bool _hasHydrant = false;
  bool _hasAutoAlarm = false;
  late final TextEditingController _extinguisherCountController;
  late final TextEditingController _hydrantCountController;
  late final TextEditingController _autoAlarmCountController;

  // CCTV 및 보안시설
  bool _hasCCTV = false;
  bool _hasAntiTheftCam = false;
  bool _hasFireDetector = false;
  late final TextEditingController _cctvCountController;
  late final TextEditingController _antiTheftCamCountController;
  late final TextEditingController _fireDetectorCountController;

  // 전기시설 관리상태
  bool _hasElectricalCheck = false;
  late final TextEditingController _electricalNotesController;

  // 가스시설 관리상태
  bool _hasGasCheck = false;
  late final TextEditingController _gasNotesController;

  // 안전경비인력 관리상태
  bool _hasSecurityPersonnel = false;
  bool _hasManagementLog = false;
  late final TextEditingController _securityPersonnelCountController;
  late final TextEditingController _securityShiftController;

  // 돌봄사업
  bool _hasCareProject = false;
  late final TextEditingController _careOrganizationController;

  // 안내 및 전시시설
  bool _hasInfoCenter = false;
  bool _hasInfoBoard = false;
  bool _hasExhibitionMuseum = false;
  bool _hasNationalHeritageInterpreter = false;
  late final TextEditingController _infoCenterController;
  late final TextEditingController _infoBoardController;
  late final TextEditingController _exhibitionMuseumController;
  late final TextEditingController _nationalHeritageInterpreterController;
  late final TextEditingController _infoExhibitionNotesController;

  // 주변 및 부대시설
  late final TextEditingController _retainingWallController;
  late final TextEditingController _surroundingTreesController;
  late final TextEditingController _protectivePavilionController;
  late final TextEditingController _otherFacilitiesController;
  late final TextEditingController _drainageFacilityController;
  late final TextEditingController _surroundingBuildingsController;

  // 원래기능/활용상태/사용빈도
  late final TextEditingController _originalFunctionController;

  @override
  void initState() {
    super.initState();
    _specialNotesController = TextEditingController();
    _extinguisherCountController = TextEditingController();
    _hydrantCountController = TextEditingController();
    _autoAlarmCountController = TextEditingController();
    _cctvCountController = TextEditingController();
    _antiTheftCamCountController = TextEditingController();
    _fireDetectorCountController = TextEditingController();
    _electricalNotesController = TextEditingController();
    _gasNotesController = TextEditingController();
    _securityPersonnelCountController = TextEditingController();
    _securityShiftController = TextEditingController();
    _careOrganizationController = TextEditingController();
    
    // 안내 및 전시시설
    _infoCenterController = TextEditingController();
    _infoBoardController = TextEditingController();
    _exhibitionMuseumController = TextEditingController();
    _nationalHeritageInterpreterController = TextEditingController();
    _infoExhibitionNotesController = TextEditingController();
    
    // 주변 및 부대시설
    _retainingWallController = TextEditingController();
    _surroundingTreesController = TextEditingController();
    _protectivePavilionController = TextEditingController();
    _otherFacilitiesController = TextEditingController();
    _drainageFacilityController = TextEditingController();
    _surroundingBuildingsController = TextEditingController();
    
    // 원래기능/활용상태/사용빈도
    _originalFunctionController = TextEditingController();
  }

  @override
  void dispose() {
    _specialNotesController.dispose();
    _extinguisherCountController.dispose();
    _hydrantCountController.dispose();
    _autoAlarmCountController.dispose();
    _cctvCountController.dispose();
    _antiTheftCamCountController.dispose();
    _fireDetectorCountController.dispose();
    _electricalNotesController.dispose();
    _gasNotesController.dispose();
    _securityPersonnelCountController.dispose();
    _securityShiftController.dispose();
    _careOrganizationController.dispose();
    
    // 안내 및 전시시설
    _infoCenterController.dispose();
    _infoBoardController.dispose();
    _exhibitionMuseumController.dispose();
    _nationalHeritageInterpreterController.dispose();
    _infoExhibitionNotesController.dispose();
    
    // 주변 및 부대시설
    _retainingWallController.dispose();
    _surroundingTreesController.dispose();
    _protectivePavilionController.dispose();
    _otherFacilitiesController.dispose();
    _drainageFacilityController.dispose();
    _surroundingBuildingsController.dispose();
    
    // 원래기능/활용상태/사용빈도
    _originalFunctionController.dispose();
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '6. 관리사항',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '소방, 전기, 가스 등 관리사항을 기록합니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 소방 및 안전관리 섹션
          _buildFireSafetySection(),
          const SizedBox(height: 20),
          
          // 전기시설 관리상태 섹션
          _buildElectricalSection(),
          const SizedBox(height: 20),
          
          // 가스시설 관리상태 섹션
          _buildGasSection(),
          const SizedBox(height: 20),
          
          // 안전경비인력 관리상태 섹션
          _buildSecuritySection(),
          const SizedBox(height: 20),
          
        // 돌봄사업 섹션
        _buildCareSection(),
        const SizedBox(height: 20),

        // 안내 및 전시시설 섹션
        _buildInfoExhibitionSection(),
        const SizedBox(height: 20),

        // 주변 및 부대시설 섹션
        _buildSurroundingFacilitiesSection(),
        const SizedBox(height: 20),

        // 원래기능/활용상태/사용빈도 섹션
        _buildOriginalFunctionSection(),
        const SizedBox(height: 20),
          
          // 저장 버튼
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Align(
                alignment: isMobile ? Alignment.center : Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveManagementItems,
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
              sectionType: SectionType.management,
              sectionTitle: '관리사항',
            ),
        ],
      ),
    );
  }

  Widget _buildFireSafetySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소방 및 안전관리',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow('■ 방재매뉴얼(소방시설도면 등) 배치 여부', _hasDisasterManual, (value) {
          setState(() => _hasDisasterManual = value);
        }),
        _buildCheckboxRow('■ 소방차의 진입 가능 여부', _hasFireTruckAccess, (value) {
          setState(() => _hasFireTruckAccess = value);
        }),
        _buildCheckboxRow('■ 방화선 여부', _hasFireLine, (value) {
          setState(() => _hasFireLine = value);
        }),
        _buildCheckboxRow('■ 국보·보물 내에 화재 시 대피 대상 국가유산 유무', _hasEvacTargets, (value) {
          setState(() => _hasEvacTargets = value);
        }),
        _buildCheckboxRow('■ 정기적인 교육과 훈련 실시 여부', _hasTraining, (value) {
          setState(() => _hasTraining = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _specialNotesController),
        const SizedBox(height: 16),
        
        // 소방 및 안전시설 관리상태
        const Text(
          '소방 및 안전시설 관리상태',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildTableRow('소화기', _hasExtinguisher, _extinguisherCountController, (hasItem) {
          setState(() {
            _hasExtinguisher = hasItem;
            if (!hasItem) _extinguisherCountController.clear();
          });
        }),
        _buildTableRow('옥외소화전', _hasHydrant, _hydrantCountController, (hasItem) {
          setState(() {
            _hasHydrant = hasItem;
            if (!hasItem) _hydrantCountController.clear();
          });
        }),
        _buildTableRow('자동화재속보설비', _hasAutoAlarm, _autoAlarmCountController, (hasItem) {
          setState(() {
            _hasAutoAlarm = hasItem;
            if (!hasItem) _autoAlarmCountController.clear();
          });
        }),
        const SizedBox(height: 16),
        
        // CCTV 및 보안시설
        const Text(
          'CCTV 및 보안시설',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildTableRow('CCTV', _hasCCTV, _cctvCountController, (hasItem) {
          setState(() {
            _hasCCTV = hasItem;
            if (!hasItem) _cctvCountController.clear();
          });
        }),
        _buildTableRow('도난방지카메라', _hasAntiTheftCam, _antiTheftCamCountController, (hasItem) {
          setState(() {
            _hasAntiTheftCam = hasItem;
            if (!hasItem) _antiTheftCamCountController.clear();
          });
        }),
        _buildTableRow('화재감지기', _hasFireDetector, _fireDetectorCountController, (hasItem) {
          setState(() {
            _hasFireDetector = hasItem;
            if (!hasItem) _fireDetectorCountController.clear();
          });
        }),
      ],
    );
  }

  Widget _buildElectricalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '전기시설 관리상태',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow('■ 정기적인 점검 실시 여부', _hasElectricalCheck, (value) {
          setState(() => _hasElectricalCheck = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _electricalNotesController),
      ],
    );
  }

  Widget _buildGasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '가스시설 관리상태',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow('■ 정기적인 점검 실시 여부', _hasGasCheck, (value) {
          setState(() => _hasGasCheck = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _gasNotesController),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '안전경비인력 관리상태',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildTableRow('안전경비인력', _hasSecurityPersonnel, _securityPersonnelCountController, (hasItem) {
          setState(() {
            _hasSecurityPersonnel = hasItem;
            if (!hasItem) _securityPersonnelCountController.clear();
          });
        }),
        _buildCheckboxRow('관리일지', _hasManagementLog, (value) {
          setState(() => _hasManagementLog = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _securityShiftController),
      ],
    );
  }

  Widget _buildCareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '돌봄사업',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow('■ 주기적인 관리를 위한 업체 및 단체의 유무', _hasCareProject, (value) {
          setState(() => _hasCareProject = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _careOrganizationController),
      ],
    );
  }

  Widget _buildInfoExhibitionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '안내 및 전시시설',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow('■ 안내소(매표소)', _hasInfoCenter, (value) {
          setState(() => _hasInfoCenter = value);
        }),
        _buildCheckboxRow('■ 안내판', _hasInfoBoard, (value) {
          setState(() => _hasInfoBoard = value);
        }),
        _buildCheckboxRow('■ 전시·박물관', _hasExhibitionMuseum, (value) {
          setState(() => _hasExhibitionMuseum = value);
        }),
        _buildCheckboxRow('■ 국가유산해설사', _hasNationalHeritageInterpreter, (value) {
          setState(() => _hasNationalHeritageInterpreter = value);
        }),
        const SizedBox(height: 8),
        _buildTextArea('특기사항', _infoExhibitionNotesController),
      ],
    );
  }

  Widget _buildSurroundingFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주변 및 부대시설',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextArea('옹벽·담장', _retainingWallController, hint: '○ 해당 없음.'),
        _buildTextArea('주변수목', _surroundingTreesController, hint: '○ 인접 도로와 풍남문 사이 조경목 있음.'),
        _buildTextArea('보호각·보호시설', _protectivePavilionController, hint: '○ 해당 없음.'),
        _buildTextArea('그 밖의 시설', _otherFacilitiesController, hint: '○ 해당 없음.'),
        _buildTextArea('배수시설', _drainageFacilityController, hint: '○ 성벽 위 배수구 있으며, 주변 자연 배수 상태 양호함.'),
        _buildTextArea('주변건물', _surroundingBuildingsController, hint: '○ 회전교차로 가운데에 위치하며 풍남문광장 및 주변 상가건물 있음.'),
      ],
    );
  }

  Widget _buildOriginalFunctionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '원래기능/활용상태/사용빈도',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextArea('내용', _originalFunctionController, hint: '○ 성벽 위, 홍예문 통로는 안전상의 이유로 관람객의 출입이 어려운 상태임.'),
      ],
    );
  }

  Widget _buildCheckboxRow(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
          ),
          Row(
            children: [
              _buildCheckbox('있음', value, () => onChanged(true)),
              const SizedBox(width: 16),
              _buildCheckbox('없음', !value, () => onChanged(false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, bool hasItem, TextEditingController controller, Function(bool) onHasItemChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                _buildCheckbox('있음', hasItem, () => onHasItemChanged(true)),
                const SizedBox(width: 8),
                _buildCheckbox('없음', !hasItem, () => onHasItemChanged(false)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: TextField(
              controller: controller,
              enabled: hasItem,
              decoration: InputDecoration(
                hintText: '현황(개수 등)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: hasItem ? const Color(0xFFD1D5DB) : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                fillColor: hasItem ? Colors.white : Colors.grey.shade50,
                filled: true,
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF1E2A44) : const Color(0xFFD1D5DB),
                width: 2,
              ),
              color: isSelected ? const Color(0xFF1E2A44) : Colors.white,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF1E2A44) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, {String hint = '○ 해당 없음.'}) {
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
          maxLines: 2,
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
      ],
    );
  }

  Future<void> _saveManagementItems() async {
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
      final title = '관리사항 - ${DateTime.now().toString().substring(0, 16)}';
      final content = StringBuffer();
      
      // 소방 및 안전관리
      content.writeln('소방 및 안전관리:');
      content.writeln('  - 방재매뉴얼 배치: ${_hasDisasterManual ? '있음' : '없음'}');
      content.writeln('  - 소방차 진입 가능: ${_hasFireTruckAccess ? '있음' : '없음'}');
      content.writeln('  - 방화선: ${_hasFireLine ? '있음' : '없음'}');
      content.writeln('  - 대피 대상 유산: ${_hasEvacTargets ? '있음' : '없음'}');
      content.writeln('  - 교육/훈련: ${_hasTraining ? '있음' : '없음'}');
      if (_specialNotesController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_specialNotesController.text.trim()}');
      }
      
      // 소방시설
      content.writeln('\n소방시설:');
      content.writeln('  - 소화기: ${_hasExtinguisher ? '있음' : '없음'} ${_extinguisherCountController.text.trim().isNotEmpty ? '(${_extinguisherCountController.text.trim()})' : ''}');
      content.writeln('  - 옥외소화전: ${_hasHydrant ? '있음' : '없음'} ${_hydrantCountController.text.trim().isNotEmpty ? '(${_hydrantCountController.text.trim()})' : ''}');
      content.writeln('  - 자동화재속보설비: ${_hasAutoAlarm ? '있음' : '없음'} ${_autoAlarmCountController.text.trim().isNotEmpty ? '(${_autoAlarmCountController.text.trim()})' : ''}');
      
      // CCTV 및 보안
      content.writeln('\nCCTV 및 보안:');
      content.writeln('  - CCTV: ${_hasCCTV ? '있음' : '없음'} ${_cctvCountController.text.trim().isNotEmpty ? '(${_cctvCountController.text.trim()})' : ''}');
      content.writeln('  - 도난방지카메라: ${_hasAntiTheftCam ? '있음' : '없음'} ${_antiTheftCamCountController.text.trim().isNotEmpty ? '(${_antiTheftCamCountController.text.trim()})' : ''}');
      content.writeln('  - 화재감지기: ${_hasFireDetector ? '있음' : '없음'} ${_fireDetectorCountController.text.trim().isNotEmpty ? '(${_fireDetectorCountController.text.trim()})' : ''}');
      
      // 전기시설
      content.writeln('\n전기시설:');
      content.writeln('  - 정기점검: ${_hasElectricalCheck ? '있음' : '없음'}');
      if (_electricalNotesController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_electricalNotesController.text.trim()}');
      }
      
      // 가스시설
      content.writeln('\n가스시설:');
      content.writeln('  - 정기점검: ${_hasGasCheck ? '있음' : '없음'}');
      if (_gasNotesController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_gasNotesController.text.trim()}');
      }
      
      // 안전경비인력
      content.writeln('\n안전경비인력:');
      content.writeln('  - 인력: ${_hasSecurityPersonnel ? '있음' : '없음'} ${_securityPersonnelCountController.text.trim().isNotEmpty ? '(${_securityPersonnelCountController.text.trim()})' : ''}');
      content.writeln('  - 관리일지: ${_hasManagementLog ? '있음' : '없음'}');
      if (_securityShiftController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_securityShiftController.text.trim()}');
      }
      
      // 돌봄사업
      content.writeln('\n돌봄사업:');
      content.writeln('  - 업체/단체: ${_hasCareProject ? '있음' : '없음'}');
      if (_careOrganizationController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_careOrganizationController.text.trim()}');
      }
      
      // 안내 및 전시시설
      content.writeln('\n안내 및 전시시설:');
      content.writeln('  - 안내소(매표소): ${_hasInfoCenter ? '있음' : '없음'}');
      content.writeln('  - 안내판: ${_hasInfoBoard ? '있음' : '없음'}');
      content.writeln('  - 전시·박물관: ${_hasExhibitionMuseum ? '있음' : '없음'}');
      content.writeln('  - 국가유산해설사: ${_hasNationalHeritageInterpreter ? '있음' : '없음'}');
      if (_infoExhibitionNotesController.text.trim().isNotEmpty) {
        content.writeln('  - 특기사항: ${_infoExhibitionNotesController.text.trim()}');
      }
      
      // 주변 및 부대시설
      content.writeln('\n주변 및 부대시설:');
      if (_retainingWallController.text.trim().isNotEmpty) {
        content.writeln('  - 옹벽·담장: ${_retainingWallController.text.trim()}');
      }
      if (_surroundingTreesController.text.trim().isNotEmpty) {
        content.writeln('  - 주변수목: ${_surroundingTreesController.text.trim()}');
      }
      if (_protectivePavilionController.text.trim().isNotEmpty) {
        content.writeln('  - 보호각·보호시설: ${_protectivePavilionController.text.trim()}');
      }
      if (_otherFacilitiesController.text.trim().isNotEmpty) {
        content.writeln('  - 그 밖의 시설: ${_otherFacilitiesController.text.trim()}');
      }
      if (_drainageFacilityController.text.trim().isNotEmpty) {
        content.writeln('  - 배수시설: ${_drainageFacilityController.text.trim()}');
      }
      if (_surroundingBuildingsController.text.trim().isNotEmpty) {
        content.writeln('  - 주변건물: ${_surroundingBuildingsController.text.trim()}');
      }
      
      // 원래기능/활용상태/사용빈도
      content.writeln('\n원래기능/활용상태/사용빈도:');
      if (_originalFunctionController.text.trim().isNotEmpty) {
        content.writeln('  - 내용: ${_originalFunctionController.text.trim()}');
      }

      final formData = SectionFormData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionType: SectionType.management,
        title: title,
        content: content.toString().trim(),
        createdAt: DateTime.now(),
        author: '현재 사용자',
      );

      await _fb.saveSectionForm(
        heritageId: widget.heritageId,
        sectionType: SectionType.management,
        formData: formData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 관리사항이 저장되었습니다'),
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