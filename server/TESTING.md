# Damage Inference API 테스트 가이드

## 1. 서버 시작

```bash
cd server
uvicorn main:app --reload
```

서버가 정상적으로 시작되면 다음과 같은 메시지가 표시됩니다:

```
[Damage Inference] 모델 로드 중...
[Damage Inference] Device: cuda (또는 cpu)
[Damage Inference] 모델 파일: /path/to/best_model.pth
[Damage Inference] ✅ 모델 로드 완료
```

## 2. API 테스트

### 2.1 Health Check

```bash
curl http://localhost:8080/health
```

예상 응답:
```json
{"status":"ok","service":"Heritage Services API"}
```

### 2.2 Damage Inference (이미지 업로드)

```bash
curl -X POST "http://localhost:8080/ai/damage/infer" \
  -F "image=@/path/to/test_image.jpg"
```

예상 응답:
```json
{
  "detections": [
    {
      "label_id": 0,
      "label": "갈램",
      "score": 0.85,
      "x": 0.35,
      "y": 0.25,
      "w": 0.20,
      "h": 0.15
    },
    {
      "label_id": 1,
      "label": "균열",
      "score": 0.72,
      "x": 0.60,
      "y": 0.40,
      "w": 0.15,
      "h": 0.10
    }
  ]
}
```

### 2.3 손상이 없는 경우

손상이 탐지되지 않으면 빈 배열을 반환합니다:

```json
{
  "detections": []
}
```

## 3. Python으로 테스트

```python
import requests

# 이미지 파일 업로드
with open("test_image.jpg", "rb") as f:
    files = {"image": f}
    response = requests.post(
        "http://localhost:8080/ai/damage/infer",
        files=files
    )

result = response.json()
print(f"탐지된 객체 수: {len(result['detections'])}")
for det in result['detections']:
    print(f"  - {det['label']}: {det['score']:.2f} at ({det['x']:.2f}, {det['y']:.2f})")
```

## 4. 에러 처리

### 모델이 로드되지 않은 경우

```json
{
  "detail": "Model inference failed: 모델이 로드되지 않았습니다. 서버 로그를 확인하세요."
}
```

### 잘못된 이미지 파일

```json
{
  "detail": "Invalid image file: ..."
}
```

## 5. 응답 형식

각 detection 객체는 다음 필드를 포함합니다:

- `label_id`: int (0-3)
  - 0: 갈램
  - 1: 균열
  - 2: 부후
  - 3: 압괴/터짐

- `label`: str (한글 이름)
- `score`: float (0.0-1.0, 신뢰도)
- `x`: float (0.0-1.0, 정규화된 중심 x 좌표)
- `y`: float (0.0-1.0, 정규화된 중심 y 좌표)
- `w`: float (0.0-1.0, 정규화된 너비)
- `h`: float (0.0-1.0, 정규화된 높이)

## 6. CORS 확인

Flutter 웹 앱에서 사용하려면 CORS 설정이 올바른지 확인하세요:

```bash
curl -X OPTIONS "http://localhost:8080/ai/damage/infer" \
  -H "Origin: http://localhost:3001" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

## 7. 모델 파일 위치

모델 파일은 다음 위치 중 하나에 있어야 합니다:

1. `server/ai/best_model.pth` (기본값)
2. `server/hanok_damage_model_1108/best_model.pth`
3. 환경변수 `MODEL_PATH`로 지정한 경로

환경변수로 지정:
```bash
export MODEL_PATH="/absolute/path/to/best_model.pth"
uvicorn main:app --reload
```

