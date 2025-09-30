import 'package:cloud_firestore/cloud_firestore.dart';

class DamageDetection {
  final String label;           // 예: "갈라짐"
  final double score;           // 0~1
  final double x, y, w, h;      // 0~1 정규화 bbox (좌상단 x,y, 폭, 높이)

  DamageDetection({required this.label, required this.score, required this.x, required this.y, required this.w, required this.h});

  Map<String, dynamic> toMap() => {
    'label': label, 'score': score, 'x': x, 'y': y, 'w': w, 'h': h,
  };

  static DamageDetection fromMap(Map<String, dynamic> m) => DamageDetection(
    label: m['label'] as String? ?? '',
    score: (m['score'] as num?)?.toDouble() ?? 0,
    x: (m['x'] as num?)?.toDouble() ?? 0,
    y: (m['y'] as num?)?.toDouble() ?? 0,
    w: (m['w'] as num?)?.toDouble() ?? 0,
    h: (m['h'] as num?)?.toDouble() ?? 0,
  );
}

class DamageSurveyDoc {
  final String id;
  final String imageUrl;
  final List<DamageDetection> detections;
  final String? severity;   // A~F (선택)
  final String? memo;       // 조사자 의견
  final DateTime createdAt;

  DamageSurveyDoc({
    required this.id,
    required this.imageUrl,
    required this.detections,
    this.severity,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'imageUrl': imageUrl,
    'detections': detections.map((e) => e.toMap()).toList(),
    'severity': severity,
    'memo': memo,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DamageSurveyDoc fromSnap(DocumentSnapshot s) {
    final d = s.data() as Map<String, dynamic>;
    final dets = (d['detections'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DamageDetection.fromMap)
        .toList();
    return DamageSurveyDoc(
      id: s.id,
      imageUrl: d['imageUrl'] as String? ?? '',
      detections: dets,
      severity: d['severity'] as String?,
      memo: d['memo'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
