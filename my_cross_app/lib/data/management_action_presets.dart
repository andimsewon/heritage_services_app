/// 손상부 조사 시 활용할 관리 조치 선택지
///
/// 조사자가 "조사자 의견"을 작성할 때 자주 사용하는 권고 사항을
/// 카테고리별로 정리한 데이터입니다. UI에서는 이 목록을 기반으로
/// 필터 칩을 생성해 다중 선택을 지원합니다.

class ManagementActionCategory {
  const ManagementActionCategory({
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;
  final List<String> actions;
}

const List<ManagementActionCategory> managementActionCategories = [
  ManagementActionCategory(
    title: '소방·안전 관리',
    description: '소화 설비, 방재 매뉴얼, 대피 훈련 등 화재 대응 체계 강화',
    actions: [
      '소화기·옥외소화전 작동 상태 점검',
      '방재 매뉴얼 및 대피 동선 보완',
      '화재 대피 모의훈련 실시',
    ],
  ),
  ManagementActionCategory(
    title: '전기·가스 시설 관리',
    description: '노후 설비 교체, 누설 점검 등 위험 요소 해소',
    actions: [
      '배전반·분전함 정밀 점검',
      '노후 배선·차단기 교체 검토',
      '가스 누설 감지 시스템 점검',
    ],
  ),
  ManagementActionCategory(
    title: '안전경비·모니터링 강화',
    description: '경비 인력, 순찰, CCTV 등 상시 감시 체계 확보',
    actions: [
      '야간 경비 인력 보강',
      'CCTV 사각지대 점검 및 추가 설치',
      '순찰 관리일지 작성·점검',
    ],
  ),
  ManagementActionCategory(
    title: '돌봄·안내·환경 정비',
    description: '방문객 안내, 돌봄사업 연계, 주변 환경 정비',
    actions: [
      '돌봄사업·자원봉사 연계 요청',
      '안내·전시 시설 정비 및 재배치',
      '배수로·주변 시설 청결 유지',
    ],
  ),
];
