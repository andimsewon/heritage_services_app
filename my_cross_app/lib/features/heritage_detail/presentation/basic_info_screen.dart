import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:my_cross_app/core/config/env.dart';
import 'package:my_cross_app/core/services/ai_detection_service.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/services/image_acquire.dart';
import 'package:my_cross_app/core/utils/image_url_helper.dart';
import 'package:my_cross_app/core/widgets/optimized_image.dart';
import 'package:my_cross_app/core/widgets/optimized_stream_builder.dart';
import 'package:my_cross_app/core/widgets/skeleton_loader.dart';
import 'package:my_cross_app/features/heritage_detail/application/heritage_detail_view_model.dart';
import 'package:my_cross_app/features/heritage_detail/data/ai_prediction_repository.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/dialogs/improved_damage_survey_dialog.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/ai_prediction_section.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/damage_summary_table.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/grade_classification_card.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/inspection_result_card.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/investigator_opinion_field.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/management_items_card.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/damage_preview_card.dart';
import 'package:my_cross_app/features/heritage_list/data/heritage_api.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

class _SectionNavigationItem {
  const _SectionNavigationItem({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String shortTitle;
  final IconData icon;
}

const List<_SectionNavigationItem> _sectionNavigationItems = [
  // 현장 조사 탭
  _SectionNavigationItem(
    key: 'basicInfo',
    title: '기본 정보',
    shortTitle: '기본',
    icon: Icons.info_outline,
  ),
  _SectionNavigationItem(
    key: 'metaInfo',
    title: '메타 정보',
    shortTitle: '메타',
    icon: Icons.description,
  ),
  _SectionNavigationItem(
    key: 'location',
    title: '위치 현황',
    shortTitle: '위치',
    icon: Icons.location_on,
  ),
  _SectionNavigationItem(
    key: 'photos',
    title: '현황 사진',
    shortTitle: '사진',
    icon: Icons.photo_camera,
  ),
  _SectionNavigationItem(
    key: 'damageSurvey',
    title: '손상부 조사',
    shortTitle: '손상',
    icon: Icons.build,
  ),
  // 조사자 의견 탭
  _SectionNavigationItem(
    key: 'preservationHistory',
    title: '보존관리 이력',
    shortTitle: '이력',
    icon: Icons.history,
  ),
  _SectionNavigationItem(
    key: 'inspectionResult',
    title: '조사 결과',
    shortTitle: '조사',
    icon: Icons.assignment,
  ),
  _SectionNavigationItem(
    key: 'preservationItems',
    title: '보존 사항',
    shortTitle: '보존',
    icon: Icons.construction,
  ),
  _SectionNavigationItem(
    key: 'management',
    title: '관리사항',
    shortTitle: '관리',
    icon: Icons.manage_accounts,
  ),
  // 종합진단 탭
  _SectionNavigationItem(
    key: 'damageSummary',
    title: '손상부 종합',
    shortTitle: '종합',
    icon: Icons.table_chart,
  ),
  _SectionNavigationItem(
    key: 'investigatorOpinion',
    title: '조사자 의견',
    shortTitle: '의견',
    icon: Icons.edit_note,
  ),
  _SectionNavigationItem(
    key: 'gradeClassification',
    title: '등급 분류',
    shortTitle: '등급',
    icon: Icons.grade,
  ),
  _SectionNavigationItem(
    key: 'aiPrediction',
    title: 'AI 예측',
    shortTitle: 'AI',
    icon: Icons.psychology,
  ),
];

const Map<String, int> _sectionNumbering = {
  // 현장 조사
  'basicInfo': 1,
  'metaInfo': 2,
  'location': 3,
  'photos': 4,
  'damageSurvey': 5,
  // 조사자 의견
  'preservationHistory': 1,
  'inspectionResult': 2,
  'preservationItems': 3,
  'management': 4,
  // 종합진단
  'damageSummary': 1,
  'investigatorOpinion': 2,
  'gradeClassification': 3,
  'aiPrediction': 4,
};

int? _sectionNumberFor(String key) => _sectionNumbering[key];

String _numberedTitle(String key, String title) {
  final number = _sectionNumberFor(key);
  return number != null ? '$number. $title' : title;
}

String _proxyImageUrl(String originalUrl, {int? maxWidth, int? maxHeight}) {
  return ImageUrlHelper.buildOptimizedUrl(
    originalUrl,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
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

class _BasicInfoScreenState extends State<BasicInfoScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _args;
  Map<String, dynamic>? _detail; // 상세 API 원본(JSON)
  bool _loading = true;
  late String heritageId;
  late final HeritageApi _api = HeritageApi(Env.proxyBase);
  final _fb = FirebaseService();
  final _ai = AiDetectionService(baseUrl: Env.aiBase);
  HeritageDetailViewModel? _detailViewModel;
  late final AIPredictionRepository _aiPredictionRepository =
      _MockAIPredictionRepository();

  // 섹션 네비게이션용 키 및 스크롤 컨트롤러
  final ScrollController _mainScrollController = ScrollController();
  TabController? _tabController;
  final Map<String, GlobalKey> _sectionKeys = {
    'basicInfo': GlobalKey(),
    'metaInfo': GlobalKey(),
    'location': GlobalKey(),
    'photos': GlobalKey(),
    'damageSurvey': GlobalKey(),
    'preservationHistory': GlobalKey(),
    'inspectionResult': GlobalKey(),
    'preservationItems': GlobalKey(),
    'management': GlobalKey(),
    'damageSummary': GlobalKey(),
    'investigatorOpinion': GlobalKey(),
    'aiPrediction': GlobalKey(),
    'gradeClassification': GlobalKey(),
  };

  String _activeSectionKey = 'basicInfo';
  int _currentTabIndex = 0; // 0: 현장 조사, 1: 조사자 의견, 2: 종합진단

  // 스크롤 감지 최적화를 위한 변수들
  Timer? _scrollThrottleTimer;
  bool _isScrollingProgrammatically = false;
  DateTime _lastScrollUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 스크롤 리스너 추가: 현재 보이는 섹션 자동 감지 (throttled)
    _mainScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onScroll);
    _scrollThrottleTimer?.cancel();
    _mainScrollController.dispose();
    _tabController?.dispose();
    _detailViewModel?.dispose();
    _metaDateController.dispose();
    _metaOrganizationController.dispose();
    _metaInvestigatorController.dispose();
    super.dispose();
  }

  // 스크롤 시 현재 섹션 자동 감지 (최적화된 버전)
  void _onScroll() {
    // 프로그래밍 방식 스크롤 중에는 감지하지 않음
    if (_isScrollingProgrammatically) return;
    if (!_mainScrollController.hasClients) return;

    // Throttling: 마지막 업데이트로부터 100ms 이내면 스킵
    final now = DateTime.now();
    if (now.difference(_lastScrollUpdate).inMilliseconds < 100) {
      return;
    }

    // 타이머가 이미 실행 중이면 취소하고 새로 시작 (debounce)
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 150), () {
      _updateActiveSection();
    });
  }

  // 실제 섹션 업데이트 로직 (throttled)
  void _updateActiveSection() {
    if (!_mainScrollController.hasClients) return;
    if (_isScrollingProgrammatically) return;

    final currentTabSections = _getCurrentTabSections();
    if (currentTabSections.isEmpty) return;

    // 스크롤 위치 기반으로 섹션 찾기 (더 효율적)
    final scrollOffset = _mainScrollController.offset;
    final viewportHeight = _mainScrollController.position.viewportDimension;
    final navBarHeight = 120.0;
    final threshold = navBarHeight + 100; // 네비게이션 바 + 여유 공간

    String? newActiveSection;
    double? minDistance;

    // 각 섹션의 위치를 확인
    for (final sectionKey in currentTabSections) {
      final key = _sectionKeys[sectionKey];
      if (key?.currentContext == null) continue;

      final RenderBox? renderBox =
          key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      // 더 효율적인 위치 계산
      try {
        final position = renderBox.localToGlobal(Offset.zero);
        final sectionTop = position.dy;
        final sectionHeight = renderBox.size.height;
        final sectionBottom = sectionTop + sectionHeight;

        // 뷰포트 상단 근처에 있는 섹션 찾기
        if (sectionTop <= threshold && sectionBottom > threshold) {
          final distance = (sectionTop - threshold).abs();
          if (minDistance == null || distance < minDistance) {
            minDistance = distance;
            newActiveSection = sectionKey;
          }
        }
      } catch (e) {
        // 렌더링 오류 무시하고 계속 진행
        continue;
      }
    }

    // 첫 번째 섹션이 아직 보이지 않으면 첫 번째 섹션을 활성화
    if (newActiveSection == null && currentTabSections.isNotEmpty) {
      final firstSectionKey = currentTabSections.first;
      final firstKey = _sectionKeys[firstSectionKey];
      if (firstKey?.currentContext != null) {
        try {
          final renderBox =
              firstKey!.currentContext!.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            if (position.dy > threshold) {
              newActiveSection = firstSectionKey;
            }
          }
        } catch (e) {
          // 오류 무시
        }
      }
    }

    // 활성 섹션 업데이트 (변경된 경우에만)
    if (newActiveSection != null && newActiveSection != _activeSectionKey) {
      _lastScrollUpdate = DateTime.now();
      if (mounted) {
        setState(() {
          _activeSectionKey = newActiveSection!;
        });
      }
    }
  }

  // 현재 탭의 섹션 목록 반환
  List<String> _getCurrentTabSections() {
    switch (_currentTabIndex) {
      case 0: // 현장 조사
        return ['basicInfo', 'metaInfo', 'location', 'photos', 'damageSurvey'];
      case 1: // 조사자 의견
        return [
          'preservationHistory',
          'inspectionResult',
          'preservationItems',
          'management',
        ];
      case 2: // 종합진단
        return [
          'damageSummary',
          'investigatorOpinion',
          'gradeClassification',
          'aiPrediction',
        ];
      default:
        return [];
    }
  }

  // 탭별 섹션 캐싱 (성능 최적화)
  List<Widget>? _cachedFieldSurveySections;
  List<Widget>? _cachedInvestigatorOpinionSections;
  List<Widget>? _cachedComprehensiveDiagnosisSections;

  // 메타 정보 컨트롤러
  final _metaDateController = TextEditingController();
  final _metaOrganizationController = TextEditingController();
  final _metaInvestigatorController = TextEditingController();

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
  final _preservationFoundationCornerstonePhotoController =
      TextEditingController();
  final _preservationShaftVerticalMembersController = TextEditingController();
  final _preservationShaftVerticalMembersPhotoController =
      TextEditingController();
  final _preservationShaftLintelTiebeamController = TextEditingController();
  final _preservationShaftLintelTiebeamPhotoController =
      TextEditingController();
  final _preservationShaftBracketSystemController = TextEditingController();
  final _preservationShaftBracketSystemPhotoController =
      TextEditingController();
  final _preservationShaftWallGomagiController = TextEditingController();
  final _preservationShaftWallGomagiPhotoController = TextEditingController();
  final _preservationShaftOndolFloorController = TextEditingController();
  final _preservationShaftOndolFloorPhotoController = TextEditingController();
  final _preservationShaftWindowsRailingsController = TextEditingController();
  final _preservationShaftWindowsRailingsPhotoController =
      TextEditingController();
  final _preservationRoofFramingMembersController = TextEditingController();
  final _preservationRoofFramingMembersPhotoController =
      TextEditingController();
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
      _tabController = TabController(length: 3, vsync: this);
      _tabController!.addListener(() {
        setState(() {
          _currentTabIndex = _tabController!.index;
        });
        if (!_tabController!.indexIsChanging) {
          _scrollToTabSection(_tabController!.index);
        }
      });
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
      // 병렬로 데이터 로드
      final futures = <Future>[];

      // 1. 기본 유산 정보 로드
      Future<Map<String, dynamic>> heritageFuture;
      if (_args?['isCustom'] == true) {
        heritageFuture = _loadCustomHeritage();
      } else {
        heritageFuture = _loadHeritageFromAPI();
      }
      futures.add(heritageFuture);

      // 2. 텍스트 데이터 로드 (병렬)
      futures.add(_loadTextFields());

      // 3. 메타 정보 로드 (병렬)
      futures.add(_loadMetaInfo());

      // 4. 모든 데이터를 병렬로 로드
      final results = await Future.wait(futures);

      // 결과 처리
      if (results.isNotEmpty && results[0] != null) {
        final detailData = results[0] as Map<String, dynamic>?;
        if (detailData != null && mounted) {
          setState(() => _detail = detailData);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 상세 데이터 로드 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');

      if (!mounted) return;

      String errorMessage = '상세 정보를 불러오는 중 오류가 발생했습니다.';

      // 구체적인 오류 메시지 제공
      final errorStr = e.toString();
      if (errorStr.contains('permission-denied')) {
        errorMessage = '데이터 조회 권한이 없습니다.';
      } else if (errorStr.contains('network') ||
          errorStr.contains('Connection')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (errorStr.contains('timeout')) {
        errorMessage = '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
      } else if (errorStr.length < 100) {
        errorMessage = '오류: $errorStr';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: '재시도',
            textColor: Colors.white,
            onPressed: () => _load(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _loadCustomHeritage() async {
    try {
      final customId = _args?['customId'] as String?;
      if (customId != null && customId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('custom_heritages')
            .doc(customId)
            .get()
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('사용자 추가 문화유산 데이터 로드 시간 초과');
              },
            );

        if (!snap.exists) {
          debugPrint('⚠️ 사용자 추가 문화유산 문서가 존재하지 않습니다: $customId');
          return {
            'item': {'ccbaMnm1': _args?['name'] as String? ?? ''},
          };
        }

        final m = snap.data() ?? <String, dynamic>{};
        return {
          'item': {
            'ccbaMnm1':
                (m['name'] as String?) ?? (_args?['name'] as String? ?? ''),
            'ccmaName': m['ccmaName'] ?? m['kindName'] ?? '',
            'ccbaAsdt': m['ccbaAsdt'] ?? m['asdt'] ?? '',
            'ccbaPoss': m['ccbaPoss'] ?? m['owner'] ?? '',
            'ccbaAdmin': m['ccbaAdmin'] ?? m['admin'] ?? '',
            'ccbaLcto': m['ccbaLcto'] ?? m['lcto'] ?? '',
            'ccbaLcad': m['ccbaLcad'] ?? m['lcad'] ?? '',
          },
        };
      } else {
        return {
          'item': {'ccbaMnm1': _args?['name'] as String? ?? ''},
        };
      }
    } on TimeoutException {
      debugPrint('⏰ 사용자 추가 문화유산 로드 타임아웃');
      rethrow;
    } catch (e) {
      debugPrint('❌ 사용자 추가 문화유산 로드 실패: $e');
      // 기본값 반환
      return {
        'item': {'ccbaMnm1': _args?['name'] as String? ?? ''},
      };
    }
  }

  Future<Map<String, dynamic>> _loadHeritageFromAPI() async {
    try {
      final ccbaKdcd = _args?['ccbaKdcd'] as String? ?? '';
      final ccbaAsno = _args?['ccbaAsno'] as String? ?? '';

      if (ccbaKdcd.isEmpty || ccbaAsno.isEmpty) {
        throw ArgumentError('문화유산 코드 또는 번호가 없습니다.');
      }

      return await _api
          .fetchDetail(
            ccbaKdcd: ccbaKdcd,
            ccbaAsno: ccbaAsno,
            ccbaCtcd: _args?['ccbaCtcd'] as String? ?? '',
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('문화유산 상세 정보 로드 시간 초과');
            },
          );
    } on TimeoutException {
      debugPrint('⏰ API 로드 타임아웃');
      rethrow;
    } catch (e) {
      debugPrint('❌ API에서 문화유산 상세 정보 로드 실패: $e');
      rethrow;
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
                      child: OptimizedImage(
                        imageUrl: proxiedUrl,
                        fit: BoxFit.contain,
                        placeholder: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 64,
                          ),
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

    // 업로드 시작 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('이미지를 업로드하는 중...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    if (!mounted) return;
    final title = await _askTitle(context);
    if (title == null) return;

    try {
      await _fb.addPhoto(
        heritageId: heritageId,
        heritageName: _name,
        title: title,
        imageBytes: bytes,
        sizeGetter: sizeGetter,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '사진이 업로드되었습니다. 잠시 후 목록에 표시됩니다.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '업로드 실패: ${e.toString()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      debugPrint('사진 업로드 오류: $e');
    }
  }

  Future<void> _addLocationPhoto() async {
    if (!mounted) return;

    // 업로드 시작 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('이미지를 업로드하는 중...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    if (!mounted) return;
    final title = await _askTitle(context);
    if (title == null) return;

    try {
      await _fb.addPhoto(
        heritageId: heritageId,
        heritageName: _name,
        title: title,
        imageBytes: bytes,
        sizeGetter: sizeGetter,
        folder: 'location_photos',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '사진이 업로드되었습니다. 잠시 후 목록에 표시됩니다.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '업로드 실패: ${e.toString()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      debugPrint('위치 사진 업로드 오류: $e');
    }
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
          SnackBar(content: Text('텍스트 저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingText = false);
      }
    }
  }

  // 텍스트 필드 데이터 로드
  Future<void> _loadMetaInfo() async {
    try {
      final metaInfo = await _fb.getMetaInfo(heritageId);
      if (metaInfo != null && mounted) {
        setState(() {
          _metaDateController.text = metaInfo['surveyDate']?.toString() ?? '';
          _metaOrganizationController.text =
              metaInfo['organization']?.toString() ?? '';
          _metaInvestigatorController.text =
              metaInfo['investigator']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('⚠️ 메타 정보 로드 실패: $e');
      // 에러가 발생해도 계속 진행 (선택적 데이터)
    }
  }

  Future<void> _loadTextFields() async {
    debugPrint('📭 텍스트 필드 데이터 로드 시작!');

    try {
      final heritageId = this.heritageId;
      if (heritageId.isEmpty) {
        debugPrint('⚠️ HeritageId가 비어있습니다.');
        return;
      }

      debugPrint('🔍 텍스트 로드 - HeritageId: $heritageId');

      // Firebase에서 최신 데이터 가져오기 (타임아웃 적용)
      final surveys = await _fb
          .getDetailSurveys(heritageId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('텍스트 필드 데이터 로드 시간 초과');
            },
          );

      if (!mounted) return;

      if (surveys.docs.isNotEmpty) {
        final latestData = surveys.docs.first.data();
        debugPrint('📝 로드된 텍스트 데이터:');
        debugPrint('  - 1.1 조사 결과: ${latestData['inspectionResult'] ?? ''}');
        debugPrint('  - 관리사항: ${latestData['managementItems'] ?? ''}');
        debugPrint('  - 손상부 종합: ${latestData['damageSummary'] ?? ''}');
        debugPrint('  - 조사자 의견: ${latestData['investigatorOpinion'] ?? ''}');
        debugPrint('  - 기존 이력: ${latestData['existingHistory'] ?? ''}');

        // 텍스트 필드에 데이터 설정 (mounted 체크 후)
        if (mounted) {
          _inspectionResult.text =
              (latestData['inspectionResult'] as String?) ?? '';
          _managementItems.text =
              (latestData['managementItems'] as String?) ?? '';
          _damageSummary.text = (latestData['damageSummary'] as String?) ?? '';
          _investigatorOpinion.text =
              (latestData['investigatorOpinion'] as String?) ?? '';
          _gradeClassification.text =
              (latestData['gradeClassification'] as String?) ?? '';
          _existingHistory.text =
              (latestData['existingHistory'] as String?) ?? '';
        }

        debugPrint('✅ 텍스트 필드 데이터 로드 완료!');
      } else {
        debugPrint('📭 저장된 텍스트 데이터가 없습니다.');
      }
    } on TimeoutException {
      debugPrint('⏰ 텍스트 필드 로드 타임아웃');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터 로드 시간이 초과되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 텍스트 필드 데이터 로드 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '텍스트 데이터 로드 실패: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e.toString()}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
        heritageName: _name.isEmpty ? '미상' : _name,
        autoCapture: autoCapture,
      ),
    );

    if (result == null) return;

    // ImprovedDamageSurveyDialog에서 이미 저장 및 업데이트를 완료했으므로
    // 여기서는 중복 저장하지 않음 (데이터는 이미 Firebase에 저장됨)
    // 다이얼로그에서 저장 완료 메시지를 표시했으므로 여기서는 간단한 확인 메시지만 표시

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('손상부 조사가 완료되었습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
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

  // 섹션으로 스크롤 이동 (최적화된 버전)
  void _scrollToSection(String sectionKey) {
    // 활성 섹션 즉시 업데이트
    if (_activeSectionKey != sectionKey && mounted) {
      setState(() {
        _activeSectionKey = sectionKey;
      });
    }

    final key = _sectionKeys[sectionKey];
    if (key?.currentContext != null) {
      // 프로그래밍 방식 스크롤 시작
      _isScrollingProgrammatically = true;

      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.08,
      ).then((_) {
        // 스크롤 완료 후 잠시 대기 후 감지 재개
        Future.delayed(const Duration(milliseconds: 400), () {
          _isScrollingProgrammatically = false;
          // 스크롤 완료 후 섹션 위치 재확인
          _updateActiveSection();
        });
      });
    }
  }

  // 탭 전환 시 해당 섹션으로 스크롤
  void _scrollToTabSection(int tabIndex) {
    String? firstSectionKey;
    switch (tabIndex) {
      case 0: // 현장 조사
        firstSectionKey = 'basicInfo';
        break;
      case 1: // 조사자 의견
        firstSectionKey = 'preservationHistory';
        break;
      case 2: // 종합진단
        firstSectionKey = 'damageSummary';
        break;
    }
    if (firstSectionKey != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToSection(firstSectionKey!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
              const SizedBox(height: 24),
              Text(
                '데이터를 불러오는 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 24.0);

    // 현재 탭에 맞는 섹션 가져오기 (캐싱 사용)
    List<Widget> currentSections;
    switch (_currentTabIndex) {
      case 0: // 현장 조사
        currentSections = _cachedFieldSurveySections ??=
            _buildFieldSurveySections(
              context: context,
              kind: kind,
              asdt: asdt,
              owner: owner,
              admin: admin,
              lcto: lcto,
              lcad: lcad,
            );
        break;
      case 1: // 조사자 의견
        currentSections = _cachedInvestigatorOpinionSections ??=
            _buildInvestigatorOpinionSections(context: context);
        break;
      case 2: // 종합진단
        currentSections = _cachedComprehensiveDiagnosisSections ??=
            _buildComprehensiveDiagnosisSections(context: context);
        break;
      default:
        currentSections = [];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A44),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
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
              icon: const Icon(Icons.history, size: 16, color: Colors.white),
              label: const Text(
                '기존이력',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1),
                backgroundColor: Colors.white.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
        bottom: _tabController != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController!,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF6E6E73),
                    indicatorColor: Colors.transparent,
                    indicatorWeight: 0,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF2563EB), // Professional Blue
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    tabs: [
                      Tab(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 12 : 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _currentTabIndex == 0
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '현장 조사',
                                style: TextStyle(fontSize: isNarrow ? 13 : 15),
                              ),
                            );
                          },
                        ),
                      ),
                      Tab(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 12 : 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _currentTabIndex == 1
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '조사자 의견',
                                style: TextStyle(fontSize: isNarrow ? 13 : 15),
                              ),
                            );
                          },
                        ),
                      ),
                      Tab(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 12 : 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _currentTabIndex == 2
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '종합진단',
                                style: TextStyle(fontSize: isNarrow ? 13 : 15),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1040.0),
                child: CustomScrollView(
                  controller: _mainScrollController,
                  slivers: [
                    // 고정된 섹션 네비게이션 바 (상단 고정)
                    SliverPersistentHeader(
                      pinned: true,
                      floating: false,
                      delegate: _NavigationBarDelegate(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildTopNavigationBar(),
                        ),
                        horizontalPadding: horizontalPadding,
                      ),
                    ),
                    // 섹션 콘텐츠
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          ...currentSections,
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 현장 조사 섹션 (탭 0)
  List<Widget> _buildFieldSurveySections({
    required BuildContext context,
    required String kind,
    required String asdt,
    required String owner,
    required String admin,
    required String lcto,
    required String lcad,
  }) {
    final sections = <Widget>[
      // 1. 기본 정보
      Container(
        key: _sectionKeys['basicInfo'],
        child: BasicInfoCard(
          sectionNumber: _sectionNumberFor('basicInfo'),
          name: _name.isEmpty ? '미상' : _name,
          kind: kind,
          asdt: asdt,
          owner: owner,
          admin: admin,
          lcto: lcto,
          lcad: lcad,
          managementNumber: _managementNumber,
        ),
      ),
      const SizedBox(height: 24),
      // 2. 메타 정보 (조사 일자, 조사 기관, 조사자)
      Container(key: _sectionKeys['metaInfo'], child: _buildMetaInfoSection()),
      const SizedBox(height: 24),
      // 3. 위치 현황
      Container(
        key: _sectionKeys['location'],
        child: HeritagePhotoSection(
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
          sectionNumber: _sectionNumberFor('location'),
          title: '위치 현황',
          description: '위성사진, 배치도 등 위치 관련 자료를 등록하세요.',
          icon: Icons.location_on,
        ),
      ),
      const SizedBox(height: 24),
      // 4. 현황 사진
      Container(
        key: _sectionKeys['photos'],
        child: HeritagePhotoSection(
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
          sectionNumber: _sectionNumberFor('photos'),
          title: '현황 사진',
          description: '현장 전경과 세부 사진을 등록하세요.',
          icon: Icons.photo_camera_outlined,
        ),
      ),
      const SizedBox(height: 24),
      // 5. 손상부 조사
      Container(
        key: _sectionKeys['damageSurvey'],
        child: DamageSurveySection(
          sectionNumber: _sectionNumberFor('damageSurvey'),
          damageStream: _fb.damageStream(heritageId),
          onAddSurvey: () => _openDamageDetectionDialog(),
          onDeepInspection: (selectedDamage) async {
            final result = await showDialog(
              context: context,
              builder: (_) =>
                  DeepDamageInspectionDialog(selectedDamage: selectedDamage),
            );
            if (result != null && result['saved'] == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('심화조사 데이터가 저장되었습니다')),
              );
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
      ),
      const SizedBox(height: 24),
    ];

    // 텍스트 입력 필드는 제거 (현장 조사 탭에는 포함되지 않음)
    sections.add(const SizedBox(height: 48));
    return sections;
  }

  // 메타 정보 섹션 빌드
  bool _isSavingMetaInfo = false;

  Future<void> _saveMetaInfo() async {
    if (_isSavingMetaInfo) return;

    setState(() => _isSavingMetaInfo = true);

    try {
      await _fb.saveMetaInfo(
        heritageId: heritageId,
        heritageName: _name.isEmpty ? '미상' : _name,
        surveyDate: _metaDateController.text.trim(),
        organization: _metaOrganizationController.text.trim(),
        investigator: _metaInvestigatorController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '메타 정보가 저장되었습니다.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 메타 정보 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '저장 실패: ${e.toString()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingMetaInfo = false);
      }
    }
  }

  Widget _buildMetaInfoSection() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final sectionPadding = EdgeInsets.all(isMobile ? 16 : 24);
    return Container(
      padding: sectionPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x1A000000), // Apple-style subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _numberedTitle('metaInfo', '메타 정보'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '조사 일자, 기관, 조사자 정보를 입력하세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _metaDateController,
            decoration: InputDecoration(
              labelText: '조사 일자',
              hintText: 'YYYY-MM-DD',
              prefixIcon: const Icon(Icons.calendar_today, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _metaOrganizationController,
            decoration: InputDecoration(
              labelText: '조사 기관',
              hintText: '기관명',
              prefixIcon: const Icon(Icons.business, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _metaInvestigatorController,
            decoration: InputDecoration(
              labelText: '조사자',
              hintText: '성명',
              prefixIcon: const Icon(Icons.person, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0x1A000000),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingMetaInfo
                  ? null
                  : () {
                      // 햅틱 피드백 (모바일)
                      if (Theme.of(context).platform == TargetPlatform.iOS ||
                          Theme.of(context).platform ==
                              TargetPlatform.android) {
                        HapticFeedback.lightImpact();
                      }
                      _saveMetaInfo();
                    },
              icon: _isSavingMetaInfo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSavingMetaInfo ? '저장 중...' : '저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 12 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 조사자 의견 섹션 편집 가능 여부
  bool _isInvestigatorOpinionEditable = false;
  bool _isInvestigatorOpinionSaved = false;

  // 조사자 의견 섹션 (탭 1)
  List<Widget> _buildInvestigatorOpinionSections({
    required BuildContext context,
  }) {
    final sections = <Widget>[];

    if (_detailViewModel != null) {
      sections.add(
        AnimatedBuilder(
          animation: _detailViewModel!,
          builder: (context, _) {
            final vm = _detailViewModel!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 보존관리 이력
                Container(
                  key: _sectionKeys['preservationHistory'],
                  child: _buildPreservationHistorySection(context),
                ),
                const SizedBox(height: 24),
                // 조사 결과
                Container(
                  key: _sectionKeys['inspectionResult'],
                  child: InspectionResultCard(
                    sectionNumber: _sectionNumberFor('inspectionResult'),
                    value: vm.inspectionResult,
                    onChanged: _isInvestigatorOpinionEditable
                        ? vm.updateInspectionResult
                        : null,
                    heritageId: heritageId,
                    heritageName: _name.isEmpty ? '미상' : _name,
                  ),
                ),
                const SizedBox(height: 24),
                // 보존 사항 (손상부 조사 정보 자동 연결)
                Container(
                  key: _sectionKeys['preservationItems'],
                  child: _buildPreservationItemsSection(context, vm),
                ),
                const SizedBox(height: 24),
                // 관리사항
                Container(
                  key: _sectionKeys['management'],
                  child: ManagementItemsCard(
                    sectionNumber: _sectionNumberFor('management'),
                    heritageId: heritageId,
                    heritageName: _name.isEmpty ? '미상' : _name,
                    isReadOnly: !_isInvestigatorOpinionEditable,
                  ),
                ),
                const SizedBox(height: 24),
                // 저장/수정 버튼 및 수정 이력 버튼
                _buildInvestigatorOpinionActionBar(context),
              ],
            );
          },
        ),
      );
    } else {
      sections.add(
        Container(
          padding: const EdgeInsets.all(24),
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
          child: const Center(
            child: Text(
              '조사자 의견을 입력하려면 데이터를 먼저 로드해주세요.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ),
      );
    }

    sections.add(const SizedBox(height: 48));
    return sections;
  }

  // 보존관리 이력 섹션 (불러오기 버튼 포함)
  Widget _buildPreservationHistorySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Icons.history,
                      color: Color(0xFF1E2A44),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _numberedTitle('preservationHistory', '보존관리 이력'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // 기존 이력에서 불러오기
                  showDialog(
                    context: context,
                    builder: (_) => HeritageHistoryDialog(
                      heritageId: heritageId,
                      heritageName: _name,
                    ),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('불러오기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2A44),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '기존 이력에서 데이터를 불러와 동기화합니다.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // 보존 사항 섹션 (손상부 조사 정보 자동 연결)
  Widget _buildPreservationItemsSection(
    BuildContext context,
    HeritageDetailViewModel vm,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  Icons.construction,
                  color: Color(0xFF1E2A44),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _numberedTitle('preservationItems', '보존 사항'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '손상부 조사 정보가 자동으로 연결됩니다.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          // 손상부 조사 정보 표시
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _fb.damageStream(heritageId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('오류: ${snapshot.error}');
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    '등록된 손상부 조사가 없습니다.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: docs.map((doc) {
                  final data = doc.data();
                  final location = data['location'] as String? ?? '';
                  final part =
                      data['damagePart'] as String? ??
                      data['partName'] as String? ??
                      '';
                  final phenomenon = data['phenomenon'] as String? ?? '';
                  final severity = data['severityGrade'] as String? ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (location.isNotEmpty || part.isNotEmpty)
                          Text(
                            '${location.isNotEmpty ? location : ''}${location.isNotEmpty && part.isNotEmpty ? ' / ' : ''}${part.isNotEmpty ? part : ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        if (phenomenon.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '현상: $phenomenon',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        if (severity.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '등급: $severity',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // 조사자 의견 액션 바 (저장/수정 버튼, 수정 이력 버튼)
  Widget _buildInvestigatorOpinionActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showEditHistoryDialog(context),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('수정 이력'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          if (!_isInvestigatorOpinionEditable && _isInvestigatorOpinionSaved)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isInvestigatorOpinionEditable = true;
                });
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('수정'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // 변경된 필드 추적
                  final changedFields = <String>[];

                  // 조사 결과 저장
                  if (_detailViewModel != null) {
                    await _fb.saveInvestigatorOpinionSection(
                      heritageId: heritageId,
                      sectionType: 'inspectionResult',
                      data: {
                        'inspectionResult': _detailViewModel!.inspectionResult,
                      },
                      editor: '현재 사용자', // TODO: 실제 사용자 정보로 교체
                      changedFields: ['조사 결과'],
                    );
                    changedFields.add('조사 결과');
                  }

                  // 관리사항은 ManagementItemsCard에서 자체적으로 저장하므로 여기서는 수정 이력만 기록
                  changedFields.add('관리사항');

                  // 수정 이력 저장
                  if (changedFields.isNotEmpty) {
                    await _fb.saveEditHistory(
                      heritageId: heritageId,
                      sectionType: 'investigatorOpinion',
                      editor: '현재 사용자', // TODO: 실제 사용자 정보로 교체
                      changedFields: changedFields,
                    );
                  }

                  setState(() {
                    _isInvestigatorOpinionSaved = true;
                    _isInvestigatorOpinionEditable = false;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('저장되었습니다')));
                  }
                } catch (e) {
                  debugPrint('❌ 저장 실패: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('저장 실패: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2A44),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 수정 이력 다이얼로그 표시
  void _showEditHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '수정 이력',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _fb.editHistoryStream(heritageId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('오류: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '수정 이력이 없습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final timestamp = data['timestamp'] as Timestamp?;
                        final createdAt = data['createdAt'] as String?;
                        final editor = data['editor'] as String? ?? '알 수 없음';
                        final changedFields =
                            (data['changedFields'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList() ??
                            [];

                        String dateStr = '날짜 없음';
                        if (timestamp != null) {
                          final date = timestamp.toDate();
                          dateStr =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                        } else if (createdAt != null) {
                          try {
                            final date = DateTime.parse(createdAt);
                            dateStr =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          } catch (e) {
                            dateStr = createdAt;
                          }
                        }

                        return _buildEditHistoryItem(
                          date: dateStr,
                          editor: editor,
                          changes: changedFields,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 수정 이력 항목 빌드
  Widget _buildEditHistoryItem({
    required String date,
    required String editor,
    required List<String> changes,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '수정일: $date',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '수정자: $editor',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            '변경된 필드: ${changes.join(', ')}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // 종합진단 섹션 (탭 2)
  List<Widget> _buildComprehensiveDiagnosisSections({
    required BuildContext context,
  }) {
    final sections = <Widget>[];

    if (_detailViewModel != null) {
      sections.add(
        AnimatedBuilder(
          animation: _detailViewModel!,
          builder: (context, _) {
            final vm = _detailViewModel!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 손상부 종합
                Container(
                  key: _sectionKeys['damageSummary'],
                  child: DamageSummaryTable(
                    sectionNumber: _sectionNumberFor('damageSummary'),
                    value: vm.damageSummary,
                    onChanged: vm.updateDamageSummary,
                    heritageId: heritageId,
                    heritageName: _name.isEmpty ? '미상' : _name,
                  ),
                ),
                const SizedBox(height: 24),
                // 2. 조사자 의견 (읽기 전용)
                Container(
                  key: _sectionKeys['investigatorOpinion'],
                  child: InvestigatorOpinionField(
                    sectionNumber: _sectionNumberFor('investigatorOpinion'),
                    value: vm.investigatorOpinion,
                    onChanged: vm.updateInvestigatorOpinion,
                    heritageId: heritageId,
                    heritageName: _name.isEmpty ? '미상' : _name,
                  ),
                ),
                const SizedBox(height: 24),
                // 3. 등급 분류
                Container(
                  key: _sectionKeys['gradeClassification'],
                  child: GradeClassificationCard(
                    sectionNumber: _sectionNumberFor('gradeClassification'),
                    value: vm.gradeClassification,
                    onChanged: vm.updateGradeClassification,
                  ),
                ),
                const SizedBox(height: 24),
                // 4. AI 예측 기능
                Container(
                  key: _sectionKeys['aiPrediction'],
                  child: AIPredictionSection(
                    sectionNumber: _sectionNumberFor('aiPrediction'),
                    state: vm.aiPredictionState,
                    actions: AIPredictionActions(
                      onPredictGrade: vm.predictGrade,
                      onGenerateMap: vm.generateMap,
                      onSuggest: vm.suggestMitigation,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // _detailViewModel이 null일 때도 모든 섹션 표시
      // 1. 손상부 종합
      sections.add(
        Container(
          key: _sectionKeys['damageSummary'],
          child: DamageSummaryTable(
            sectionNumber: _sectionNumberFor('damageSummary'),
            value: DamageSummary.initial(),
            onChanged: (_) {},
            heritageId: heritageId,
            heritageName: _name.isEmpty ? '미상' : _name,
          ),
        ),
      );
      sections.add(const SizedBox(height: 24));

      // 2. 조사자 의견
      sections.add(
        Container(
          key: _sectionKeys['investigatorOpinion'],
          child: InvestigatorOpinionField(
            sectionNumber: _sectionNumberFor('investigatorOpinion'),
            value: InvestigatorOpinion.empty(),
            onChanged: (_) {},
            heritageId: heritageId,
            heritageName: _name.isEmpty ? '미상' : _name,
          ),
        ),
      );
      sections.add(const SizedBox(height: 24));

      // 3. 등급 분류
      sections.add(
        Container(
          key: _sectionKeys['gradeClassification'],
          child: GradeClassificationCard(
            sectionNumber: _sectionNumberFor('gradeClassification'),
            value: GradeClassification.initial(),
            onChanged: (_) {},
          ),
        ),
      );
      sections.add(const SizedBox(height: 24));

      // 4. AI 예측 기능
      sections.add(
        Container(
          key: _sectionKeys['aiPrediction'],
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _numberedTitle('aiPrediction', 'AI 예측 및 보고서 생성'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
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

    sections.add(const SizedBox(height: 48));
    return sections;
  }

  // 상단 네비게이션 바 (모바일/태블릿용)
  Widget _buildTopNavigationBar() {
    // 현재 탭에 맞는 섹션만 필터링
    final currentTabSections = <String>[];
    switch (_currentTabIndex) {
      case 0: // 현장 조사
        currentTabSections.addAll([
          'basicInfo',
          'metaInfo',
          'location',
          'photos',
          'damageSurvey',
        ]);
        break;
      case 1: // 조사자 의견
        currentTabSections.addAll([
          'preservationHistory',
          'inspectionResult',
          'preservationItems',
          'management',
        ]);
        break;
      case 2: // 종합진단
        currentTabSections.addAll([
          'damageSummary',
          'investigatorOpinion',
          'gradeClassification',
          'aiPrediction',
        ]);
        break;
    }

    final navItems = _sectionNavigationItems
        .where((item) => currentTabSections.contains(item.key))
        .toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 64 : 72),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        child: Row(
          children: navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = item.key == _activeSectionKey;
            return Padding(
              padding: EdgeInsets.only(right: isMobile ? 8 : 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _scrollToSection(item.key),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    highlightColor: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF2563EB) // Professional Blue 활성 색상
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                  spreadRadius: 0,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: isMobile ? 16 : 18,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF6E6E73),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Flexible(
                            child: Text(
                              '${index + 1}. ${item.shortTitle}',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF1D1D1F),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// 네비게이션 바 고정을 위한 Delegate
class _NavigationBarDelegate extends SliverPersistentHeaderDelegate {
  _NavigationBarDelegate({
    required this.child,
    required this.horizontalPadding,
  });

  final Widget child;
  final double horizontalPadding;
  static const double _navigationBarHeight = 96.0; // 높이 증가

  @override
  double get minExtent => _navigationBarHeight;

  @override
  double get maxExtent => _navigationBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_NavigationBarDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.horizontalPadding != horizontalPadding;
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
    this.sectionNumber,
    required this.name,
    required this.kind,
    required this.asdt,
    required this.owner,
    required this.admin,
    required this.lcto,
    required this.lcad,
    required this.managementNumber,
  });

  final int? sectionNumber;
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
    // 정기조사 지침 기준에 맞춰 소재지(지역)/주소(상세)를 분리
    final trimmedLcad = lcad.trim();
    final trimmedLcto = lcto.trim();
    final trimmedOwner = owner.trim();
    final trimmedAdmin = admin.trim();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final cardPadding = EdgeInsets.all(isMobile ? 20 : (isTablet ? 24 : 28));

    // 소재지: 지역만 표시 (lcto에서 첫 번째 공백 이전 부분만 추출)
    String regionLocation = '';
    if (trimmedLcto.isNotEmpty) {
      // 첫 번째 공백 이전의 부분만 추출 (예: "서울 중구..." -> "서울")
      final firstSpaceIndex = trimmedLcto.indexOf(' ');
      regionLocation = firstSpaceIndex > 0
          ? trimmedLcto.substring(0, firstSpaceIndex)
          : trimmedLcto;
    }

    // 주소: 상세 주소 표시
    final detailAddress = trimmedLcad.isNotEmpty ? trimmedLcad : trimmedLcto;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 섹션 (그라데이션 배경)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2563EB),
                  const Color(0xFF3B82F6),
                  const Color(0xFF60A5FA),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: isMobile ? 22 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionNumber != null
                            ? '${sectionNumber!}. 기본 정보'
                            : '기본 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 20 : 22,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '문화유산의 기본 정보를 확인합니다',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: -0.2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 콘텐츠 섹션
          Padding(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 유산명 (강조 표시)
                _buildHighlightedRow(
                  icon: Icons.landscape_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: '유산명',
                  value: name.isEmpty ? '미상' : name,
                  isHighlighted: true,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 16 : 18),

                // 지정연월
                _buildOverviewRow(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: '지정연월',
                  value: _formatDate(asdt),
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 14 : 16),

                // 종목
                _buildOverviewRow(
                  icon: Icons.category_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: '종목',
                  value: kind.isEmpty ? '-' : kind,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 14 : 16),

                // 소재지 (지역)
                _buildOverviewRow(
                  icon: Icons.location_city_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: '소재지',
                  value: regionLocation.isEmpty ? '-' : regionLocation,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 14 : 16),

                // 주소 (상세)
                _buildOverviewRow(
                  icon: Icons.place_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: '주소',
                  value: detailAddress.isEmpty ? '-' : detailAddress,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 14 : 16),

                // 관리번호
                _buildOverviewRow(
                  icon: Icons.numbers_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  label: '관리번호',
                  value: managementNumber.isEmpty ? '-' : managementNumber,
                  isMobile: isMobile,
                ),

                // 소유자와 관리자 정보 추가
                if (trimmedOwner.isNotEmpty || trimmedAdmin.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 18 : 20),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.grey.shade300,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 18 : 20),
                ],

                // 소유자
                if (trimmedOwner.isNotEmpty) ...[
                  _buildOverviewRow(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF6366F1),
                    label: '소유자',
                    value: trimmedOwner,
                    isMobile: isMobile,
                  ),
                  if (trimmedAdmin.isNotEmpty)
                    SizedBox(height: isMobile ? 14 : 16),
                ],

                // 관리자
                if (trimmedAdmin.isNotEmpty)
                  _buildOverviewRow(
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: const Color(0xFF14B8A6),
                    label: '관리자',
                    value: trimmedAdmin,
                    isMobile: isMobile,
                  ),
              ],
            ),
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

  Widget _buildOverviewRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 16 : 18,
        horizontal: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: isMobile ? 18 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                    color: const Color(0xFF6B7280),
                    letterSpacing: -0.1,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isHighlighted,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            iconColor.withValues(alpha: 0.08),
            iconColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isMobile ? 20 : 22,
            ),
          ),
          SizedBox(width: isMobile ? 14 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                    color: iconColor,
                    letterSpacing: -0.1,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.3,
                    height: 1.3,
                  ),
                ),
              ],
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
    this.title = '현황 사진',
    this.description = '위성사진, 배치도 등 위치 관련 자료를 등록하세요.',
    this.icon = Icons.photo_camera,
    this.sectionNumber,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> photosStream;
  final VoidCallback onAddPhoto;
  final void Function(String url, String title) onPreview;
  final Future<void> Function(String docId, String url) onDelete;
  final String Function(num? bytes) formatBytes;
  final String title;
  final String description;
  final IconData icon;
  final int? sectionNumber;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;
    final sectionPadding = EdgeInsets.all(isCompact ? 16 : 24);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x1A000000), // Apple-style subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: icon,
            title: title,
            description: description,
            sectionNumber: sectionNumber,
          ),
          const SizedBox(height: 16),
          OptimizedStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: photosStream,
            loadingBuilder: (context) =>
                const SkeletonList(itemCount: 3, itemHeight: 120),
            builder: (context, querySnapshot) {
              if (querySnapshot.docs.isEmpty) {
                return _EmptyPhotoState(onAddPhoto: onAddPhoto);
              }

              final docs = querySnapshot.docs
                  .where(
                    (doc) =>
                        ((doc.data())['url'] as String?)?.isNotEmpty ?? false,
                  )
                  .toList();

              if (docs.isEmpty) {
                return _EmptyPhotoState(onAddPhoto: onAddPhoto);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isNarrow = width < 640;
                  final isVeryNarrow = width < 420;
                  final buttonAlignment = isNarrow
                      ? WrapAlignment.start
                      : WrapAlignment.end;

                  Widget buildHorizontalList() {
                    final listHeight = isVeryNarrow ? 260.0 : 220.0;
                    return SizedBox(
                      height: listHeight,
                      child: Scrollbar(
                        thumbVisibility: true,
                        thickness: 10,
                        radius: const Radius.circular(5),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, index) {
                            final data = docs[index].data();
                            final title = (data['title'] as String?) ?? '';
                            final url = (data['url'] as String?) ?? '';
                            final meta =
                                '${data['width'] ?? '?'}x${data['height'] ?? '?'} • ${formatBytes(data['bytes'] as num?)}';
                            final cardWidth = isVeryNarrow ? 180.0 : 200.0;
                            final thumbnailSize = (cardWidth * 2)
                                .round(); // 2x 해상도로 요청
                            return SizedBox(
                              width: cardWidth,
                              child: _PhotoCard(
                                title: title,
                                url: _proxyImageUrl(
                                  url,
                                  maxWidth: thumbnailSize,
                                  maxHeight: thumbnailSize,
                                ),
                                meta: meta,
                                onPreview: () => onPreview(url, title),
                                onDelete: () => onDelete(docs[index].id, url),
                                thumbnailSize: thumbnailSize,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  Widget buildGrid() {
                    final crossAxisCount = width < 900 ? 3 : 4;
                    final spacing = width < 900 ? 10.0 : 12.0;
                    // GridView 카드 크기 계산 (childAspectRatio 0.75 = width/height)
                    final cardWidth =
                        (width - (spacing * (crossAxisCount + 1))) /
                        crossAxisCount;
                    final cardHeight = cardWidth / 0.75;
                    final thumbnailSize = (cardHeight * 2)
                        .round(); // 높이 기준 2x 해상도
                    return GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
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
                          url: _proxyImageUrl(
                            url,
                            maxWidth: thumbnailSize,
                            maxHeight: thumbnailSize,
                          ),
                          meta: meta,
                          onPreview: () => onPreview(url, title),
                          onDelete: () => onDelete(docs[index].id, url),
                          thumbnailSize: thumbnailSize,
                        );
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: buttonAlignment,
                        runAlignment: buttonAlignment,
                        spacing: 12,
                        runSpacing: 8,
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
                              backgroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      isNarrow ? buildHorizontalList() : buildGrid(),
                    ],
                  );
                },
              );
            },
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
    int? thumbnailSize,
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
                  OptimizedImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    maxWidth: thumbnailSize,
                    maxHeight: thumbnailSize,
                    placeholder: Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: Container(
                      color: const Color(0xFFF8FAFC),
                      child: const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
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
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '사진' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: onPreview,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1E2A44)),
                        foregroundColor: const Color(0xFF1E2A44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.description,
    this.sectionNumber,
  });

  final IconData icon;
  final String title;
  final String? description;
  final int? sectionNumber;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
            ),
            Text(
              sectionNumber != null ? '$sectionNumber. $title' : title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: isCompact ? 13 : 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState({required this.onAddPhoto});

  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('등록된 사진이 없습니다.', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onAddPhoto,
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Color(0xFF1E2A44),
              ),
              label: Text(
                '사진 등록',
                style: TextStyle(
                  color: const Color(0xFF1E2A44),
                  fontSize: isCompact ? 13 : 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 18 : 22,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DamageSurveySection extends StatefulWidget {
  const DamageSurveySection({
    super.key,
    this.sectionNumber,
    required this.damageStream,
    required this.onAddSurvey,
    required this.onDeepInspection,
    required this.onDelete,
  });

  final int? sectionNumber;

  final Stream<QuerySnapshot<Map<String, dynamic>>> damageStream;
  final VoidCallback onAddSurvey;
  final Future<void> Function(Map<String, dynamic> selectedDamage)
  onDeepInspection;
  final Future<void> Function(String docId, String imageUrl) onDelete;

  @override
  State<DamageSurveySection> createState() => _DamageSurveySectionState();
}

class _DamageSurveySectionState extends State<DamageSurveySection> {
  Map<String, dynamic>? _selectedDamage;
  String? _selectedDocId;
  static const List<String> _gradeFilterOptions = [
    '전체',
    'A',
    'B',
    'C1',
    'C2',
    'D',
    'E',
    'F',
    '미분류',
  ];
  late final ScrollController _damageTableHorizontalController;
  late final ScrollController _damagePreviewScrollController;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  String? _selectedGradeFilter;

  @override
  void initState() {
    super.initState();
    _damageTableHorizontalController = ScrollController();
    _damagePreviewScrollController = ScrollController();
    _searchController.addListener(_onSearchKeywordChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchKeywordChanged);
    _searchController.dispose();
    _damageTableHorizontalController.dispose();
    _damagePreviewScrollController.dispose();
    super.dispose();
  }

  void _onSearchKeywordChanged() {
    setState(() {
      _searchKeyword = _searchController.text.trim();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedDamage = null;
      _selectedDocId = null;
    });
  }

  // 등급 표시 로직: AI가 손상을 감지하지 못했을 경우 ' - ' 표시
  String _getDisplayGrade(Map<String, dynamic> data) {
    final grade = data['severityGrade']?.toString();
    if (grade != null && grade.isNotEmpty && grade != 'null') {
      return grade;
    }

    // detections 확인: 비어있거나 null이면 ' - ' 표시
    final detections = data['detections'] as List?;
    if (detections == null || detections.isEmpty) {
      return ' - ';
    }

    // 등급이 없지만 감지는 된 경우도 ' - ' 표시
    return ' - ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x1A000000), // Apple-style subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.build_outlined,
                  color: const Color(0xFF2563EB),
                  size: MediaQuery.of(context).size.width < 600 ? 20 : 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sectionNumber != null
                          ? '${widget.sectionNumber}. 손상부 조사'
                          : '손상부 조사',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 18
                            : 20,
                        color: const Color(0xFF1D1D1F),
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '손상부를 조사하고 기록합니다',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 12
                            : 13,
                        color: Colors.grey.shade600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isNarrow = constraints.maxWidth < 400;
              
              // 좁은 화면에서는 세로 배치
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: widget.onAddSurvey,
                      icon: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        '조사 등록',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedDamage != null
                          ? _openDeepInspection
                          : null,
                      icon: Icon(
                        Icons.assignment_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        _selectedDamage != null
                            ? '심화조사'
                            : '심화조사 (선택 필요)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDamage != null
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF9CA3AF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ],
                );
              }
              
              // 넓은 화면에서는 가로 배치 (Wrap 사용)
              return Wrap(
                spacing: isMobile ? 8 : 12,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.onAddSurvey,
                    icon: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: isMobile ? 16 : 18,
                    ),
                    label: Text(
                      '조사 등록',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: isMobile ? 10 : 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectedDamage != null
                        ? _openDeepInspection
                        : null,
                    icon: Icon(
                      Icons.assignment_outlined,
                      size: isMobile ? 16 : 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      _selectedDamage != null
                          ? '심화조사'
                          : (isMobile ? '심화조사\n(선택 필요)' : '심화조사 (선택 필요)'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isMobile ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedDamage != null
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: isMobile ? 10 : 12,
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // 통계 정보
          _buildStatistics(),
          const SizedBox(height: 16),
          // Interactive Damage Table
          _buildDamageTable(),
          if (_selectedDamage != null) ...[
            const SizedBox(height: 16),
            _buildSelectedDamageDetail(),
          ],
          const SizedBox(height: 16),
          // Responsive height for damage list
          LayoutBuilder(
            builder: (context, constraints) {
              // 화면 크기에 따라 높이 조정
              final height = MediaQuery.of(context).size.height > 600
                  ? 320.0
                  : MediaQuery.of(context).size.height > 400
                  ? 240.0
                  : 200.0;
              return SizedBox(
                height: height,
                child:
                    OptimizedStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.damageStream,
                      loadingBuilder: (context) =>
                          const SkeletonList(itemCount: 3, itemHeight: 120),
                      builder: (context, querySnapshot) {
                        if (querySnapshot.docs.isEmpty) {
                          return _buildEmptyState(
                            icon: Icons.photo_camera_outlined,
                            title: '등록된 손상부 조사가 없습니다',
                            subtitle: '조사 등록 버튼을 눌러 첫 조사를 시작하세요',
                          );
                        }
                        final docs = querySnapshot.docs.where((doc) {
                          final data = doc.data();
                          final url =
                              (data['url'] as String?) ??
                              (data['imageUrl'] as String?);
                          return url != null && url.isNotEmpty;
                        }).toList();
                        if (docs.isEmpty) {
                          return _buildEmptyState(
                            icon: Icons.image_not_supported,
                            title: '이미지가 포함된 조사가 없습니다',
                            subtitle: '사진을 포함하여 조사를 등록해주세요',
                          );
                        }
                        return Scrollbar(
                          controller: _damagePreviewScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 10,
                          radius: const Radius.circular(5),
                          child: ScrollConfiguration(
                            behavior: const MaterialScrollBehavior().copyWith(
                              dragDevices: {
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.touch,
                                PointerDeviceKind.stylus,
                                PointerDeviceKind.trackpad,
                              },
                            ),
                            child: ListView.separated(
                              controller: _damagePreviewScrollController,
                              primary: false,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                // 'url' 또는 'imageUrl' 필드 확인 (최신 저장 로직은 'url' 사용)
                                final url =
                                    (data['url'] as String?) ??
                                    (data['imageUrl'] as String?) ??
                                    '';
                                final detections =
                                    (data['detections'] as List? ?? [])
                                        .map((item) {
                                          if (item is Map) {
                                            return Map<String, dynamic>.from(
                                              item.map(
                                                (key, value) => MapEntry(
                                                  key.toString(),
                                                  value,
                                                ),
                                              ),
                                            );
                                          }
                                          return null;
                                        })
                                        .whereType<Map<String, dynamic>>()
                                        .toList(growable: false);
                                final grade = data['severityGrade'] as String?;
                                final location = data['location'] as String?;
                                final phenomenon =
                                    data['phenomenon'] as String?;
                                final imageWidth =
                                    (data['width'] as num?)?.toDouble() ??
                                    (data['imageWidth'] as num?)?.toDouble();
                                final imageHeight =
                                    (data['height'] as num?)?.toDouble() ??
                                    (data['imageHeight'] as num?)?.toDouble();
                                final previewUrl = _proxyImageUrl(
                                  url,
                                  maxWidth: 1280,
                                  maxHeight: 960,
                                );
                                final timestamp =
                                    data['timestamp']?.toString() ??
                                    data['createdAt']?.toString() ??
                                    data['date']?.toString();
                                return DamageCardPreview(
                                  imageUrl: previewUrl,
                                  detections: detections,
                                  severityGrade: grade,
                                  location: location,
                                  phenomenon: phenomenon,
                                  timestamp: timestamp,
                                  imageWidth: imageWidth,
                                  imageHeight: imageHeight,
                                  onDelete: () => widget.onDelete(doc.id, url),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
              );
            },
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
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: '등록된 손상부 조사가 없습니다',
            subtitle: '조사 등록 버튼을 눌러 첫 조사를 시작하세요',
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final url = (data['url'] as String?) ?? (data['imageUrl'] as String?);
          return url != null && url.isNotEmpty;
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.image_not_supported,
            title: '이미지가 포함된 조사가 없습니다',
            subtitle: '사진을 포함하여 조사를 등록해주세요',
          );
        }

        final filteredDocs = _applyDamageFilters(docs);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDamageTableHeader(docs.length),
              _buildDamageTableFilters(docs.length, filteredDocs.length),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              if (filteredDocs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildEmptyState(
                    icon: Icons.filter_alt_off,
                    title: '조건에 맞는 손상부 조사가 없습니다',
                    subtitle: '검색어나 등급 필터를 조정해주세요',
                  ),
                )
              else
                _buildDamageDataTable(filteredDocs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDamageTableHeader(int totalCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.swipe,
                size: 16,
                color: const Color(0xFF2563EB).withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              const Text(
                '손상부 조사 목록 (좌우 스크롤 가능)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A44),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '총 ${totalCount}건',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageTableFilters(int totalCount, int filteredCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              hintText: '위치, 손상 유형, 조사 의견 검색',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _buildGradeFilterChips()),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '표시 중: $filteredCount / $totalCount건',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGradeFilterChips() {
    return _gradeFilterOptions.map((grade) {
      final isAll = grade == '전체';
      final isSelected = isAll
          ? _selectedGradeFilter == null
          : _selectedGradeFilter == grade;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(grade),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (isAll) {
                _selectedGradeFilter = null;
              } else {
                _selectedGradeFilter = selected ? grade : null;
              }
            });
          },
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF1E2A44)
                : const Color(0xFF4B5563),
          ),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB),
          ),
          selectedColor: const Color(0xFF2563EB).withOpacity(0.12),
          backgroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  Widget _buildDamageDataTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _damageTableHorizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _damageTableHorizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 56,
                columnSpacing: 16,
                columns: const [
                  DataColumn(
                    label: Text(
                      '선택',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '사진',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '위치',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '손상 유형',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '등급',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '조사일시',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '조사자 의견',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: docs.asMap().entries.map((entry) {
                  final doc = entry.value;
                  final data = doc.data();
                  final isSelected = doc.id == _selectedDocId;

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      if (selected == true) {
                        setState(() {
                          _selectedDocId = doc.id;
                          _selectedDamage = {...data, 'docId': doc.id};
                        });
                      }
                    },
                    cells: [
                      DataCell(
                        Radio<String>(
                          value: doc.id,
                          groupValue: _selectedDocId,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedDocId = value;
                              _selectedDamage = {...data, 'docId': doc.id};
                            });
                          },
                        ),
                      ),
                      DataCell(_buildPhotoThumbnail(data)),
                      DataCell(Text(data['location']?.toString() ?? '—')),
                      DataCell(Text(data['phenomenon']?.toString() ?? '—')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getGradeColor(
                              data['severityGrade']?.toString(),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getDisplayGrade(data),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          data['timestamp'] != null
                              ? _formatTimestamp(data['timestamp'].toString())
                              : '—',
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['inspectorOpinion']?.toString() ?? '—',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if ((data['detections'] as List?)?.isNotEmpty ==
                                true)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4B6CB7,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(data['detections'] as List).length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4B6CB7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyDamageFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_selectedGradeFilter == null && _searchKeyword.isEmpty) {
      return docs;
    }
    final keyword = _searchKeyword.toLowerCase();
    return docs.where((doc) {
      final data = doc.data();
      final rawGrade = (data['severityGrade']?.toString() ?? '').trim();
      final normalizedGrade =
          rawGrade.isEmpty || rawGrade.toLowerCase() == 'null' ? '' : rawGrade;
      final matchesGrade = _selectedGradeFilter == null
          ? true
          : _selectedGradeFilter == '미분류'
          ? normalizedGrade.isEmpty
          : normalizedGrade == _selectedGradeFilter;
      if (_searchKeyword.isEmpty) {
        return matchesGrade;
      }
      final matchesKeyword =
          [
                data['location'],
                data['phenomenon'],
                data['inspectorOpinion'],
                data['recommendation'],
              ]
              .map((value) => value?.toString().toLowerCase() ?? '')
              .any((value) => value.contains(keyword));
      return matchesGrade && matchesKeyword;
    }).toList();
  }

  Color _getGradeColor(String? grade) {
    // ' - ' 또는 null인 경우 회색 반환
    if (grade == null || grade.isEmpty || grade == 'null' || grade.trim() == '-') {
      return const Color(0xFF9CA3AF);
    }
    
    switch (grade.trim()) {
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C1':
        return const Color(0xFFFFC107);
      case 'C2':
        return const Color(0xFFFF9800);
      case 'D':
        return const Color(0xFFFF5722);
      case 'E':
        return const Color(0xFFF44336);
      case 'F':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildSelectedDamageDetail() {
    final selected = _selectedDamage;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final timestamp = selected['timestamp']?.toString();
    final formattedTimestamp = (timestamp == null || timestamp.trim().isEmpty)
        ? '—'
        : _formatTimestamp(timestamp);
    final inspector = selected['inspector']?.toString();
    final inspectorName = (inspector != null && inspector.trim().isNotEmpty)
        ? inspector
        : selected['inspectorName']?.toString();
    final List<Map<String, dynamic>> detectionList =
        (selected['detections'] as List?)
            ?.map(
              (e) => e is Map<String, dynamic>
                  ? e
                  : e is Map
                  ? Map<String, dynamic>.from(e as Map)
                  : null,
            )
            .whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];
    final gradeLabel = _getDisplayGrade(selected);
    final hasGrade = gradeLabel.trim().isNotEmpty && gradeLabel.trim() != '-';
    final gradeColor = _getGradeColor(selected['severityGrade']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '선택된 손상 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              if (hasGrade)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '등급 $gradeLabel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: gradeColor,
                    ),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('선택 해제'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openDeepInspection,
                icon: const Icon(Icons.assignment_outlined, size: 16),
                label: const Text('심화조사 열기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDetailBadge(
                icon: Icons.place_outlined,
                label: '조사 위치',
                value: selected['location']?.toString() ?? '—',
              ),
              _buildDetailBadge(
                icon: Icons.bubble_chart_outlined,
                label: '손상 유형',
                value: selected['phenomenon']?.toString() ?? '—',
              ),
              _buildDetailBadge(
                icon: Icons.schedule_outlined,
                label: '조사일시',
                value: formattedTimestamp,
              ),
              _buildDetailBadge(
                icon: Icons.person_outline,
                label: '조사자',
                value: (inspectorName?.isNotEmpty ?? false)
                    ? inspectorName!
                    : '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '감지된 손상',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (detectionList.isEmpty)
            Text('감지된 손상이 없습니다.', style: TextStyle(color: Colors.grey.shade500))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detectionList.map((det) {
                final label = det['label']?.toString() ?? '손상';
                final score = det['score'];
                final double? scorePercent = score is num
                    ? (score * 100).clamp(0, 100).toDouble()
                    : null;
                final confidence = scorePercent != null
                    ? '(${scorePercent.toStringAsFixed(1)}%)'
                    : '';
                return Chip(
                  avatar: const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  label: Text('$label $confidence'),
                  backgroundColor: const Color(0xFFFFF7E6),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text(
            '조사자 의견',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              (selected['inspectorOpinion']?.toString() ?? '').trim().isEmpty
                  ? '조사자 의견이 입력되지 않았습니다.'
                  : selected['inspectorOpinion'].toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    value.isEmpty ? '—' : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.damageStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final totalCount = docs.length;

        // 등급별 통계
        final gradeCounts = <String, int>{};
        int totalDetections = 0;

        for (final doc in docs) {
          final data = doc.data();
          final grade = data['severityGrade']?.toString() ?? '미분류';
          gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;

          final detections = data['detections'] as List?;
          if (detections != null) {
            totalDetections += detections.length;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              
              if (isNarrow) {
                // 좁은 화면: 세로 배치
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatItem(
                          icon: Icons.assignment,
                          label: '총 조사',
                          value: '$totalCount건',
                          color: const Color(0xFF1E2A44),
                        ),
                        const SizedBox(width: 16),
                        _StatItem(
                          icon: Icons.auto_graph,
                          label: '감지된 손상',
                          value: '$totalDetections건',
                          color: const Color(0xFF4B6CB7),
                        ),
                      ],
                    ),
                    if (gradeCounts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: gradeCounts.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(entry.key).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getGradeColor(entry.key).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getGradeColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.key}: ${entry.value}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getGradeColor(entry.key),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              }
              
              // 넓은 화면: 가로 배치
              return Row(
                children: [
                  _StatItem(
                    icon: Icons.assignment,
                    label: '총 조사',
                    value: '$totalCount건',
                    color: const Color(0xFF1E2A44),
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    icon: Icons.auto_graph,
                    label: '감지된 손상',
                    value: '$totalDetections건',
                    color: const Color(0xFF4B6CB7),
                  ),
                  const SizedBox(width: 16),
                  if (gradeCounts.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: gradeCounts.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(entry.key).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getGradeColor(entry.key).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getGradeColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.key}: ${entry.value}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getGradeColor(entry.key),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPhotoThumbnail(Map<String, dynamic> data) {
    final url = (data['url'] as String?) ?? (data['imageUrl'] as String?);
    if (url == null || url.isEmpty) {
      return Container(
        width: 60,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 24,
          color: Colors.grey,
        ),
      );
    }

    final proxiedUrl = _proxyImageUrl(url, maxWidth: 200, maxHeight: 150);
    return Container(
      width: 60,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: OptimizedImage(
          imageUrl: proxiedUrl,
          fit: BoxFit.cover,
          width: 60,
          height: 45,
          errorWidget: Container(
            width: 60,
            height: 45,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Future<void> _openDeepInspection() async {
    if (_selectedDamage == null) return;
    await widget.onDeepInspection(_selectedDamage!);
  }
}

/// 통계 아이템 위젯
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
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
    _SurveyRowConfig(
      key: 'coloring',
      label: '채색 (단청, 벽화)',
      hint: '채색 관련 조사 결과를 입력하세요',
    ),
    _SurveyRowConfig(key: 'pest', label: '충해', hint: '충해 관련 조사 결과를 입력하세요'),
    _SurveyRowConfig(key: 'etc', label: '기타', hint: '기타 조사 결과를 입력하세요'),
    // 추가 필드들
    _SurveyRowConfig(key: 'safetyNotes', label: '특기사항', hint: '특기사항을 입력하세요'),
    _SurveyRowConfig(
      key: 'investigatorOpinion',
      label: '조사 종합의견',
      hint: '조사 종합의견을 입력하세요',
    ),
    _SurveyRowConfig(key: 'grade', label: '등급분류', hint: '등급분류를 입력하세요'),
    _SurveyRowConfig(
      key: 'investigationDate',
      label: '조사일시',
      hint: '조사일시를 입력하세요',
    ),
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
  final _ai = AiDetectionService(baseUrl: Env.aiBase);

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
  final _preservationFoundationCornerstonePhotoController =
      TextEditingController();
  final _preservationShaftVerticalMembersController = TextEditingController();
  final _preservationShaftVerticalMembersPhotoController =
      TextEditingController();
  final _preservationShaftLintelTiebeamController = TextEditingController();
  final _preservationShaftLintelTiebeamPhotoController =
      TextEditingController();
  final _preservationShaftBracketSystemController = TextEditingController();
  final _preservationShaftBracketSystemPhotoController =
      TextEditingController();
  final _preservationShaftWallGomagiController = TextEditingController();
  final _preservationShaftWallGomagiPhotoController = TextEditingController();
  final _preservationShaftOndolFloorController = TextEditingController();
  final _preservationShaftOndolFloorPhotoController = TextEditingController();
  final _preservationShaftWindowsRailingsController = TextEditingController();
  final _preservationShaftWindowsRailingsPhotoController =
      TextEditingController();
  final _preservationRoofFramingMembersController = TextEditingController();
  final _preservationRoofFramingMembersPhotoController =
      TextEditingController();
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
          Map<String, dynamic>? aiSummary;
          final summaryRaw = mapItem['aiSummary'];
          if (summaryRaw is Map) {
            aiSummary = Map<String, dynamic>.from(
              summaryRaw.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
          result.add(
            _HistoryImage(
              id: id,
              url: url,
              bytes: bytes,
              storagePath: storagePath,
              uploadedAt: uploadedAt,
              rawValue: mapItem,
              aiSummary: aiSummary,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진 선택 중 오류가 발생했습니다: $e')));
    }
  }

  // Firebase에 사진 업로드
  Future<void> _uploadPhotoToFirebase(
    String photoKey,
    Uint8List imageBytes,
  ) async {
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진이 성공적으로 업로드되었습니다.')));
    } catch (e) {
      print('사진 업로드 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진 업로드 중 오류가 발생했습니다: $e')));
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
    final String? remoteUrl = _preservationPhotoUrls[photoKey];
    final Uint8List? imageBytes = _preservationPhotos[photoKey];

    if (remoteUrl == null && imageBytes == null) return;

    final String? optimizedUrl = remoteUrl != null
        ? _proxyImageUrl(remoteUrl, maxWidth: 1600, maxHeight: 1200)
        : null;

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
                      : optimizedUrl != null
                          ? OptimizedImage(
                              imageUrl: optimizedUrl,
                              fit: BoxFit.contain,
                              maxWidth: 1600,
                              maxHeight: 1200,
                            )
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
    if (controller == _preservationFoundationBasePhotoController)
      return 'foundationBase';
    if (controller == _preservationFoundationCornerstonePhotoController)
      return 'foundationCornerstone';
    if (controller == _preservationShaftVerticalMembersPhotoController)
      return 'shaftVerticalMembers';
    if (controller == _preservationShaftLintelTiebeamPhotoController)
      return 'shaftLintelTiebeam';
    if (controller == _preservationShaftBracketSystemPhotoController)
      return 'shaftBracketSystem';
    if (controller == _preservationShaftWallGomagiPhotoController)
      return 'shaftWallGomagi';
    if (controller == _preservationShaftOndolFloorPhotoController)
      return 'shaftOndolFloor';
    if (controller == _preservationShaftWindowsRailingsPhotoController)
      return 'shaftWindowsRailings';
    if (controller == _preservationRoofFramingMembersPhotoController)
      return 'roofFramingMembers';
    if (controller == _preservationRoofRaftersPuyeonPhotoController)
      return 'roofRaftersPuyeon';
    if (controller == _preservationRoofRoofTilesPhotoController)
      return 'roofRoofTiles';
    if (controller == _preservationRoofCeilingDanjipPhotoController)
      return 'roofCeilingDanjip';
    if (controller == _preservationOtherSpecialNotesPhotoController)
      return 'otherSpecialNotes';
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
    _preservationFoundationCornerstonePhotoController.addListener(
      _onFieldChanged,
    );
    _preservationShaftVerticalMembersController.addListener(_onFieldChanged);
    _preservationShaftVerticalMembersPhotoController.addListener(
      _onFieldChanged,
    );
    _preservationShaftLintelTiebeamController.addListener(_onFieldChanged);
    _preservationShaftLintelTiebeamPhotoController.addListener(_onFieldChanged);
    _preservationShaftBracketSystemController.addListener(_onFieldChanged);
    _preservationShaftBracketSystemPhotoController.addListener(_onFieldChanged);
    _preservationShaftWallGomagiController.addListener(_onFieldChanged);
    _preservationShaftWallGomagiPhotoController.addListener(_onFieldChanged);
    _preservationShaftOndolFloorController.addListener(_onFieldChanged);
    _preservationShaftOndolFloorPhotoController.addListener(_onFieldChanged);
    _preservationShaftWindowsRailingsController.addListener(_onFieldChanged);
    _preservationShaftWindowsRailingsPhotoController.addListener(
      _onFieldChanged,
    );
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
    _preservationFoundationCornerstonePhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationShaftVerticalMembersController.removeListener(_onFieldChanged);
    _preservationShaftVerticalMembersPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationShaftLintelTiebeamController.removeListener(_onFieldChanged);
    _preservationShaftLintelTiebeamPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationShaftBracketSystemController.removeListener(_onFieldChanged);
    _preservationShaftBracketSystemPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationShaftWallGomagiController.removeListener(_onFieldChanged);
    _preservationShaftWallGomagiPhotoController.removeListener(_onFieldChanged);
    _preservationShaftOndolFloorController.removeListener(_onFieldChanged);
    _preservationShaftOndolFloorPhotoController.removeListener(_onFieldChanged);
    _preservationShaftWindowsRailingsController.removeListener(_onFieldChanged);
    _preservationShaftWindowsRailingsPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationRoofFramingMembersController.removeListener(_onFieldChanged);
    _preservationRoofFramingMembersPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationRoofRaftersPuyeonController.removeListener(_onFieldChanged);
    _preservationRoofRaftersPuyeonPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationRoofRoofTilesController.removeListener(_onFieldChanged);
    _preservationRoofRoofTilesPhotoController.removeListener(_onFieldChanged);
    _preservationRoofCeilingDanjipController.removeListener(_onFieldChanged);
    _preservationRoofCeilingDanjipPhotoController.removeListener(
      _onFieldChanged,
    );
    _preservationOtherSpecialNotesController.removeListener(_onFieldChanged);
    _preservationOtherSpecialNotesPhotoController.removeListener(
      _onFieldChanged,
    );
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
          _surveyControllers[row.key]?.text =
              surveyData[row.key]?.toString() ?? '';
        }

        // 보존 사항 데이터 로드
        final preservationData =
            data['preservationItems'] as Map<String, dynamic>? ?? {};
        _preservationFoundationBaseController.text =
            preservationData['foundationBase']?.toString() ?? '';
        _preservationFoundationBasePhotoController.text =
            preservationData['foundationBasePhoto']?.toString() ?? '';
        _preservationFoundationCornerstonePhotoController.text =
            preservationData['foundationCornerstonePhoto']?.toString() ?? '';
        _preservationShaftVerticalMembersController.text =
            preservationData['shaftVerticalMembers']?.toString() ?? '';
        _preservationShaftVerticalMembersPhotoController.text =
            preservationData['shaftVerticalMembersPhoto']?.toString() ?? '';
        _preservationShaftLintelTiebeamController.text =
            preservationData['shaftLintelTiebeam']?.toString() ?? '';
        _preservationShaftLintelTiebeamPhotoController.text =
            preservationData['shaftLintelTiebeamPhoto']?.toString() ?? '';
        _preservationShaftBracketSystemController.text =
            preservationData['shaftBracketSystem']?.toString() ?? '';
        _preservationShaftBracketSystemPhotoController.text =
            preservationData['shaftBracketSystemPhoto']?.toString() ?? '';
        _preservationShaftWallGomagiController.text =
            preservationData['shaftWallGomagi']?.toString() ?? '';
        _preservationShaftWallGomagiPhotoController.text =
            preservationData['shaftWallGomagiPhoto']?.toString() ?? '';
        _preservationShaftOndolFloorController.text =
            preservationData['shaftOndolFloor']?.toString() ?? '';
        _preservationShaftOndolFloorPhotoController.text =
            preservationData['shaftOndolFloorPhoto']?.toString() ?? '';
        _preservationShaftWindowsRailingsController.text =
            preservationData['shaftWindowsRailings']?.toString() ?? '';
        _preservationShaftWindowsRailingsPhotoController.text =
            preservationData['shaftWindowsRailingsPhoto']?.toString() ?? '';
        _preservationRoofFramingMembersController.text =
            preservationData['roofFramingMembers']?.toString() ?? '';
        _preservationRoofFramingMembersPhotoController.text =
            preservationData['roofFramingMembersPhoto']?.toString() ?? '';
        _preservationRoofRaftersPuyeonController.text =
            preservationData['roofRaftersPuyeon']?.toString() ?? '';
        _preservationRoofRaftersPuyeonPhotoController.text =
            preservationData['roofRaftersPuyeonPhoto']?.toString() ?? '';
        _preservationRoofRoofTilesController.text =
            preservationData['roofRoofTiles']?.toString() ?? '';
        _preservationRoofRoofTilesPhotoController.text =
            preservationData['roofRoofTilesPhoto']?.toString() ?? '';
        _preservationRoofCeilingDanjipController.text =
            preservationData['roofCeilingDanjip']?.toString() ?? '';
        _preservationRoofCeilingDanjipPhotoController.text =
            preservationData['roofCeilingDanjipPhoto']?.toString() ?? '';
        _preservationOtherSpecialNotesController.text =
            preservationData['otherSpecialNotes']?.toString() ?? '';
        _preservationOtherSpecialNotesPhotoController.text =
            preservationData['otherSpecialNotesPhoto']?.toString() ?? '';

        // 관리사항 데이터 로드
        final managementData =
            data['managementItems'] as Map<String, dynamic>? ?? {};
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
        _hasNationalHeritageInterpreter =
            managementData['hasNationalHeritageInterpreter'] == true;

        // 유지보수/수리 이력 데이터 로드
        final maintenanceData =
            data['maintenanceHistory'] as Map<String, dynamic>? ?? {};
        _precisionDiagnosis = maintenanceData['precision_diagnosis'] == true;
        _careProject = maintenanceData['care_project'] == true;
        _repairRecordController.text =
            maintenanceData['repair_record']?.toString() ?? '';

        // 원본 데이터 저장 (변경 감지용)
        _originalData = Map.from(data);

        setState(() {
          _hasUnsavedChanges = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$_selectedYear 데이터를 불러왔습니다.')));
      } else {
        // 데이터가 없는 경우 필드 초기화
        _clearAllFields();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedYear 데이터가 없습니다. 새로 입력하세요.')),
        );
      }
    } catch (e) {
      print('연도별 데이터 불러오기 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('데이터 불러오기 중 오류가 발생했습니다: $e')));
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
      'foundationBasePhoto': _preservationFoundationBasePhotoController.text
          .trim(),
      'foundationCornerstonePhoto':
          _preservationFoundationCornerstonePhotoController.text.trim(),
      'shaftVerticalMembers': _preservationShaftVerticalMembersController.text
          .trim(),
      'shaftVerticalMembersPhoto':
          _preservationShaftVerticalMembersPhotoController.text.trim(),
      'shaftLintelTiebeam': _preservationShaftLintelTiebeamController.text
          .trim(),
      'shaftLintelTiebeamPhoto': _preservationShaftLintelTiebeamPhotoController
          .text
          .trim(),
      'shaftBracketSystem': _preservationShaftBracketSystemController.text
          .trim(),
      'shaftBracketSystemPhoto': _preservationShaftBracketSystemPhotoController
          .text
          .trim(),
      'shaftWallGomagi': _preservationShaftWallGomagiController.text.trim(),
      'shaftWallGomagiPhoto': _preservationShaftWallGomagiPhotoController.text
          .trim(),
      'shaftOndolFloor': _preservationShaftOndolFloorController.text.trim(),
      'shaftOndolFloorPhoto': _preservationShaftOndolFloorPhotoController.text
          .trim(),
      'shaftWindowsRailings': _preservationShaftWindowsRailingsController.text
          .trim(),
      'shaftWindowsRailingsPhoto':
          _preservationShaftWindowsRailingsPhotoController.text.trim(),
      'roofFramingMembers': _preservationRoofFramingMembersController.text
          .trim(),
      'roofFramingMembersPhoto': _preservationRoofFramingMembersPhotoController
          .text
          .trim(),
      'roofRaftersPuyeon': _preservationRoofRaftersPuyeonController.text.trim(),
      'roofRaftersPuyeonPhoto': _preservationRoofRaftersPuyeonPhotoController
          .text
          .trim(),
      'roofRoofTiles': _preservationRoofRoofTilesController.text.trim(),
      'roofRoofTilesPhoto': _preservationRoofRoofTilesPhotoController.text
          .trim(),
      'roofCeilingDanjip': _preservationRoofCeilingDanjipController.text.trim(),
      'roofCeilingDanjipPhoto': _preservationRoofCeilingDanjipPhotoController
          .text
          .trim(),
      'otherSpecialNotes': _preservationOtherSpecialNotesController.text.trim(),
      'otherSpecialNotesPhoto': _preservationOtherSpecialNotesPhotoController
          .text
          .trim(),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_selectedYear 데이터가 저장되었습니다.')));
    } catch (e) {
      print('연도별 데이터 저장 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다: $e')));
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

      print(
        '🔍 1.1 조사 결과 저장 - HeritageId: $heritageId, HeritageName: $heritageName',
      );

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
        surveyData: {'surveyResults': surveyData},
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

    Map<String, dynamic>? aiSummary;
    if (kind == _HistoryPhotoKind.damage) {
      aiSummary = await _autoDetectDamage(bytes);
    }

    try {
      final metadata = await _persistPhoto(
        image: image,
        kind: kind,
        aiSummary: aiSummary,
      );
      if (!mounted) return;
      final storedSummary =
          metadata['aiSummary'] as Map<String, dynamic>? ?? aiSummary;
      setState(() {
        image.markUploaded(
          url: metadata['url'] as String,
          storagePath: metadata['storagePath'] as String,
          uploadedAt: metadata['uploadedAt'] as String,
          rawValue: metadata,
          aiSummary: storedSummary,
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

  Future<Map<String, dynamic>?> _autoDetectDamage(Uint8List bytes) async {
    try {
      final result = await _ai.detect(bytes);
      final summary = _buildAiSummary(result);
      _showDamageAiResultBanner(summary);
      return summary;
    } on AiModelNotLoadedException catch (e) {
      _showAiError('AI 모델이 아직 준비되지 않았습니다. ${e.message}');
    } on AiConnectionException catch (e) {
      _showAiError('AI 서버에 연결할 수 없습니다. ${e.message}');
    } on AiTimeoutException catch (_) {
      _showAiError('AI 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
    } on AiServerException catch (e) {
      _showAiError(e.message);
    } catch (e) {
      _showAiError('AI 감지 실패: $e');
    }
    return null;
  }

  Map<String, dynamic> _buildAiSummary(AiDetectionResult result) {
    final detections = result.detections
        .map((det) => Map<String, dynamic>.from(det))
        .toList();
    detections.sort((a, b) {
      final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
      final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
      return scoreB.compareTo(scoreA);
    });
    final top = detections.isNotEmpty ? detections.first : null;

    final grade = result.grade?.toUpperCase();
    final explanation = result.explanation;

    return {
      'status': 'success',
      'count': result.count ?? detections.length,
      if (grade != null && grade.isNotEmpty) 'grade': grade,
      if (explanation != null && explanation.isNotEmpty)
        'explanation': explanation,
      'detections': detections,
      if (top != null && top['label'] != null) 'topLabel': top['label'],
      if (top != null && top['score'] is num)
        'topScore': (top['score'] as num).toDouble(),
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  void _showDamageAiResultBanner(Map<String, dynamic> summary) {
    if (!mounted) return;
    final count = summary['count'] as int? ?? 0;
    final topLabel = summary['topLabel'] as String?;
    final score = (summary['topScore'] as num?)?.toDouble();
    final scoreText = score != null
        ? ' (${(score * 100).toStringAsFixed(1)}%)'
        : '';
    final message = count == 0
        ? 'AI 감지 결과: 손상이 감지되지 않았습니다.'
        : 'AI 감지 완료: ${topLabel ?? '손상'}$scoreText 포함 총 $count건';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showAiError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<Map<String, dynamic>> _persistPhoto({
    required _HistoryImage image,
    required _HistoryPhotoKind kind,
    Map<String, dynamic>? aiSummary,
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
      if (aiSummary != null) 'aiSummary': aiSummary,
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

  // 수정이력 다이얼로그 표시
  void _showEditHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수정이력'),
        content: SizedBox(
          width: 800,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이력 수정 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _getEditHistoryList().length,
                  itemBuilder: (context, index) {
                    final edit = _getEditHistoryList()[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (edit['title'] as String? ?? ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: edit['status'] == '완료'
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (edit['status'] as String? ?? ''),
                                    style: TextStyle(
                                      color: edit['status'] == '완료'
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '수정자: ${edit['editor']}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '수정일: ${edit['date']}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '수정내용: ${edit['description']}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (edit['changedFields'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '변경된 필드: ${edit['changedFields']}',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 수정이력 목록 생성 (실제로는 Firestore에서 가져와야 함)
  List<Map<String, String>> _getEditHistoryList() {
    return [
      {
        'title': '조사결과 수정',
        'editor': '김조사',
        'date': '2024-01-15 14:30',
        'description': '기단부 조사 결과에서 균열 현상 추가 기록',
        'status': '완료',
        'changedFields': '기단부 조사결과, 특기사항',
      },
      {
        'title': '보존사항 수정',
        'editor': '이보존',
        'date': '2024-01-10 09:15',
        'description': '벽체부 보존 상태를 양호에서 주의로 변경',
        'status': '완료',
        'changedFields': '벽체부 보존상태, 조사 종합의견',
      },
      {
        'title': '관리사항 수정',
        'editor': '박관리',
        'date': '2024-01-05 16:45',
        'description': '안전시설 현황에 소화기 설치 현황 추가',
        'status': '완료',
        'changedFields': '안전시설 현황, 관리사항',
      },
      {
        'title': '등급분류 수정',
        'editor': '최등급',
        'date': '2024-01-03 11:20',
        'description': '전체 등급을 B에서 C1으로 하향 조정',
        'status': '진행중',
        'changedFields': '등급분류, 조사 종합의견',
      },
      {
        'title': '유지보수 이력 추가',
        'editor': '정유지',
        'date': '2024-01-01 13:00',
        'description': '2023년 12월 정기점검 결과 추가',
        'status': '완료',
        'changedFields': '유지보수/수리 이력',
      },
    ];
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
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _selectedYear,
                            onChanged: (String? newValue) {
                              if (newValue != null &&
                                  newValue != _selectedYear) {
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
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => _showEditHistoryDialog(),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('수정이력'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF6B7280)),
                              foregroundColor: const Color(0xFF6B7280),
                            ),
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
                        onPressed:
                            _isEditable && !_isSaving && _hasUnsavedChanges
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
            _buildSurveyTableRow(
              '채색 (단청, 벽화)',
              _surveyControllers['coloring']!,
            ),
            _buildSurveyTableRow('충해', _surveyControllers['pest']!),
            _buildSurveyTableRow('기타', _surveyControllers['etc']!),
          ]),
          // 조사 정보 섹션
          _buildSurveyTableSection('조사 정보', [
            _buildSurveyTableRow('특기사항', _surveyControllers['safetyNotes']!),
            _buildSurveyTableRow(
              '조사 종합의견',
              _surveyControllers['investigatorOpinion']!,
            ),
            _buildSurveyTableRow('등급분류', _surveyControllers['grade']!),
            _buildSurveyTableRow(
              '조사일시',
              _surveyControllers['investigationDate']!,
            ),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
        _buildManagementCheckboxRow(
          '방재매뉴얼(소방시설도면 등) 배치 여부',
          _hasDisasterManual,
          (value) {
            setState(() => _hasDisasterManual = value);
          },
        ),
        _buildManagementCheckboxRow('소방차의 진입 가능 여부', _hasFireTruckAccess, (
          value,
        ) {
          setState(() => _hasFireTruckAccess = value);
        }),
        _buildManagementCheckboxRow('방화선 여부', _hasFireLine, (value) {
          setState(() => _hasFireLine = value);
        }),
        _buildManagementCheckboxRow(
          '국보·보물 내에 화재 시 대피 대상 국가유산 유무',
          _hasEvacTargets,
          (value) {
            setState(() => _hasEvacTargets = value);
          },
        ),
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
        _buildManagementCheckboxWithCountRow('자동화재속보설비', _hasAutoAlarm, (
          value,
        ) {
          setState(() => _hasAutoAlarm = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('CCTV', _hasCCTV, (value) {
          setState(() => _hasCCTV = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('도난방지카메라', _hasAntiTheftCam, (
          value,
        ) {
          setState(() => _hasAntiTheftCam = value);
        }, TextEditingController()),
        _buildManagementCheckboxWithCountRow('화재감지기', _hasFireDetector, (
          value,
        ) {
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
        _buildManagementCheckboxRow('안전경비인력 배치 여부', _hasSecurityPersonnel, (
          value,
        ) {
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
        _buildManagementCheckboxRow(
          '국가유산 해설사',
          _hasNationalHeritageInterpreter,
          (value) {
            setState(() => _hasNationalHeritageInterpreter = value);
          },
        ),
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

  Widget _buildManagementCheckboxRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
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

  Widget _buildManagementCheckboxWithCountRow(
    String label,
    bool hasItem,
    ValueChanged<bool> onHasItemChanged,
    TextEditingController controller,
  ) {
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
                _buildManagementCheckbox(
                  '있음',
                  hasItem,
                  () => onHasItemChanged(true),
                ),
                const SizedBox(width: 8),
                _buildManagementCheckbox(
                  '없음',
                  !hasItem,
                  () => onHasItemChanged(false),
                ),
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
                  borderSide: BorderSide(
                    color: hasItem
                        ? const Color(0xFFD1D5DB)
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
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

  Widget _buildManagementTextFieldRow(
    String label,
    TextEditingController controller,
  ) {
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
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

  Widget _buildManagementCheckbox(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
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
                color: isSelected
                    ? const Color(0xFF1E2A44)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(3),
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
              color: isSelected
                  ? const Color(0xFF1E2A44)
                  : const Color(0xFF6B7280),
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
            _buildPreservationTableRow(
              '기단부',
              '기단',
              _preservationFoundationBaseController,
              _preservationFoundationBasePhotoController,
              surveyContent:
                  '조사내용에서는 부재/위치/현상 순으로 내용을 기입한다.\n해당 현상을 촬영한 사진을 첨부하고, 사진/위치 란에 사진번호를 기입한다.\n사진번호는 부재명과 번호를 같이 기입한다.',
            ),
            _buildPreservationTableRow(
              '',
              '초석',
              TextEditingController(),
              _preservationFoundationCornerstonePhotoController,
            ),
          ]),
          // ② 축부(벽체부) 섹션
          _buildPreservationTableSection('② 축부(벽체부)', [
            _buildPreservationTableRow(
              '축부(벽체부)',
              '기둥 등 수직재 (기둥 등 수직으로 하중을 받는 모든 부재)',
              _preservationShaftVerticalMembersController,
              _preservationShaftVerticalMembersPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '인방(引枋: 기둥과 기둥 사이에 놓이는 부재)/창방 등',
              _preservationShaftLintelTiebeamController,
              _preservationShaftLintelTiebeamPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '공포',
              _preservationShaftBracketSystemController,
              _preservationShaftBracketSystemPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '벽체/고막이',
              _preservationShaftWallGomagiController,
              _preservationShaftWallGomagiPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '구들/마루',
              _preservationShaftOndolFloorController,
              _preservationShaftOndolFloorPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '창호/난간',
              _preservationShaftWindowsRailingsController,
              _preservationShaftWindowsRailingsPhotoController,
            ),
          ]),
          // ③ 지붕부 섹션
          _buildPreservationTableSection('③ 지붕부', [
            _buildPreservationTableRow(
              '지붕부',
              '지붕 가구재',
              _preservationRoofFramingMembersController,
              _preservationRoofFramingMembersPhotoController,
              surveyContent: '보 부재 등의 조사내용을 기입한다.',
            ),
            _buildPreservationTableRow(
              '',
              '서까래/부연 (처마 서까래의 끝에 덧없는 네모지고 짧은 서까래)',
              _preservationRoofRaftersPuyeonController,
              _preservationRoofRaftersPuyeonPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '지붕/기와',
              _preservationRoofRoofTilesController,
              _preservationRoofRoofTilesPhotoController,
            ),
            _buildPreservationTableRow(
              '',
              '천장/단집',
              _preservationRoofCeilingDanjipController,
              _preservationRoofCeilingDanjipPhotoController,
            ),
          ]),
          // 기타사항 섹션
          _buildPreservationTableSection('기타사항', [
            _buildPreservationTableRow(
              '기타사항',
              '특기사항',
              _preservationOtherSpecialNotesController,
              _preservationOtherSpecialNotesPhotoController,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPreservationTableSection(
    String sectionTitle,
    List<Widget> rows,
  ) {
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

  Widget _buildPreservationTableRow(
    String category,
    String component,
    TextEditingController surveyController,
    TextEditingController photoController, {
    String? surveyContent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
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
                    onPressed: _isEditable
                        ? () => _pickImage(_getPhotoKey(photoController))
                        : null,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('사진 첨부', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2A44),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
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
                      color: photoController.text.isNotEmpty
                          ? const Color(0xFFF0F9FF)
                          : Colors.white,
                    ),
                    child: Text(
                      photoController.text.isNotEmpty ? '사진 보기' : '사진 없음',
                      style: TextStyle(
                        fontSize: 12,
                        color: photoController.text.isNotEmpty
                            ? const Color(0xFF1E2A44)
                            : Colors.grey.shade600,
                        fontWeight: photoController.text.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.normal,
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
        Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          radius: const Radius.circular(5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FixedColumnWidth(100), // 구성 요소
                1: FixedColumnWidth(80), // 위치
                2: FixedColumnWidth(100), // 구조적 손상 이격/이완
                3: FixedColumnWidth(100), // 구조적 손상 기울
                4: FixedColumnWidth(100), // 물리적 손상 탈락
                5: FixedColumnWidth(100), // 물리적 손상 갈램
                6: FixedColumnWidth(100), // 생물·화학적 손상 천공
                7: FixedColumnWidth(100), // 생물·화학적 손상 부후
                8: FixedColumnWidth(80), // 육안 등급 육안
                9: FixedColumnWidth(80), // 실험실 등급 실험실
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
                      _DamageTableCell(
                        '행을 추가해 주세요.',
                        isHeader: false,
                        colSpan: 11,
                      ),
                    ],
                  )
                else
                  ..._damageSummaryRows.map((row) => row.buildRow()),
              ],
            ),
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
          _buildMaintenanceCheckboxRow('정밀진단 실시 여부', _precisionDiagnosis, (
            value,
          ) {
            setState(() => _precisionDiagnosis = value);
          }),
          const SizedBox(height: 16),

          // 돌봄사업 수행 여부
          _buildMaintenanceCheckboxRow('돌봄사업 수행 여부', _careProject, (value) {
            setState(() => _careProject = value);
          }),
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

  Widget _buildMaintenanceCheckboxRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
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
                _buildMaintenanceCheckbox(
                  '미실시',
                  !value,
                  () => onChanged(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCheckbox(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
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
                color: isSelected
                    ? const Color(0xFF1E2A44)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
              color: isSelected ? const Color(0xFF1E2A44) : Colors.white,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected
                  ? const Color(0xFF1E2A44)
                  : const Color(0xFF6B7280),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTextFieldRow(
    String label,
    TextEditingController controller,
    String hintText,
  ) {
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
        if (image.hasAiSummary)
          Positioned(
            left: 8,
            bottom: 8,
            child: _AiSummaryBadge(
              summary: image.aiSummary!,
              onTap: () => _showAiSummaryDialog(context),
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

  void _showAiSummaryDialog(BuildContext context) {
    final summary = image.aiSummary;
    if (summary == null) return;
    final detections =
        (summary['detections'] as List?)
            ?.map(
              (e) => e is Map
                  ? Map<String, dynamic>.from(
                      e.map((key, value) => MapEntry(key.toString(), value)),
                    )
                  : null,
            )
            .whereType<Map<String, dynamic>>()
            .toList() ??
        const [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI 손상 감지 결과'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary['grade'] != null)
                  _buildSummaryRow('등급', summary['grade'].toString()),
                if (summary['explanation'] != null &&
                    summary['explanation'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      summary['explanation'].toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                _buildSummaryRow(
                  '감지 수',
                  '${summary['count'] ?? detections.length}건',
                ),
                const SizedBox(height: 12),
                if (detections.isEmpty) const Text('감지된 손상이 없습니다.'),
                if (detections.isNotEmpty) ...[
                  const Text(
                    '상위 손상',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final det in detections.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${det['label'] ?? '손상'} (${_formatScore(det['score'])})',
                        style: const TextStyle(color: Color(0xFF374151)),
                      ),
                    ),
                  if (detections.length > 3)
                    Text('+ ${detections.length - 3}건 추가 결과'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatScore(dynamic raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null) return '-';
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

class _AiSummaryBadge extends StatelessWidget {
  const _AiSummaryBadge({
    required this.summary,
    required this.onTap,
    super.key,
  });

  final Map<String, dynamic> summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grade = summary['grade'] as String?;
    final label = summary['topLabel'] as String?;
    final double? score = (summary['topScore'] as num?)?.toDouble();
    final parts = <String>[];
    if (grade != null && grade.isNotEmpty) {
      parts.add('등급 $grade');
    }
    if (label != null && label.isNotEmpty) {
      final double? percent = score != null
          ? ((score * 100).clamp(0, 100)).toDouble()
          : null;
      final percentText = percent != null
          ? ' ${percent.toStringAsFixed(0)}%'
          : '';
      parts.add('$label$percentText');
    }
    final text = parts.isEmpty ? 'AI 결과 보기' : parts.join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_graph, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
    this.aiSummary,
    this.isUploading = false,
  });

  final String id;
  Uint8List? bytes;
  String? url;
  String? storagePath;
  String? uploadedAt;
  Object? rawValue;
  Map<String, dynamic>? aiSummary;
  bool isUploading;

  bool get hasAiSummary => aiSummary != null;

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
    Map<String, dynamic>? aiSummary,
  }) {
    this.url = url;
    this.storagePath = storagePath;
    this.uploadedAt = uploadedAt;
    this.rawValue = rawValue;
    this.aiSummary = aiSummary ?? this.aiSummary;
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
  const DeepInspectionScreen({super.key, required this.selectedDamage});

  final Map<String, dynamic> selectedDamage;

  @override
  State<DeepInspectionScreen> createState() => _DeepInspectionScreenState();
}

class _DeepInspectionScreenState extends State<DeepInspectionScreen> {
  final TextEditingController _detailedOpinionController =
      TextEditingController();
  final TextEditingController _recommendationController =
      TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  String _selectedPriority = '중';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 기존 데이터로 폼 초기화
    _detailedOpinionController.text =
        widget.selectedDamage['inspectorOpinion']?.toString() ?? '';
    _recommendationController.text =
        widget.selectedDamage['recommendation']?.toString() ?? '';
    _priorityController.text =
        widget.selectedDamage['priority']?.toString() ?? '중';
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
    final String? rawImageUrl =
        (widget.selectedDamage['imageUrl'] ?? widget.selectedDamage['url'])
            ?.toString();
    final String? optimizedThumbUrl =
        rawImageUrl != null && rawImageUrl.trim().isNotEmpty
            ? _proxyImageUrl(rawImageUrl, maxWidth: 640, maxHeight: 480)
            : null;

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
                      _buildInfoRow(
                        '위치',
                        widget.selectedDamage['location']?.toString() ?? '—',
                      ),
                      _buildInfoRow(
                        '손상 유형',
                        widget.selectedDamage['phenomenon']?.toString() ?? '—',
                      ),
                      _buildInfoRow(
                        '등급',
                        widget.selectedDamage['severityGrade']?.toString() ??
                            '—',
                      ),
                    ],
                  ),
                ),
                if (optimizedThumbUrl != null)
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
                        child: OptimizedImage(
                          imageUrl: optimizedThumbUrl,
                          fit: BoxFit.contain,
                          maxWidth: 640,
                          maxHeight: 480,
                          errorWidget: const Icon(Icons.image_not_supported),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      final fb = FirebaseService();
      final heritageId = widget.selectedDamage['heritageId'] as String? ?? '';
      final heritageName =
          widget.selectedDamage['heritageName'] as String? ?? '미상';

      if (heritageId.isNotEmpty) {
        // 손상부 조사 데이터 업데이트
        final docId = widget.selectedDamage['docId'] as String?;
        if (docId != null && docId.isNotEmpty) {
          await fb.updateDamageSurvey(
            heritageId: heritageId,
            docId: docId,
            data: {
              'detailInputs': inspectionData,
              'updatedAt': DateTime.now().toIso8601String(),
            },
          );
        } else {
          // 새 문서로 저장
          await fb.saveDamageSurvey(
            heritageId: heritageId,
            data: {...updatedDamage, 'heritageName': heritageName},
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 심화조사 결과가 저장되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
  final Map<String, dynamic> selectedDamage;
  const DeepDamageInspectionDialog({super.key, required this.selectedDamage});

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
    final String rawDamageUrl =
        (widget.selectedDamage['imageUrl'] as String?) ??
            (widget.selectedDamage['url'] as String?) ??
            damageImageUrl;
    final String optimizedDamageUrl =
        _proxyImageUrl(rawDamageUrl, maxWidth: 1600, maxHeight: 1200);

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
                              child: OptimizedImage(
                                imageUrl: optimizedDamageUrl,
                                fit: BoxFit.cover,
                                maxWidth: 1600,
                                maxHeight: 1200,
                                errorWidget: Container(
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
                      // 등급 산출 로직: AI 감지 결과와 손상 정보를 기반으로 등급 계산
                      final detections =
                          widget.selectedDamage['detections']
                              as List<dynamic>? ??
                          [];
                      final severityGrade =
                          widget.selectedDamage['severityGrade'] as String? ??
                          'C';

                      // 감지된 손상 수와 신뢰도 기반 등급 계산
                      String calculatedGrade = severityGrade;
                      if (detections.isNotEmpty) {
                        final avgConfidence =
                            detections
                                .map(
                                  (d) =>
                                      (d['score'] as num?)?.toDouble() ?? 0.0,
                                )
                                .reduce((a, b) => a + b) /
                            detections.length;

                        if (avgConfidence > 0.8) {
                          calculatedGrade = 'A';
                        } else if (avgConfidence > 0.6) {
                          calculatedGrade = 'B';
                        } else if (avgConfidence > 0.4) {
                          calculatedGrade = 'C';
                        } else {
                          calculatedGrade = 'D';
                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('등급 산출 완료: $calculatedGrade'),
                          backgroundColor: Colors.blue,
                          duration: const Duration(seconds: 2),
                        ),
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
                    onPressed: () async {
                      // 저장 로직: 현재 입력된 모든 데이터를 Firebase에 저장
                      try {
                        final fb = FirebaseService();
                        final heritageId =
                            widget.selectedDamage['heritageId'] as String? ??
                            '';
                        final heritageName =
                            widget.selectedDamage['heritageName'] as String? ??
                            '미상';

                        if (heritageId.isNotEmpty) {
                          final docId =
                              widget.selectedDamage['docId'] as String?;
                          final dataToSave =
                              Map<String, dynamic>.from(widget.selectedDamage)
                                ..['heritageName'] = heritageName
                                ..['updatedAt'] = DateTime.now()
                                    .toIso8601String();

                          if (docId != null && docId.isNotEmpty) {
                            await fb.updateDamageSurvey(
                              heritageId: heritageId,
                              docId: docId,
                              data: dataToSave,
                            );
                          } else {
                            await fb.saveDamageSurvey(
                              heritageId: heritageId,
                              data: dataToSave,
                            );
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ 저장되었습니다.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context, {'saved': true});
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ 문화유산 정보가 없습니다.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ 저장 실패: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
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
  final TextEditingController structuralSeparationController =
      TextEditingController();
  final TextEditingController structuralTiltController =
      TextEditingController();
  final TextEditingController physicalDetachmentController =
      TextEditingController();
  final TextEditingController physicalCrackingController =
      TextEditingController();
  final TextEditingController biologicalPerforationController =
      TextEditingController();
  final TextEditingController biologicalDecayController =
      TextEditingController();
  final TextEditingController visualGradeController = TextEditingController();
  final TextEditingController labGradeController = TextEditingController();
  final TextEditingController finalGradeController = TextEditingController();

  TableRow buildRow() {
    return TableRow(
      children: [
        _DamageTableCell('', isHeader: false, controller: componentController),
        _DamageTableCell('', isHeader: false, controller: locationController),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: structuralSeparationController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: structuralTiltController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: physicalDetachmentController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: physicalCrackingController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: biologicalPerforationController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: biologicalDecayController,
        ),
        _DamageTableCell(
          '',
          isHeader: false,
          controller: visualGradeController,
        ),
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

/// 바운딩 박스를 이미지 위에 그리는 CustomPainter
/// BoxFit.contain을 고려하여 실제 렌더링 영역을 계산합니다.
class BoundingBoxPainter extends CustomPainter {
  const BoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<Map<String, dynamic>> detections;
  final double imageWidth;
  final double imageHeight;

  /// 손상 유형별 색상 반환
  Color _getDamageColor(String label, double score) {
    // 손상 유형에 따른 색상 매핑
    final labelLower = label.toLowerCase();
    if (labelLower.contains('갈램') || labelLower.contains('갈래')) {
      return const Color(0xFFFF6B6B); // 빨간색
    } else if (labelLower.contains('균열')) {
      return const Color(0xFFFFA500); // 주황색
    } else if (labelLower.contains('부후')) {
      return const Color(0xFF8B4513); // 갈색
    } else if (labelLower.contains('압괴') || labelLower.contains('터짐')) {
      return const Color(0xFFDC143C); // 진한 빨간색
    }

    // 신뢰도에 따른 색상 조정
    if (score >= 0.7) {
      return const Color(0xFFFF0000); // 높은 신뢰도: 진한 빨간색
    } else if (score >= 0.5) {
      return const Color(0xFFFF6B6B); // 중간 신뢰도: 빨간색
    } else {
      return const Color(0xFFFFA500); // 낮은 신뢰도: 주황색
    }
  }

  /// BoxFit.contain을 사용할 때 실제 이미지 렌더링 영역을 계산합니다.
  /// [containerSize]: 위젯의 전체 크기
  /// [imageSize]: 원본 이미지 크기
  /// 반환: (실제 렌더링 크기, 오프셋)
  (Size, Offset) _calculateRenderedImageBounds(
    Size containerSize,
    Size imageSize,
  ) {
    // 이미지와 컨테이너의 비율 계산
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double renderedWidth;
    double renderedHeight;
    double offsetX;
    double offsetY;

    if (imageAspectRatio > containerAspectRatio) {
      // 이미지가 더 넓음: 너비에 맞춤
      renderedWidth = containerSize.width;
      renderedHeight = containerSize.width / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerSize.height - renderedHeight) / 2;
    } else {
      // 이미지가 더 높음: 높이에 맞춤
      renderedWidth = containerSize.height * imageAspectRatio;
      renderedHeight = containerSize.height;
      offsetX = (containerSize.width - renderedWidth) / 2;
      offsetY = 0;
    }

    return (Size(renderedWidth, renderedHeight), Offset(offsetX, offsetY));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;
    if (detections.isEmpty) return;

    // BoxFit.contain을 고려한 실제 렌더링 영역 계산
    final imageSize = Size(imageWidth, imageHeight);
    final (renderedSize, offset) = _calculateRenderedImageBounds(
      size,
      imageSize,
    );

    // 스케일 팩터 계산 (원본 이미지 대비 렌더링 크기)
    final scaleX = renderedSize.width / imageWidth;
    final scaleY = renderedSize.height / imageHeight;

    // 모든 감지 결과에 대해 바운딩 박스 그리기
    for (final det in detections) {
      final bbox = det['bbox'] as List?;
      if (bbox == null || bbox.length != 4) continue;

      // 원본 이미지 좌표에서 바운딩 박스 추출
      final x1 = (bbox[0] as num).toDouble();
      final y1 = (bbox[1] as num).toDouble();
      final x2 = (bbox[2] as num).toDouble();
      final y2 = (bbox[3] as num).toDouble();

      // 렌더링 좌표로 변환 (오프셋 추가)
      final rect = Rect.fromLTRB(
        offset.dx + x1 * scaleX,
        offset.dy + y1 * scaleY,
        offset.dx + x2 * scaleX,
        offset.dy + y2 * scaleY,
      );

      // 손상 유형별 색상 결정
      final label = det['label'] as String? ?? '';
      final score = (det['score'] as num?)?.toDouble() ?? 0.0;
      final boxColor = _getDamageColor(label, score);

      // 바운딩 박스 그리기 (더 두껍고 명확하게)
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // 외곽선 (검은색) 추가로 가시성 향상
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );

      // 실제 바운딩 박스
      canvas.drawRect(rect, boxPaint);

      // 라벨과 점수 텍스트 준비
      final text = '$label ${(score * 100).toStringAsFixed(1)}%';

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

      // 텍스트 배경 위치 계산 (바운딩 박스 위쪽)
      final textBg = Rect.fromLTWH(
        rect.left,
        (rect.top - textPainter.height - 4).clamp(offset.dy, double.infinity),
        textPainter.width + 8,
        textPainter.height + 4,
      );

      // 텍스트 배경 그리기 (반투명 배경 + 테두리)
      final bgPaint = Paint()..color = boxColor.withValues(alpha: 0.9);
      canvas.drawRect(textBg, bgPaint);

      // 텍스트 배경 테두리
      canvas.drawRect(
        textBg,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      textPainter.paint(canvas, Offset(rect.left + 4, textBg.top + 2));
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections ||
        imageWidth != oldDelegate.imageWidth ||
        imageHeight != oldDelegate.imageHeight;
  }
}
