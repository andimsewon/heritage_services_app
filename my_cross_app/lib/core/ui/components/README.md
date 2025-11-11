# 🎨 공통 UI 컴포넌트 시스템

통일된 디자인 시스템으로 모든 섹션을 관리하는 재사용 가능한 컴포넌트 라이브러리

## 📁 파일 구조

```
lib/ui/components/
├── components.dart          # 메인 export 파일 (이것만 import하면 됨)
├── section_card.dart        # 섹션 카드 컴포넌트
├── section_button.dart      # 버튼 스타일 컴포넌트
├── input_helpers.dart       # 입력 필드 헬퍼
├── EXAMPLE.md              # 사용 예시 가이드
└── README.md               # 이 파일
```

## 🚀 빠른 시작

### 1. Import

```dart
import 'package:my_cross_app/ui/components/components.dart';
```

### 2. 기본 사용

```dart
SectionCard(
  title: "조사자 의견",
  action: SectionButton.filled(
    label: "저장",
    onPressed: () {},
  ),
  child: Text("본문 내용"),
)
```

## 📦 컴포넌트 목록

### 1. SectionCard
모든 섹션의 기본 컨테이너
- 통일된 배경, 그림자, 둥근 모서리
- 제목 + 액션 버튼 자동 레이아웃
- 커스터마이징 가능한 색상, 여백

### 2. SectionButton
재사용 가능한 버튼 스타일
- `filled()` - 주요 액션용
- `outlined()` - 보조 액션용
- `text()` - 취소/닫기용
- `icon()` - 편집/삭제용

### 3. InputHelpers
입력 필드 생성 헬퍼
- `buildTextField()` - 텍스트 입력
- `buildDropdownField()` - 드롭다운 선택
- `buildDateField()` - 날짜 선택
- `fieldGroup()` - 여러 필드 그룹화

### 4. EmptyStateContainer
빈 상태 표시용 컨테이너

### 5. InfoContainer
정보/경고 메시지 표시용 컨테이너

## 💡 디자인 원칙

### 색상
- **주 색상**: `#1C2D5A` (진한 남색)
- **배경**: `#FFFFFF` (흰색)
- **빈 상태 배경**: `#F8F9FB` (연한 회색)
- **테두리**: `#E5E7EB` (중간 회색)
- **텍스트 힌트**: `#9CA3AF` (회색)
- **포커스**: `#3B82F6` (파란색)

### 간격
- **외부 여백**: 12px (horizontal), 10px (vertical)
- **내부 여백**: 18px (all)
- **필드 간격**: 12px
- **버튼 간격**: 8px

### 모서리
- **카드**: 14px
- **입력 필드**: 8px
- **버튼**: 10px
- **정보 컨테이너**: 12px

## 🎯 사용 사례

### 기존 코드 (Before)

```dart
Card(
  elevation: 3,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("조사자 의견", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton(onPressed: () {}, child: Text("저장")),
          ],
        ),
        SizedBox(height: 16),
        TextField(...),
      ],
    ),
  ),
)
```

### 새로운 코드 (After)

```dart
SectionCard(
  title: "조사자 의견",
  action: SectionButton.filled(label: "저장", onPressed: () {}),
  child: InputHelpers.buildTextField(
    label: "구조부",
    hint: "예: 균열, 변형 등",
  ),
)
```

## ✅ 장점

### 1. 일관성
- 모든 섹션이 동일한 디자인
- 색상, 간격, 모서리 통일

### 2. 재사용성
- 한 번 정의하면 여러 곳에서 사용
- 코드 중복 제거

### 3. 유지보수성
- 디자인 변경 시 한 곳만 수정
- 테마 변경 용이

### 4. 가독성
- 명확한 컴포넌트 이름
- 깔끔한 코드 구조

## 📚 더 알아보기

- **EXAMPLE.md** - 실제 사용 예시 코드
- **section_card.dart** - SectionCard 구현 상세
- **section_button.dart** - SectionButton 구현 상세
- **input_helpers.dart** - InputHelpers 구현 상세

## 🔄 리팩토링 가이드

### 1단계: 기존 코드 확인
기존 섹션 코드에서 반복되는 패턴 찾기

### 2단계: SectionCard로 래핑
Card/Container → SectionCard로 교체

### 3단계: 버튼 교체
ElevatedButton/OutlinedButton → SectionButton으로 교체

### 4단계: 입력 필드 교체
TextFormField → InputHelpers.buildTextField()로 교체

### 5단계: 테스트
웹/앱 모두에서 레이아웃 확인

## 🎨 커스터마이징 예시

### 색상 변경
```dart
SectionCard(
  title: "경고",
  backgroundColor: Colors.orange.shade50,
  child: InfoContainer(
    message: "주의 필요",
    color: Colors.orange.shade100,
  ),
)
```

### 그림자 제거
```dart
SectionCard(
  title: "플랫 디자인",
  hasShadow: false,
  child: ...,
)
```

### 여백 조정
```dart
SectionCard(
  title: "넓은 여백",
  padding: EdgeInsets.all(32),
  margin: EdgeInsets.all(20),
  child: ...,
)
```

## 🤝 기여 방법

새로운 컴포넌트나 스타일이 필요하면:
1. 이 폴더에 새 파일 추가
2. `components.dart`에 export 추가
3. `EXAMPLE.md`에 사용 예시 추가
4. 테스트 후 커밋

## 📝 TODO

- [ ] 다크 모드 지원
- [ ] 애니메이션 추가
- [ ] 접근성 개선
- [ ] 더 많은 입력 타입 지원

---

**Made with ❤️ for Heritage Services App**
