// lib/screens/detail_survey_screen.dart (⑤ 상세조사 화면)

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/widgets/section.dart';
import '../ui/widgets/attach_tile.dart';
import '../ui/widgets/yellow_nav_button.dart';
import '../services/firebase_service.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/responsive_page.dart';
import 'damage_model_screen.dart';
import 'damage_part_dialog.dart';
import 'detail_sections/survey_sections_panel.dart';

class DetailSurveyScreen extends StatefulWidget {
  static const route = '/detail-survey';
  final String? heritageId;
  final String? heritageName;
  
  const DetailSurveyScreen({
    super.key,
    this.heritageId,
    this.heritageName,
  });

  @override
  State<DetailSurveyScreen> createState() => _DetailSurveyScreenState();
}

class _DetailSurveyScreenState extends State<DetailSurveyScreen> {
  final _firebaseService = FirebaseService();
  final _picker = ImagePicker();

  // 기록개요 필드
  final _section = TextEditingController();
  final _period = TextEditingController();
  final _writer = TextEditingController();
  final _note = TextEditingController();

  // 보존이력 (간단 테이블 목업 데이터)
  final List<Map<String, String>> _history = [
    {'date': '2021-05-01', 'desc': '부분 보수(지붕 기와)'},
  ];

  // 손상요소
  final List<Map<String, dynamic>> _damages = [];

  // 조사 결과 필드들
  final _inspectionResult = TextEditingController();
  final _managementItems = TextEditingController();
  final _damageSummary = TextEditingController();
  final _investigatorOpinion = TextEditingController();
  final _gradeClassification = TextEditingController();
  final _existingHistory = TextEditingController();

  // 새로운 섹션 필드들 (1.1, 1.2, 1.3)
  final _section11Foundation = TextEditingController();
  final _section11Wall = TextEditingController();
  final _section11Roof = TextEditingController();
  final _section11Paint = TextEditingController();
  final _section11Pest = TextEditingController();
  final _section11Etc = TextEditingController();
  final _section11SafetyNotes = TextEditingController();
  final _section11InvestigatorOpinion = TextEditingController();
  final _section11Grade = TextEditingController();

  // 1.2 보존사항 (간단한 텍스트 필드로 구현)
  final _section12Conservation = TextEditingController();

  // 1.3 관리사항
  final _section13Safety = TextEditingController();
  final _section13Electric = TextEditingController();
  final _section13Gas = TextEditingController();
  final _section13Guard = TextEditingController();
  final _section13Care = TextEditingController();
  final _section13Guide = TextEditingController();
  final _section13Surroundings = TextEditingController();
  final _section13Usage = TextEditingController();

