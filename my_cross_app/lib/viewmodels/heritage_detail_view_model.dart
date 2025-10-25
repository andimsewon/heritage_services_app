import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/heritage_detail_models.dart';
import '../repositories/ai_prediction_repository.dart';

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
      await task();
    } catch (error, stackTrace) {
      debugPrint('AI task failed: $error');
      debugPrint('$stackTrace');
      aiPredictionState = aiPredictionState.copyWith(
        loading: false,
        error: error.toString(),
      );
    } finally {
      notifyListeners();
    }
  }
}
