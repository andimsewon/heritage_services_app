import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/services/ai_detection_service.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/services/image_acquire.dart';
import 'package:my_cross_app/utils/position_options.dart';

/// 조사 단계 정의
enum SurveyStep {
  register,   // ① 조사등록 (부재명/번호/향 선택)
  detail,     // ② 손상부 조사 (사진, 손상위치, 의견)
  confirm,    // ③ 감지 결과 확인
  advanced,   // ④ 심화조사
}

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
    required this.heritageId,
    this.autoCapture = false,
    this.initialPart,
  });

  final AiDetectionService aiService;
  final String heritageId;
  final bool autoCapture;
  final Map<String, dynamic>? initialPart;

  @override
  State<ImprovedDamageSurveyDialog> createState() =>
      _ImprovedDamageSurveyDialogState();
}

class _ImprovedDamageSurveyDialogState
    extends State<ImprovedDamageSurveyDialog> {
  // 조사 단계 관리
  SurveyStep _currentStep = SurveyStep.register;

  // ① 조사등록 단계 - 부재 선택 필드
  String? _selectedPartName;
  String? _selectedDirection;
  String? _selectedPosition;
  final TextEditingController _partNumberController = TextEditingController();

  final List<String> _partNames = ['기둥', '보', '도리', '창방', '평방', '장혀', '추녀', '서까래'];
  final List<String> _directions = ['동향', '서향', '남향', '북향'];
  List<String> _positions = PositionOptions.defaultPositions;

  // 이미지 데이터
  Uint8List? _imageBytes;
  String? _previousYearImageUrl; // 전년도 사진 URL
  bool _loadingPreviousPhoto = false;
  List<Map<String, dynamic>> _detections = [];
  bool _loading = false;
  String? _savedDocId; // 저장된 문서 ID (최종 저장 시 업데이트용)
  String? _savedImageUrl; // 저장된 이미지 URL

  // Firebase Service
  final _fb = FirebaseService();

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

  // 표준 손상 용어 전체 리스트 (문화재청 기준)
  final List<String> _standardDamageTerms = [
    // 구조적 손상
    '이격/이완', '기움', '들림', '축 변형', '침하', '유실',
    // 물리적 손상
    '탈락', '들뜸', '부러짐', '분리', '균열', '갈래', '박리/박락',
    '처짐/휨', '비틀림', '돌아감',
    // 생물·화학적 손상
    '공동화', '천공', '변색', '부후', '식물생장', '표면 오염균',
  ];

  // 사용자 정의 손상 용어 (직접 추가된 것들)
  final List<String> _customDamageTerms = [];

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
    _partNumberController.dispose();
    _locationController.dispose();
    _partController.dispose();
    _opinionController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  /// 전년도 손상부 조사 사진 자동 로드
  Future<void> _loadPreviousYearPhoto() async {
    // 부재 정보가 모두 입력되어 있는지 확인
    if (_selectedPartName == null || _selectedDirection == null || _selectedPosition == null) {
      return;
    }

    setState(() => _loadingPreviousPhoto = true);

    try {
      // 부재 정보를 조합하여 location 문자열 생성
      final partNumber = _partNumberController.text.trim();
      final locationPieces = <String>[
        _selectedDirection!,
        if (partNumber.isNotEmpty) '$partNumber번',
        _selectedPosition!,
      ];
      final location = '$_selectedPartName ${locationPieces.join(' ')}';

      // Firebase에서 전년도 사진 검색
      final photoUrl = await _fb.fetchPreviousYearPhoto(
        heritageId: widget.heritageId,
        location: location,
        partName: _selectedPartName,
        direction: _selectedDirection,
        number: partNumber,
        position: _selectedPosition,
      );

      if (mounted) {
        setState(() {
          _previousYearImageUrl = photoUrl;
          _loadingPreviousPhoto = false;
        });

        if (photoUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 전년도 조사 사진을 불러왔습니다'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPreviousPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전년도 사진 로드 실패: $e')),
        );
      }
    }
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
    if (!mounted) return;
    
    final picked = await ImageAcquire.pick(context);
    if (picked == null || !mounted) return;
    
    final (bytes, sizeGetter) = picked;
    
    // 이미지 크기 검증
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 데이터가 비어있습니다.')),
        );
      }
      return;
    }

    // 이미지 크기 가져오기 (에러 처리 포함)
    try {
      await sizeGetter();
    } catch (e) {
      debugPrint('⚠️ 이미지 크기 파싱 실패: $e');
      // 계속 진행 (크기 정보는 선택사항)
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _imageBytes = bytes;
      _detections = [];
      _selectedLabel = null;
      _selectedConfidence = null;
      _autoGrade = null;
      _autoExplanation = null;
    });

    try {
      // 1. Firebase에 사진 저장
      String? imageUrl;
      try {
        imageUrl = await _fb.uploadImage(
          heritageId: widget.heritageId,
          folder: 'damage_surveys',
          bytes: bytes,
        );
      } catch (e) {
        debugPrint('❌ Firebase 이미지 업로드 실패: $e');
        if (!mounted) return;
        
        String uploadError = '이미지 업로드 실패';
        if (e.toString().contains('permission-denied')) {
          uploadError = '이미지 업로드 권한이 없습니다.';
        } else if (e.toString().contains('quota')) {
          uploadError = 'Firebase Storage 할당량을 초과했습니다.';
        } else if (e.toString().contains('timeout')) {
          uploadError = '이미지 업로드 시간이 초과되었습니다.';
        }
        
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $uploadError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('이미지 URL을 받지 못했습니다.');
      }

      if (!mounted) return;

      // 2. AI 모델로 손상 탐지
      AiDetectionResult? detectionResult;
      try {
        detectionResult = await widget.aiService.detect(bytes);
      } catch (e) {
        debugPrint('❌ AI 감지 실패: $e');
        // AI 실패해도 이미지는 저장되었으므로 계속 진행
        detectionResult = null;
      }

      if (!mounted) return;

      List<Map<String, dynamic>> normalized = [];
      if (detectionResult != null && detectionResult.detections.isNotEmpty) {
        final sorted = List<Map<String, dynamic>>.from(detectionResult.detections)
          ..sort(
            (a, b) =>
                ((b['score'] as num?) ?? 0).compareTo(((a['score'] as num?) ?? 0)),
          );
        normalized = _normalizeDetections(sorted);
      }

      // 3. 손상부 조사 데이터를 Firebase에 저장 (초기 저장)
      String? docId;
      try {
        docId = await _saveDamageSurveyData(imageUrl, normalized);
        _savedDocId = docId;
        _savedImageUrl = imageUrl;
      } catch (e) {
        debugPrint('❌ 손상부 조사 데이터 저장 실패: $e');
        // 저장 실패해도 UI는 업데이트
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _detections = normalized;
        if (_detections.isNotEmpty) {
          _selectedLabel = _detections.first['label'] as String?;
          _selectedConfidence = (_detections.first['score'] as num?)?.toDouble();
          // 감지된 손상을 자동으로 선택
          final label = _selectedLabel;
          if (label != null && !_selectedDamageTypes.contains(label)) {
            _selectedDamageTypes.add(label);
          }
        }
        if (detectionResult != null) {
          final normalizedGrade = detectionResult.grade?.toUpperCase();
          _autoGrade = normalizedGrade;
          _autoExplanation = detectionResult.explanation;
          if (normalizedGrade != null &&
              ['A', 'B', 'C1', 'C2', 'D', 'E', 'F'].contains(normalizedGrade)) {
            _severityGrade = normalizedGrade;
          }
        }
      });

      // 4. 성공 메시지 표시
      if (mounted) {
        final message = detectionResult != null
            ? '사진이 저장되었고 AI 손상 탐지가 완료되었습니다.'
            : '사진이 저장되었습니다. (AI 감지는 실패했습니다)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: detectionResult != null ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 이미지 선택 및 감지 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });
      
      String errorMessage = '사진 처리 중 오류가 발생했습니다';
      
      // 구체적인 오류 메시지 제공
      final errorStr = e.toString();
      if (errorStr.contains('AiModelNotLoadedException')) {
        errorMessage = 'AI 모델이 아직 로드되지 않았습니다. 잠시 후 다시 시도해주세요.';
      } else if (errorStr.contains('AiConnectionException')) {
        errorMessage = 'AI 서버에 연결할 수 없습니다. 서버 상태를 확인해주세요.';
      } else if (errorStr.contains('AiTimeoutException')) {
        errorMessage = 'AI 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
      } else if (errorStr.contains('permission-denied')) {
        errorMessage = '저장 권한이 없습니다. Firebase 설정을 확인해주세요.';
      } else if (errorStr.contains('network') || errorStr.contains('Connection')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
        errorMessage = '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
      } else if (errorStr.length < 100) {
        errorMessage = '오류: $errorStr';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // 손상부 조사 데이터를 Firebase에 저장
  Future<String?> _saveDamageSurveyData(
    String imageUrl,
    List<Map<String, dynamic>> detections,
  ) async {
    // 입력 검증
    if (imageUrl.isEmpty) {
      throw ArgumentError('이미지 URL이 비어있습니다.');
    }
    if (widget.heritageId.isEmpty) {
      throw ArgumentError('heritageId가 비어있습니다.');
    }

    try {
      final damageSurveyData = {
        'heritageId': widget.heritageId,
        'imageUrl': imageUrl,
        'partName': _selectedPartName ?? '',
        'direction': _selectedDirection ?? '',
        'position': _selectedPosition ?? '',
        'partNumber': _partNumberController.text.trim(),
        'location': _locationController.text.trim(),
        'damagePart': _partController.text.trim(),
        'opinion': _opinionController.text.trim(),
        'temperature': _temperatureController.text.trim(),
        'humidity': _humidityController.text.trim(),
        'severityGrade': _severityGrade,
        'damageTypes': _selectedDamageTypes.toList(),
        'detections': detections,
        'selectedLabel': _selectedLabel,
        'selectedConfidence': _selectedConfidence,
        'autoGrade': _autoGrade,
        'autoExplanation': _autoExplanation,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final docId = await _fb.saveDamageSurvey(
        heritageId: widget.heritageId,
        data: damageSurveyData,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('손상부 조사 데이터 저장 시간 초과');
        },
      );

      if (docId == null || docId.isEmpty) {
        throw Exception('저장된 문서 ID를 받지 못했습니다.');
      }

      debugPrint('✅ 손상부 조사 데이터 저장 완료: $imageUrl, docId: $docId');
      return docId;
    } on TimeoutException {
      debugPrint('⏰ 손상부 조사 데이터 저장 타임아웃');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ 손상부 조사 데이터 저장 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 손상부 조사 데이터 업데이트
  Future<void> _updateDamageSurveyData(String docId, String imageUrl) async {
    // 입력 검증
    if (docId.isEmpty) {
      throw ArgumentError('문서 ID가 비어있습니다.');
    }
    if (imageUrl.isEmpty) {
      throw ArgumentError('이미지 URL이 비어있습니다.');
    }

    try {
      final updateData = {
        'imageUrl': imageUrl, // imageUrl도 업데이트에 포함
        'partName': _selectedPartName ?? '',
        'direction': _selectedDirection ?? '',
        'position': _selectedPosition ?? '',
        'partNumber': _partNumberController.text.trim(),
        'location': _locationController.text.trim(),
        'damagePart': _partController.text.trim(),
        'opinion': _opinionController.text.trim(),
        'temperature': _temperatureController.text.trim(),
        'humidity': _humidityController.text.trim(),
        'severityGrade': _severityGrade,
        'damageTypes': _selectedDamageTypes.toList(),
        'detections': _detections, // 감지 결과도 업데이트
        'selectedLabel': _selectedLabel,
        'selectedConfidence': _selectedConfidence,
        'autoGrade': _autoGrade,
        'autoExplanation': _autoExplanation,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _fb.updateDamageSurvey(
        heritageId: widget.heritageId,
        docId: docId,
        data: updateData,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('손상부 조사 데이터 업데이트 시간 초과');
        },
      );

      debugPrint('✅ 손상부 조사 데이터 업데이트 완료: $docId');
    } on TimeoutException {
      debugPrint('⏰ 손상부 조사 데이터 업데이트 타임아웃');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ 손상부 조사 데이터 업데이트 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 텍스트 데이터만 저장 (이미지 없이)
  Future<void> _saveTextDataOnly() async {
    try {
      final damageSurveyData = {
        'heritageId': widget.heritageId,
        'partName': _selectedPartName ?? '',
        'direction': _selectedDirection ?? '',
        'position': _selectedPosition ?? '',
        'partNumber': _partNumberController.text.trim(),
        'location': _locationController.text.trim(),
        'damagePart': _partController.text.trim(),
        'opinion': _opinionController.text.trim(),
        'temperature': _temperatureController.text.trim(),
        'humidity': _humidityController.text.trim(),
        'severityGrade': _severityGrade,
        'damageTypes': _selectedDamageTypes.toList(),
        'selectedLabel': _selectedLabel,
        'selectedConfidence': _selectedConfidence,
        'autoGrade': _autoGrade,
        'autoExplanation': _autoExplanation,
        'isTextOnly': true, // 텍스트만 저장된 데이터임을 표시
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _fb.saveDamageSurvey(
        heritageId: widget.heritageId,
        data: damageSurveyData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 텍스트 데이터가 저장되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ 텍스트 데이터 저장 완료');
    } catch (e) {
      debugPrint('❌ 텍스트 데이터 저장 실패: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('텍스트 저장 실패: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    // 단계별 처리
    switch (_currentStep) {
      case SurveyStep.register:
        // ① 조사등록 → ② 손상부 조사
        // 부재 선택 완료 확인
        if (_selectedPartName == null || _selectedDirection == null || _selectedPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('부재명, 향, 부재 내 위치를 모두 선택하세요.')),
          );
          return;
        }
        // 다음 단계로 이동
        setState(() {
          _currentStep = SurveyStep.detail;
          // 부재 정보를 prefilled로 설정
          _applyInitialPart({
            'partName': _selectedPartName,
            'partNumber': _partNumberController.text.trim(),
            'direction': _selectedDirection,
            'position': _selectedPosition,
          }, notify: false);
        });
        // 전년도 사진 자동 로드
        _loadPreviousYearPhoto();
        return;

      case SurveyStep.detail:
        // ② 손상부 조사 → ③ 감지 결과 확인
        if (_imageBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진을 먼저 촬영하거나 업로드하세요.')),
          );
          return;
        }
        setState(() => _currentStep = SurveyStep.confirm);
        return;

      case SurveyStep.confirm:
        // ③ 감지 결과 확인 → ④ 심화조사
        setState(() => _currentStep = SurveyStep.advanced);
        return;

      case SurveyStep.advanced:
        // ④ 심화조사 → 최종 저장
        break; // 아래 저장 로직으로 계속
    }

    // 최종 저장 확인
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

    // 최종 저장: 사용자가 입력한 모든 정보를 반영하여 업데이트
    try {
      String? imageUrl = _savedImageUrl;
      
      // 사진이 선택되었지만 아직 업로드되지 않은 경우 업로드
      // 전년도 사진 없이도 이번 조사 사진만으로 저장 가능하도록 수정
      if (_imageBytes != null && imageUrl == null) {
        debugPrint('📸 사진을 Firebase Storage에 업로드 중...');
        imageUrl = await _fb.uploadImage(
          heritageId: widget.heritageId,
          folder: 'damage_surveys',
          bytes: _imageBytes!,
        );
        _savedImageUrl = imageUrl;
        debugPrint('✅ 사진 업로드 완료: $imageUrl');
      }
      
      // 이미 저장된 문서가 있으면 업데이트 (전년도 사진 여부와 무관하게)
      if (_savedDocId != null && imageUrl != null) {
        await _updateDamageSurveyData(_savedDocId!, imageUrl);
        debugPrint('✅ 기존 문서 업데이트 완료: ${_savedDocId}');
      } 
      // 새로 저장해야 하는 경우 (전년도 사진 없이도 이번 조사 사진만으로 저장)
      else if (_imageBytes != null) {
        // imageUrl이 아직 없으면 업로드
        if (imageUrl == null) {
          debugPrint('📸 사진을 Firebase Storage에 업로드 중...');
          imageUrl = await _fb.uploadImage(
            heritageId: widget.heritageId,
            folder: 'damage_surveys',
            bytes: _imageBytes!,
          );
          _savedImageUrl = imageUrl;
          debugPrint('✅ 사진 업로드 완료: $imageUrl');
        }
        
        // AI 감지 결과가 없으면 빈 배열로 저장
        final detections = _detections.isNotEmpty
            ? List<Map<String, dynamic>>.from(_detections)
            : <Map<String, dynamic>>[];
        
        // 새 문서 생성 및 저장 (전년도 사진 없이도 저장)
        _savedDocId = await _saveDamageSurveyData(imageUrl!, detections);
        debugPrint('✅ 새 문서 저장 완료: $_savedDocId (전년도 사진 없이도 저장됨)');
      }
      // 사진이 없는 경우 텍스트만 저장
      else if (_imageBytes == null) {
        await _saveTextDataOnly();
        debugPrint('✅ 텍스트 데이터만 저장 완료');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('손상부 조사 데이터가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 최종 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // 저장 실패 시 다이얼로그 닫지 않음
    }

    // 결과 반환 (사진이 있는 경우에만)
    DamageDetectionResult? result;
    if (_imageBytes != null) {
      result = DamageDetectionResult(
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
    }

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
        'bbox': d['bbox'],  // 백엔드와 키 이름 일치 ('box' → 'bbox')
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // 단계 관리 헬퍼 메서드
  // ═══════════════════════════════════════════════════════════════

  String _getStepTitle() {
    switch (_currentStep) {
      case SurveyStep.register:
        return '① 조사 등록';
      case SurveyStep.detail:
        return '② 손상부 조사';
      case SurveyStep.confirm:
        return '③ 감지 결과 확인';
      case SurveyStep.advanced:
        return '④ 심화조사';
    }
  }

  String _getButtonText() {
    switch (_currentStep) {
      case SurveyStep.register:
        return '다음';
      case SurveyStep.detail:
        return '감지 결과 확인';
      case SurveyStep.confirm:
        return '심화조사 진행';
      case SurveyStep.advanced:
        return '저장';
    }
  }

  void _goBack() {
    setState(() {
      switch (_currentStep) {
        case SurveyStep.register:
          Navigator.pop(context);
          return;
        case SurveyStep.detail:
          _currentStep = SurveyStep.register;
          return;
        case SurveyStep.confirm:
          _currentStep = SurveyStep.detail;
          return;
        case SurveyStep.advanced:
          _currentStep = SurveyStep.confirm;
          return;
      }
    });
  }

  Widget _buildStepContent(Color headerColor, Color accentBlue, Color grayBg) {
    switch (_currentStep) {
      case SurveyStep.register:
        return _buildRegisterStep(headerColor);
      case SurveyStep.detail:
        return _buildDetailStep(headerColor, accentBlue);
      case SurveyStep.confirm:
        return _buildConfirmStep(headerColor, accentBlue);
      case SurveyStep.advanced:
        return _buildAdvancedStep(headerColor);
    }
  }

  // ① 조사등록 단계 - 부재 선택
  Widget _buildRegisterStep(Color headerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
                  Icon(Icons.architecture, color: headerColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '손상 조사할 부재를 선택하세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 부재명 선택 (필수)
              DropdownButtonFormField<String>(
                value: _selectedPartName,
                decoration: InputDecoration(
                  labelText: '부재명 *',
                  hintText: '부재명을 선택하세요',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  errorText: _currentStep == SurveyStep.register && _selectedPartName == null
                      ? '부재명을 선택해주세요'
                      : null,
                ),
                items: _partNames.map((name) {
                  return DropdownMenuItem(value: name, child: Text(name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPartName = value;
                    // 부재 유형에 따라 위치 옵션 업데이트
                    if (value != null) {
                      _positions = PositionOptions.getPositionsForMember(value);
                      // 현재 선택된 위치가 새로운 옵션에 없으면 초기화
                      if (_selectedPosition != null && !_positions.contains(_selectedPosition)) {
                        _selectedPosition = null;
                      }
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '부재명을 선택해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 부재번호 입력
              TextFormField(
                controller: _partNumberController,
                decoration: const InputDecoration(
                  labelText: '부재번호',
                  hintText: '예: 1, 2, 3...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // 향 선택 (필수)
              DropdownButtonFormField<String>(
                value: _selectedDirection,
                decoration: InputDecoration(
                  labelText: '향 *',
                  hintText: '향을 선택하세요',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  errorText: _currentStep == SurveyStep.register && _selectedDirection == null
                      ? '향을 선택해주세요'
                      : null,
                ),
                items: _directions.map((dir) {
                  return DropdownMenuItem(value: dir, child: Text(dir));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDirection = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '향을 선택해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 부재 내 위치 선택
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: const InputDecoration(
                  labelText: '부재 내 위치',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _positions.map((pos) {
                  final displayText = _selectedPartName != null 
                      ? PositionOptions.getPositionDisplayText(_selectedPartName!, pos)
                      : pos;
                  return DropdownMenuItem(value: pos, child: Text(displayText));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPosition = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ② 손상부 조사 단계 - 기존 UI
  Widget _buildDetailStep(Color headerColor, Color accentBlue) {
    return Column(
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
                _previousYearImageUrl,
                onTap: null, // 자동 로드되므로 탭 불필요
                isLoading: _loadingPreviousPhoto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPhotoBox(
                '이번 조사 사진 등록',
                _imageBytes,
                onTap: _loading ? null : _pickImageAndDetect,
                isLoading: _loading,
                detections: _detections.isNotEmpty ? _detections : null,
                imageWidth: 640,  // 4:3 비율 유지
                imageHeight: 480, // 4:3 비율 (640:480)
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

        // 5-1️⃣ 직접 추가 (표준 손상 용어 전체 선택)
        _buildSectionTitle('직접 추가 (표준 손상 용어)', Icons.add_circle_outline, headerColor),
        const SizedBox(height: 12),
        _buildDirectAddSection(),
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
    );
  }

  // ③ 감지 결과 확인 단계
  Widget _buildConfirmStep(Color headerColor, Color accentBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: accentBlue, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    '감지 결과를 확인하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 선택된 부재 정보
              if (_prefilledPart != null) ...[
                _buildPrefilledPartSummary(headerColor),
                const SizedBox(height: 20),
              ],

              // 촬영 이미지 (바운딩 박스 포함)
              if (_imageBytes != null) ...[
                const Text(
                  '촬영 이미지',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _detections.isNotEmpty
                    ? CustomPaint(
                        painter: BoundingBoxPainter(
                          detections: _detections,
                          imageWidth: 640,  // DETA 모델 입력 크기
                          imageHeight: 640,
                        ),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      )
                    : Image.memory(_imageBytes!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
              ],

              // 감지 결과
              _buildSectionTitle('AI 감지 결과', Icons.auto_graph, headerColor),
              const SizedBox(height: 12),
              _buildDetectionResult(accentBlue),
              const SizedBox(height: 20),

              // 손상 등급
              if (_autoGrade != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentBlue),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.assessment, color: accentBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI 판정 등급',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_autoGrade 등급 - ${_getGradeDescription(_autoGrade!)}',
                              style: TextStyle(
                                color: accentBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ④ 심화조사 단계
  Widget _buildAdvancedStep(Color headerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
                  Icon(Icons.science, color: headerColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '심화 조사',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '추가 조사 사항이 있으면 입력하세요.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: '심화 조사 내용',
                  hintText: '상세한 조사 내용을 입력하세요...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: '조치 권고사항',
                  hintText: '필요한 조치나 권고사항을 입력하세요...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = const Color(0xFF1C3763); // ✅ 진한 네이비 (명확한 대비)
    final accentBlue = const Color(0xFF1C3763);  // ✅ 포인트 네이비 (통일)
    final grayBg = const Color(0xFFF8FAFC); // 밝은 회색톤 배경

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
                  Text(
                    _getStepTitle(),
                    style: const TextStyle(
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
                child: _buildStepContent(headerColor, accentBlue, grayBg),
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
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: headerColor),
                      foregroundColor: headerColor,
                      minimumSize: const Size(100, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(_currentStep == SurveyStep.register ? '취소' : '이전'),
                  ),
                  const SizedBox(width: 12),
                  // 텍스트 데이터 저장 버튼 (단계 2, 3, 4에서만 표시)
                  if (_currentStep != SurveyStep.register)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton.icon(
                        onPressed: _saveTextDataOnly,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('텍스트 저장'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: headerColor,
                          side: BorderSide(color: headerColor),
                          minimumSize: const Size(120, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,              // ✅ #1C3763 (진한 네이비)
                      foregroundColor: Colors.white,            // ✅ #FFFFFF (흰색 텍스트)
                      disabledBackgroundColor: const Color(0xFFE6E9EF), // ✅ 비활성: 밝은 회색
                      disabledForegroundColor: const Color(0xFF8A93A3), // ✅ 비활성: 회색 텍스트
                      elevation: 0,
                      minimumSize: const Size(100, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _getButtonText(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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
    dynamic imageSource, {  // Uint8List? 또는 String? (URL) 지원
    VoidCallback? onTap,
    bool isLoading = false,
    List<Map<String, dynamic>>? detections,
    double? imageWidth,
    double? imageHeight,
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
            height: 240, // 4:3 비율을 위한 높이 조정 (320x240)
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                if (imageSource == null)
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
                else if (imageSource is String)
                  // URL인 경우 Image.network 사용
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageSource,
                      fit: BoxFit.contain, // 4:3 비율 유지
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 40),
                              SizedBox(height: 8),
                              Text('이미지 로드 실패', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else if (imageSource is Uint8List)
                  // Uint8List인 경우 Image.memory 사용
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (detections != null && detections.isNotEmpty && imageWidth != null && imageHeight != null)
                      ? CustomPaint(
                          painter: BoundingBoxPainter(
                            detections: detections,
                            imageWidth: imageWidth,
                            imageHeight: imageHeight,
                          ),
                          child: Image.memory(
                            imageSource,
                            fit: BoxFit.contain, // 4:3 비율 유지
                            width: double.infinity,
                          ),
                        )
                      : Image.memory(
                          imageSource,
                          fit: BoxFit.contain, // 4:3 비율 유지
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
          _buildDamageCategory('구조적 손상', ['균열', '이격', '탈락', '기울어짐', '변형']),
          const Divider(height: 24),
          _buildDamageCategory('물리적 손상', ['부식', '박리', '파손', '변색', '침식']),
          const Divider(height: 24),
          _buildDamageCategory('생물·화학적 손상', ['백화', '오염', '곰팡이', '이끼', '생물 부착']),
          const Divider(height: 24),
          _buildDamageCategory('재료적 손상', ['재료 분리', '표면 박락', '내부 붕괴']),
          const Divider(height: 24),
          _buildDamageCategory('기타 손상', ['낙서', '결손', '외부 충격']),
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

  // 직접 추가 섹션 - 표준 손상 용어 전체 선택
  Widget _buildDirectAddSection() {
    // 표준 용어 + 사용자 정의 용어 합치기
    final allTerms = [..._standardDamageTerms, ..._customDamageTerms];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 문구
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1E2A44),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '표준 손상 용어를 직접 선택하거나, 새로운 손상 유형을 추가할 수 있습니다.',
                    style: TextStyle(
                      color: const Color(0xFF1E2A44),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 표준 손상 용어 전체 선택
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTerms.map((term) {
              final isSelected = _selectedDamageTypes.contains(term);
              final isCustom = _customDamageTerms.contains(term);

              return FilterChip(
                label: Text(term),
                selected: isSelected,
                selectedColor: const Color(0xFF2C3E8C).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF2C3E8C),
                backgroundColor: isCustom
                    ? const Color(0xFFE8ECF3)
                    : Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF2C3E8C)
                      : const Color(0xFFD1D5DB),
                  width: 1,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDamageTypes.add(term);
                    } else {
                      _selectedDamageTypes.remove(term);
                    }
                  });
                },
                deleteIcon: isCustom
                    ? const Icon(Icons.close, size: 16)
                    : null,
                onDeleted: isCustom
                    ? () {
                        setState(() {
                          _customDamageTerms.remove(term);
                          _selectedDamageTypes.remove(term);
                        });
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 직접 추가 버튼
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _showCustomDamageAddDialog,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF1E2A44)),
              label: const Text(
                '새 손상 유형 추가',
                style: TextStyle(
                  color: Color(0xFF1E2A44),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF1E2A44), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 커스텀 손상 유형 추가 다이얼로그
  void _showCustomDamageAddDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          '새 손상 유형 추가',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '표준 용어에 없는 새로운 손상 유형을 입력하세요.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '예: 목재 탈색, 균열 확장',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44), width: 1.2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newTerm = controller.text.trim();
              if (newTerm.isNotEmpty) {
                setState(() {
                  if (!_customDamageTerms.contains(newTerm) &&
                      !_standardDamageTerms.contains(newTerm)) {
                    _customDamageTerms.add(newTerm);
                    _selectedDamageTypes.add(newTerm);
                  }
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
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
            items: const ['A', 'B', 'C1', 'C2', 'D', 'E', 'F']
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
      case 'C1':
        return '주의 - 경미한 손상, 정기적 관찰 필요';
      case 'C2':
        return '주의 - 중간 손상, 모니터링 및 예방 조치 필요';
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

/// 바운딩 박스를 이미지 위에 그리는 CustomPainter
class BoundingBoxPainter extends CustomPainter {
  const BoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<Map<String, dynamic>> detections;
  final double imageWidth;
  final double imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final bbox = det['bbox'] as List?;
      if (bbox == null || bbox.length != 4) continue;

      final x1 = (bbox[0] as num).toDouble();
      final y1 = (bbox[1] as num).toDouble();
      final x2 = (bbox[2] as num).toDouble();
      final y2 = (bbox[3] as num).toDouble();

      final scaleX = size.width / imageWidth;
      final scaleY = size.height / imageHeight;

      final rect = Rect.fromLTRB(
        x1 * scaleX,
        y1 * scaleY,
        x2 * scaleX,
        y2 * scaleY,
      );

      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      final label = det['label'] as String? ?? '';
      final score = (det['score'] as num?)?.toDouble() ?? 0;
      final text = '$label ${(score * 100).toStringAsFixed(0)}%';

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textBg = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRect(textBg, Paint()..color = Colors.red);
      textPainter.paint(canvas, Offset(rect.left + 4, textBg.top + 2));
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}
