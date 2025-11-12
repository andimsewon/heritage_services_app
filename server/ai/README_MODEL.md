# AI 모델 파일 설정 가이드

## 🤖 모델 동작 로직

### 입력 데이터
- **이미지 파일**: JPG, PNG 등 일반적인 이미지 형식
- **형식**: 바이트 데이터로 전달 (HTTP POST 요청의 multipart/form-data)

### 처리 파이프라인

#### 1️⃣ 이미지 전처리
```
이미지 바이트 → PIL Image (RGB) → DetaImageProcessor
```
- 이미지를 RGB 형식으로 변환
- `DetaImageProcessor`를 사용하여 모델 입력 형식으로 전처리
- 출력: `pixel_values` 텐서 (배치 차원 포함)

#### 2️⃣ 객체 탐지 추론
```
pixel_values → CustomDeta 모델 → 객체 탐지 결과
```
- **모델 아키텍처**: DETA (Detection Transformer) 기반
- **백본**: ResNet-50
- **작업**: 한옥 손상 영역 탐지 (객체 탐지)
- **출력 클래스**: 4가지 손상 유형
  - `0`: 갈램
  - `1`: 균열
  - `2`: 부후
  - `3`: 압괴/터짐

#### 3️⃣ 후처리 (Post-processing)

**3-1. 초기 필터링**
- 낮은 신뢰도 threshold (0.05)로 후보 탐지 결과 추출
- `processor.post_process_object_detection()` 사용

**3-2. 클래스별 Threshold 적용**
각 손상 유형별로 다른 신뢰도 기준을 적용합니다:
```python
CLASS_THRESHOLDS = {
    0: 0.30,  # 갈램
    1: 0.25,  # 균열
    2: 0.15,  # 부후
    3: 0.25,  # 압괴/터짐
}
```

**3-3. NMS (Non-Maximum Suppression)**
- 중복 탐지 제거
- IoU (Intersection over Union) threshold: **0.1**
- 클래스별로 독립적으로 NMS 적용

#### 4️⃣ 결과 생성

**탐지 결과 구조:**
```json
{
  "detections": [
    {
      "label": "균열",           // 한글 레이블
      "label_id": 1,              // 클래스 ID
      "score": 0.85,              // 신뢰도 (0~1)
      "bbox": [x1, y1, x2, y2]    // 바운딩 박스 좌표
    }
  ],
  "count": 3,                     // 탐지된 객체 수
  "grade": "C2",                  // 손상 등급 (A, B, C1, C2, D)
  "explanation": "균열 손상이 명확히 관찰됩니다..."  // 등급 설명
}
```

**손상 등급 산정 기준:**
- **A**: 신뢰도 < 0.5 또는 탐지 없음 → "이상 징후 거의 없음"
- **B**: 0.5 ≤ 신뢰도 < 0.6 → "손상 의심, 지속적 관찰 필요"
- **C1**: 0.6 ≤ 신뢰도 < 0.75 → "경미한 손상, 정기적 관찰 필요"
- **C2**: 0.75 ≤ 신뢰도 < 0.85 → "명확한 손상, 모니터링 및 예방 조치 필요"
- **D**: 신뢰도 ≥ 0.85 → "심각한 손상, 즉시 보수 필요"

### 전체 흐름도
```
[이미지 파일]
    ↓
[PIL Image 변환]
    ↓
[DetaImageProcessor 전처리]
    ↓
[CustomDeta 모델 추론]
    ↓
[초기 필터링 (threshold=0.05)]
    ↓
[클래스별 Threshold 적용]
    ↓
[NMS 적용 (IoU=0.1)]
    ↓
[결과 파싱 및 등급 산정]
    ↓
[JSON 응답 반환]
```

## 📁 모델 파일 위치

AI 모델 파일(`.pth` 또는 `.pt`)을 다음 위치 중 하나에 배치하세요:

### 방법 1: 기본 위치 (권장)
```
server/ai/hanok_damage_model.pth
또는
server/ai/hanok_damage_model.pt
```

> `hanok_damage_model.*` 파일명이 기본 모델 파일로 우선 선택됩니다. `best_model.*` 파일도 대체 경로로 자동 탐색합니다.