  // 저장 상태
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // 저장된 데이터 로드 (병렬 처리)
  Future<void> _loadSavedData() async {
    if (widget.heritageId == null) {
      debugPrint('⚠️ HeritageId가 null입니다. 데이터를 로드할 수 없습니다.');
      return;
    }
    
    debugPrint('🔄 데이터 로드 시작 - HeritageId: ${widget.heritageId}');
    setState(() => _isLoading = true);
    
    try {
      // 병렬로 여러 데이터 소스 로드
      final futures = <Future>[];
      
      // 1. 상세 조사 데이터
      futures.add(_firebaseService.getDetailSurveys(widget.heritageId!));
      
      // 2. 추가 데이터가 있다면 여기에 추가
      // futures.add(_loadAdditionalData());
      
      final results = await Future.wait(futures);
      
      if (results.isNotEmpty) {
        final snapshot = results[0] as QuerySnapshot;
        debugPrint('📊 Firestore에서 ${snapshot.docs.length}개의 문서를 찾았습니다.');

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data() as Map<String, dynamic>;
          debugPrint('📋 로드된 데이터 키들: ${data.keys.toList()}');
          _loadDataIntoFields(data);
          debugPrint('✅ 데이터 로드 완료');
        } else {
          debugPrint('📭 저장된 데이터가 없습니다.');
        }
      }
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 데이터를 폼 필드에 로드
  void _loadDataIntoFields(Map<String, dynamic> data) {
    // 기록개요
    if (data['recordOverview'] != null) {
      final overview = data['recordOverview'] as Map<String, dynamic>;
      _section.text = overview['section'] ?? '';
      _period.text = overview['period'] ?? '';
      _writer.text = overview['writer'] ?? '';
      _note.text = overview['note'] ?? '';
    }

    // 보존이력
    if (data['conservationHistory'] != null) {
      _history.clear();
      _history.addAll((data['conservationHistory'] as List)
          .map((item) => Map<String, String>.from(item)));
    }

    // 손상요소
    if (data['damageItems'] != null) {
      _damages.clear();
      _damages.addAll((data['damageItems'] as List)
          .map((item) => Map<String, dynamic>.from(item)));
    }

    // 기타 필드들
    _inspectionResult.text = data['inspectionResult'] ?? '';
    _managementItems.text = data['managementItems'] ?? '';
    _damageSummary.text = data['damageSummary'] ?? '';
    _investigatorOpinion.text = data['investigatorOpinion'] ?? '';
    _gradeClassification.text = data['gradeClassification'] ?? '';
    _existingHistory.text = data['existingHistory'] ?? '';
    
    debugPrint('📝 로드된 기본 필드들:');
    debugPrint('  - 주요 점검 결과: "${_inspectionResult.text}"');
    debugPrint('  - 관리사항: "${_managementItems.text}"');
    debugPrint('  - 손상부 종합: "${_damageSummary.text}"');
    debugPrint('  - 조사자 의견: "${_investigatorOpinion.text}"');
    debugPrint('  - 등급 분류: "${_gradeClassification.text}"');
    debugPrint('  - 기존 이력: "${_existingHistory.text}"');

    // 새로운 섹션들 (1.1, 1.2, 1.3)
    if (data['section11'] != null) {
      final section11 = data['section11'] as Map<String, dynamic>;
      debugPrint('🔍 Section11 데이터 로드: ${section11.keys.toList()}');
      _section11Foundation.text = section11['foundation'] ?? '';
      _section11Wall.text = section11['wall'] ?? '';
      _section11Roof.text = section11['roof'] ?? '';
      _section11Paint.text = section11['paint'] ?? '';
      _section11Pest.text = section11['pest'] ?? '';
      _section11Etc.text = section11['etc'] ?? '';
      _section11SafetyNotes.text = section11['safetyNotes'] ?? '';
      _section11InvestigatorOpinion.text = section11['investigatorOpinion'] ?? '';
      _section11Grade.text = section11['grade'] ?? '';
      debugPrint('📝 로드된 Section11 값들:');
      debugPrint('  - 기단부: "${_section11Foundation.text}"');
      debugPrint('  - 축부: "${_section11Wall.text}"');
      debugPrint('  - 지붕부: "${_section11Roof.text}"');
      debugPrint('  - 채색: "${_section11Paint.text}"');
      debugPrint('  - 충해: "${_section11Pest.text}"');
      debugPrint('  - 기타: "${_section11Etc.text}"');
      debugPrint('  - 특기사항: "${_section11SafetyNotes.text}"');
      debugPrint('  - 조사자 의견: "${_section11InvestigatorOpinion.text}"');
      debugPrint('  - 등급: "${_section11Grade.text}"');
    } else {
      debugPrint('⚠️ Section11 데이터가 없습니다.');
    }

    if (data['section12'] != null) {
      final section12 = data['section12'] as Map<String, dynamic>;
      _section12Conservation.text = section12['conservation'] ?? '';
    }

    if (data['section13'] != null) {
      final section13 = data['section13'] as Map<String, dynamic>;
      _section13Safety.text = section13['safety'] ?? '';
      _section13Electric.text = section13['electric'] ?? '';
      _section13Gas.text = section13['gas'] ?? '';
      _section13Guard.text = section13['guard'] ?? '';
      _section13Care.text = section13['care'] ?? '';
      _section13Guide.text = section13['guide'] ?? '';
      _section13Surroundings.text = section13['surroundings'] ?? '';
      _section13Usage.text = section13['usage'] ?? '';
    }

    setState(() {});
  }

  // ─────────────────────────────────────────────
  // 전체 조사 데이터 저장
  // ─────────────────────────────────────────────
  Future<void> _handleSave() async {
    print('🚨 _handleSave 함수가 호출되었습니다!');
    debugPrint('🚨 _handleSave 함수가 호출되었습니다!');
    
    if (_isSaving) {
      print('⚠️ 이미 저장 중입니다. 중복 호출 방지됨.');
      return;
    }

    print('🔄 저장 상태를 true로 설정합니다.');
    setState(() => _isSaving = true);

    try {
      // heritageId와 heritageName 확인
      final heritageId = widget.heritageId ?? "UNKNOWN_HERITAGE";
      final heritageName = widget.heritageName ?? "알 수 없는 문화유산";
      
      print('🔍 저장 시작 - HeritageId: $heritageId, HeritageName: $heritageName');
      debugPrint('🔍 저장 시작 - HeritageId: $heritageId, HeritageName: $heritageName');

      // Firebase 연결 테스트
      debugPrint('🧪 Firebase 연결 테스트 중...');
      final connectionTest = await _firebaseService.testFirebaseConnection();
      if (!connectionTest) {
        throw Exception('Firebase 연결 실패 - 데이터베이스에 접근할 수 없습니다.');
      }
      debugPrint('✅ Firebase 연결 확인 완료');

      // 조사 데이터 수집
      final surveyData = {
        'recordOverview': {
          'section': _section.text.trim(),
          'period': _period.text.trim(),
          'writer': _writer.text.trim(),
          'note': _note.text.trim(),
        },
        'conservationHistory': _history,
        'damageItems': _damages,
        'inspectionResult': _inspectionResult.text.trim(),
        'managementItems': _managementItems.text.trim(),
        'damageSummary': _damageSummary.text.trim(),
        'investigatorOpinion': _investigatorOpinion.text.trim(),
        'gradeClassification': _gradeClassification.text.trim(),
        'existingHistory': _existingHistory.text.trim(),
        
        // 새로운 섹션들 (1.1, 1.2, 1.3)
        'section11': {
          'foundation': _section11Foundation.text.trim(),
          'wall': _section11Wall.text.trim(),
          'roof': _section11Roof.text.trim(),
          'paint': _section11Paint.text.trim(),
          'pest': _section11Pest.text.trim(),
          'etc': _section11Etc.text.trim(),
          'safetyNotes': _section11SafetyNotes.text.trim(),
          'investigatorOpinion': _section11InvestigatorOpinion.text.trim(),
          'grade': _section11Grade.text.trim(),
        },
        'section12': {
          'conservation': _section12Conservation.text.trim(),
        },
        'section13': {
          'safety': _section13Safety.text.trim(),
          'electric': _section13Electric.text.trim(),
          'gas': _section13Gas.text.trim(),
          'guard': _section13Guard.text.trim(),
          'care': _section13Care.text.trim(),
          'guide': _section13Guide.text.trim(),
          'surroundings': _section13Surroundings.text.trim(),
          'usage': _section13Usage.text.trim(),
        },
        
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 저장할 데이터 로깅
      debugPrint('📝 저장할 데이터:');
      debugPrint('  - 기록개요 섹션: ${_section.text.trim()}');
      debugPrint('  - 기록개요 기간: ${_period.text.trim()}');
      debugPrint('  - 기록개요 작성자: ${_writer.text.trim()}');
      debugPrint('  - 기록개요 비고: ${_note.text.trim()}');
      debugPrint('  - 주요 점검 결과: ${_inspectionResult.text.trim()}');
      debugPrint('  - 관리사항: ${_managementItems.text.trim()}');
      debugPrint('  - 손상부 종합: ${_damageSummary.text.trim()}');
      debugPrint('  - 조사자 의견: ${_investigatorOpinion.text.trim()}');
      debugPrint('  - 등급 분류: ${_gradeClassification.text.trim()}');
      debugPrint('  - 기존 이력: ${_existingHistory.text.trim()}');
      debugPrint('  - 기단부: ${_section11Foundation.text.trim()}');
      debugPrint('  - 축부(벽체부): ${_section11Wall.text.trim()}');
      debugPrint('  - 지붕부: ${_section11Roof.text.trim()}');
      debugPrint('  - 보존사항: ${_section12Conservation.text.trim()}');
      debugPrint('  - 소방 및 안전관리: ${_section13Safety.text.trim()}');
      debugPrint('  - 데이터 크기: ${surveyData.toString().length} 문자');

      // Firebase에 저장 (사진과 동일한 방식)
      print('🔥 Firebase 저장 시작 - HeritageId: $heritageId');
      debugPrint('🔥 Firebase 저장 시작 - HeritageId: $heritageId');
      
      await _firebaseService.addDetailSurvey(
        heritageId: heritageId,
        heritageName: heritageName,
        surveyData: surveyData,
      );
      
      print('✅ Firebase 저장 완료 - HeritageId: $heritageId');
      debugPrint('✅ Firebase 저장 완료 - HeritageId: $heritageId');

      if (mounted) {
        // 성공 다이얼로그 표시
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('저장 완료!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Firebase 데이터베이스에 성공적으로 저장되었습니다.'),
                const SizedBox(height: 8),
                Text('📋 문화유산: $heritageName'),
                const SizedBox(height: 8),
                Text('🆔 ID: $heritageId'),
                const SizedBox(height: 8),
                const Text('💾 저장된 필드들:'),
                const SizedBox(height: 4),
                const Text('• 기록개요 (섹션, 기간, 작성자, 비고)'),
                const Text('• 주요 점검 결과'),
                const Text('• 관리사항'),
                const Text('• 손상부 종합'),
                const Text('• 조사자 의견'),
                const Text('• 등급 분류'),
                const Text('• 기존 이력'),
                const Text('• 1.1 조사결과 (기단부, 축부, 지붕부 등)'),
                const Text('• 1.2 보존사항'),
                const Text('• 1.3 관리사항'),
                const SizedBox(height: 8),
                const Text('🔄 새로고침 후에도 모든 데이터가 유지됩니다.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        
        debugPrint('🎉 저장 성공 다이얼로그 표시됨');
        
        // 저장 후 데이터 다시 로드하여 확인 (실제 저장 검증)
        debugPrint('🔄 저장 검증을 위해 데이터 다시 로드 중...');
        await Future.delayed(const Duration(milliseconds: 2000)); // Firebase 동기화 대기
        await _loadSavedData();
        debugPrint('✅ 저장 검증 완료');
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

  // ─────────────────────────────────────────────
  // 새로운 섹션들 UI 구성
  Widget _buildSurveySections() {
    return Column(
      children: [
        // 1.1 조사결과
        Section(
          title: '1.1 조사결과',
          child: Column(
            children: [
              TextField(
                controller: _section11Foundation,
                decoration: const InputDecoration(
                  labelText: '기단부',
                  hintText: '기단부 조사 결과를 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Wall,
                decoration: const InputDecoration(
                  labelText: '축부(벽체부)',
                  hintText: '축부 조사 결과를 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Roof,
                decoration: const InputDecoration(
                  labelText: '지붕부',
                  hintText: '지붕부 조사 결과를 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Paint,
                decoration: const InputDecoration(
                  labelText: '채색(단청, 벽화)',
                  hintText: '채색 조사 결과를 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Pest,
                decoration: const InputDecoration(
                  labelText: '충해',
                  hintText: '충해 조사 결과를 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Etc,
                decoration: const InputDecoration(
                  labelText: '기타',
                  hintText: '기타 조사 결과를 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11SafetyNotes,
                decoration: const InputDecoration(
                  labelText: '특기사항',
                  hintText: '특기사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11InvestigatorOpinion,
                decoration: const InputDecoration(
                  labelText: '조사자 종합의견',
                  hintText: '조사자의 종합적인 의견을 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section11Grade,
                decoration: const InputDecoration(
                  labelText: '등급분류',
                  hintText: 'A, B, C, D, E, F 등급 중 선택하세요',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 1.2 보존사항(목조)
        Section(
          title: '1.2 보존사항(목조)',
          child: TextField(
            controller: _section12Conservation,
            decoration: const InputDecoration(
              labelText: '보존사항',
              hintText: '보존사항을 입력하세요',
            ),
            maxLines: 4,
          ),
        ),
        const SizedBox(height: 20),

        // 1.3 관리사항
        Section(
          title: '1.3 관리사항',
          child: Column(
            children: [
              TextField(
                controller: _section13Safety,
                decoration: const InputDecoration(
                  labelText: '소방 및 안전관리',
                  hintText: '소방 및 안전관리 사항을 입력하세요',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Electric,
                decoration: const InputDecoration(
                  labelText: '전기시설',
                  hintText: '전기시설 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Gas,
                decoration: const InputDecoration(
                  labelText: '가스시설',
                  hintText: '가스시설 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Guard,
                decoration: const InputDecoration(
                  labelText: '안전경비인력',
                  hintText: '안전경비인력 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Care,
                decoration: const InputDecoration(
                  labelText: '돌봄사업',
                  hintText: '돌봄사업 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Guide,
                decoration: const InputDecoration(
                  labelText: '안내 및 전시시설',
                  hintText: '안내 및 전시시설 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Surroundings,
                decoration: const InputDecoration(
                  labelText: '주변 및 부대시설',
                  hintText: '주변 및 부대시설 관리사항을 입력하세요',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section13Usage,
                decoration: const InputDecoration(
                  labelText: '원래기능/활용상태/사용빈도',
                  hintText: '원래기능/활용상태/사용빈도를 입력하세요',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 손상요소 신규 등록 (도면 선택 → 카메라/갤러리 → Firestore 저장)
  // ─────────────────────────────────────────────
  Future<void> _pickAndUploadDamage(ImageSource source) async {
    // 1) 도면에서 부재 선택 (Dialog 방식)
    if (!mounted) return;
    final selectedPart = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const DamagePartDialog(),
    );
    if (selectedPart == null) return;

    // 2) 카메라 또는 갤러리에서 이미지 가져오기
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    // 3) 바이트 변환
    final Uint8List bytes = await pickedFile.readAsBytes();

    // 4) 손상 정보 입력 다이얼로그 (부재 정보 포함)
    if (!mounted) return;
    final item = await _showAddDamageDialog(context, selectedPart);
    if (item == null) return;

    // 5) Firestore에 저장
    await _firebaseService.addDamageSurvey(
      heritageId: widget.heritageId ?? "UNKNOWN_HERITAGE",
      heritageName: widget.heritageName ?? "알 수 없는 문화유산",
      imageBytes: bytes,
      detections: [],
      location: "${selectedPart['name']} #${selectedPart['id']}",
      phenomenon: item['type'],
      severityGrade: item['severity'],
      inspectorOpinion: item['memo'],
    );

    // 6) UI 반영
    setState(() => _damages.add(item));
  }

  // 도면 선택 없이 손상요소 등록 (기존 방식)
  Future<void> _addDamageManually() async {
    if (!mounted) return;
    final item = await _showAddDamageDialog(context, null);
    if (item == null) return;

    setState(() => _damages.add(item));
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 설정
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final crossAxisCount = isMobile ? 1 : 2;
    final horizontalPadding = isMobile ? 12.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text('상세 조사')),
      body: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonCard(width: 300, height: 200),
                  SizedBox(height: 16),
                  SkeletonText(width: 200, height: 20),
                  SizedBox(height: 8),
                  SkeletonText(width: 150, height: 16),
                ],
              ),
            )
          : ResponsivePage(
              maxWidth: 1100.0,
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // (1) 기록개요
                Section(
                  title: '기록개요',
                  child: GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    childAspectRatio: isMobile ? 4.0 : 3.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TextField(
                        controller: _section,
                        decoration: const InputDecoration(labelText: '구/부/세부명'),
                      ),
                      TextField(
                        controller: _period,
                        decoration: const InputDecoration(labelText: '시정/지정일(예시)'),
                      ),
                      TextField(
                        controller: _writer,
                        decoration: const InputDecoration(labelText: '작성인'),
                      ),
                      TextField(
                        controller: _note,
                        decoration: const InputDecoration(labelText: '메모/비고'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // (2) 보존이력
                Section(
                  title: '보존이력',
                  action: OutlinedButton.icon(
                    onPressed: () async {
                      final item = await _showAddHistoryDialog(context);
                      if (item != null) setState(() => _history.add(item));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('추가'),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: isMobile ? 12 : 24,
                      headingRowHeight: 40,
                      dataRowHeight: 48,
                      columns: const [
                        DataColumn(label: Text('일자')),
                        DataColumn(label: Text('내용')),
                      ],
                      rows: _history
                          .map(
                            (h) => DataRow(
                          cells: [
                            DataCell(Text(h['date']!)),
                            DataCell(Text(h['desc']!)),
                          ],
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // (3) 첨부 (목업 상태 그대로)
                Section(
                  title: '첨부',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      AttachTile(icon: Icons.photo_camera, label: '사진촬영(목업)'),
                      AttachTile(icon: Icons.image_outlined, label: '사진선택'),
                      AttachTile(icon: Icons.info_outline, label: '메타데이터'),
                      AttachTile(icon: Icons.mic_none, label: '음성기록'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // (4) 손상요소
                Section(
                  title: '손상요소',
                  action: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _pickAndUploadDamage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('도면+촬영'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff003B7A),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _pickAndUploadDamage(ImageSource.gallery),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('도면+갤러리'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff003B7A),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addDamageManually,
                        icon: const Icon(Icons.add),
                        label: const Text('수동 등록'),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final d in _damages)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.report_problem_outlined),
                            title: Text('${d['type']} · 심각도 ${d['severity']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (d['partName'] != null && d['partName'].toString().isNotEmpty)
                                  Text('부재: ${d['partName']} #${d['partNumber']} (${d['direction']})'),
                                Text('${d['memo']}'),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // New Survey Sections (1.1, 1.2, 1.3) - Integrated with main save
                if (widget.heritageId != null)
                  _buildSurveySections(),
                const SizedBox(height: 20),

                // (5) 1.1 조사 결과
                Section(
                  title: '1.1 조사 결과',
                  child: TextField(
                    controller: _inspectionResult,
                    decoration: const InputDecoration(
                      labelText: '1.1 조사 결과를 입력하세요',
                      hintText: '조사 결과를 상세히 기록하세요',
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),

                // (6) 관리사항
                Section(
                  title: '관리사항',
                  child: TextField(
                    controller: _managementItems,
                    decoration: const InputDecoration(
                      labelText: '관리사항을 입력하세요',
                      hintText: '관리해야 할 사항들을 기록하세요',
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),

                // (7) 손상부 종합
                Section(
                  title: '손상부 종합',
                  child: TextField(
                    controller: _damageSummary,
                    decoration: const InputDecoration(
                      labelText: '손상부 종합 내용을 입력하세요',
                      hintText: '손상부에 대한 종합적인 분석을 기록하세요',
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),

                // (8) 조사자 의견
                Section(
                  title: '조사자 의견',
                  child: TextField(
                    controller: _investigatorOpinion,
                    decoration: const InputDecoration(
                      labelText: '조사자 의견을 입력하세요',
                      hintText: '조사자의 전문적인 의견을 기록하세요',
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),

                // (9) 등급 분류
                Section(
                  title: '등급 분류',
                  child: TextField(
                    controller: _gradeClassification,
                    decoration: const InputDecoration(
                      labelText: '등급 분류를 입력하세요',
                      hintText: 'A, B, C, D, E, F 등급 중 선택하세요',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // (10) 기존이력
                Section(
                  title: '기존이력',
                  child: TextField(
                    controller: _existingHistory,
                    decoration: const InputDecoration(
                      labelText: '기존이력을 입력하세요',
                      hintText: '과거 조사 이력이나 관련 기록을 입력하세요',
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 20),

                // 저장 버튼
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? '저장 중...' : '모든 데이터 저장'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff003B7A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 이전/다음 네비게이션
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('기본정보로'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: YellowNavButton(
                        label: '다음(손상 예측/모델)',
                        onTap: () => Navigator.pushNamed(
                          context,
                          DamageModelScreen.route,
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
    );
  }

  // 보존이력 추가 다이얼로그
  Future<Map<String, String>?> _showAddHistoryDialog(BuildContext context) async {
    final date = TextEditingController();
    final desc = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('보존이력 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: date,
              decoration: const InputDecoration(labelText: '일자 (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: '내용'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {'date': date.text, 'desc': desc.text}),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 손상요소 신규 등록 다이얼로그
  Future<Map<String, String>?> _showAddDamageDialog(
    BuildContext context,
    Map<String, dynamic>? selectedPart,
  ) async {
    final partName = TextEditingController(text: selectedPart?['name'] ?? '');
    final partNumber = TextEditingController(text: selectedPart != null ? '${selectedPart['id']}' : '');
    final direction = TextEditingController(text: selectedPart?['direction'] ?? '');
    final type = TextEditingController();
    final severity = ValueNotifier<String>('중');
    final memo = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('손상요소 등록'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 부재 정보 (도면에서 선택한 경우 자동 입력됨)
              if (selectedPart != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xff003B7A), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '도면에서 선택된 부재',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('부재명: ${selectedPart['name']}'),
                      Text('부재번호: ${selectedPart['id']}'),
                      Text('향: ${selectedPart['direction']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: partName,
                decoration: const InputDecoration(labelText: '부재명'),
                readOnly: selectedPart != null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: partNumber,
                decoration: const InputDecoration(labelText: '부재번호'),
                readOnly: selectedPart != null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: direction,
                decoration: const InputDecoration(labelText: '향'),
                readOnly: selectedPart != null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: type,
                decoration: const InputDecoration(labelText: '손상유형(예: 균열/박락/오염)'),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder(
                valueListenable: severity,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: '심각도'),
                  items: const [
                    DropdownMenuItem(value: '경', child: Text('경')),
                    DropdownMenuItem(value: '중', child: Text('중')),
                    DropdownMenuItem(value: '심', child: Text('심')),
                  ],
                  onChanged: (v) => severity.value = v!,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: memo,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'partName': partName.text,
              'partNumber': partNumber.text,
              'direction': direction.text,
              'type': type.text,
              'severity': severity.value,
              'memo': memo.text,
            }),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff003B7A),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
