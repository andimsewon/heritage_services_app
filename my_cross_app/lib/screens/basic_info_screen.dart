import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/heritage_api.dart';
import '../env.dart';
import '../services/firebase_service.dart';
import '../services/ai_detection_service.dart';
import '../services/image_acquire.dart';
import '../models/heritage_detail_models.dart';
import '../repositories/ai_prediction_repository.dart';
import '../ui/heritage_detail/ai_prediction_section.dart';
import '../ui/heritage_detail/damage_summary_table.dart';
import '../ui/heritage_detail/grade_classification_card.dart';
import '../ui/heritage_detail/inspection_result_card.dart';
import '../ui/heritage_detail/investigator_opinion_field.dart';
import '../ui/widgets/section_divider.dart';
import '../viewmodels/heritage_detail_view_model.dart';
import '../utils/date_formatter.dart';
import 'improved_damage_survey_dialog.dart';
import '../ui/heritage_detail/management_items_card.dart';
import '../ui/heritage_detail/location_status_card.dart';
import '../ui/section_form/section_form_widget.dart';
import '../models/section_form_models.dart';
import 'detail_survey_screen.dart';

String _proxyImageUrl(String originalUrl) {
  if (originalUrl.contains('firebasestorage.googleapis.com')) {
    final proxyBase = Env.proxyBase;
    return '$proxyBase/image/proxy?url=${Uri.encodeComponent(originalUrl)}';
  }
  return originalUrl;
}