### 방법 2: 환경변수로 경로 지정
```bash
export MODEL_PATH="/path/to/your/model.pth"
# 또는 폴더 경로 지정 (자동으로 best 모델 선택)
export MODEL_PATH="/path/to/model/folder"
```

### 방법 3: 폴더 경로 지정 (자동 best 모델 선택)
모델 폴더를 지정하면 `best_map`이 가장 높은 모델을 자동으로 선택합니다:
```bash
export MODEL_PATH="/path/to/hanok_damage_model_1108"
```

## 🔍 모델 파일 자동 검색

다음 순서로 모델 파일을 자동으로 찾습니다:

1. **환경변수 `MODEL_PATH`** (파일 또는 폴더 경로)
2. **`server/ai/` 디렉토리의 `hanok_damage_model.pth` / `hanok_damage_model.pt`** (기본 모델 파일, 우선순위 1)
3. **`server/ai/` 디렉토리의 `best_model.pth` / `best_model.pt`** (대체 경로)
4. **그 외 `server/ai/`의 `.pth` 또는 `.pt` 파일** 가운데 가장 최근 파일

## 📋 모델 파일 형식

모델 파일은 다음 형식을 따라야 합니다:

```python
{
    'model_state_dict': {...},  # 모델 가중치
    'epoch': int,                # 학습 epoch (선택)
    'best_map': float,           # 최고 mAP 점수 (선택)
    'num_classes': int,         # 클래스 수 (선택, 기본값: 4)
    'id2label': {                # 레이블 매핑 (선택)
        0: 'LABEL_0',
        1: 'LABEL_1',
        2: 'LABEL_2',
        3: 'LABEL_3'
    }
}
```

## 🚀 사용 예시

### 예시 1: 기본 위치에 모델 파일 배치
```bash
# 모델 파일을 server/ai/ 디렉토리에 복사 (기본 파일명 사용)
cp /path/to/model.pth server/ai/hanok_damage_model.pth

# 또는 best_model.pth로도 사용 가능 (대체 경로)
cp /path/to/model.pth server/ai/best_model.pth

# 서버 실행
cd server
python main.py
```

### 예시 2: 환경변수로 모델 경로 지정
```bash
# 단일 파일
export MODEL_PATH="/home/user/models/hanok_damage_model.pth"
python main.py

# 또는 다른 파일명
export MODEL_PATH="/home/user/models/best_model.pth"
python main.py

# 폴더 경로 (자동으로 best 모델 선택)
export MODEL_PATH="/home/user/models/hanok_damage_model_1108"
python main.py
```

### 예시 3: Docker 사용 시
```bash
# docker-compose.yml 또는 Dockerfile에서
ENV MODEL_PATH=/app/models/best_model.pth

# 또는 볼륨 마운트
docker run -v /path/to/models:/app/models -e MODEL_PATH=/app/models/best_model.pth ...
```

## ✅ 모델 로드 확인

서버 시작 시 다음 메시지가 표시되면 성공입니다:

```
[AI] ✅ 모델 로드 성공!
[AI]    클래스 수: 4개
[AI]    레이블: {0: 'LABEL_0', 1: 'LABEL_1', 2: 'LABEL_2', 3: 'LABEL_3'}
[AI]    Epoch: 50
[AI]    Best mAP: 0.8523
```

## 🐛 문제 해결

### 모델 파일을 찾을 수 없음
```
[AI] ❌ 모델 파일을 찾을 수 없습니다!
```

**해결 방법:**
1. 모델 파일이 `server/ai/` 디렉토리에 있는지 확인
2. 파일 확장자가 `.pth` 또는 `.pt`인지 확인
3. 환경변수 `MODEL_PATH`가 올바르게 설정되었는지 확인

### 모델 로드 실패
```
[AI] ❌ 모델 로드 실패: ...
```

**해결 방법:**
1. 모델 파일이 손상되지 않았는지 확인
2. PyTorch 버전 호환성 확인
3. 서버 로그의 전체 에러 메시지 확인

## 📝 참고

- 노트북(`visualize_test (2).ipynb`)에서 사용하는 모델 파일 형식과 동일하게 지원합니다
- 폴더 경로를 지정하면 노트북과 동일한 방식으로 `best_map`이 가장 높은 모델을 자동 선택합니다
- `.pth`와 `.pt` 확장자 모두 지원합니다

