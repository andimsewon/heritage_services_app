import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/ai_detection_service.dart';
import '../services/image_acquire.dart';

/// 개선된 손상부 조사 다이얼로그
///
/// 사용자 경험 개선 사항:
/// - 사진 비교 (전년도 vs 이번 조사)
/// - 감지결과 명확한 표시
/// - 손상 분류 섹션
/// - 손상 등급 설명
/// - 조사자 의견
/// - 하단 고정 버튼
class ImprovedDamageSurveyDialog extends StatefulWidget {
  const ImprovedDamageSurveyDialog({
    super.key,
    required this.aiService,
    this.autoCapture = false,
    this.initialPart,
  });

  final AiDetectionService aiService;
  final bool autoCapture;
  final Map<String, dynamic>? initialPart;

  @override
  State<ImprovedDamageSurveyDialog> createState() =>
      _ImprovedDamageSurveyDialogState();
}

class _ImprovedDamageSurveyDialogState
    extends State<ImprovedDamageSurveyDialog> {
  // 이미지 데이터
  Uint8List? _imageBytes;
  Uint8List? _previousYearImage; // TODO: 전년도 사진 로딩
  List<Map<String, dynamic>> _detections = [];
  bool _loading = false;

  // AI 감지 결과
  String? _selectedLabel;
  double? _selectedConfidence;
  String? _autoGrade;
  String? _autoExplanation;
  Map<String, String>? _prefilledPart;

  // 입력 컨트롤러
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _partController = TextEditingController();
  final TextEditingController _opinionController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();

  // 손상 등급 및 분류
  String _severityGrade = 'C';
  final Set<String> _selectedDamageTypes = {};

  @override
  void initState() {
    super.initState();
    _applyInitialPart(widget.initialPart);
    if (widget.autoCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickImageAndDetect();
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _partController.dispose();
    _opinionController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  void _applyInitialPart(Map<String, dynamic>? rawPart, {bool notify = false}) {
    if (rawPart == null) return;
    final partName = (rawPart['partName'] as String?)?.trim() ?? '';
    final partNumber = (rawPart['partNumber'] as String?)?.trim() ?? '';
    final direction = (rawPart['direction'] as String?)?.trim() ?? '';
    final position = (rawPart['position'] as String?)?.trim() ?? '';

    final locationPieces = <String>[
      if (direction.isNotEmpty) direction,
      if (partNumber.isNotEmpty) '$partNumber번',
      if (position.isNotEmpty) position,
    ];
    final location = locationPieces.join(' ');

    void assign() {
      if (location.isNotEmpty && _locationController.text.isEmpty) {
        _locationController.text = location;
      }
      if (partName.isNotEmpty && _partController.text.isEmpty) {
        _partController.text = partName;
      }
      _prefilledPart = {
        if (partName.isNotEmpty) 'partName': partName,
        if (partNumber.isNotEmpty) 'partNumber': partNumber,
        if (direction.isNotEmpty) 'direction': direction,
        if (position.isNotEmpty) 'position': position,
        if (location.isNotEmpty) 'location': location,
      };
    }

    if (notify && mounted) {
      setState(assign);
    } else {
      assign();
    }
  }

  Future<void> _pickImageAndDetect() async {
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, sizeGetter) = picked;
    await sizeGetter(); // 이미지 크기 가져오기 (현재 미사용)
    setState(() {
      _loading = true;
      _imageBytes = bytes;
      _detections = [];
      _selectedLabel = null;
      _selectedConfidence = null;
      _autoGrade = null;
      _autoExplanation = null;
    });

    final detectionResult = await widget.aiService.detect(bytes);
    if (!mounted) return;

    final sorted = List<Map<String, dynamic>>.from(detectionResult.detections)
      ..sort(
        (a, b) =>
            ((b['score'] as num?) ?? 0).compareTo(((a['score'] as num?) ?? 0)),
      );
    final normalized = _normalizeDetections(sorted);

    setState(() {
      _loading = false;
      _detections = normalized;
      if (_detections.isNotEmpty) {
        _selectedLabel = _detections.first['label'] as String?;
        _selectedConfidence = (_detections.first['score'] as num?)?.toDouble();
        // 감지된 손상을 자동으로 선택
        final label = _selectedLabel;
        if (label != null) {
          _selectedDamageTypes.add(label);
        }
      }
      final normalizedGrade = detectionResult.grade?.toUpperCase();
      _autoGrade = normalizedGrade;
      _autoExplanation = detectionResult.explanation;
      if (normalizedGrade != null &&
          ['A', 'B', 'C', 'D', 'E', 'F'].contains(normalizedGrade)) {
        _severityGrade = normalizedGrade;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 먼저 촬영하거나 업로드하세요.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('손상 감지 결과 저장'),
        content: const Text('현재 입력한 조사 내용을 저장하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = DamageDetectionResult(
      imageBytes: _imageBytes!,
      detections: _detections,
      selectedLabel: _selectedLabel,
      selectedConfidence: _selectedConfidence,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      damagePart: _partController.text.trim().isEmpty
          ? null
          : _partController.text.trim(),
      temperature: _temperatureController.text.trim().isEmpty
          ? null
          : _temperatureController.text.trim(),
      humidity: _humidityController.text.trim().isEmpty
          ? null
          : _humidityController.text.trim(),
      opinion: _opinionController.text.trim().isEmpty
          ? null
          : _opinionController.text.trim(),
      severityGrade: _severityGrade,
      autoGrade: _autoGrade,
      autoExplanation: _autoExplanation,
      selectedDamageTypes: _selectedDamageTypes.toList(),
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  List<Map<String, dynamic>> _normalizeDetections(
    List<Map<String, dynamic>> detections,
  ) {
    return detections.map((d) {
      final label = (d['label'] as String?)?.replaceAll('_', ' ') ?? '미분류';
      return {
        'label': label,
        'score': d['score'],
        'box': d['box'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = const Color(0xFF2F3E46); // 짙은 청회색 (따뜻하고 전문적)
    final accentBlue = const Color(0xFF4C8BF5); // 포인트 블루 (부드러운 블루)
    final grayBg = const Color(0xFFF8F9FB); // 은은한 회색톤 배경

    // 화면 크기 가져오기
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      // 화면의 10% 여백
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.1,
        vertical: screenHeight * 0.1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        // 화면의 80% 크기
        width: screenWidth * 0.8,
        height: screenHeight * 0.8,
        decoration: BoxDecoration(
          color: grayBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════ 헤더 ═══════════════
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assessment, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    '손상부 조사',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ═══════════════ 스크롤 가능한 본문 ═══════════════
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1️⃣ 사진 비교
                    _buildSectionTitle('사진 비교', Icons.photo_library, headerColor),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoBox(
                            '전년도 조사 사진',
                            _previousYearImage,
                            onTap: () {
                              // TODO: 전년도 사진 선택 기능
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('전년도 사진 불러오기 기능 준비 중')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPhotoBox(
                            '이번 조사 사진 등록',
                            _imageBytes,
                            onTap: _loading ? null : _pickImageAndDetect,
                            isLoading: _loading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2️⃣ 감지 결과
                    if (_imageBytes != null) ...[
                      _buildSectionTitle('손상 감지 결과', Icons.auto_graph, headerColor),
                      const SizedBox(height: 12),
                      _buildDetectionResult(accentBlue),
                      const SizedBox(height: 24),
                    ],

                    // 3️⃣ 부재 정보 (있는 경우)
                    if (_prefilledPart != null) ...[
                      _buildPrefilledPartSummary(headerColor),
                      const SizedBox(height: 24),
                    ],

                    // 4️⃣ 손상 정보 입력
                    _buildSectionTitle('손상 정보 입력', Icons.edit_note, headerColor),
                    const SizedBox(height: 12),
                    _buildInfoSection(),
                    const SizedBox(height: 24),

                    // 5️⃣ 손상 분류
                    _buildSectionTitle('손상 분류', Icons.category, headerColor),
                    const SizedBox(height: 12),
                    _buildClassificationSection(),
                    const SizedBox(height: 24),

                    // 6️⃣ 손상 등급
                    _buildSectionTitle('손상 등급', Icons.priority_high, headerColor),
                    const SizedBox(height: 12),
                    _buildGradeSection(accentBlue),
                    const SizedBox(height: 24),

                    // 7️⃣ 조사자 의견
                    _buildSectionTitle('조사자 의견', Icons.comment, headerColor),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _opinionController,
                      decoration: InputDecoration(
                        hintText: '조사자의 의견을 입력하세요',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      maxLines: 4,
                    ),
                  ],
                  ),
                ),
              ),

            // ═══════════════ 하단 고정 버튼 ═══════════════
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: headerColor),
                      foregroundColor: headerColor,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 위젯 빌더 메서드들
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoBox(
    String label,
    Uint8List? imageBytes, {
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                if (imageBytes == null)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            color: Colors.black38, size: 40),
                        SizedBox(height: 8),
                        Text(
                          '사진 등록',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionResult(Color accentBlue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_detections.isEmpty)
            const Text(
              '감지된 손상이 없습니다.',
              style: TextStyle(color: Colors.black54),
            )
          else ...[
            const Text(
              '감지된 손상:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _detections.map((det) {
                final label = det['label'] as String? ?? '미분류';
                final score = (det['score'] as num?)?.toDouble() ?? 0;
                final percent = (score * 100).toStringAsFixed(1);
                return Chip(
                  label: Text('$label ($percent%)'),
                  backgroundColor: accentBlue.withValues(alpha: 0.1),
                  side: BorderSide(color: accentBlue, width: 1),
                  labelStyle: TextStyle(
                    color: accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            if (_autoExplanation != null && _autoExplanation!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'AI 설명: $_autoExplanation',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPrefilledPartSummary(Color headerColor) {
    final data = _prefilledPart;
    if (data == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.architecture, color: headerColor, size: 20),
              const SizedBox(width: 6),
              Text(
                '선택된 부재 정보',
                style: TextStyle(
                  color: headerColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('부재명', data['partName']),
          _buildInfoRow('부재 번호', data['partNumber']),
          _buildInfoRow('향', data['direction']),
          _buildInfoRow('부재 내 위치', data['position']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: '손상 위치',
              hintText: '예: 남향 2번 평주',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _partController,
            decoration: const InputDecoration(
              labelText: '촬영 부위',
              hintText: '예: 기둥 - 상부',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _temperatureController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '온도(℃)',
                    hintText: '예: 23',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _humidityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '습도(%)',
                    hintText: '예: 55',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDamageCategory('구조적 손상', ['갈램', '균열', '변형', '파손']),
          const Divider(height: 24),
          _buildDamageCategory('물리적 손상', ['탈락', '부식', '박락', '박리']),
          const Divider(height: 24),
          _buildDamageCategory('생물·화학적 손상', ['변색', '오염균', '백화', '이끼']),
        ],
      ),
    );
  }

  Widget _buildDamageCategory(String category, List<String> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = _selectedDamageTypes.contains(type);
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDamageTypes.add(type);
                  } else {
                    _selectedDamageTypes.remove(type);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGradeSection(Color accentBlue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _severityGrade,
            decoration: const InputDecoration(
              labelText: '손상 등급',
              border: OutlineInputBorder(),
            ),
            items: const ['A', 'B', 'C', 'D', 'E', 'F']
                .map((g) => DropdownMenuItem(value: g, child: Text('$g 등급')))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _severityGrade = val);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: accentBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getGradeDescription(_severityGrade),
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  String _getGradeDescription(String grade) {
    switch (grade) {
      case 'A':
        return '양호 - 손상 없음, 관찰 불필요';
      case 'B':
        return '경미 - 작은 손상, 정기적 관찰 권장';
      case 'C':
        return '주의 - 관찰 필요, 손상 진행 모니터링';
      case 'D':
        return '보수 필요 - 단기간 내 보수 권장';
      case 'E':
        return '긴급 보수 필요 - 빠른 시일 내 조치';
      case 'F':
        return '심각 - 즉시 조치 필요, 안전 위험';
      default:
        return '';
    }
  }
}

/// 손상 감지 결과 데이터 클래스
class DamageDetectionResult {
  const DamageDetectionResult({
    required this.imageBytes,
    required this.detections,
    this.selectedLabel,
    this.selectedConfidence,
    this.location,
    this.damagePart,
    this.temperature,
    this.humidity,
    this.opinion,
    this.severityGrade,
    this.autoGrade,
    this.autoExplanation,
    this.selectedDamageTypes,
  });

  final Uint8List imageBytes;
  final List<Map<String, dynamic>> detections;
  final String? selectedLabel;
  final double? selectedConfidence;
  final String? location;
  final String? damagePart;
  final String? temperature;
  final String? humidity;
  final String? opinion;
  final String? severityGrade;
  final String? autoGrade;
  final String? autoExplanation;
  final List<String>? selectedDamageTypes;

  Map<String, String?> toDetailInputs() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'part': damagePart,
      'damageTypes': selectedDamageTypes?.join(', '),
    };
  }
}
