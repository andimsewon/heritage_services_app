import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  late final AIPredictionRepository _aiPredictionRepository =
      _MockAIPredictionRepository();

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
          foundation: '기단부 점검 내용을 입력하세요.',
          wall: '축부(벽체부) 점검 내용을 입력하세요.',
          roof: '지붕부 점검 내용을 입력하세요.',
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
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        title: Text(
          _name.isEmpty ? '기본개요' : _name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  builder: (_) => HeritageHistoryDialog(
                    heritageId: heritageId,
                    heritageName: _name,
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 16, color: Color(0xFF2563EB)),
              label: const Text(
                '기존이력',
                style: TextStyle(color: Color(0xFF2563EB), fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxContentWidth = 960.0;
          final horizontalPadding = constraints.maxWidth > maxContentWidth
              ? (constraints.maxWidth - maxContentWidth) / 2
              : 16.0;
          return ScrollConfiguration(
            behavior: const MaterialScrollBehavior(),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      HeritagePhotoSection(
                        photosStream: _fb.photosStream(heritageId),
                        onAddPhoto: _addPhoto,
                        onPreview: (url, title) =>
                            _openPhotoViewer(url: url, title: title),
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
                          if (result != null &&
                              result['saved'] == true &&
                              mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('심화조사 데이터가 저장되었습니다'),
                              ),
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
                      const SectionDivider(),
                      if (_detailViewModel != null)
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
                                ),
                                const SectionDivider(),
                                DamageSummaryTable(
                                  value: vm.damageSummary,
                                  onChanged: vm.updateDamageSummary,
                                ),
                                const SectionDivider(),
                                InvestigatorOpinionField(
                                  value: vm.investigatorOpinion,
                                  onChanged: vm.updateInvestigatorOpinion,
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
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '기본 정보',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          // 유산명
          _buildOverviewRow('유산명', name.isEmpty ? '미상' : name),
          const Divider(height: 10, color: Color(0xFFE0E0E0)),

          // 지정연월
          _buildOverviewRow('지정연월', _formatDate(asdt)),
          const Divider(height: 10, color: Color(0xFFE0E0E0)),

          // 종목
          _buildOverviewRow('종목', kind.isEmpty ? '-' : kind),
          const Divider(height: 10, color: Color(0xFFE0E0E0)),

          // 소재지
          _buildOverviewRow('소재지', location.isEmpty ? '-' : location),
          const Divider(height: 10, color: Color(0xFFE0E0E0)),

          // 관리번호
          _buildOverviewRow('관리번호', managementNumber.isEmpty ? '-' : managementNumber),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF333333),
              ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '문화유산 현황',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
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
                        const Text('등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF666666))),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('사진 등록'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2956CC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                          ((doc.data())['url'] as String?)?.isNotEmpty ??
                          false,
                    )
                    .toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF666666))),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('사진 등록'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2956CC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
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
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E66FB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('미리보기', style: TextStyle(fontSize: 12)),
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

class DamageSurveySection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '손상부 조사',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddSurvey,
                  icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
                  label: const Text('조사 등록'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDeepInspection,
                  icon: const Icon(Icons.article_outlined, color: Colors.white),
                  label: const Text('심화조사'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: damageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('등록된 손상부 조사가 없습니다'));
                }
                final docs = snapshot.data!.docs
                    .where(
                      (doc) =>
                          ((doc.data())['imageUrl'] as String?)?.isNotEmpty ??
                          false,
                    )
                    .toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('등록된 손상부 조사가 없습니다'));
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
                        onDelete: () => onDelete(doc.id, url),
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
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '검출: ${detections.length}개',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
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
    _SurveyRowConfig(
      key: 'structure',
      label: '구조부',
      hint: '예: 이하 내용 1.1 총괄사항 참고',
    ),
    _SurveyRowConfig(key: 'wall', label: '축석(벽체부)', hint: '예: 균열, 박락 등 조사 결과'),
    _SurveyRowConfig(key: 'roof', label: '지붕부', hint: '예: 이하 내용 1.1 총괄사항 참고'),
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

  Map<String, dynamic> _managementYears = {};
  bool _isEditable = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  Presence? _mgmtFireSafety;
  Presence? _mgmtElectrical;
  Timer? _saveDebounce;
  StreamSubscription<Map<String, dynamic>>? _managementSub;

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

    _surveyControllers['structure']?.text = '이하 내용 1.1 총괄사항 참고';
    _surveyControllers['wall']?.text = '—';
    _surveyControllers['roof']?.text = '이하 내용 1.1 총괄사항 참고';
    _conservationPartControllers['structure']?.text = '기단';
    _conservationPartControllers['roof']?.text = '—';
    _conservationNoteControllers['structure']?.text = '이하 내용 1.2 보존사항 참고';
    _conservationNoteControllers['roof']?.text = '* 필요시 사진 보이기';
    _conservationLocationControllers['structure']?.text = '7,710';
    _conservationLocationControllers['roof']?.text = '';
    _fireSafetyPartController.text = '방재/피뢰설비';
    _electricalPartController.text = '전선/조명 등';

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
    _saveDebounce?.cancel();
    final yearKey = _currentYearKey;
    if (yearKey.isEmpty) return;

    String trim(TextEditingController controller) => controller.text.trim();

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
          'years.$yearKey.updatedAt': timestamp,
          'heritageName': widget.heritageName,
          'updatedAt': timestamp,
        }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
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
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedYear = v;
                            _isEditable = false;
                          });
                          _refreshManagementFields(overrideNotes: true);
                        },
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
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.2 보존사항'),
                          const SizedBox(height: 8),
                          _buildConservationTable(),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.3 관리사항'),
                          const SizedBox(height: 8),
                          _buildManagementTable(),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.4 위치현황'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '위치 도면/위성자료 등록',
                            description: '위치 및 도면 자료를 업로드하세요.',
                            photos: _locationImages,
                            kind: _HistoryPhotoKind.location,
                          ),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.5 현황사진'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '현황 사진 등록',
                            description: '최근 촬영한 현황 사진을 관리합니다.',
                            photos: _currentPhotos,
                            kind: _HistoryPhotoKind.current,
                          ),
                          const SizedBox(height: 24),
                          const _HistorySectionTitle('1.6 손상부 조사'),
                          const SizedBox(height: 8),
                          _buildHistoryPhotoSection(
                            title: '손상부 사진 등록',
                            description: '손상부 조사 결과를 사진과 함께 보관합니다.',
                            photos: _damagePhotos,
                            kind: _HistoryPhotoKind.damage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _saveDebounce?.cancel();
                          setState(() {
                            _isEditable = false;
                            _hasUnsavedChanges = false;
                          });
                          _refreshManagementFields(overrideNotes: true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('최신 데이터를 불러왔습니다')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 44),
                        ),
                        child: const Text('불러오기'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed:
                            _isEditable && !_isSaving && _hasUnsavedChanges
                            ? () async {
                                FocusScope.of(context).unfocus();
                                setState(() => _isSaving = true);
                                try {
                                  await _saveNow();
                                  if (!mounted) return;
                                  setState(() {
                                    _isEditable = false;
                                    _isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('저장되었습니다')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('저장 실패: $e')),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
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
                      OutlinedButton(
                        onPressed: _isEditable
                            ? null
                            : () {
                                setState(() {
                                  _isEditable = true;
                                  _hasUnsavedChanges = false;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 44),
                        ),
                        child: const Text('수정'),
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
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [_tableHeaderCell('구분'), _tableHeaderCell('내용')],
        ),
        for (final row in _surveyRowConfigs)
          TableRow(
            children: [
              _readOnlyCell(row.label),
              _editableCell(
                _surveyControllers[row.key]!,
                hint: row.hint,
                maxLines: 2,
              ),
            ],
          ),
      ],
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
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(0.6),
        4: FlexColumnWidth(0.6),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('부재', isHeader: true),
            _HistoryTableCell('조사내용(현상)', isHeader: true),
            _HistoryTableCell('있음', isHeader: true),
            _HistoryTableCell('없음', isHeader: true),
          ],
        ),
        TableRow(
          children: [
            const _HistoryTableCell('소방 및 안전관리'),
            _MgmtNoteCell(
              controller: _fireSafetyPartController,
              enabled: _isEditable,
              onChanged: (_) => _scheduleSave(),
            ),
            _MgmtNoteCell(
              controller: _fireSafetyNoteController,
              enabled: _isEditable,
              onChanged: (_) => _scheduleSave(),
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtFireSafety,
              target: Presence.yes,
              onChanged: (value) {
                setState(() => _mgmtFireSafety = value);
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtFireSafety,
              target: Presence.no,
              onChanged: (value) {
                setState(() => _mgmtFireSafety = value);
                _scheduleSave();
              },
            ),
          ],
        ),
        TableRow(
          children: [
            const _HistoryTableCell('전기시설'),
            _MgmtNoteCell(
              controller: _electricalPartController,
              enabled: _isEditable,
              onChanged: (_) => _scheduleSave(),
            ),
            _MgmtNoteCell(
              controller: _electricalNoteController,
              enabled: _isEditable,
              onChanged: (_) => _scheduleSave(),
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtElectrical,
              target: Presence.yes,
              onChanged: (value) {
                setState(() => _mgmtElectrical = value);
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtElectrical,
              target: Presence.no,
              onChanged: (value) {
                setState(() => _mgmtElectrical = value);
                _scheduleSave();
              },
            ),
          ],
        ),
      ],
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
        horizontal: screenWidth * 0.1,  // 좌우 10% 여백
        vertical: screenHeight * 0.1,   // 상하 10% 여백
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.8,   // 화면 너비의 80%
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