bool _isValidImageUrl(String url) {
  if (url.isEmpty) return false;
  try {
    final uri = Uri.parse(url);
    return uri.scheme.isNotEmpty && uri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ── 누락된 설정용 타입 (const로 쓰기 때문에 반드시 const 생성자 필요)
class _SurveyRowConfig {
  const _SurveyRowConfig({required this.key, required this.label, this.hint});

  final String key;
  final String label;
  final String? hint;
}

class _ConservationRowConfig {
  const _ConservationRowConfig({
    required this.key,
    required this.section,
    required this.part,
    this.noteHint,
    this.locationHint,
  });

  final String key;
  final String section;
  final String part;
  final String? noteHint;
  final String? locationHint;
}

/// ④ 기본개요 화면
class BasicInfoScreen extends StatefulWidget {
  static const route = '/basic-info';
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  Map<String, dynamic>? _args;
  Map<String, dynamic>? _detail; // 상세 API 원본(JSON)
  bool _loading = true;
  late String heritageId;
  late final HeritageApi _api = HeritageApi(Env.proxyBase);
  final _fb = FirebaseService();
  final _ai = AiDetectionService(
    baseUrl: Env.proxyBase.replaceFirst(':8080', ':8081'),
  );
  HeritageDetailViewModel? _detailViewModel;
  final ScrollController _detailScrollController = ScrollController();
  late final AIPredictionRepository _aiPredictionRepository =
_MockAIPredictionRepository();

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

  // 1.2 보존사항
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

  // 1.4 유지보수/수리 이력
  bool _precisionDiagnosis = false;
  bool _careProject = false;
  final TextEditingController _repairRecordController = TextEditingController();

  // 1.2 보존 사항 컨트롤러들
  final _preservationFoundationBaseController = TextEditingController();
  final _preservationFoundationBasePhotoController = TextEditingController();
  final _preservationFoundationCornerstonePhotoController = TextEditingController();
  final _preservationShaftVerticalMembersController = TextEditingController();
  final _preservationShaftVerticalMembersPhotoController = TextEditingController();
  final _preservationShaftLintelTiebeamController = TextEditingController();
  final _preservationShaftLintelTiebeamPhotoController = TextEditingController();
  final _preservationShaftBracketSystemController = TextEditingController();
  final _preservationShaftBracketSystemPhotoController = TextEditingController();
  final _preservationShaftWallGomagiController = TextEditingController();
  final _preservationShaftWallGomagiPhotoController = TextEditingController();
  final _preservationShaftOndolFloorController = TextEditingController();
  final _preservationShaftOndolFloorPhotoController = TextEditingController();
  final _preservationShaftWindowsRailingsController = TextEditingController();
  final _preservationShaftWindowsRailingsPhotoController = TextEditingController();
  final _preservationRoofFramingMembersController = TextEditingController();
  final _preservationRoofFramingMembersPhotoController = TextEditingController();
  final _preservationRoofRaftersPuyeonController = TextEditingController();
  final _preservationRoofRaftersPuyeonPhotoController = TextEditingController();
  final _preservationRoofRoofTilesController = TextEditingController();
  final _preservationRoofRoofTilesPhotoController = TextEditingController();
  final _preservationRoofCeilingDanjipController = TextEditingController();
  final _preservationRoofCeilingDanjipPhotoController = TextEditingController();
  final _preservationOtherSpecialNotesController = TextEditingController();
  final _preservationOtherSpecialNotesPhotoController = TextEditingController();

  // 저장 상태
  bool _isSavingText = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      _args =
          (ModalRoute.of(context)?.settings.arguments ?? {})
              as Map<String, dynamic>;
      final isCustom = _args?['isCustom'] == true;
      if (isCustom) {
        // 커스텀은 고유 키 조합이 없으므로 customId 사용
        heritageId = 'CUSTOM_${_args?['customId'] ?? 'UNKNOWN'}';
      } else {
        heritageId =
            "${_args?['ccbaKdcd']}_${_args?['ccbaAsno']}_${_args?['ccbaCtcd']}";
      }
      _detailViewModel ??= HeritageDetailViewModel(
        heritageId: heritageId,
        aiRepository: _aiPredictionRepository,
        inspectionResult: const InspectionResult(
          foundation: '', // 사전 예시 데이터 제거
          wall: '', // 사전 예시 데이터 제거
          roof: '', // 사전 예시 데이터 제거
        ),
        damageSummary: DamageSummary.initial(),
        investigatorOpinion: InvestigatorOpinion.empty(),
        gradeClassification: GradeClassification.initial(),
        aiState: AIPredictionState.initial(),
      );
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_args?['isCustom'] == true) {
        // Firestore에 저장된 커스텀 유산 문서를 불러와 기본개요를 구성
        final customId = _args?['customId'] as String?;
        if (customId != null && customId.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('custom_heritages')
              .doc(customId)
              .get();
          final m = snap.data() ?? <String, dynamic>{};
          setState(
            () => _detail = {
              'item': {
                'ccbaMnm1': (m['name'] as String?) ?? (_args?['name'] ?? ''),
                'ccmaName': m['ccmaName'] ?? m['kindName'],
                'ccbaAsdt': m['ccbaAsdt'] ?? m['asdt'],
                'ccbaPoss': m['ccbaPoss'] ?? m['owner'],
                'ccbaAdmin': m['ccbaAdmin'] ?? m['admin'],
                'ccbaLcto': m['ccbaLcto'] ?? m['lcto'],
                'ccbaLcad': m['ccbaLcad'] ?? m['lcad'],
              },
            },
          );
        } else {
          // 폴백: 전달된 인자만으로 구성
          setState(
            () => _detail = {
              'item': {'ccbaMnm1': _args?['name'] ?? ''},
            },
          );
        }
      } else {
        final d = await _api.fetchDetail(
          ccbaKdcd: _args?['ccbaKdcd'] ?? '',
          ccbaAsno: _args?['ccbaAsno'] ?? '',
          ccbaCtcd: _args?['ccbaCtcd'] ?? '',
        );
        setState(() => _detail = d);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상세 로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
      
      // 저장된 텍스트 데이터 로드
      await _loadTextFields();
    }
  }

  String _read(List<List<String>> paths) {
    if (_detail == null) return '';
    for (final path in paths) {
      dynamic cur = _detail;
      var ok = true;
      for (final k in path) {
        if (cur is Map<String, dynamic> && cur.containsKey(k)) {
          cur = cur[k];
        } else {
          ok = false;
          break;
        }
      }
      if (ok && cur != null) return cur.toString();
    }
    return '';
  }

  String get _name => _read([
    ['result', 'item', 'ccbaMnm1'],
    ['item', 'ccbaMnm1'],
  ]);

  String get _managementNumber => _read([
    ['result', 'item', 'ccbaAsno'],
    ['item', 'ccbaAsno'],
  ]);

  String _formatBytes(num? b) {
    final bytes = (b ?? 0).toDouble();
    if (bytes < 1024) return '${bytes.toInt()}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)}MB';
  }

  void _openPhotoViewer({required String url, required String title}) {
    if (!_isValidImageUrl(url)) return;
    final proxiedUrl = _proxyImageUrl(url);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '사진 확대 보기',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (context, _, __) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: Image.network(
                        proxiedUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          final total = loadingProgress.expectedTotalBytes;
                          final loaded = loadingProgress.cumulativeBytesLoaded;
                          return Center(
                            child: CircularProgressIndicator(
                              value: total != null ? loaded / total : null,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                if (title.trim().isNotEmpty)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── 문화유산 현황 사진 업로드
  Future<void> _addPhoto() async {
    if (!mounted) return;
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    if (!mounted) return;
    final title = await _askTitle(context);
    if (title == null) return;

    await _fb.addPhoto(
      heritageId: heritageId,
      heritageName: _name,
      title: title,
      imageBytes: bytes,
      sizeGetter: sizeGetter,
    );
  }

  Future<void> _addLocationPhoto() async {
    if (!mounted) return;
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    if (!mounted) return;
    final title = await _askTitle(context);
    if (title == null) return;

    await _fb.addPhoto(
      heritageId: heritageId,
      heritageName: _name,
      title: title,
      imageBytes: bytes,
      sizeGetter: sizeGetter,
      folder: 'location_photos',
    );
  }

  // 텍스트 데이터 저장 함수
  Future<void> _saveTextData() async {
    if (_isSavingText) return;
    
    print('🚨 텍스트 데이터 저장 시작!');
    debugPrint('🚨 텍스트 데이터 저장 시작!');
    
    setState(() => _isSavingText = true);
    
    try {
      final heritageId = this.heritageId;
      final heritageName = _name;
      
      print('🔍 텍스트 저장 - HeritageId: $heritageId, HeritageName: $heritageName');
      
      // 조사 데이터 수집
      final surveyData = {
        'inspectionResult': _inspectionResult.text.trim(),
        'managementItems': _managementItems.text.trim(),
        'damageSummary': _damageSummary.text.trim(),
        'investigatorOpinion': _investigatorOpinion.text.trim(),
        'gradeClassification': _gradeClassification.text.trim(),
        'existingHistory': _existingHistory.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📝 저장할 텍스트 데이터:');
      print('  - 1.1 조사 결과: ${_inspectionResult.text.trim()}');
      print('  - 관리사항: ${_managementItems.text.trim()}');
      print('  - 손상부 종합: ${_damageSummary.text.trim()}');
      print('  - 조사자 의견: ${_investigatorOpinion.text.trim()}');
      print('  - 기존 이력: ${_existingHistory.text.trim()}');

      // Firebase에 저장
      await _fb.addDetailSurvey(
        heritageId: heritageId,
        heritageName: heritageName,
        surveyData: surveyData,
      );

      print('✅ 텍스트 데이터 저장 완료!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('텍스트 데이터가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ 텍스트 데이터 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('텍스트 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingText = false);
      }
    }
  }

  // 텍스트 필드 데이터 로드
  Future<void> _loadTextFields() async {
    print('📭 텍스트 필드 데이터 로드 시작!');
    debugPrint('📭 텍스트 필드 데이터 로드 시작!');
    
    try {
      final heritageId = this.heritageId;
      print('🔍 텍스트 로드 - HeritageId: $heritageId');
      
      // Firebase에서 최신 데이터 가져오기
      final surveys = await _fb.getDetailSurveys(heritageId);
      
      if (surveys.docs.isNotEmpty) {
        final latestData = surveys.docs.first.data();
        print('📝 로드된 텍스트 데이터:');
        print('  - 1.1 조사 결과: ${latestData['inspectionResult'] ?? ''}');
        print('  - 관리사항: ${latestData['managementItems'] ?? ''}');
        print('  - 손상부 종합: ${latestData['damageSummary'] ?? ''}');
        print('  - 조사자 의견: ${latestData['investigatorOpinion'] ?? ''}');
        print('  - 기존 이력: ${latestData['existingHistory'] ?? ''}');
        
        // 텍스트 필드에 데이터 설정
        _inspectionResult.text = latestData['inspectionResult'] ?? '';
        _managementItems.text = latestData['managementItems'] ?? '';
        _damageSummary.text = latestData['damageSummary'] ?? '';
        _investigatorOpinion.text = latestData['investigatorOpinion'] ?? '';
        _gradeClassification.text = latestData['gradeClassification'] ?? '';
        _existingHistory.text = latestData['existingHistory'] ?? '';
        
        print('✅ 텍스트 필드 데이터 로드 완료!');
      } else {
        print('📭 저장된 텍스트 데이터가 없습니다.');
      }
    } catch (e) {
      print('❌ 텍스트 필드 데이터 로드 실패: $e');
    }
  }

  Future<String?> _askTitle(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 제목 입력'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '예: 남측면 전경'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A44),
              foregroundColor: Colors.white,
            ),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 손상부 조사 촬영→AI 분석→저장
  Future<void> _startDamageSurvey() async {
    await _openDamageDetectionDialog(autoCapture: true);
  }

  Future<void> _openDamageDetectionDialog({bool autoCapture = false}) async {
    if (!mounted) return;
    final result = await showDialog<DamageDetectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImprovedDamageSurveyDialog(
        aiService: _ai,
        heritageId: heritageId,
        autoCapture: autoCapture,
      ),
    );

    if (result == null) return;

    final severity = (result.severityGrade?.trim().isNotEmpty ?? false)
        ? result.severityGrade
        : result.autoGrade;

    await _fb.addDamageSurvey(
      heritageId: heritageId,
      heritageName: _name,
      imageBytes: result.imageBytes,
      detections: result.detections,
      location: result.location,
      phenomenon: result.selectedLabel,
      inspectorOpinion: result.opinion,
      severityGrade: severity,
      detailInputs: result.toDetailInputs(),
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('손상부 조사 등록 완료')));
    }
  }


  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('해당 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detailScrollController.dispose();
    _detailViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kind = _read([
      ['result', 'item', 'ccmaName'],
      ['item', 'ccmaName'],
    ]);
    final asdt = _read([
      ['result', 'item', 'ccbaAsdt'],
      ['item', 'ccbaAsdt'],
    ]);
    final owner = _read([
      ['result', 'item', 'ccbaPoss'],
      ['item', 'ccbaPoss'],
    ]);
    final admin = _read([
      ['result', 'item', 'ccbaAdmin'],
      ['item', 'ccbaAdmin'],
    ]);
    final lcto = _read([
      ['result', 'item', 'ccbaLcto'],
      ['item', 'ccbaLcto'],
    ]);
    final lcad = _read([
      ['result', 'item', 'ccbaLcad'],
      ['item', 'ccbaLcad'],
    ]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A44),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: true,
        title: Text(
          _name.isEmpty ? '기본개요' : _name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.5),
                  builder: (_) => HeritageHistoryDialog(
                    heritageId: heritageId,
                    heritageName: _name,
                  ),
                );
              },
              icon: const Icon(
                Icons.history,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                '기존이력',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const desktopBreakpoint = 1100.0;
            const maxContentWidth = 1040.0;
            final isDesktop = constraints.maxWidth >= desktopBreakpoint;
            
            // 화면 배율 100%에서도 내용이 보이도록 최소 높이 보장
            final screenHeight = MediaQuery.of(context).size.height;
            final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
            final availableHeight = screenHeight - appBarHeight;
            
            final detailSections = _buildDetailSections(
              context: context,
              kind: kind,
              asdt: asdt,
              owner: owner,
              admin: admin,
              lcto: lcto,
              lcad: lcad,
            );
            
            // 100% 배율에서도 확실히 보이도록 높이 보장 (최대한 강력한 설정)
            final minHeight = math.max(availableHeight, 1200.0);
            
            final detailView = _buildDetailScrollView(
              maxContentWidth: maxContentWidth,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 24,
              ),
              showScrollbarThumb: isDesktop,
              minHeight: minHeight,
              children: detailSections,
            );

            // 100% 배율에서도 확실히 보이도록 높이 강제 설정 (최대한 강력한 설정)
            return SizedBox(
              height: math.max(availableHeight, 1200.0),
              width: double.infinity,
              child: detailView,
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  List<Widget> _buildDetailSections({
    required BuildContext context,
    required String kind,
    required String asdt,
    required String owner,
    required String admin,
    required String lcto,
    required String lcad,
  }) {
    final sections = <Widget>[
      BasicInfoCard(
        name: _name.isEmpty ? '미상' : _name,
        kind: kind,
        asdt: asdt,
        owner: owner,
        admin: admin,
        lcto: lcto,
        lcad: lcad,
        managementNumber: _managementNumber,
      ),
      const SizedBox(height: 24),
      LocationStatusCard(
        heritageId: heritageId,
        heritageName: _name.isEmpty ? '미상' : _name,
        photosStream: _fb.photosStream(heritageId, folder: 'location_photos'),
        onAddPhoto: _addLocationPhoto,
        onPreview: (url, title) => _openPhotoViewer(url: url, title: title),
        onDelete: (docId, url) async {
          final ok = await _confirmDelete(context);
          if (ok != true) return;
          await _fb.deletePhoto(
            heritageId: heritageId,
            docId: docId,
            url: url,
            folder: 'location_photos',
          );
        },
        formatBytes: _formatBytes,
      ),
      const SizedBox(height: 24),
      HeritagePhotoSection(
        photosStream: _fb.photosStream(heritageId),
        onAddPhoto: _addPhoto,
        onPreview: (url, title) => _openPhotoViewer(url: url, title: title),
        onDelete: (docId, url) async {
          final ok = await _confirmDelete(context);
          if (ok != true) return;
          await _fb.deletePhoto(
            heritageId: heritageId,
            docId: docId,
            url: url,
            folder: 'photos',
          );
        },
        formatBytes: _formatBytes,
      ),
      const SizedBox(height: 24),
      DamageSurveySection(
        damageStream: _fb.damageStream(heritageId),
        onAddSurvey: () => _openDamageDetectionDialog(),
        onDeepInspection: () async {
          final result = await showDialog(
            context: context,
            builder: (_) => const DeepDamageInspectionDialog(),
          );
          if (result != null && result['saved'] == true && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('심화조사 데이터가 저장되었습니다')));
          }
        },
        onDelete: (docId, imageUrl) async {
          final ok = await _confirmDelete(context);
          if (ok != true) return;
          await _fb.deleteDamageSurvey(
            heritageId: heritageId,
            docId: docId,
            imageUrl: imageUrl,
          );
        },
      ),
      const SectionDivider(),
      const SizedBox(height: 24),
    ];

    if (_detailViewModel != null) {
      sections.add(
        AnimatedBuilder(
          animation: _detailViewModel!,
          builder: (context, _) {
            final vm = _detailViewModel!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InspectionResultCard(
                  value: vm.inspectionResult,
                  onChanged: vm.updateInspectionResult,
                  heritageId: heritageId,
                  heritageName: _name.isEmpty ? '미상' : _name,
                ),
                const SectionDivider(),
                ManagementItemsCard(
                  heritageId: heritageId,
                  heritageName: _name.isEmpty ? '미상' : _name,
                ),
                const SectionDivider(),
                DamageSummaryTable(
                  value: vm.damageSummary,
                  onChanged: vm.updateDamageSummary,
                  heritageId: heritageId,
                  heritageName: _name.isEmpty ? '미상' : _name,
                ),
                const SectionDivider(),
                InvestigatorOpinionField(
                  value: vm.investigatorOpinion,
                  onChanged: vm.updateInvestigatorOpinion,
                  heritageId: heritageId,
                  heritageName: _name.isEmpty ? '미상' : _name,
                ),
                const SectionDivider(),
                GradeClassificationCard(
                  value: vm.gradeClassification,
                  onChanged: vm.updateGradeClassification,
                ),
                const SectionDivider(),
                AIPredictionSection(
                  state: vm.aiPredictionState,
                  actions: AIPredictionActions(
                    onPredictGrade: vm.predictGrade,
                    onGenerateMap: vm.generateMap,
                    onSuggest: vm.suggestMitigation,
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // _detailViewModel이 null일 때도 AI 섹션 표시
      sections.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 예측 및 보고서 생성',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              
              // AI 예측 버튼들
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI 등급 예측 기능을 준비 중입니다')),
                        );
                      },
                      icon: const Icon(Icons.psychology),
                      label: const Text('AI 등급 예측'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF7C3AED).withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI 지도 생성 기능을 준비 중입니다')),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('AI 지도 생성'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 보고서 생성 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI 보고서 생성 기능을 준비 중입니다')),
                    );
                  },
                  icon: const Icon(Icons.description),
                  label: const Text('AI 보고서 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF059669).withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 텍스트 저장 버튼 추가
    sections.add(
      Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '텍스트 데이터 저장',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2A44),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아래 입력 필드들의 데이터를 Firebase에 저장합니다:',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 1.1 조사 결과 • 관리사항 • 손상부 종합 • 조사자 의견 • 기존 이력',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSavingText ? null : _saveTextData,
              icon: _isSavingText 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
              label: Text(_isSavingText ? '저장 중...' : '텍스트 데이터 저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2A44),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF1E2A44).withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    sections.add(const SizedBox(height: 48));
    return sections;
  }

  Widget _buildDetailScrollView({
    required double maxContentWidth,
    required EdgeInsets padding,
    required bool showScrollbarThumb,
    required double minHeight,
    required List<Widget> children,
  }) {
    return SizedBox(
      height: minHeight,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior(),
        child: Scrollbar(
          controller: _detailScrollController,
          thumbVisibility: showScrollbarThumb,
          child: SingleChildScrollView(
            controller: _detailScrollController,
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxContentWidth,
                  minHeight: minHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// Redesigned detail components
// ═══════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 16, thickness: 1, color: dividerColor),
      ],
    );
  }
}

class BasicInfoCard extends StatelessWidget {
  const BasicInfoCard({
    super.key,
    required this.name,
    required this.kind,
    required this.asdt,
    required this.owner,
    required this.admin,
    required this.lcto,
    required this.lcad,
    required this.managementNumber,
  });

  final String name;
  final String kind;
  final String asdt;
  final String owner;
  final String admin;
  final String lcto;
  final String lcad;
  final String managementNumber;

  @override
  Widget build(BuildContext context) {
    // 정기조사 지침 기준: 소재지는 lcad 우선, 없으면 lcto
    final location = lcad.trim().isNotEmpty ? lcad : lcto;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A44).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1E2A44),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
          const Text(
            '기본 정보',
            style: TextStyle(
              fontWeight: FontWeight.w700,
                  fontSize: 18,
              color: Color(0xFF111827),
                  letterSpacing: -0.3,
            ),
          ),
            ],
          ),
          const SizedBox(height: 20),
          // 유산명
          _buildOverviewRow('유산명', name.isEmpty ? '미상' : name),
          const SizedBox(height: 12),

          // 지정연월
          _buildOverviewRow('지정연월', _formatDate(asdt)),
          const SizedBox(height: 12),

          // 종목
          _buildOverviewRow('종목', kind.isEmpty ? '-' : kind),
          const SizedBox(height: 12),

          // 소재지
          _buildOverviewRow('소재지', location.isEmpty ? '-' : location),
          const SizedBox(height: 12),

          // 관리번호
          _buildOverviewRow(
            '관리번호',
            managementNumber.isEmpty ? '-' : managementNumber,
          ),
        ],
      ),
    );
  }

  // 날짜 형식 변환 함수
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "-";
    // YYYYMMDD 형식
    if (RegExp(r'^\d{8}$').hasMatch(dateStr)) {
      final y = dateStr.substring(0, 4);
      final m = dateStr.substring(4, 6);
      final d = dateStr.substring(6, 8);
      return "$y년 $m월 $d일";
    }
    // YYYY-MM-DD 형식
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      final parts = dateStr.split("-");
      return "${parts[0]}년 ${parts[1]}월 ${parts[2]}일";
    }
    return dateStr;
  }

  Widget _buildOverviewRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1E2A44),
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class HeritagePhotoSection extends StatelessWidget {
  const HeritagePhotoSection({
    super.key,
    required this.photosStream,
    required this.onAddPhoto,
    required this.onPreview,
    required this.onDelete,
    required this.formatBytes,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> photosStream;
  final VoidCallback onAddPhoto;
  final void Function(String url, String title) onPreview;
  final Future<void> Function(String docId, String url) onDelete;
  final String Function(num? bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A44).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF1E2A44),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
          const Text(
            '현황 사진',
            style: TextStyle(
              fontWeight: FontWeight.w700,
                  fontSize: 18,
              color: Color(0xFF111827),
                  letterSpacing: -0.3,
            ),
          ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '위성사진, 배치도 등 위치 관련 자료를 등록하세요.',
            style: TextStyle(
              color: Color(0xFF6B7280), 
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: photosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF1E2A44),
                          ),
                          label: const Text(
                            '사진 등록',
                            style: TextStyle(color: Color(0xFF1E2A44)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1E2A44)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final docs = snapshot.data!.docs
                    .where(
                      (doc) =>
                          ((doc.data())['url'] as String?)?.isNotEmpty ?? false,
                    )
                    .toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF1E2A44),
                          ),
                          label: const Text(
                            '사진 등록',
                            style: TextStyle(color: Color(0xFF1E2A44)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1E2A44)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    // 사진 등록 버튼 (항상 표시)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: onAddPhoto,
                            icon: const Icon(
                              Icons.add_a_photo,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              '사진 추가',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2A44),
                              elevation: 2,
                              shadowColor: const Color(0xFF1E2A44).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 사진 목록 - 깔끔한 그리드 레이아웃
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: GridView.builder(
                            primary: false,
                            physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                            itemCount: docs.length,
                            itemBuilder: (_, index) {
                              final data = docs[index].data();
                              final title = (data['title'] as String?) ?? '';
                              final url = (data['url'] as String?) ?? '';
                              final meta =
                                  '${data['width'] ?? '?'}x${data['height'] ?? '?'} • ${formatBytes(data['bytes'] as num?)}';
                          return _PhotoCard(
                                  title: title,
                                  url: url,
                                  meta: meta,
                                  onPreview: () => onPreview(url, title),
                                  onDelete: () => onDelete(docs[index].id, url),
                              );
                            },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _PhotoCard({
    required String title,
    required String url,
    required String meta,
    required VoidCallback onPreview,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF8FAFC),
                        child: const Icon(
                          Icons.broken_image, 
                          size: 40,
                          color: Color(0xFF9CA3AF),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    child: IconButton(
                      onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline, 
                          color: Colors.white,
                          size: 16,
                        ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                          minimumSize: const Size(28, 28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                    style: const TextStyle(
                      color: Color(0xFF6B7280), 
                      fontSize: 10,
                    ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                  const Spacer(),
                SizedBox(
                  width: double.infinity,
                    height: 24,
                  child: ElevatedButton(
                    onPressed: onPreview,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2A44),
                      foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('미리보기', style: TextStyle(fontSize: 12)),
                  ),
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

class DamageSurveySection extends StatefulWidget {
  const DamageSurveySection({
    super.key,
    required this.damageStream,
    required this.onAddSurvey,
    required this.onDeepInspection,
    required this.onDelete,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> damageStream;
  final VoidCallback onAddSurvey;
  final Future<void> Function() onDeepInspection;
  final Future<void> Function(String docId, String imageUrl) onDelete;

  @override
  State<DamageSurveySection> createState() => _DamageSurveySectionState();
}

class _DamageSurveySectionState extends State<DamageSurveySection> {
  Map<String, dynamic>? _selectedDamage;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A44).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF1E2A44),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
          const Text(
            '손상부 조사',
            style: TextStyle(
              fontWeight: FontWeight.w700,
                  fontSize: 18,
              color: Color(0xFF111827),
                  letterSpacing: -0.3,
            ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onAddSurvey,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text(
                  '조사 등록',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2A44),
                  elevation: 2,
                  shadowColor: const Color(0xFF1E2A44).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _selectedDamage != null ? _openDeepInspection : null,
                icon: const Icon(
                  Icons.assignment,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  _selectedDamage != null ? '심화조사' : '심화조사 (선택 필요)',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDamage != null 
                      ? const Color(0xFF4B6CB7) 
                      : const Color(0xFF9CA3AF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shadowColor: const Color(0xFF4B6CB7).withOpacity(0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Interactive Damage Table
          _buildDamageTable(),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.damageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 손상부 조사가 없습니다.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  );
                }
                final docs = snapshot.data!.docs
                    .where(
                      (doc) =>
                          ((doc.data())['imageUrl'] as String?)?.isNotEmpty ??
                          false,
                    )
                    .toList();
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 손상부 조사가 없습니다.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  );
                }
                return ScrollConfiguration(
                  behavior: const MaterialScrollBehavior(),
                  child: ListView.separated(
                    primary: false,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final url = data['imageUrl'] as String? ?? '';
                      final detections = (data['detections'] as List? ?? [])
                          .cast<Map<String, dynamic>>();
                      final grade = data['severityGrade'] as String?;
                      final location = data['location'] as String?;
                      final phenomenon = data['phenomenon'] as String?;
                      return _DamageCard(
                        url: url,
                        detections: detections,
                        severityGrade: grade,
                        location: location,
                        phenomenon: phenomenon,
                        onDelete: () => widget.onDelete(doc.id, url),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageTable() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.damageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text(
                '등록된 손상부 조사가 없습니다.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs
            .where((doc) => ((doc.data())['imageUrl'] as String?)?.isNotEmpty ?? false)
            .toList();

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text(
                '등록된 손상부 조사가 없습니다.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  '손상부 조사 목록 (행을 선택하여 심화조사 진행)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 48,
                  dataRowMinHeight: 56,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('선택', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('위치', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('손상 유형', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('등급', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('조사일시', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('조사자 의견', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data();
                    final isSelected = _selectedIndex == index;
                    
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        if (selected == true) {
                          setState(() {
                            _selectedIndex = index;
                            _selectedDamage = data;
                          });
                        }
                      },
                      cells: [
                        DataCell(
                          Radio<int>(
                            value: index,
                            groupValue: _selectedIndex,
                            onChanged: (value) {
                              setState(() {
                                _selectedIndex = value;
                                _selectedDamage = data;
                              });
                            },
                          ),
                        ),
                        DataCell(Text(data['location']?.toString() ?? '—')),
                        DataCell(Text(data['phenomenon']?.toString() ?? '—')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getGradeColor(data['severityGrade']?.toString()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              data['severityGrade']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                          data['timestamp'] != null 
                              ? _formatTimestamp(data['timestamp'].toString())
                              : '—'
                        )),
                        DataCell(Text(
                          data['inspectorOpinion']?.toString() ?? '—',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getGradeColor(String? grade) {
    switch (grade) {
      case 'A': return const Color(0xFF4CAF50);
      case 'B': return const Color(0xFF8BC34A);
      case 'C1': return const Color(0xFFFFC107);
      case 'C2': return const Color(0xFFFF9800);
      case 'D': return const Color(0xFFFF5722);
      case 'E': return const Color(0xFFF44336);
      case 'F': return const Color(0xFFD32F2F);
      default: return const Color(0xFF9CA3AF);
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  void _openDeepInspection() {
    if (_selectedDamage == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeepInspectionScreen(selectedDamage: _selectedDamage!),
      ),
    );
  }

  Widget _DamageCard({
    required String url,
    required List<Map<String, dynamic>> detections,
    required String? severityGrade,
    required String? location,
    required String? phenomenon,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                  if (severityGrade != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(severityGrade),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          severityGrade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location != null && location.isNotEmpty) ...[
                  Text(
                    '위치: $location',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                if (phenomenon != null && phenomenon.isNotEmpty) ...[
                  Text(
                    '현상: $phenomenon',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '검출: ${detections.length}개',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.red;
      case 'D':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }


}

class _MockAIPredictionRepository implements AIPredictionRepository {
  final Map<int, Future<ImageProvider>> _imageCache = {};

  @override
  Future<AIPredictionGrade> predictGrade(String heritageId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return AIPredictionGrade(
      from: 'C',
      to: 'D',
      before: await _imageFor(const Color(0xFF6C8CD5)),
      after: await _imageFor(const Color(0xFFD95D5D)),
      years: 5,
    );
  }

  @override
  Future<ImageProvider> generateDamageMap(String heritageId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _imageFor(const Color(0xFF64B5F6));
  }

  @override
  Future<List<MitigationRow>> suggestMitigation(String heritageId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return const [
      MitigationRow(factor: '고습 · 고온', action: '환기 강화, 방수 모니터링, 방충·방균 처리'),
      MitigationRow(factor: '폭우 · 침수', action: '배수로 점검, 차수 시설 점검, 응급 복구 계획 수립'),
      MitigationRow(factor: '한랭 · 결빙', action: '보온 자재 확보, 균열 모니터링, 제설 계획 마련'),
    ];
  }

  Future<ImageProvider> _imageFor(Color color) {
    final key = color.value;
    return _imageCache.putIfAbsent(key, () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = color;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 160, 120), paint);
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 240);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return MemoryImage(byteData!.buffer.asUint8List());
    });
  }


}

// ═══════════════════════════════════════════════════════════════
// Table Cell Widgets for the new table-based UI
// ═══════════════════════════════════════════════════════════════

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final int colspan;
  const _TableCell(this.text, {this.colspan = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Text(
        text.isEmpty ? '-' : text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Heritage History Dialog - 기존이력확인 팝업
// ═══════════════════════════════════════════════════════════════

class HeritageHistoryDialog extends StatefulWidget {
  HeritageHistoryDialog({
    super.key,
    required this.heritageId,
    required this.heritageName,
    this.initialManagementData,
    this.managementDataStream,
    this.firestore,
    this.storage,
  }) : assert(heritageId.isNotEmpty, 'heritageId must not be empty');

  final String heritageId;
  final String heritageName;
  final Map<String, dynamic>? initialManagementData;
  final Stream<Map<String, dynamic>>? managementDataStream;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;

  @override
  State<HeritageHistoryDialog> createState() => _HeritageHistoryDialogState();
}

class _HeritageHistoryDialogState extends State<HeritageHistoryDialog> {
  static const List<_SurveyRowConfig> _surveyRowConfigs = [
    // 구조부 섹션
    _SurveyRowConfig(key: 'foundation', label: '기단부', hint: '기단부 조사 결과를 입력하세요'),
    _SurveyRowConfig(key: 'wall', label: '축부(벽체부)', hint: '벽체부 조사 결과를 입력하세요'),
    _SurveyRowConfig(key: 'roof', label: '지붕부', hint: '지붕부 조사 결과를 입력하세요'),
    // 조사결과 기타부 섹션
    _SurveyRowConfig(key: 'coloring', label: '채색 (단청, 벽화)', hint: '채색 관련 조사 결과를 입력하세요'),
    _SurveyRowConfig(key: 'pest', label: '충해', hint: '충해 관련 조사 결과를 입력하세요'),
    _SurveyRowConfig(key: 'etc', label: '기타', hint: '기타 조사 결과를 입력하세요'),
    // 추가 필드들
    _SurveyRowConfig(key: 'safetyNotes', label: '특기사항', hint: '특기사항을 입력하세요'),
    _SurveyRowConfig(key: 'investigatorOpinion', label: '조사 종합의견', hint: '조사 종합의견을 입력하세요'),
    _SurveyRowConfig(key: 'grade', label: '등급분류', hint: '등급분류를 입력하세요'),
    _SurveyRowConfig(key: 'investigationDate', label: '조사일시', hint: '조사일시를 입력하세요'),
    _SurveyRowConfig(key: 'investigator', label: '조사자', hint: '조사자명을 입력하세요'),
  ];
  static const List<_ConservationRowConfig> _conservationRowConfigs = [
    _ConservationRowConfig(
      key: 'structure',
      section: '구조부',
      part: '기단',
      noteHint: '예: 균열, 침하 등 현상 기록',
      locationHint: '예: 7,710 / 좌표',
    ),
    _ConservationRowConfig(
      key: 'roof',
      section: '지붕부',
      part: '—',
      noteHint: '예: 필요 시 사진 보이기',
      locationHint: '예: 첨탑 상부',
    ),
  ];
  static const double _tableHeaderFontSize = 15;
  static const double _tableBodyFontSize = 14;

  FirebaseFirestore get _firestore =>
      widget.firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => widget.storage ?? FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  bool _invalidHeritage = false;
  String _selectedYear = '2024년 조사';
  late final Map<String, TextEditingController> _surveyControllers;
  late final Map<String, TextEditingController> _conservationPartControllers;
  late final Map<String, TextEditingController> _conservationNoteControllers;
  late final Map<String, TextEditingController>
  _conservationLocationControllers;
  final TextEditingController _fireSafetyPartController =
      TextEditingController();
  final TextEditingController _fireSafetyNoteController =
      TextEditingController();
  final TextEditingController _electricalPartController =
      TextEditingController();
  final TextEditingController _electricalNoteController =
      TextEditingController();

  final List<_HistoryImage> _locationImages = [];
  final List<_HistoryImage> _currentPhotos = [];
  final List<_HistoryImage> _damagePhotos = [];
  final Set<_HistoryPhotoKind> _uploadingKinds = <_HistoryPhotoKind>{};
  
  // 손상부 종합 테이블 데이터
  final List<_DamageSummaryRow> _damageSummaryRows = [];
  
  // 간단한 손상부 종합 텍스트 컨트롤러
  final _damageSummaryTextController = TextEditingController();

  Map<String, dynamic> _managementYears = {};
  bool _isEditable = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isLoading = false;
  Map<String, dynamic> _originalData = {}; // 원본 데이터 저장
  Presence? _mgmtFireSafety;
  Presence? _mgmtElectrical;
  
  // 기본 정보 화면과 동일한 관리사항 변수들
  bool _hasDisasterManual = false;
  bool _hasFireTruckAccess = false;
  bool _hasFireLine = false;
  bool _hasEvacTargets = false;
  bool _hasTraining = false;
  bool _hasExtinguisher = false;
  bool _hasHydrant = false;
  bool _hasAutoAlarm = false;
  bool _hasCCTV = false;
  bool _hasAntiTheftCam = false;
  bool _hasFireDetector = false;
  bool _hasElectricalCheck = false;
  bool _hasGasCheck = false;
  bool _hasSecurityPersonnel = false;
  bool _hasManagementLog = false;
  bool _hasCareProject = false;
  bool _hasInfoCenter = false;
  bool _hasInfoBoard = false;
  bool _hasExhibitionMuseum = false;
  bool _hasNationalHeritageInterpreter = false;
  Timer? _saveDebounce;
  StreamSubscription<Map<String, dynamic>>? _managementSub;

  // 1.2 보존 사항 컨트롤러들
  final _preservationFoundationBaseController = TextEditingController();
  final _preservationFoundationBasePhotoController = TextEditingController();
  final _preservationFoundationCornerstonePhotoController = TextEditingController();
  final _preservationShaftVerticalMembersController = TextEditingController();
  final _preservationShaftVerticalMembersPhotoController = TextEditingController();
  final _preservationShaftLintelTiebeamController = TextEditingController();
  final _preservationShaftLintelTiebeamPhotoController = TextEditingController();
  final _preservationShaftBracketSystemController = TextEditingController();
  final _preservationShaftBracketSystemPhotoController = TextEditingController();
  final _preservationShaftWallGomagiController = TextEditingController();
  final _preservationShaftWallGomagiPhotoController = TextEditingController();
  final _preservationShaftOndolFloorController = TextEditingController();
  final _preservationShaftOndolFloorPhotoController = TextEditingController();
  final _preservationShaftWindowsRailingsController = TextEditingController();
  final _preservationShaftWindowsRailingsPhotoController = TextEditingController();
  final _preservationRoofFramingMembersController = TextEditingController();
  final _preservationRoofFramingMembersPhotoController = TextEditingController();
  final _preservationRoofRaftersPuyeonController = TextEditingController();
  final _preservationRoofRaftersPuyeonPhotoController = TextEditingController();
  final _preservationRoofRoofTilesController = TextEditingController();
  final _preservationRoofRoofTilesPhotoController = TextEditingController();
  final _preservationRoofCeilingDanjipController = TextEditingController();
  final _preservationRoofCeilingDanjipPhotoController = TextEditingController();
  final _preservationOtherSpecialNotesController = TextEditingController();
  final _preservationOtherSpecialNotesPhotoController = TextEditingController();

  // 사진 관련 상태 변수들
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, Uint8List?> _preservationPhotos = {};
  Map<String, String?> _preservationPhotoUrls = {};
  final _fb = FirebaseService();

  // 새로운 유지보수/수리 이력 필드들
  bool _precisionDiagnosis = false;
  bool _careProject = false;
  final TextEditingController _repairRecordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.heritageId.isEmpty) {
      _invalidHeritage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    _surveyControllers = {
      for (final row in _surveyRowConfigs) row.key: TextEditingController(),
    };
    _conservationPartControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };
    _conservationNoteControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };
    _conservationLocationControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };

    // 사전 예시 데이터 제거 - 사용자 입력과 충돌 방지
    // _surveyControllers['structure']?.text = '이하 내용 1.1 총괄사항 참고';
    // _surveyControllers['wall']?.text = '—';
    // _surveyControllers['roof']?.text = '이하 내용 1.1 총괄사항 참고';
    // _conservationPartControllers['structure']?.text = '기단';
    // _conservationPartControllers['roof']?.text = '—';
    // _conservationNoteControllers['structure']?.text = '이하 내용 1.2 보존사항 참고';
    // _conservationNoteControllers['roof']?.text = '* 필요시 사진 보이기';
    // _conservationLocationControllers['structure']?.text = '7,710';
    // _conservationLocationControllers['roof']?.text = '';
    // _fireSafetyPartController.text = '방재/피뢰설비';
    // _electricalPartController.text = '전선/조명 등';

    final stream =
        widget.managementDataStream ??
        _firestore
            .collection('heritage_management')
            .doc(widget.heritageId)
            .snapshots()
            .map((doc) => doc.data() ?? <String, dynamic>{});
    _managementSub = stream.listen(_handleManagementData);

    if (widget.initialManagementData != null) {
      _handleManagementData(widget.initialManagementData!);
    }

    // 변경사항 감지를 위한 리스너 추가
    _addChangeListeners();
  }


  void _handleManagementData(Map<String, dynamic> data) {
    if (!mounted) return;
    final years = _mapFrom(data['years']);
    if (years.isEmpty) {
      final legacyFire = data['fireSafety'];
      final legacyElectrical = data['electrical'];
      if (legacyFire != null || legacyElectrical != null) {
        years[_currentYearKey] = {
          if (legacyFire != null) 'fireSafety': {'exists': legacyFire},
          if (legacyElectrical != null)
            'electrical': {'exists': legacyElectrical},
        };
      }
    }

    final yearData = _yearDataFromYears(years, _currentYearKey);
    final fireSection = _mapFrom(yearData['fireSafety']);
    final electricalSection = _mapFrom(yearData['electrical']);
    final surveyData = _mapFrom(yearData['survey']);
    final conservationData = _mapFrom(yearData['conservation']);
    final firePresence = _presenceFromSection(fireSection);
    final electricalPresence = _presenceFromSection(electricalSection);
    final fireNote = _noteFromSection(fireSection);
    final electricalNote = _noteFromSection(electricalSection);

    final shouldHydrate = !_isEditable;
    if (shouldHydrate) {
      _fireSafetyNoteController.text = fireNote;
      _electricalNoteController.text = electricalNote;
      for (final row in _surveyRowConfigs) {
        final value = surveyData[row.key];
        if (value is String) {
          _surveyControllers[row.key]?.text = value;
        }
      }
      for (final row in _conservationRowConfigs) {
        final rowData = _mapFrom(conservationData[row.key]);
        final partText = rowData['part'];
        final note = rowData['note'];
        final location = rowData['photoLocation'] ?? rowData['location'];
        if (partText is String) {
          _conservationPartControllers[row.key]?.text = partText;
        }
        if (note is String) {
          _conservationNoteControllers[row.key]?.text = note;
        }
        if (location is String) {
          _conservationLocationControllers[row.key]?.text = location;
        }
      }
    }

    final locationImages = _decodePhotoList(yearData['locationPhotos']);
    final currentImages = _decodePhotoList(yearData['currentPhotos']);
    final damageImages = _decodePhotoList(yearData['damagePhotos']);

    setState(() {
      _managementYears = years;
      _mgmtFireSafety = firePresence;
      _mgmtElectrical = electricalPresence;
      if (shouldHydrate) {
        _locationImages
          ..clear()
          ..addAll(locationImages);
        _currentPhotos
          ..clear()
          ..addAll(currentImages);
        _damagePhotos
          ..clear()
          ..addAll(damageImages);
        _hasUnsavedChanges = false;
      }
    });
  }

  String get _currentYearKey {
    final match = RegExp(r'\d{4}').firstMatch(_selectedYear);
    return match?.group(0) ?? _selectedYear;
  }

  Map<String, dynamic> _yearDataFromYears(
    Map<String, dynamic> years,
    String yearKey,
  ) => _mapFrom(years[yearKey]);

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  Presence? _presenceFromSection(Map<String, dynamic> section) {
    final source = section['exists'] ?? section['presence'] ?? section['value'];
    return _parsePresence(source);
  }

  Presence? _parsePresence(dynamic value) {
    if (value == null) return null;
    if (value is Presence) return value;
    if (value is bool) return value ? Presence.yes : Presence.no;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['yes', 'y', 'true'].contains(normalized)) return Presence.yes;
      if (['no', 'n', 'false'].contains(normalized)) return Presence.no;
    }
    return null;
  }

  String _noteFromSection(Map<String, dynamic> section) {
    final note = section['note'];
    if (note is String) return note;
    return '';
  }

  List<_HistoryImage> _decodePhotoList(dynamic raw) {
    final result = <_HistoryImage>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.isNotEmpty) {
          result.add(_HistoryImage(id: _uuid.v4(), url: item, rawValue: item));
        } else if (item is Map) {
          final mapItem = _mapFrom(item);
          final id = (mapItem['id'] as String?) ?? _uuid.v4();
          final url = mapItem['url'] as String?;
          final storagePath = mapItem['storagePath'] as String?;
          final uploadedAt = mapItem['uploadedAt'] as String?;
          Uint8List? bytes;
          final base64 = mapItem['bytes'] as String?;
          if (base64 != null && base64.isNotEmpty) {
            try {
              bytes = base64Decode(base64);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Failed to decode base64 image: $e');
              }
            }
          }
          result.add(
            _HistoryImage(
              id: id,
              url: url,
              bytes: bytes,
              storagePath: storagePath,
              uploadedAt: uploadedAt,
              rawValue: mapItem,
            ),
          );
        }
      }
    }
    return result;
  }

  void _refreshManagementFields({bool overrideNotes = false}) {
    final yearData = _yearDataFromYears(_managementYears, _currentYearKey);
    final fireSection = _mapFrom(yearData['fireSafety']);
    final electricalSection = _mapFrom(yearData['electrical']);
    final surveyData = _mapFrom(yearData['survey']);
    final conservationData = _mapFrom(yearData['conservation']);
    final firePresence = _presenceFromSection(fireSection);
    final electricalPresence = _presenceFromSection(electricalSection);
    final fireNote = _noteFromSection(fireSection);
    final electricalNote = _noteFromSection(electricalSection);

    if (overrideNotes || !_isEditable) {
      _fireSafetyNoteController.text = fireNote;
      _electricalNoteController.text = electricalNote;
      for (final row in _surveyRowConfigs) {
        final value = surveyData[row.key];
        if (value is String) {
          _surveyControllers[row.key]?.text = value;
        }
      }
      for (final row in _conservationRowConfigs) {
        final rowData = _mapFrom(conservationData[row.key]);
        final partText = rowData['part'];
        final note = rowData['note'];
        final location = rowData['photoLocation'] ?? rowData['location'];
        if (partText is String) {
          _conservationPartControllers[row.key]?.text = partText;
        }
        if (note is String) {
          _conservationNoteControllers[row.key]?.text = note;
        }
        if (location is String) {
          _conservationLocationControllers[row.key]?.text = location;
        }
      }
      final locationImages = _decodePhotoList(yearData['locationPhotos']);
      final currentImages = _decodePhotoList(yearData['currentPhotos']);
      final damageImages = _decodePhotoList(yearData['damagePhotos']);
      _locationImages
        ..clear()
        ..addAll(locationImages);
      _currentPhotos
        ..clear()
        ..addAll(currentImages);
      _damagePhotos
        ..clear()
        ..addAll(damageImages);
      _hasUnsavedChanges = false;
    }

    setState(() {
      _mgmtFireSafety = firePresence;
      _mgmtElectrical = electricalPresence;
    });
  }

  void _scheduleSave() {
    if (!_isEditable) return;
    _hasUnsavedChanges = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _saveNow();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to auto-save management data: $e');
          debugPrint(st.toString());
        }
      }
    });
  }




  Future<void> _saveNow() async {
    print('🚨 BasicInfoScreen._saveNow 함수가 호출되었습니다!');
    debugPrint('🚨 BasicInfoScreen._saveNow 함수가 호출되었습니다!');
    
    _saveDebounce?.cancel();
    final yearKey = _currentYearKey;
    if (yearKey.isEmpty) {
      print('⚠️ yearKey가 비어있습니다. 저장을 건너뜁니다.');
      return;
    }
    
    print('🔄 BasicInfoScreen 저장 시작 - yearKey: $yearKey');

    String trim(TextEditingController controller) => controller.text.trim();

    // 텍스트 필드 데이터 수집 (별도 저장 버튼 사용)
    final textFieldsData = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('📝 텍스트 필드는 별도 저장 버튼으로 저장됩니다.');

    final surveyData = <String, dynamic>{
      for (final row in _surveyRowConfigs)
        row.key: trim(_surveyControllers[row.key]!),
    };

    final conservationData = <String, dynamic>{
      for (final row in _conservationRowConfigs)
        row.key: {
          'section': row.section,
          'part': trim(_conservationPartControllers[row.key]!),
          'note': trim(_conservationNoteControllers[row.key]!),
          'photoLocation': trim(_conservationLocationControllers[row.key]!),
        },
    };

    Map<String, dynamic> presencePayload(
      Presence? presence,
      TextEditingController controller, {
      required String section,
      required String part,
    }) => {
      'section': section,
      'part': part,
      'note': trim(controller),
      'presence': presence == null
          ? null
          : (presence == Presence.yes ? 'yes' : 'no'),
      'exists': presence == null
          ? null
          : (presence == Presence.yes ? 'yes' : 'no'),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final fireData = presencePayload(
      _mgmtFireSafety,
      _fireSafetyNoteController,
      section: '소방 및 안전관리',
      part: trim(_fireSafetyPartController),
    );
    final electricalData = presencePayload(
      _mgmtElectrical,
      _electricalNoteController,
      section: '전기시설',
      part: trim(_electricalPartController),
    );

    final timestamp = FieldValue.serverTimestamp();
    await _firestore
        .collection('heritage_management')
        .doc(widget.heritageId)
        .set({
          'years.$yearKey.survey': surveyData,
          'years.$yearKey.conservation': conservationData,
          'years.$yearKey.fireSafety': fireData,
          'years.$yearKey.electrical': electricalData,
          'years.$yearKey.textFields': textFieldsData, // 텍스트 필드 데이터 추가
          'years.$yearKey.updatedAt': timestamp,
          'heritageName': widget.heritageName,
          'updatedAt': timestamp,
        }, SetOptions(merge: true));

    // 텍스트 필드 데이터는 별도 저장 버튼으로 저장
    print('📝 텍스트 필드는 "텍스트 데이터 저장" 버튼을 통해 저장됩니다.');

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
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
        _preservationFoundationBasePhotoController.text = url;
        break;
      case 'foundationCornerstone':
        _preservationFoundationCornerstonePhotoController.text = url;
        break;
      case 'shaftVerticalMembers':
        _preservationShaftVerticalMembersPhotoController.text = url;
        break;
      case 'shaftLintelTiebeam':
        _preservationShaftLintelTiebeamPhotoController.text = url;
        break;
      case 'shaftBracketSystem':
        _preservationShaftBracketSystemPhotoController.text = url;
        break;
      case 'shaftWallGomagi':
        _preservationShaftWallGomagiPhotoController.text = url;
        break;
      case 'shaftOndolFloor':
        _preservationShaftOndolFloorPhotoController.text = url;
        break;
      case 'shaftWindowsRailings':
        _preservationShaftWindowsRailingsPhotoController.text = url;
        break;
      case 'roofFramingMembers':
        _preservationRoofFramingMembersPhotoController.text = url;
        break;
      case 'roofRaftersPuyeon':
        _preservationRoofRaftersPuyeonPhotoController.text = url;
        break;
      case 'roofRoofTiles':
        _preservationRoofRoofTilesPhotoController.text = url;
        break;
      case 'roofCeilingDanjip':
        _preservationRoofCeilingDanjipPhotoController.text = url;
        break;
      case 'otherSpecialNotes':
        _preservationOtherSpecialNotesPhotoController.text = url;
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

  // 컨트롤러를 기반으로 사진 키 반환
  String _getPhotoKey(TextEditingController controller) {
    if (controller == _preservationFoundationBasePhotoController) return 'foundationBase';
    if (controller == _preservationFoundationCornerstonePhotoController) return 'foundationCornerstone';
    if (controller == _preservationShaftVerticalMembersPhotoController) return 'shaftVerticalMembers';
    if (controller == _preservationShaftLintelTiebeamPhotoController) return 'shaftLintelTiebeam';
    if (controller == _preservationShaftBracketSystemPhotoController) return 'shaftBracketSystem';
    if (controller == _preservationShaftWallGomagiPhotoController) return 'shaftWallGomagi';
    if (controller == _preservationShaftOndolFloorPhotoController) return 'shaftOndolFloor';
    if (controller == _preservationShaftWindowsRailingsPhotoController) return 'shaftWindowsRailings';
    if (controller == _preservationRoofFramingMembersPhotoController) return 'roofFramingMembers';
    if (controller == _preservationRoofRaftersPuyeonPhotoController) return 'roofRaftersPuyeon';
    if (controller == _preservationRoofRoofTilesPhotoController) return 'roofRoofTiles';
    if (controller == _preservationRoofCeilingDanjipPhotoController) return 'roofCeilingDanjip';
    if (controller == _preservationOtherSpecialNotesPhotoController) return 'otherSpecialNotes';
    return 'unknown';
  }

  // 변경사항 감지를 위한 리스너 추가
  void _addChangeListeners() {
    // 조사 결과 컨트롤러들에 리스너 추가
    for (final controller in _surveyControllers.values) {
      controller.addListener(_onFieldChanged);
    }
    
    // 보존 사항 컨트롤러들에 리스너 추가
    _preservationFoundationBaseController.addListener(_onFieldChanged);
    _preservationFoundationBasePhotoController.addListener(_onFieldChanged);
    _preservationFoundationCornerstonePhotoController.addListener(_onFieldChanged);
    _preservationShaftVerticalMembersController.addListener(_onFieldChanged);
    _preservationShaftVerticalMembersPhotoController.addListener(_onFieldChanged);
    _preservationShaftLintelTiebeamController.addListener(_onFieldChanged);
    _preservationShaftLintelTiebeamPhotoController.addListener(_onFieldChanged);
    _preservationShaftBracketSystemController.addListener(_onFieldChanged);
    _preservationShaftBracketSystemPhotoController.addListener(_onFieldChanged);
    _preservationShaftWallGomagiController.addListener(_onFieldChanged);
    _preservationShaftWallGomagiPhotoController.addListener(_onFieldChanged);
    _preservationShaftOndolFloorController.addListener(_onFieldChanged);
    _preservationShaftOndolFloorPhotoController.addListener(_onFieldChanged);
    _preservationShaftWindowsRailingsController.addListener(_onFieldChanged);
    _preservationShaftWindowsRailingsPhotoController.addListener(_onFieldChanged);
    _preservationRoofFramingMembersController.addListener(_onFieldChanged);
    _preservationRoofFramingMembersPhotoController.addListener(_onFieldChanged);
    _preservationRoofRaftersPuyeonController.addListener(_onFieldChanged);
    _preservationRoofRaftersPuyeonPhotoController.addListener(_onFieldChanged);
    _preservationRoofRoofTilesController.addListener(_onFieldChanged);
    _preservationRoofRoofTilesPhotoController.addListener(_onFieldChanged);
    _preservationRoofCeilingDanjipController.addListener(_onFieldChanged);
    _preservationRoofCeilingDanjipPhotoController.addListener(_onFieldChanged);
    _preservationOtherSpecialNotesController.addListener(_onFieldChanged);
    _preservationOtherSpecialNotesPhotoController.addListener(_onFieldChanged);
  }

  // 필드 변경 감지
  void _onFieldChanged() {
    if (_isEditable) {
      setState(() {
        _hasUnsavedChanges = _hasChanges();
      });
    }
  }

  // 변경사항 감지 리스너 제거
  void _removeChangeListeners() {
    // 조사 결과 컨트롤러들에서 리스너 제거
    for (final controller in _surveyControllers.values) {
      controller.removeListener(_onFieldChanged);
    }
    
    // 보존 사항 컨트롤러들에서 리스너 제거
    _preservationFoundationBaseController.removeListener(_onFieldChanged);
    _preservationFoundationBasePhotoController.removeListener(_onFieldChanged);
    _preservationFoundationCornerstonePhotoController.removeListener(_onFieldChanged);
    _preservationShaftVerticalMembersController.removeListener(_onFieldChanged);
    _preservationShaftVerticalMembersPhotoController.removeListener(_onFieldChanged);
    _preservationShaftLintelTiebeamController.removeListener(_onFieldChanged);
    _preservationShaftLintelTiebeamPhotoController.removeListener(_onFieldChanged);
    _preservationShaftBracketSystemController.removeListener(_onFieldChanged);
    _preservationShaftBracketSystemPhotoController.removeListener(_onFieldChanged);
    _preservationShaftWallGomagiController.removeListener(_onFieldChanged);
    _preservationShaftWallGomagiPhotoController.removeListener(_onFieldChanged);
    _preservationShaftOndolFloorController.removeListener(_onFieldChanged);
    _preservationShaftOndolFloorPhotoController.removeListener(_onFieldChanged);
    _preservationShaftWindowsRailingsController.removeListener(_onFieldChanged);
    _preservationShaftWindowsRailingsPhotoController.removeListener(_onFieldChanged);
    _preservationRoofFramingMembersController.removeListener(_onFieldChanged);
    _preservationRoofFramingMembersPhotoController.removeListener(_onFieldChanged);
    _preservationRoofRaftersPuyeonController.removeListener(_onFieldChanged);
    _preservationRoofRaftersPuyeonPhotoController.removeListener(_onFieldChanged);
    _preservationRoofRoofTilesController.removeListener(_onFieldChanged);
    _preservationRoofRoofTilesPhotoController.removeListener(_onFieldChanged);
    _preservationRoofCeilingDanjipController.removeListener(_onFieldChanged);
    _preservationRoofCeilingDanjipPhotoController.removeListener(_onFieldChanged);
    _preservationOtherSpecialNotesController.removeListener(_onFieldChanged);
    _preservationOtherSpecialNotesPhotoController.removeListener(_onFieldChanged);
  }

  // 연도별 데이터 불러오기
  Future<void> _loadYearData() async {
    if (widget.heritageId.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final fb = FirebaseService();
      final yearKey = _selectedYear.replaceAll('년 조사', '');
      
      // Firebase에서 해당 연도 데이터 조회
      final data = await fb.getYearData(widget.heritageId, yearKey);
      
      if (data != null) {
        // 조사 결과 데이터 로드
        final surveyData = data['surveyResults'] as Map<String, dynamic>? ?? {};
        for (final row in _surveyRowConfigs) {
          _surveyControllers[row.key]?.text = surveyData[row.key]?.toString() ?? '';
        }
        
        // 보존 사항 데이터 로드
        final preservationData = data['preservationItems'] as Map<String, dynamic>? ?? {};
        _preservationFoundationBaseController.text = preservationData['foundationBase']?.toString() ?? '';
        _preservationFoundationBasePhotoController.text = preservationData['foundationBasePhoto']?.toString() ?? '';
        _preservationFoundationCornerstonePhotoController.text = preservationData['foundationCornerstonePhoto']?.toString() ?? '';
        _preservationShaftVerticalMembersController.text = preservationData['shaftVerticalMembers']?.toString() ?? '';
        _preservationShaftVerticalMembersPhotoController.text = preservationData['shaftVerticalMembersPhoto']?.toString() ?? '';
        _preservationShaftLintelTiebeamController.text = preservationData['shaftLintelTiebeam']?.toString() ?? '';
        _preservationShaftLintelTiebeamPhotoController.text = preservationData['shaftLintelTiebeamPhoto']?.toString() ?? '';
        _preservationShaftBracketSystemController.text = preservationData['shaftBracketSystem']?.toString() ?? '';
        _preservationShaftBracketSystemPhotoController.text = preservationData['shaftBracketSystemPhoto']?.toString() ?? '';
        _preservationShaftWallGomagiController.text = preservationData['shaftWallGomagi']?.toString() ?? '';
        _preservationShaftWallGomagiPhotoController.text = preservationData['shaftWallGomagiPhoto']?.toString() ?? '';
        _preservationShaftOndolFloorController.text = preservationData['shaftOndolFloor']?.toString() ?? '';
        _preservationShaftOndolFloorPhotoController.text = preservationData['shaftOndolFloorPhoto']?.toString() ?? '';
        _preservationShaftWindowsRailingsController.text = preservationData['shaftWindowsRailings']?.toString() ?? '';
        _preservationShaftWindowsRailingsPhotoController.text = preservationData['shaftWindowsRailingsPhoto']?.toString() ?? '';
        _preservationRoofFramingMembersController.text = preservationData['roofFramingMembers']?.toString() ?? '';
        _preservationRoofFramingMembersPhotoController.text = preservationData['roofFramingMembersPhoto']?.toString() ?? '';
        _preservationRoofRaftersPuyeonController.text = preservationData['roofRaftersPuyeon']?.toString() ?? '';
        _preservationRoofRaftersPuyeonPhotoController.text = preservationData['roofRaftersPuyeonPhoto']?.toString() ?? '';
        _preservationRoofRoofTilesController.text = preservationData['roofRoofTiles']?.toString() ?? '';
        _preservationRoofRoofTilesPhotoController.text = preservationData['roofRoofTilesPhoto']?.toString() ?? '';
        _preservationRoofCeilingDanjipController.text = preservationData['roofCeilingDanjip']?.toString() ?? '';
        _preservationRoofCeilingDanjipPhotoController.text = preservationData['roofCeilingDanjipPhoto']?.toString() ?? '';
        _preservationOtherSpecialNotesController.text = preservationData['otherSpecialNotes']?.toString() ?? '';
        _preservationOtherSpecialNotesPhotoController.text = preservationData['otherSpecialNotesPhoto']?.toString() ?? '';
        
        // 관리사항 데이터 로드
        final managementData = data['managementItems'] as Map<String, dynamic>? ?? {};
        _hasDisasterManual = managementData['hasDisasterManual'] == true;
        _hasFireTruckAccess = managementData['hasFireTruckAccess'] == true;
        _hasFireLine = managementData['hasFireLine'] == true;
        _hasEvacTargets = managementData['hasEvacTargets'] == true;
        _hasTraining = managementData['hasTraining'] == true;
        _hasExtinguisher = managementData['hasExtinguisher'] == true;
        _hasHydrant = managementData['hasHydrant'] == true;
        _hasAutoAlarm = managementData['hasAutoAlarm'] == true;
        _hasCCTV = managementData['hasCCTV'] == true;
        _hasAntiTheftCam = managementData['hasAntiTheftCam'] == true;
        _hasFireDetector = managementData['hasFireDetector'] == true;
        _hasElectricalCheck = managementData['hasElectricalCheck'] == true;
        _hasGasCheck = managementData['hasGasCheck'] == true;
        _hasSecurityPersonnel = managementData['hasSecurityPersonnel'] == true;
        _hasManagementLog = managementData['hasManagementLog'] == true;
        _hasCareProject = managementData['hasCareProject'] == true;
        _hasInfoCenter = managementData['hasInfoCenter'] == true;
        _hasInfoBoard = managementData['hasInfoBoard'] == true;
        _hasExhibitionMuseum = managementData['hasExhibitionMuseum'] == true;
        _hasNationalHeritageInterpreter = managementData['hasNationalHeritageInterpreter'] == true;
        
        // 유지보수/수리 이력 데이터 로드
        final maintenanceData = data['maintenanceHistory'] as Map<String, dynamic>? ?? {};
        _precisionDiagnosis = maintenanceData['precision_diagnosis'] == true;
        _careProject = maintenanceData['care_project'] == true;
        _repairRecordController.text = maintenanceData['repair_record']?.toString() ?? '';
        
        // 원본 데이터 저장 (변경 감지용)
        _originalData = Map.from(data);
        
        setState(() {
          _hasUnsavedChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedYear 데이터를 불러왔습니다.')),
        );
      } else {
        // 데이터가 없는 경우 필드 초기화
        _clearAllFields();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedYear 데이터가 없습니다. 새로 입력하세요.')),
        );
      }
    } catch (e) {
      print('연도별 데이터 불러오기 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 불러오기 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 모든 필드 초기화
  void _clearAllFields() {
    for (final controller in _surveyControllers.values) {
      controller.clear();
    }
    for (final controller in _conservationPartControllers.values) {
      controller.clear();
    }
    for (final controller in _conservationNoteControllers.values) {
      controller.clear();
    }
    for (final controller in _conservationLocationControllers.values) {
      controller.clear();
    }
    _fireSafetyPartController.clear();
    _fireSafetyNoteController.clear();
    _electricalPartController.clear();
    _electricalNoteController.clear();
    
    // 보존 사항 필드 초기화
    _preservationFoundationBaseController.clear();
    _preservationFoundationBasePhotoController.clear();
    _preservationFoundationCornerstonePhotoController.clear();
    _preservationShaftVerticalMembersController.clear();
    _preservationShaftVerticalMembersPhotoController.clear();
    _preservationShaftLintelTiebeamController.clear();
    _preservationShaftLintelTiebeamPhotoController.clear();
    _preservationShaftBracketSystemController.clear();
    _preservationShaftBracketSystemPhotoController.clear();
    _preservationShaftWallGomagiController.clear();
    _preservationShaftWallGomagiPhotoController.clear();
    _preservationShaftOndolFloorController.clear();
    _preservationShaftOndolFloorPhotoController.clear();
    _preservationShaftWindowsRailingsController.clear();
    _preservationShaftWindowsRailingsPhotoController.clear();
    _preservationRoofFramingMembersController.clear();
    _preservationRoofFramingMembersPhotoController.clear();
    _preservationRoofRaftersPuyeonController.clear();
    _preservationRoofRaftersPuyeonPhotoController.clear();
    _preservationRoofRoofTilesController.clear();
    _preservationRoofRoofTilesPhotoController.clear();
    _preservationRoofCeilingDanjipController.clear();
    _preservationRoofCeilingDanjipPhotoController.clear();
    _preservationOtherSpecialNotesController.clear();
    _preservationOtherSpecialNotesPhotoController.clear();
    
    // 관리사항 체크박스 초기화
    _hasDisasterManual = false;
    _hasFireTruckAccess = false;
    _hasFireLine = false;
    _hasEvacTargets = false;
    _hasTraining = false;
    _hasExtinguisher = false;
    _hasHydrant = false;
    _hasAutoAlarm = false;
    _hasCCTV = false;
    _hasAntiTheftCam = false;
    _hasFireDetector = false;
    _hasElectricalCheck = false;
    _hasGasCheck = false;
    _hasSecurityPersonnel = false;
    _hasManagementLog = false;
    _hasCareProject = false;
    _hasInfoCenter = false;
    _hasInfoBoard = false;
    _hasExhibitionMuseum = false;
    _hasNationalHeritageInterpreter = false;
    
    // 유지보수/수리 이력 필드 초기화
    _precisionDiagnosis = false;
    _careProject = false;
    _repairRecordController.clear();
  }

  // 변경사항 감지
  bool _hasChanges() {
    // 현재 데이터와 원본 데이터 비교
    final currentData = _getCurrentData();
    return !_mapsEqual(currentData, _originalData);
  }

  // 현재 데이터 수집
  Map<String, dynamic> _getCurrentData() {
    final surveyData = <String, dynamic>{
      for (final row in _surveyRowConfigs)
        row.key: _surveyControllers[row.key]!.text.trim(),
    };
    
    final preservationData = <String, dynamic>{
      'foundationBase': _preservationFoundationBaseController.text.trim(),
      'foundationBasePhoto': _preservationFoundationBasePhotoController.text.trim(),
      'foundationCornerstonePhoto': _preservationFoundationCornerstonePhotoController.text.trim(),
      'shaftVerticalMembers': _preservationShaftVerticalMembersController.text.trim(),
      'shaftVerticalMembersPhoto': _preservationShaftVerticalMembersPhotoController.text.trim(),
      'shaftLintelTiebeam': _preservationShaftLintelTiebeamController.text.trim(),
      'shaftLintelTiebeamPhoto': _preservationShaftLintelTiebeamPhotoController.text.trim(),
      'shaftBracketSystem': _preservationShaftBracketSystemController.text.trim(),
      'shaftBracketSystemPhoto': _preservationShaftBracketSystemPhotoController.text.trim(),
      'shaftWallGomagi': _preservationShaftWallGomagiController.text.trim(),
      'shaftWallGomagiPhoto': _preservationShaftWallGomagiPhotoController.text.trim(),
      'shaftOndolFloor': _preservationShaftOndolFloorController.text.trim(),
      'shaftOndolFloorPhoto': _preservationShaftOndolFloorPhotoController.text.trim(),
      'shaftWindowsRailings': _preservationShaftWindowsRailingsController.text.trim(),
      'shaftWindowsRailingsPhoto': _preservationShaftWindowsRailingsPhotoController.text.trim(),
      'roofFramingMembers': _preservationRoofFramingMembersController.text.trim(),
      'roofFramingMembersPhoto': _preservationRoofFramingMembersPhotoController.text.trim(),
      'roofRaftersPuyeon': _preservationRoofRaftersPuyeonController.text.trim(),
      'roofRaftersPuyeonPhoto': _preservationRoofRaftersPuyeonPhotoController.text.trim(),
      'roofRoofTiles': _preservationRoofRoofTilesController.text.trim(),
      'roofRoofTilesPhoto': _preservationRoofRoofTilesPhotoController.text.trim(),
      'roofCeilingDanjip': _preservationRoofCeilingDanjipController.text.trim(),
      'roofCeilingDanjipPhoto': _preservationRoofCeilingDanjipPhotoController.text.trim(),
      'otherSpecialNotes': _preservationOtherSpecialNotesController.text.trim(),
      'otherSpecialNotesPhoto': _preservationOtherSpecialNotesPhotoController.text.trim(),
    };
    
    final managementData = <String, dynamic>{
      'hasDisasterManual': _hasDisasterManual,
      'hasFireTruckAccess': _hasFireTruckAccess,
      'hasFireLine': _hasFireLine,
      'hasEvacTargets': _hasEvacTargets,
      'hasTraining': _hasTraining,
      'hasExtinguisher': _hasExtinguisher,
      'hasHydrant': _hasHydrant,
      'hasAutoAlarm': _hasAutoAlarm,
      'hasCCTV': _hasCCTV,
      'hasAntiTheftCam': _hasAntiTheftCam,
      'hasFireDetector': _hasFireDetector,
      'hasElectricalCheck': _hasElectricalCheck,
      'hasGasCheck': _hasGasCheck,
      'hasSecurityPersonnel': _hasSecurityPersonnel,
      'hasManagementLog': _hasManagementLog,
      'hasCareProject': _hasCareProject,
      'hasInfoCenter': _hasInfoCenter,
      'hasInfoBoard': _hasInfoBoard,
      'hasExhibitionMuseum': _hasExhibitionMuseum,
      'hasNationalHeritageInterpreter': _hasNationalHeritageInterpreter,
    };
    
    final maintenanceData = <String, dynamic>{
      'precision_diagnosis': _precisionDiagnosis,
      'care_project': _careProject,
      'repair_record': _repairRecordController.text.trim(),
    };
    
    return {
      'surveyResults': surveyData,
      'preservationItems': preservationData,
      'managementItems': managementData,
      'maintenanceHistory': maintenanceData,
    };
  }

  // 맵 비교 함수
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key] != map2[key]) return false;
    }
    
    return true;
  }

  // 연도별 데이터 저장
  Future<void> _saveYearData() async {
    if (widget.heritageId.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    try {
      final fb = FirebaseService();
      final yearKey = _selectedYear.replaceAll('년 조사', '');
      final currentData = _getCurrentData();
      
      // Firebase에 연도별 데이터 저장
      await fb.saveYearData(widget.heritageId, yearKey, currentData);
      
      // 원본 데이터 업데이트
      _originalData = Map.from(currentData);
      
      setState(() {
        _hasUnsavedChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedYear 데이터가 저장되었습니다.')),
      );
    } catch (e) {
      print('연도별 데이터 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 수정 모드 토글
  void _toggleEditMode() {
    setState(() {
      _isEditable = !_isEditable;
      if (!_isEditable) {
        // 수정 모드 종료시 변경사항 감지
        _hasUnsavedChanges = _hasChanges();
      }
    });
  }

  // 1.1 조사 결과 저장 함수
  Future<void> _saveSurveyData() async {
    print('🚨 1.1 조사 결과 저장 시작!');
    debugPrint('🚨 1.1 조사 결과 저장 시작!');
    
    try {
      final heritageId = widget.heritageId;
      final heritageName = widget.heritageName;
      
      print('🔍 1.1 조사 결과 저장 - HeritageId: $heritageId, HeritageName: $heritageName');
      
      // 조사 결과 데이터 수집 (실제 사용자 입력 필드들)
      final surveyData = <String, dynamic>{
        for (final row in _surveyRowConfigs)
          row.key: _surveyControllers[row.key]!.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📝 저장할 조사 결과 데이터:');
      for (final row in _surveyRowConfigs) {
        print('  - ${row.label}: ${_surveyControllers[row.key]!.text.trim()}');
      }

      // Firebase에 저장
      final fb = FirebaseService();
      await fb.addDetailSurvey(
        heritageId: heritageId,
        heritageName: heritageName,
        surveyData: {
          'surveyResults': surveyData,
        },
      );

      print('✅ 1.1 조사 결과 저장 완료!');
    } catch (e) {
      print('❌ 1.1 조사 결과 저장 실패: $e');
      rethrow;
    }
  }

  Future<void> _addPhoto(_HistoryPhotoKind kind) async {
    if (!_isEditable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수정 모드에서만 사진을 추가할 수 있습니다.')));
      return;
    }
    if (_uploadingKinds.contains(kind)) return;
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, _) = picked;
    if (!mounted) return;
    final image = _HistoryImage(
      id: _uuid.v4(),
      bytes: bytes,
      isUploading: true,
    );
    final target = _photosForKind(kind);
    setState(() {
      _uploadingKinds.add(kind);
      target.add(image);
    });

    try {
      final metadata = await _persistPhoto(image: image, kind: kind);
      if (!mounted) return;
      setState(() {
        image.markUploaded(
          url: metadata['url'] as String,
          storagePath: metadata['storagePath'] as String,
          uploadedAt: metadata['uploadedAt'] as String,
          rawValue: metadata,
        );
        image.isUploading = false;
        _uploadingKinds.remove(kind);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진이 업로드되었습니다.')));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to upload history photo: $e');
        debugPrint(st.toString());
      }
      if (!mounted) return;
      setState(() {
        _uploadingKinds.remove(kind);
        target.remove(image);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진 업로드 실패: $e')));
    }
  }

  Future<Map<String, dynamic>> _persistPhoto({
    required _HistoryImage image,
    required _HistoryPhotoKind kind,
  }) async {
    final bytes = image.bytes;
    if (bytes == null) {
      throw StateError('이미지 데이터가 없습니다.');
    }
    final yearKey = _currentYearKey;
    final field = _photoField(kind);
    final storagePath =
        'heritages/${widget.heritageId}/history/$field/$yearKey/${image.id}.jpg';
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000',
      customMetadata: {
        'heritageId': widget.heritageId,
        'category': field,
        'year': yearKey,
      },
    );
    final task = await ref.putData(bytes, metadata);
    if (task.state != TaskState.success) {
      throw Exception('업로드 실패: ${task.state}');
    }
    final url = await ref.getDownloadURL();
    final uploadedAt = DateTime.now().toIso8601String();
    final map = {
      'id': image.id,
      'url': url,
      'storagePath': storagePath,
      'uploadedAt': uploadedAt,
    };
    await _firestore
        .collection('heritage_management')
        .doc(widget.heritageId)
        .set({
          'years.$yearKey.$field': FieldValue.arrayUnion([map]),
          'updatedAt': FieldValue.serverTimestamp(),
          'heritageName': widget.heritageName,
        }, SetOptions(merge: true));
    return map;
  }

  Future<void> _removePhoto(_HistoryPhotoKind kind, int index) async {
    if (!_isEditable) return;
    final target = _photosForKind(kind);
    if (index < 0 || index >= target.length) return;
    final image = target[index];
    if (image.isUploading) return;
    setState(() => target.removeAt(index));

    final payload = image.removalPayload();
    final field = _photoField(kind);
    final yearKey = _currentYearKey;
    try {
      if (payload != null) {
        await _firestore
            .collection('heritage_management')
            .doc(widget.heritageId)
            .set({
              'years.$yearKey.$field': FieldValue.arrayRemove([payload]),
            }, SetOptions(merge: true));
      }
      if (image.storagePath != null) {
        await _storage.ref(image.storagePath!).delete();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to remove history photo: $e');
        debugPrint(st.toString());
      }
      if (!mounted) return;
      setState(() => target.insert(index, image));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진 삭제 실패: $e')));
    }
  }

  List<_HistoryImage> _photosForKind(_HistoryPhotoKind kind) {
    switch (kind) {
      case _HistoryPhotoKind.location:
        return _locationImages;
      case _HistoryPhotoKind.current:
        return _currentPhotos;
      case _HistoryPhotoKind.damage:
        return _damagePhotos;
    }
  }

  String _photoField(_HistoryPhotoKind kind) {
    switch (kind) {
      case _HistoryPhotoKind.location:
        return 'locationPhotos';
      case _HistoryPhotoKind.current:
        return 'currentPhotos';
      case _HistoryPhotoKind.damage:
        return 'damagePhotos';
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _managementSub?.cancel();
    for (final controller in _surveyControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationPartControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationNoteControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationLocationControllers.values) {
      controller.dispose();
    }
    _fireSafetyPartController.dispose();
    _fireSafetyNoteController.dispose();
    _electricalPartController.dispose();
    _electricalNoteController.dispose();

    // 1.2 보존 사항 컨트롤러들 해제
    _preservationFoundationBaseController.dispose();
    _preservationFoundationBasePhotoController.dispose();
    _preservationFoundationCornerstonePhotoController.dispose();
    _preservationShaftVerticalMembersController.dispose();
    _preservationShaftVerticalMembersPhotoController.dispose();
    _preservationShaftLintelTiebeamController.dispose();
    _preservationShaftLintelTiebeamPhotoController.dispose();
    _preservationShaftBracketSystemController.dispose();
    _preservationShaftBracketSystemPhotoController.dispose();
    _preservationShaftWallGomagiController.dispose();
    _preservationShaftWallGomagiPhotoController.dispose();
    _preservationShaftOndolFloorController.dispose();
    _preservationShaftOndolFloorPhotoController.dispose();
    _preservationShaftWindowsRailingsController.dispose();
    _preservationShaftWindowsRailingsPhotoController.dispose();
    _preservationRoofFramingMembersController.dispose();
    _preservationRoofFramingMembersPhotoController.dispose();
    _preservationRoofRaftersPuyeonController.dispose();
    _preservationRoofRaftersPuyeonPhotoController.dispose();
    _preservationRoofRoofTilesController.dispose();
    _preservationRoofRoofTilesPhotoController.dispose();
    _preservationRoofCeilingDanjipController.dispose();
    _preservationRoofCeilingDanjipPhotoController.dispose();
    _preservationOtherSpecialNotesController.dispose();
    _preservationOtherSpecialNotesPhotoController.dispose();
    _repairRecordController.dispose();
    
    // 리스너 제거
    _removeChangeListeners();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_invalidHeritage) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = size.width * 0.9;
          final dialogHeight = size.height * 0.9;

          return SizedBox(
            width: dialogWidth.clamp(600, 1300),
            height: dialogHeight.clamp(500, 1000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '기존 이력',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedYear,
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedYear) {
                            setState(() {
                              _selectedYear = newValue;
                            });
                            _loadYearData();
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: '2024년 조사',
                            child: Text('2024년 조사'),
                          ),
                          DropdownMenuItem(
                            value: '2022년 조사',
                            child: Text('2022년 조사'),
                          ),
                          DropdownMenuItem(
                            value: '2020년 조사',
                            child: Text('2020년 조사'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HistorySectionTitle('1.1 조사결과'),
                          const SizedBox(height: 8),
                          _buildSurveyTable(),
                          const SizedBox(height: 32),
                          const _HistorySectionTitle('1.2 보존사항'),
                          const SizedBox(height: 8),
                          _buildPreservationTable(),
                          const SizedBox(height: 8),
                          _buildConservationTable(),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.3 관리사항'),
                          const SizedBox(height: 8),
                          _buildManagementTable(),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.4 유지보수/수리 이력'),
                          const SizedBox(height: 8),
                          _buildMaintenanceHistorySection(),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.5 위치현황'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '위치 도면/위성자료 등록',
                            description: '위치 및 도면 자료를 업로드하세요.',
                            photos: _locationImages,
                            kind: _HistoryPhotoKind.location,
                          ),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.6 현황사진'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '현황 사진 등록',
                            description: '최근 촬영한 현황 사진을 관리합니다.',
                            photos: _currentPhotos,
                            kind: _HistoryPhotoKind.current,
                          ),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.7 손상부 조사'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '손상부 사진 등록',
                            description: '손상부 조사 결과를 사진과 함께 보관합니다.',
                            photos: _damagePhotos,
                            kind: _HistoryPhotoKind.damage,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('뒤로가기'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6B7280)),
                          foregroundColor: const Color(0xFF6B7280),
                          minimumSize: const Size(120, 44),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isEditable && !_isSaving && _hasUnsavedChanges
                            ? () async {
                                await _saveYearData();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E2A44),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF1E2A44).withOpacity(0.3),
                          minimumSize: const Size(120, 44),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('저장'),
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _isEditable
                            ? () {
                                _toggleEditMode();
                              }
                            : () {
                                _toggleEditMode();
                              },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6B7280)),
                          foregroundColor: const Color(0xFF6B7280),
                          minimumSize: const Size(120, 44),
                        ),
                        child: Text(_isEditable ? '취소' : '수정'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tableHeaderCell(String text) => Container(
    color: Colors.grey.shade200,
    padding: const EdgeInsets.all(10),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: _tableHeaderFontSize,
      ),
    ),
  );

  Widget _readOnlyCell(String text) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      text.isEmpty ? '—' : text,
      style: TextStyle(fontSize: _tableBodyFontSize),
    ),
  );

  Widget _editableCell(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.all(6),
    child: TextFormField(
      controller: controller,
      enabled: _isEditable,
      minLines: 1,
      maxLines: maxLines,
      style: TextStyle(fontSize: _tableBodyFontSize),
      onChanged: (_) => _scheduleSave(),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint ?? '입력하세요',
        border: const OutlineInputBorder(),
        disabledBorder: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: _isEditable ? Colors.white : Colors.grey.shade100,
      ),
    ),
  );

  Widget _buildSurveyTable() {
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
          _buildSurveyTableSection('구조부', [
            _buildSurveyTableRow('기단부', _surveyControllers['foundation']!),
            _buildSurveyTableRow('축부(벽체부)', _surveyControllers['wall']!),
            _buildSurveyTableRow('지붕부', _surveyControllers['roof']!),
          ]),
          // 기타부 섹션
          _buildSurveyTableSection('기타부', [
            _buildSurveyTableRow('채색 (단청, 벽화)', _surveyControllers['coloring']!),
            _buildSurveyTableRow('충해', _surveyControllers['pest']!),
            _buildSurveyTableRow('기타', _surveyControllers['etc']!),
          ]),
          // 조사 정보 섹션
          _buildSurveyTableSection('조사 정보', [
            _buildSurveyTableRow('특기사항', _surveyControllers['safetyNotes']!),
            _buildSurveyTableRow('조사 종합의견', _surveyControllers['investigatorOpinion']!),
            _buildSurveyTableRow('등급분류', _surveyControllers['grade']!),
            _buildSurveyTableRow('조사일시', _surveyControllers['investigationDate']!),
            _buildSurveyTableRow('조사자', _surveyControllers['investigator']!),
          ]),
        ],
      ),
    );
  }

  Widget _buildSurveyTableSection(String sectionTitle, List<Widget> rows) {
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

  Widget _buildSurveyTableRow(String label, TextEditingController controller) {
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
              enabled: _isEditable,
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

  Widget _buildConservationTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _tableHeaderCell('구분'),
            _tableHeaderCell('부재'),
            _tableHeaderCell('조사내용(현상)'),
            _tableHeaderCell('사진/위치'),
          ],
        ),
        for (final row in _conservationRowConfigs)
          TableRow(
            children: [
              _readOnlyCell(row.section),
              _editableCell(
                _conservationPartControllers[row.key]!,
                hint: '예: ${row.part}',
              ),
              _editableCell(
                _conservationNoteControllers[row.key]!,
                hint: row.noteHint,
                maxLines: 3,
              ),
              _editableCell(
                _conservationLocationControllers[row.key]!,
                hint: row.locationHint,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildManagementTable() {
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
            '3. 관리사항',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          
          // 소방 및 안전관리 섹션
          _buildManagementFireSafetySection(),
          const SizedBox(height: 20),
          
          // 전기시설 관리상태 섹션
          _buildManagementElectricalSection(),
          const SizedBox(height: 20),
          
          // 가스시설 관리상태 섹션
          _buildManagementGasSection(),
          const SizedBox(height: 20),
          
          // 안전경비인력 관리상태 섹션
          _buildManagementSecuritySection(),
          const SizedBox(height: 20),
          
          // 돌봄사업 섹션
          _buildManagementCareSection(),
          const SizedBox(height: 20),

          // 안내 및 전시시설 섹션
          _buildManagementInfoExhibitionSection(),
          const SizedBox(height: 20),

          // 주변 및 부대시설 섹션
          _buildManagementSurroundingFacilitiesSection(),
          const SizedBox(height: 20),

          // 원래기능/활용상태/사용빈도 섹션
          _buildManagementOriginalFunctionSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildManagementFireSafetySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소방 및 안전관리',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('방재매뉴얼(소방시설도면 등) 배치 여부', _hasDisasterManual, (value) {
          setState(() => _hasDisasterManual = value);
        }),
        _buildManagementCheckboxRow('소방차의 진입 가능 여부', _hasFireTruckAccess, (value) {
          setState(() => _hasFireTruckAccess = value);
        }),
        _buildManagementCheckboxRow('방화선 여부', _hasFireLine, (value) {
          setState(() => _hasFireLine = value);
        }),
        _buildManagementCheckboxRow('국보·보물 내에 화재 시 대피 대상 국가유산 유무', _hasEvacTargets, (value) {
          setState(() => _hasEvacTargets = value);
        }),
        _buildManagementCheckboxRow('정기적인 교육과 훈련 실시 여부', _hasTraining, (value) {
          setState(() => _hasTraining = value);
        }),
        const SizedBox(height: 8),
        _buildManagementCheckboxWithCountRow('소화기', _hasExtinguisher, (value) {
          setState(() => _hasExtinguisher = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('옥외소화전', _hasHydrant, (value) {
          setState(() => _hasHydrant = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('자동화재속보설비', _hasAutoAlarm, (value) {
          setState(() => _hasAutoAlarm = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('CCTV', _hasCCTV, (value) {
          setState(() => _hasCCTV = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('도난방지카메라', _hasAntiTheftCam, (value) {
          setState(() => _hasAntiTheftCam = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('화재감지기', _hasFireDetector, (value) {
          setState(() => _hasFireDetector = value);
        }, TextEditingController()),
      ],
    );
  }

  Widget _buildManagementElectricalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text(
          '전기시설',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('전기시설 점검 여부', _hasElectricalCheck, (value) {
          setState(() => _hasElectricalCheck = value);
        }),
      ],
    );
  }

  Widget _buildManagementGasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        const Text(
          '가스시설',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('가스시설 점검 여부', _hasGasCheck, (value) {
          setState(() => _hasGasCheck = value);
        }),
      ],
    );
  }

  Widget _buildManagementSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '안전경비인력',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('안전경비인력 배치 여부', _hasSecurityPersonnel, (value) {
          setState(() => _hasSecurityPersonnel = value);
        }),
        _buildManagementCheckboxRow('관리일지 작성 여부', _hasManagementLog, (value) {
          setState(() => _hasManagementLog = value);
        }),
      ],
    );
  }

  Widget _buildManagementCareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        const Text(
          '돌봄사업',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('돌봄사업 참여 여부', _hasCareProject, (value) {
          setState(() => _hasCareProject = value);
        }),
      ],
    );
  }

  Widget _buildManagementInfoExhibitionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '안내 및 전시시설',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementCheckboxRow('안내센터', _hasInfoCenter, (value) {
          setState(() => _hasInfoCenter = value);
        }),
        _buildManagementCheckboxRow('안내판', _hasInfoBoard, (value) {
          setState(() => _hasInfoBoard = value);
        }),
        _buildManagementCheckboxRow('전시관/박물관', _hasExhibitionMuseum, (value) {
          setState(() => _hasExhibitionMuseum = value);
        }),
        _buildManagementCheckboxRow('국가유산 해설사', _hasNationalHeritageInterpreter, (value) {
          setState(() => _hasNationalHeritageInterpreter = value);
        }),
      ],
    );
  }

  Widget _buildManagementSurroundingFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주변 및 부대시설',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementTextFieldRow('보호벽', TextEditingController()),
        _buildManagementTextFieldRow('주변 수목', TextEditingController()),
        _buildManagementTextFieldRow('보호정자', TextEditingController()),
        _buildManagementTextFieldRow('기타 시설', TextEditingController()),
        _buildManagementTextFieldRow('배수시설', TextEditingController()),
        _buildManagementTextFieldRow('주변 건물', TextEditingController()),
      ],
    );
  }

  Widget _buildManagementOriginalFunctionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        const Text(
          '원래기능/활용상태/사용빈도',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildManagementTextFieldRow('원래기능/활용상태/사용빈도', TextEditingController()),
      ],
    );
  }

  Widget _buildManagementCheckboxRow(String label, bool value, ValueChanged<bool> onChanged) {
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
                _buildManagementCheckbox('있음', value, () => onChanged(true)),
                const SizedBox(width: 8),
                _buildManagementCheckbox('없음', !value, () => onChanged(false)),
              ],
            ),
            ),
          ],
        ),
    );
  }

  Widget _buildManagementCheckboxWithCountRow(String label, bool hasItem, ValueChanged<bool> onHasItemChanged, TextEditingController controller) {
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
                _buildManagementCheckbox('있음', hasItem, () => onHasItemChanged(true)),
                const SizedBox(width: 8),
                _buildManagementCheckbox('없음', !hasItem, () => onHasItemChanged(false)),
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

  Widget _buildManagementTextFieldRow(String label, TextEditingController controller) {
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
            flex: 2,
            child: TextField(
              controller: controller,
              enabled: _isEditable,
              decoration: InputDecoration(
                hintText: '내용을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                fillColor: Colors.white,
                filled: true,
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCheckbox(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? const Color(0xFF1E2A44) : const Color(0xFFD1D5DB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(3),
              color: isSelected ? const Color(0xFF1E2A44) : Colors.white,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
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
            _buildPreservationTableRow('기단부', '기단', _preservationFoundationBaseController, _preservationFoundationBasePhotoController, 
              surveyContent: '조사내용에서는 부재/위치/현상 순으로 내용을 기입한다.\n해당 현상을 촬영한 사진을 첨부하고, 사진/위치 란에 사진번호를 기입한다.\n사진번호는 부재명과 번호를 같이 기입한다.'),
            _buildPreservationTableRow('', '초석', TextEditingController(), _preservationFoundationCornerstonePhotoController),
          ]),
          // ② 축부(벽체부) 섹션
          _buildPreservationTableSection('② 축부(벽체부)', [
            _buildPreservationTableRow('축부(벽체부)', '기둥 등 수직재 (기둥 등 수직으로 하중을 받는 모든 부재)', 
              _preservationShaftVerticalMembersController, _preservationShaftVerticalMembersPhotoController),
            _buildPreservationTableRow('', '인방(引枋: 기둥과 기둥 사이에 놓이는 부재)/창방 등', 
              _preservationShaftLintelTiebeamController, _preservationShaftLintelTiebeamPhotoController),
            _buildPreservationTableRow('', '공포', _preservationShaftBracketSystemController, _preservationShaftBracketSystemPhotoController),
            _buildPreservationTableRow('', '벽체/고막이', _preservationShaftWallGomagiController, _preservationShaftWallGomagiPhotoController),
            _buildPreservationTableRow('', '구들/마루', _preservationShaftOndolFloorController, _preservationShaftOndolFloorPhotoController),
            _buildPreservationTableRow('', '창호/난간', _preservationShaftWindowsRailingsController, _preservationShaftWindowsRailingsPhotoController),
          ]),
          // ③ 지붕부 섹션
          _buildPreservationTableSection('③ 지붕부', [
            _buildPreservationTableRow('지붕부', '지붕 가구재', _preservationRoofFramingMembersController, _preservationRoofFramingMembersPhotoController,
              surveyContent: '보 부재 등의 조사내용을 기입한다.'),
            _buildPreservationTableRow('', '서까래/부연 (처마 서까래의 끝에 덧없는 네모지고 짧은 서까래)', 
              _preservationRoofRaftersPuyeonController, _preservationRoofRaftersPuyeonPhotoController),
            _buildPreservationTableRow('', '지붕/기와', _preservationRoofRoofTilesController, _preservationRoofRoofTilesPhotoController),
            _buildPreservationTableRow('', '천장/단집', _preservationRoofCeilingDanjipController, _preservationRoofCeilingDanjipPhotoController),
          ]),
          // 기타사항 섹션
          _buildPreservationTableSection('기타사항', [
            _buildPreservationTableRow('기타사항', '특기사항', _preservationOtherSpecialNotesController, _preservationOtherSpecialNotesPhotoController),
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
              enabled: _isEditable,
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
                    onPressed: _isEditable ? () => _pickImage(_getPhotoKey(photoController)) : null,
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

  Widget _buildSimpleDamageSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _damageSummaryTextController,
          decoration: const InputDecoration(
            labelText: '손상부 종합 내용',
            hintText: '손상부에 대한 종합적인 분석을 기록하세요',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        // 저장 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: null, // 임시로 비활성화
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 18),
                        SizedBox(width: 8),
                        Text('손상부 종합 저장'),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDamageSummaryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // 행 삭제 기능
                if (_damageSummaryRows.isNotEmpty) {
                  setState(() {
                    _damageSummaryRows.removeLast();
                  });
                }
              },
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('행 삭제'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 36),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _damageSummaryRows.add(_DamageSummaryRow());
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ 행 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(100), // 구성 요소
              1: FixedColumnWidth(80),  // 위치
              2: FixedColumnWidth(100), // 구조적 손상 이격/이완
              3: FixedColumnWidth(100), // 구조적 손상 기울
              4: FixedColumnWidth(100), // 물리적 손상 탈락
              5: FixedColumnWidth(100), // 물리적 손상 갈램
              6: FixedColumnWidth(100), // 생물·화학적 손상 천공
              7: FixedColumnWidth(100), // 생물·화학적 손상 부후
              8: FixedColumnWidth(80),  // 육안 등급 육안
              9: FixedColumnWidth(80),  // 실험실 등급 실험실
              10: FixedColumnWidth(80), // 최종 등급 최종
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
                children: [
                  _DamageTableCell('구성 요소', isHeader: true),
                  _DamageTableCell('위치', isHeader: true),
                  _DamageTableCell('구조적 손상\n이격/이완', isHeader: true),
                  _DamageTableCell('구조적 손상\n기울', isHeader: true),
                  _DamageTableCell('물리적 손상\n탈락', isHeader: true),
                  _DamageTableCell('물리적 손상\n갈램', isHeader: true),
                  _DamageTableCell('생물·화학적\n손상 천공', isHeader: true),
                  _DamageTableCell('생물·화학적\n손상 부후', isHeader: true),
                  _DamageTableCell('육안 등급\n육안', isHeader: true),
                  _DamageTableCell('실험실 등급\n실험실', isHeader: true),
                  _DamageTableCell('최종 등급\n최종', isHeader: true),
                ],
              ),
              if (_damageSummaryRows.isEmpty)
                const TableRow(
                  children: [
                    _DamageTableCell('행을 추가해 주세요.', isHeader: false, colSpan: 11),
                  ],
                )
              else
                ..._damageSummaryRows.map((row) => row.buildRow()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 저장 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: null, // 임시로 비활성화
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 18),
                        SizedBox(width: 8),
                        Text('손상부 종합 저장'),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaintenanceHistorySection() {
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
            '4. 유지보수/수리 이력',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          
          // 정밀진단 실시 여부
          _buildMaintenanceCheckboxRow(
            '정밀진단 실시 여부',
            _precisionDiagnosis,
            (value) {
              setState(() => _precisionDiagnosis = value);
            },
          ),
          const SizedBox(height: 16),
          
          // 돌봄사업 수행 여부
          _buildMaintenanceCheckboxRow(
            '돌봄사업 수행 여부',
            _careProject,
            (value) {
              setState(() => _careProject = value);
            },
          ),
          const SizedBox(height: 16),
          
          // 수리 기록
          _buildMaintenanceTextFieldRow(
            '수리 기록',
            _repairRecordController,
            '유지보수, 수리, 복원 이력을 입력하세요',
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCheckboxRow(String label, bool value, ValueChanged<bool> onChanged) {
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
                _buildMaintenanceCheckbox('실시', value, () => onChanged(true)),
                const SizedBox(width: 8),
                _buildMaintenanceCheckbox('미실시', !value, () => onChanged(false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCheckbox(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
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
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? const Color(0xFF1E2A44) : const Color(0xFF6B7280),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTextFieldRow(String label, TextEditingController controller, String hintText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: _isEditable,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hintText,
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
              fillColor: _isEditable ? Colors.white : const Color(0xFFF9FAFB),
              filled: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPhotoSection({
    required String title,
    required String description,
    required List<_HistoryImage> photos,
    required _HistoryPhotoKind kind,
  }) {
    final uploading = _uploadingKinds.contains(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: photos.length + (_isEditable ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isEditable && index == photos.length) {
              return _AddPhotoTile(
                onTap: uploading ? null : () => _addPhoto(kind),
                uploading: uploading,
              );
            }
            final photo = photos[index];
            return _HistoryImageTile(
              image: photo,
              canRemove: _isEditable && !photo.isUploading,
              onRemove: () => _removePhoto(kind, index),
            );
          },
        ),
      ],
    );
  }
}

enum Presence { yes, no }

enum _HistoryPhotoKind { location, current, damage }

class _HistorySectionTitle extends StatelessWidget {
  const _HistorySectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _HistoryTableCell extends StatelessWidget {
  const _HistoryTableCell(
    this.text, {
    super.key,
    this.isHeader = false,
    this.isRed = false,
  });

  final String text;
  final bool isHeader;
  final bool isRed;

  @override
  Widget build(BuildContext context) {
    if (isRed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _MgmtRadioCell extends StatelessWidget {
  const _MgmtRadioCell({
    super.key,
    required this.groupValue,
    required this.target,
    required this.onChanged,
    this.enabled = false,
  });

  final Presence? groupValue;
  final Presence target;
  final ValueChanged<Presence> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? () => onChanged(target) : null,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 1.3,
              child: Radio<Presence>(
                value: target,
                groupValue: groupValue,
                onChanged: enabled
                    ? (value) => value != null ? onChanged(value) : null
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MgmtNoteCell extends StatelessWidget {
  const _MgmtNoteCell({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            onChanged: enabled ? onChanged : null,
            style: TextStyle(
              color: enabled ? Colors.black87 : Colors.grey.shade600,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '조사내용을 입력하세요',
              border: const OutlineInputBorder(),
              disabledBorder: const OutlineInputBorder(),
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              filled: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap, this.uploading = false, super.key});

  final VoidCallback? onTap;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
          color: Colors.grey.shade100,
        ),
        child: Center(
          child: uploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 32,
                      color: Colors.black54,
                    ),
                    SizedBox(height: 6),
                    Text(
                      '사진 추가',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HistoryImageTile extends StatelessWidget {
  const _HistoryImageTile({
    required this.image,
    required this.onRemove,
    this.canRemove = false,
    super.key,
  });

  final _HistoryImage image;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Ink.image(
            image: image.provider,
            fit: BoxFit.cover,
            child: InkWell(onTap: () => _showPreview(context)),
          ),
        ),
        if (canRemove)
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (image.isUploading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: AspectRatio(
            aspectRatio: 1,
            child: Image(image: image.provider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _HistoryImage {
  _HistoryImage({
    required this.id,
    this.bytes,
    this.url,
    this.storagePath,
    this.uploadedAt,
    this.rawValue,
    this.isUploading = false,
  });

  final String id;
  Uint8List? bytes;
  String? url;
  String? storagePath;
  String? uploadedAt;
  Object? rawValue;
  bool isUploading;

  ImageProvider get provider {
    if (bytes != null && bytes!.isNotEmpty) {
      return MemoryImage(bytes!);
    }
    if (url != null && url!.isNotEmpty) {
      return NetworkImage(url!);
    }
    throw StateError('History image has no data');
  }

  void markUploaded({
    required String url,
    required String storagePath,
    required String uploadedAt,
    required Map<String, dynamic> rawValue,
  }) {
    this.url = url;
    this.storagePath = storagePath;
    this.uploadedAt = uploadedAt;
    this.rawValue = rawValue;
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    if (url != null) 'url': url,
    if (storagePath != null) 'storagePath': storagePath,
    if (uploadedAt != null) 'uploadedAt': uploadedAt,
  };

  Object? removalPayload() => rawValue ?? (url != null ? toFirestore() : null);
}
// ═══════════════════════════════════════════════════════════════
// DeepInspectionScreen - 심화조사 화면
// ═══════════════════════════════════════════════════════════════

class DeepInspectionScreen extends StatefulWidget {
  const DeepInspectionScreen({
    super.key,
    required this.selectedDamage,
  });

  final Map<String, dynamic> selectedDamage;

  @override
  State<DeepInspectionScreen> createState() => _DeepInspectionScreenState();
}

class _DeepInspectionScreenState extends State<DeepInspectionScreen> {
  final TextEditingController _detailedOpinionController = TextEditingController();
  final TextEditingController _recommendationController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  String _selectedPriority = '중';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 기존 데이터로 폼 초기화
    _detailedOpinionController.text = widget.selectedDamage['inspectorOpinion']?.toString() ?? '';
    _recommendationController.text = widget.selectedDamage['recommendation']?.toString() ?? '';
    _priorityController.text = widget.selectedDamage['priority']?.toString() ?? '중';
  }

  @override
  void dispose() {
    _detailedOpinionController.dispose();
    _recommendationController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('심화조사'),
        backgroundColor: const Color(0xFF1E2A44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 선택된 손상 정보 카드
            _buildSelectedDamageCard(),
            const SizedBox(height: 24),
            
            // 심화조사 폼
            _buildInspectionForm(),
            const SizedBox(height: 24),
            
            // 저장 버튼
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDamageCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '선택된 손상 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2A44),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('위치', widget.selectedDamage['location']?.toString() ?? '—'),
                      _buildInfoRow('손상 유형', widget.selectedDamage['phenomenon']?.toString() ?? '—'),
                      _buildInfoRow('등급', widget.selectedDamage['severityGrade']?.toString() ?? '—'),
                    ],
                  ),
                ),
                if (widget.selectedDamage['imageUrl'] != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.network(
                          widget.selectedDamage['imageUrl'].toString(),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '심화조사 상세 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2A44),
              ),
            ),
            const SizedBox(height: 16),
            
            // 상세 의견
            TextFormField(
              controller: _detailedOpinionController,
              decoration: const InputDecoration(
                labelText: '상세 조사 의견',
                hintText: '손상에 대한 상세한 조사 의견을 입력하세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            
            // 권고사항
            TextFormField(
              controller: _recommendationController,
              decoration: const InputDecoration(
                labelText: '권고사항',
                hintText: '보수 및 관리 권고사항을 입력하세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // 우선순위
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: '우선순위',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '높음', child: Text('높음')),
                DropdownMenuItem(value: '중', child: Text('중')),
                DropdownMenuItem(value: '낮음', child: Text('낮음')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value ?? '중';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveInspection,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E2A44),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              '심화조사 결과 저장',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _saveInspection() async {
    setState(() => _isSaving = true);

    try {
      // Firebase에 심화조사 데이터 저장
      final inspectionData = {
        'detailedOpinion': _detailedOpinionController.text.trim(),
        'recommendation': _recommendationController.text.trim(),
        'priority': _selectedPriority,
        'timestamp': DateTime.now().toIso8601String(),
        'inspectorId': 'current_user', // 실제 사용자 ID로 교체
      };

      // 기존 손상 데이터에 심화조사 정보 추가
      final updatedDamage = Map<String, dynamic>.from(widget.selectedDamage);
      updatedDamage.addAll(inspectionData);

      // Firebase에 업데이트된 데이터 저장
      // TODO: 실제 Firebase 저장 로직 구현
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('심화조사 결과가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {'saved': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
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

// ═══════════════════════════════════════════════════════════════
// DamageDetectionDialog - AI 손상부 조사 다이얼로그
// ═══════════════════════════════════════════════════════════════

class DamageDetectionDialog extends StatefulWidget {
  const DamageDetectionDialog({
    super.key,
    required this.aiService,
    this.autoCapture = false,
  });

  final AiDetectionService aiService;
  final bool autoCapture;

  @override
  State<DamageDetectionDialog> createState() => _DamageDetectionDialogState();
}

class _DamageDetectionDialogState extends State<DamageDetectionDialog> {
  Uint8List? _imageBytes;
  List<Map<String, dynamic>> _detections = [];
  bool _loading = false;

  String? _selectedLabel;
  double? _selectedConfidence;
  String? _autoGrade;
  String? _autoExplanation;
  double? _imageWidth;
  double? _imageHeight;

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _partController = TextEditingController();
  final TextEditingController _opinionController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  String _severityGrade = 'A';

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickImageAndDetect() async {
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, sizeGetter) = picked;
    final ui.Size size = await sizeGetter();
    setState(() {
      _loading = true;
      _imageBytes = bytes;
      _imageWidth = size.width;
      _imageHeight = size.height;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 먼저 촬영하거나 업로드하세요.')));
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
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.1, // 좌우 10% 여백
        vertical: screenHeight * 0.1, // 상하 10% 여백
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.8, // 화면 너비의 80%
        height: screenHeight * 0.8, // 화면 높이의 80%
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '손상부 조사',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _loading ? null : _pickImageAndDetect,
                icon: const Icon(Icons.camera_alt),
                label: const Text('사진 촬영 또는 업로드'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 44),
                ),
              ),
              const SizedBox(height: 16),

              _buildPreview(),
              const SizedBox(height: 20),

              if (_imageBytes != null) _buildAiSection(),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 12),
              const Text(
                '조사 정보 입력',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _infoField('손상 위치', _locationController, hint: '예: 남향 2번 평주'),
              _infoField('손상 부위', _partController, hint: '예: 기둥 - 상부'),
              Row(
                children: [
                  Expanded(
                    child: _infoField(
                      '온도(℃)',
                      _temperatureController,
                      hint: '예: 23',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoField(
                      '습도(%)',
                      _humidityController,
                      hint: '예: 55',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _severityGrade,
                decoration: const InputDecoration(
                  labelText: '심각도 (A~F)',
                  border: OutlineInputBorder(),
                ),
                items: const ['A', 'B', 'C', 'D', 'E', 'F']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _severityGrade = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _opinionController,
                decoration: const InputDecoration(
                  labelText: '조사자 의견',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 44),
                    ),
                    child: const Text('저장'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: _imageBytes == null
                ? const Center(child: Text('촬영된 이미지가 없습니다.'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    final uniqueLabels = _detections
        .map((e) => e['label'] as String? ?? '미분류')
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 예측 결과',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_detections.isEmpty)
          const Text('예측 데이터를 가져오지 못했습니다. 필요 시 직접 입력하세요.'),
        ..._detections.map((det) {
          final label = det['label'] as String? ?? '미분류';
          final score = (det['score'] as num?)?.toDouble() ?? 0;
          final percent = (score * 100).toStringAsFixed(1);
          final isPrimary = label == _selectedLabel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $label (${percent}%)',
              style: TextStyle(
                color: isPrimary ? Colors.redAccent : Colors.black87,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLabel,
          decoration: const InputDecoration(
            labelText: '결과 수정',
            border: OutlineInputBorder(),
          ),
          items: uniqueLabels
              .map(
                (label) => DropdownMenuItem(value: label, child: Text(label)),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedLabel = val;
              final match = _detections.firstWhere(
                (e) => (e['label'] as String?) == val,
                orElse: () => const {},
              );
              _selectedConfidence =
                  (match['score'] as num?)?.toDouble() ?? _selectedConfidence;
            });
          },
        ),
        if (_autoGrade != null) ...[
          const SizedBox(height: 16),
          _buildGradeSummary(),
        ],
      ],
    );
  }

  Widget _infoField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSummary() {
    final grade = (_autoGrade ?? '').toUpperCase();
    final explanation = _autoExplanation ?? '추가 설명이 제공되지 않았습니다.';

    Color background;
    switch (grade) {
      case 'D':
        background = Colors.red.shade100;
        break;
      case 'C':
        background = Colors.orange.shade100;
        break;
      case 'B':
        background = Colors.blue.shade100;
        break;
      default:
        background = Colors.green.shade100;
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              grade.isEmpty ? '?' : grade,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _normalizeDetections(
    List<Map<String, dynamic>> detections,
  ) {
    final width = _imageWidth;
    final height = _imageHeight;
    if (width == null || height == null || width == 0 || height == 0) {
      return detections
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    double clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

    return detections
        .map((det) {
          final mapped = Map<String, dynamic>.from(det);
          if (!(mapped.containsKey('x') &&
              mapped.containsKey('y') &&
              mapped.containsKey('w') &&
              mapped.containsKey('h'))) {
            final bbox = (mapped['bbox'] as List?)?.cast<num>();
            if (bbox != null && bbox.length == 4) {
              final x1 = bbox[0].toDouble();
              final y1 = bbox[1].toDouble();
              final x2 = bbox[2].toDouble();
              final y2 = bbox[3].toDouble();
              final w = (x2 - x1).clamp(0, width).toDouble();
              final h = (y2 - y1).clamp(0, height).toDouble();
              mapped['x'] = clamp01(x1 / width);
              mapped['y'] = clamp01(y1 / height);
              mapped['w'] = clamp01(w / width);
              mapped['h'] = clamp01(h / height);
            }
          }
          return mapped;
        })
        .toList(growable: false);
  }
}

class DamageDetectionResult {
  DamageDetectionResult({
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

  Map<String, dynamic> toDetailInputs() {
    return {
      if (damagePart != null) 'damagePart': damagePart,
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (selectedLabel != null) 'selectedLabel': selectedLabel,
      if (selectedConfidence != null) 'selectedConfidence': selectedConfidence,
      if (autoGrade != null) 'autoGrade': autoGrade,
      if (autoExplanation != null) 'autoExplanation': autoExplanation,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// DeepDamageInspectionDialog - 손상부 조사 (심화조사)
// ═══════════════════════════════════════════════════════════════

class DeepDamageInspectionDialog extends StatefulWidget {
  const DeepDamageInspectionDialog({super.key});

  @override
  State<DeepDamageInspectionDialog> createState() =>
      _DeepDamageInspectionDialogState();
}

class _DeepDamageInspectionDialogState
    extends State<DeepDamageInspectionDialog> {
  // 더미 이미지 URL (손상부 사진)
  final String damageImageUrl =
      'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=800';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '손상부 조사 (심화조사)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 스크롤 가능 영역 전체
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 손상 감지 이미지 + 박스 표시
                      Container(
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black12,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                damageImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 손상 박스들
                            Positioned(
                              left: 30,
                              top: 50,
                              child: _damageBox('갈라짐', Colors.yellow),
                            ),
                            Positioned(
                              right: 50,
                              top: 40,
                              child: _damageBox('충해흔', Colors.orange),
                            ),
                            Positioned(
                              left: 80,
                              bottom: 40,
                              child: _damageBox('변색', Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 손상유형 표
                      const Text(
                        '손상 유형 및 물리 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade400),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          _tableHeader(['손상유형', '구조', '물리', '생물·화학']),
                          _tableRow(['비중', '-', '-', '-']),
                          _tableRow(['함수율', '-', '-', '-']),
                          _tableRow(['공극률', '-', '-', '-']),
                          _tableRow(['압축강도', '-', '-', '-']),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 추가 정보 섹션
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '조사자 의견',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '손상 상태 및 보수 의견을 입력하세요',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),


                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // 버튼 영역 (스크롤 하단)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 등급 산출 로직
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('등급 산출 기능 준비 중')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade300,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('등급 산출'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 저장 로직
                      Navigator.pop(context, {'saved': true});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('저장'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 테이블 헤더
  TableRow _tableHeader(List<String> titles) => TableRow(
    decoration: BoxDecoration(color: Colors.grey.shade200),
    children: titles
        .map(
          (t) => Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                t,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        )
        .toList(),
  );

  // 테이블 행
  TableRow _tableRow(List<String> data) => TableRow(
    children: data
        .map(
          (d) => Padding(
            padding: const EdgeInsets.all(8),
            child: Center(child: Text(d)),
          ),
        )
        .toList(),
  );

  // 손상 박스 위젯
  Widget _damageBox(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2.5),
            color: color.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// 손상부 종합 테이블 행 클래스
class _DamageSummaryRow {
  final TextEditingController componentController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController structuralSeparationController = TextEditingController();
  final TextEditingController structuralTiltController = TextEditingController();
  final TextEditingController physicalDetachmentController = TextEditingController();
  final TextEditingController physicalCrackingController = TextEditingController();
  final TextEditingController biologicalPerforationController = TextEditingController();
  final TextEditingController biologicalDecayController = TextEditingController();
  final TextEditingController visualGradeController = TextEditingController();
  final TextEditingController labGradeController = TextEditingController();
  final TextEditingController finalGradeController = TextEditingController();

  TableRow buildRow() {
    return TableRow(
      children: [
        _DamageTableCell('', isHeader: false, controller: componentController),
        _DamageTableCell('', isHeader: false, controller: locationController),
        _DamageTableCell('', isHeader: false, controller: structuralSeparationController),
        _DamageTableCell('', isHeader: false, controller: structuralTiltController),
        _DamageTableCell('', isHeader: false, controller: physicalDetachmentController),
        _DamageTableCell('', isHeader: false, controller: physicalCrackingController),
        _DamageTableCell('', isHeader: false, controller: biologicalPerforationController),
        _DamageTableCell('', isHeader: false, controller: biologicalDecayController),
        _DamageTableCell('', isHeader: false, controller: visualGradeController),
        _DamageTableCell('', isHeader: false, controller: labGradeController),
        _DamageTableCell('', isHeader: false, controller: finalGradeController),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'component': componentController.text.trim(),
      'location': locationController.text.trim(),
      'structuralSeparation': structuralSeparationController.text.trim(),
      'structuralTilt': structuralTiltController.text.trim(),
      'physicalDetachment': physicalDetachmentController.text.trim(),
      'physicalCracking': physicalCrackingController.text.trim(),
      'biologicalPerforation': biologicalPerforationController.text.trim(),
      'biologicalDecay': biologicalDecayController.text.trim(),
      'visualGrade': visualGradeController.text.trim(),
      'labGrade': labGradeController.text.trim(),
      'finalGrade': finalGradeController.text.trim(),
    };
  }

  void dispose() {
    componentController.dispose();
    locationController.dispose();
    structuralSeparationController.dispose();
    structuralTiltController.dispose();
    physicalDetachmentController.dispose();
    physicalCrackingController.dispose();
    biologicalPerforationController.dispose();
    biologicalDecayController.dispose();
    visualGradeController.dispose();
    labGradeController.dispose();
    finalGradeController.dispose();
  }
}

// 손상부 종합 테이블 셀 위젯
class _DamageTableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final int colSpan;
  final TextEditingController? controller;

  const _DamageTableCell(
    this.text, {
    this.isHeader = false,
    this.colSpan = 1,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
          color: isHeader ? Colors.black87 : Colors.black54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
