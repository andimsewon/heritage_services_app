# AI 모델 파일 설정 가이드

## 📁 모델 파일 위치

AI 모델 파일(`.pth` 또는 `.pt`)을 다음 위치 중 하나에 배치하세요:

### 방법 1: 기본 위치 (권장)
```
server/ai/hanok_damage_model.pth
또는
server/ai/hanok_damage_model.pt
```

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
2. **`server/ai/` 디렉토리**의 `.pth` 또는 `.pt` 파일
3. **기본 파일명**: `hanok_damage_model.pt` 또는 `hanok_damage_model.pth`

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
# 모델 파일을 server/ai/ 디렉토리에 복사
cp /path/to/best_model.pth server/ai/hanok_damage_model.pth

# 서버 실행
cd server
python main.py
```

### 예시 2: 환경변수로 모델 경로 지정
```bash
# 단일 파일
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

