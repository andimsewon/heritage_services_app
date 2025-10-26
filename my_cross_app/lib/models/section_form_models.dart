// lib/models/section_form_models.dart
// 각 섹션별 폼 데이터 모델 정의

class SectionFormData {
  final String id;
  final String sectionType; // 'inspection', 'management', 'damage', 'opinion'
  final String title;
  final String content;
  final DateTime createdAt;
  final String author;

  SectionFormData({
    required this.id,
    required this.sectionType,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sectionType': sectionType,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'author': author,
    };
  }

  factory SectionFormData.fromMap(Map<String, dynamic> map) {
    return SectionFormData(
      id: map['id'] ?? '',
      sectionType: map['sectionType'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      author: map['author'] ?? '',
    );
  }

  SectionFormData copyWith({
    String? id,
    String? sectionType,
    String? title,
    String? content,
    DateTime? createdAt,
    String? author,
  }) {
    return SectionFormData(
      id: id ?? this.id,
      sectionType: sectionType ?? this.sectionType,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
    );
  }
}

// 섹션 타입 상수
class SectionType {
  static const String inspection = 'inspection';
  static const String management = 'management';
  static const String damage = 'damage';
  static const String opinion = 'opinion';
}

// 섹션별 제목 상수
class SectionTitles {
  static const String inspection = '주요 점검 결과';
  static const String management = '관리사항';
  static const String damage = '손상부 종합';
  static const String opinion = '조사자 의견';
}
