import 'package:flutter/widgets.dart';

import '../models/heritage_detail_models.dart';

abstract class AIPredictionRepository {
  Future<AIPredictionGrade> predictGrade(String heritageId);
  Future<ImageProvider> generateDamageMap(String heritageId);
  Future<List<MitigationRow>> suggestMitigation(String heritageId);
}
