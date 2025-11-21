/// 손상 계통도 정의
///
/// 문화유산 손상부 조사를 위해 구조적/물리적/생물·화학적 손상 그룹을
/// 계층 구조로 정리한 데이터입니다. 각 말단 노드는 실제 조사 시 선택되는
/// 표준 손상 용어입니다.

class DamageTaxonomyCategory {
  const DamageTaxonomyCategory({
    required this.name,
    required this.terms,
    this.description,
  });

  final String name;
  final List<String> terms;
  final String? description;
}

class DamageTaxonomyGroup {
  const DamageTaxonomyGroup({
    required this.name,
    required this.description,
    required this.accentColor,
    required this.categories,
  });

  final String name;
  final String description;
  final int accentColor; // ARGB hex (e.g. 0xFFB91C1C)
  final List<DamageTaxonomyCategory> categories;
}

/// 손상 계통도 전체 데이터셋
const List<DamageTaxonomyGroup> damageTaxonomyGroups = [
  DamageTaxonomyGroup(
    name: '구조적 손상',
    description: '변위 · 변형 · 파손 등 하중 전달체계에 영향을 주는 손상',
    accentColor: 0xFFB91C1C,
    categories: [
      DamageTaxonomyCategory(
        name: '변위 / 변형',
        description: '부재의 배열 및 자세가 틀어지며 구조 안정성에 영향을 주는 상태',
        terms: [
          '이격/이완',
          '기움',
          '들림',
          '축 변형',
          '침하',
          '처짐/휨',
          '비틀림',
          '돌아감',
        ],
      ),
      DamageTaxonomyCategory(
        name: '파손 / 결손',
        description: '부재가 끊어지거나 떨어져 나간 상태',
        terms: [
          '유실',
          '분리',
          '부러짐',
        ],
      ),
    ],
  ),
  DamageTaxonomyGroup(
    name: '물리적 손상',
    description: '표면 균열, 갈라짐, 박락 등 재료 자체의 물리적 결함',
    accentColor: 0xFF1D4ED8,
    categories: [
      DamageTaxonomyCategory(
        name: '균열 / 분할',
        terms: [
          '균열',
          '갈래',
        ],
      ),
      DamageTaxonomyCategory(
        name: '표면 박리 · 박락',
        terms: [
          '탈락',
          '들뜸',
          '박리/박락',
        ],
      ),
    ],
  ),
  DamageTaxonomyGroup(
    name: '생물·화학적 손상',
    description: '생물 증식이나 화학 반응에 의해 발생하는 손상',
    accentColor: 0xFF047857,
    categories: [
      DamageTaxonomyCategory(
        name: '생물 / 유기물 침식',
        terms: [
          '부후',
          '식물생장',
          '표면 오염균',
        ],
      ),
      DamageTaxonomyCategory(
        name: '공극 / 천공',
        terms: [
          '공동화',
          '천공',
        ],
      ),
      DamageTaxonomyCategory(
        name: '재료 변질',
        terms: [
          '변색',
        ],
      ),
    ],
  ),
];

/// 계통도에 포함된 모든 손상 용어 목록을 반환한다.
List<String> collectDamageTaxonomyTerms() {
  final terms = <String>{};
  for (final group in damageTaxonomyGroups) {
    for (final category in group.categories) {
      terms.addAll(category.terms);
    }
  }
  final sorted = terms.toList()..sort();
  return sorted;
}
