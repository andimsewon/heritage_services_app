# 공통 UI 컴포넌트 사용 가이드

통일된 디자인 시스템으로 모든 섹션을 관리합니다.

## 📦 Import

```dart
import 'package:my_cross_app/ui/components/components.dart';
```

## 🎨 컴포넌트

### 1. SectionCard - 섹션 카드

모든 섹션의 기본 컨테이너입니다.

**기본 사용법:**
```dart
SectionCard(
  title: "섹션 제목",
  child: Text("본문 내용"),
)
```

**버튼 추가:**
```dart
SectionCard(
  title: "조사자 의견",
  action: SectionButton.filled(
    label: "저장",
    onPressed: () {},
    icon: Icons.save,
  ),
  child: Text("본문"),
)
```

**여러 버튼:**
```dart
SectionCard(
  title: "손상부 조사",
  action: SectionButtonGroup(
    buttons: [
      SectionButton.outlined(
        label: "조사 등록",
        onPressed: () {},
      ),
      SectionButton.filled(
        label: "심화조사",
        onPressed: () {},
      ),
    ],
  ),
  child: EmptyStateContainer(
    message: "등록된 조사가 없습니다.",
    icon: Icons.folder_open,
  ),
)
```

### 2. SectionButton - 버튼 스타일

**Filled (주요 액션):**
```dart
SectionButton.filled(
  label: "AI 예측",
  onPressed: () {},
  icon: Icons.auto_graph,
)
```

**Outlined (보조 액션):**
```dart
SectionButton.outlined(
  label: "지도 생성",
  onPressed: () {},
  icon: Icons.map,
)
```

**Text (취소/닫기):**
```dart
SectionButton.text(
  label: "취소",
  onPressed: () {},
)
```

**Icon (편집/삭제):**
```dart
SectionButton.icon(
  iconData: Icons.edit,
  onPressed: () {},
  tooltip: "편집",
)
```

### 3. InputHelpers - 입력 필드

**텍스트 필드:**
```dart
InputHelpers.buildTextField(
  label: "구조부",
  hint: "예: 균열, 변형 등",
  controller: controller,
  maxLines: 2,
)
```

**드롭다운:**
```dart
InputHelpers.buildDropdownField(
  label: "등급",
  value: selectedGrade,
  items: ['A', 'B', 'C', 'D', 'E', 'F'],
  itemLabel: (grade) => grade,
  onChanged: (value) => setState(() => selectedGrade = value),
)
```

**날짜 선택:**
```dart
InputHelpers.buildDateField(
  context: context,
  label: "조사 일자",
  value: selectedDate,
  onChanged: (date) => setState(() => selectedDate = date),
)
```

**필드 그룹:**
```dart
InputHelpers.fieldGroup(
  spacing: 12,
  children: [
    InputHelpers.buildTextField(label: "구조부", hint: "..."),
    InputHelpers.buildTextField(label: "기타부", hint: "..."),
    InputHelpers.buildTextField(label: "특기사항", hint: "..."),
  ],
)
```

### 4. EmptyStateContainer - 빈 상태

```dart
EmptyStateContainer(
  message: "데이터가 없습니다.",
  icon: Icons.folder_open,
)
```

### 5. InfoContainer - 정보 표시

```dart
InfoContainer(
  message: "예측 결과가 없습니다. 생성 버튼을 눌러 예측하세요.",
  icon: Icons.info_outline,
)
```

## 📝 전체 예시

### 조사자 의견 섹션

```dart
SectionCard(
  title: "조사자 의견",
  action: SectionButton.filled(
    label: "저장",
    onPressed: _handleSave,
    icon: Icons.save,
  ),
  child: InputHelpers.fieldGroup(
    children: [
      InputHelpers.buildTextField(
        label: "구조부",
        hint: "예: 균열, 변형 등의 구조적 손상 평가",
        controller: _structuralController,
        maxLines: 2,
      ),
      InputHelpers.buildTextField(
        label: "기타부",
        hint: "예: 비구조적 손상, 오염, 마감재 상태 등",
        controller: _othersController,
        maxLines: 2,
      ),
      InputHelpers.buildTextField(
        label: "특기사항",
        hint: "예: 긴급 보수 필요 부위, 비고 사항 등",
        controller: _notesController,
        maxLines: 2,
      ),
      InputHelpers.buildTextField(
        label: "조사자 종합의견",
        hint: "전체 평가 및 개선 제안",
        controller: _opinionController,
        maxLines: 4,
      ),
    ],
  ),
)
```

### AI 예측 기능 섹션

```dart
SectionCard(
  title: "AI 예측 기능",
  child: Column(
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SectionButton.filled(
            label: "AI 손상등급 예측",
            onPressed: _predictGrade,
            icon: Icons.auto_graph,
          ),
          SectionButton.outlined(
            label: "손상지도 생성",
            onPressed: _generateMap,
            icon: Icons.map,
          ),
          SectionButton.outlined(
            label: "기후변화 대응",
            onPressed: _suggestMitigation,
            icon: Icons.cloud,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_hasPrediction)
        InfoContainer(
          message: "예측 등급: A",
          icon: Icons.check_circle,
          color: Colors.green.shade50,
        )
      else
        InfoContainer(
          message: "예측 결과가 없습니다. 생성 버튼을 눌러 예측하세요.",
          icon: Icons.explore_off,
        ),
    ],
  ),
)
```

### 손상부 조사 섹션

```dart
SectionCard(
  title: "손상부 조사",
  action: SectionButtonGroup(
    buttons: [
      SectionButton.outlined(
        label: "조사 등록",
        onPressed: _addSurvey,
        icon: Icons.add,
      ),
      SectionButton.filled(
        label: "심화조사",
        onPressed: _deepInspection,
        icon: Icons.assignment,
      ),
    ],
  ),
  child: _surveys.isEmpty
      ? EmptyStateContainer(
          message: "등록된 손상부 조사가 없습니다.",
          icon: Icons.folder_open,
        )
      : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _surveys.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(_surveys[index].title),
              trailing: SectionButton.icon(
                iconData: Icons.delete,
                onPressed: () => _deleteSurvey(index),
                tooltip: "삭제",
              ),
            );
          },
        ),
)
```

## 🎨 색상 커스터마이징

```dart
SectionCard(
  title: "경고 섹션",
  backgroundColor: Colors.orange.shade50,
  child: InfoContainer(
    message: "주의가 필요합니다.",
    icon: Icons.warning,
    color: Colors.orange.shade100,
  ),
)

SectionButton.filled(
  label: "삭제",
  onPressed: () {},
  backgroundColor: Colors.red,
  icon: Icons.delete,
)
```

## 📐 레이아웃 조정

```dart
SectionCard(
  title: "커스텀 섹션",
  padding: EdgeInsets.all(24), // 내부 여백
  margin: EdgeInsets.symmetric(vertical: 16), // 외부 여백
  hasShadow: false, // 그림자 제거
  child: ...,
)
```
