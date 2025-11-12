import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_cross_app/features/heritage_detail/data/ai_prediction_repository.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

class HeritageDetailViewModel extends ChangeNotifier {
  HeritageDetailViewModel({
    required this.heritageId,
    required AIPredictionRepository aiRepository,
    InspectionResult? inspectionResult,
    DamageSummary? damageSummary,
    InvestigatorOpinion? investigatorOpinion,
    GradeClassification? gradeClassification,
    AIPredictionState? aiState,
  }) : _aiRepository = aiRepository,
       inspectionResult = inspectionResult ?? InspectionResult.empty(),
       damageSummary = damageSummary ?? DamageSummary.initial(),
       investigatorOpinion = investigatorOpinion ?? InvestigatorOpinion.empty(),
       gradeClassification =
           gradeClassification ?? GradeClassification.initial(),
       aiPredictionState = aiState ?? AIPredictionState.initial();

  final String heritageId;
  final AIPredictionRepository _aiRepository;

  InspectionResult inspectionResult;
  DamageSummary damageSummary;
  InvestigatorOpinion investigatorOpinion;
  GradeClassification gradeClassification;
  AIPredictionState aiPredictionState;

  void updateInspectionResult(InspectionResult value) {
    inspectionResult = value;
    notifyListeners();
  }

  void updateDamageSummary(DamageSummary value) {
    damageSummary = value;
    notifyListeners();
  }

  void updateInvestigatorOpinion(InvestigatorOpinion value) {
    investigatorOpinion = value;
    gradeClassification = gradeClassification.copyWith(
      summary: value.opinion.isNotEmpty
          ? value.opinion.trim()
          : gradeClassification.summary,
    );
    notifyListeners();
  }

  void updateGradeClassification(GradeClassification value) {
    gradeClassification = value;
    notifyListeners();
  }

  Future<void> predictGrade() async {
    await _executeAiTask(() async {
      final grade = await _aiRepository.predictGrade(heritageId);
      aiPredictionState = aiPredictionState.copyWith(
        grade: grade,
        loading: false,
        error: null,
      );
    });
  }

  Future<void> generateMap() async {
    await _executeAiTask(() async {
      final map = await _aiRepository.generateDamageMap(heritageId);
      aiPredictionState = aiPredictionState.copyWith(
        map: map,
        loading: false,
        error: null,
      );
    });
  }

  Future<void> suggestMitigation() async {
    await _executeAiTask(() async {
      final mitigations = await _aiRepository.suggestMitigation(heritageId);
      aiPredictionState = aiPredictionState.copyWith(
        mitigations: mitigations,
        loading: false,
        error: null,
      );
    });
  }

  Future<void> _executeAiTask(Future<void> Function() task) async {
    aiPredictionState = aiPredictionState.copyWith(loading: true, error: null);
    notifyListeners();
    
    try {
      await task().timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException('AI 작업 시간이 초과되었습니다.');
        },
      );
    } on TimeoutException catch (e) {
      debugPrint('⏰ AI 작업 타임아웃: $e');
      aiPredictionState = aiPredictionState.copyWith(
        loading: false,
        error: '작업 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.',
      );
    } catch (error, stackTrace) {
      debugPrint('❌ AI 작업 실패: $error');
      debugPrint('스택 트레이스: $stackTrace');
      
      String errorMessage = 'AI 작업 중 오류가 발생했습니다.';
      final errorStr = error.toString();
      
      // 구체적인 오류 메시지 제공
      if (errorStr.contains('AiModelNotLoadedException')) {
        errorMessage = 'AI 모델이 아직 로드되지 않았습니다.';
      } else if (errorStr.contains('AiConnectionException')) {
        errorMessage = 'AI 서버에 연결할 수 없습니다.';
      } else if (errorStr.contains('AiTimeoutException')) {
        errorMessage = 'AI 서버 응답 시간이 초과되었습니다.';
      } else if (errorStr.length < 100) {
        errorMessage = '오류: $errorStr';
      }
      
      aiPredictionState = aiPredictionState.copyWith(
        loading: false,
        error: errorMessage,
      );
    } finally {
      notifyListeners();
    }
  }
}
