# Heritage Services API Server

국가유산 관리 및 AI 손상 탐지 통합 서버 (리팩토링 버전)

## 📂 프로젝트 구조

```
server/
├── main.py                      # FastAPI 앱 진입점
├── requirements.txt             # Python 의존성
├── run_server.sh               # 서버 실행 스크립트
│
├── heritage/                    # 국가유산 API 모듈
│   ├── __init__.py
│   ├── router.py               # /heritage/* 라우트
│   ├── service.py              # 비즈니스 로직
│   └── utils.py                # XML 파싱 유틸
│
├── ai/                          # AI 손상 탐지 모듈
│   ├── __init__.py
│   ├── router.py               # /ai/* 라우트
│   ├── model.py                # CustomDeta 모델
│   ├── service.py              # 추론 로직
│   ├── loader.py               # 모델 로딩 관리
│   └── hanok_damage_model.pt   # PyTorch 모델 (552MB)
│
└── common/                      # 공통 모듈
    ├── __init__.py
    ├── config.py               # 설정 관리
    └── middleware.py           # CORS 등 미들웨어
```

## 🚀 설치 및 실행

### 1. 의존성 설치

```bash
pip install -r requirements.txt
```

### 2. 서버 실행

#### 방법 1: 스크립트 사용 (권장)
```bash
./run_server.sh
```

#### 방법 2: 직접 실행
```bash
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

#### 방법 3: Python으로 실행
```bash
python3 main.py
```

### 3. API 문서 확인

서버 실행 후 브라우저에서 다음 주소로 접속:

- **Swagger UI**: http://localhost:8080/docs
- **ReDoc**: http://localhost:8080/redoc

## 📡 API 엔드포인트

### 🏛️ Heritage API (국가유산 API)

#### 1. 유산 목록 조회
```http
GET /heritage/list?keyword={유산명}&kind={종목코드}&region={지역코드}&page=1&size=20
```

**예시:**
```bash
curl "http://localhost:8080/heritage/list?keyword=불국사&page=1&size=10"
```

#### 2. 유산 상세 정보
```http
GET /heritage/detail?ccbaKdcd={종목코드}&ccbaAsno={지정번호}&ccbaCtcd={시도코드}
```

**예시:**
```bash
curl "http://localhost:8080/heritage/detail?ccbaKdcd=11&ccbaAsno=00010000&ccbaCtcd=27"
```

### 🤖 AI Detection API (손상 탐지)

#### 1. 모델 상태 확인
```http
GET /ai/model/status
```

**응답 예시:**
```json
{
  "status": "loaded",
  "available": true,
  "labels": {
    "0": "균열",
    "1": "박락",
    "2": "부식"
  },
  "num_classes": 3,
  "device": "cpu"
}
```

#### 2. 손상 탐지 (이미지 업로드)
```http
POST /ai/damage/infer
Content-Type: multipart/form-data
```

**예시 (curl):**
```bash
curl -X POST "http://localhost:8080/ai/damage/infer" \
  -F "image=@/path/to/image.jpg"
```

**응답 예시:**
```json
{
  "detections": [
    {
      "label": "균열",
      "score": 0.95,
      "bbox": [120.5, 230.8, 450.2, 380.6]
    }
  ],
  "count": 1
}
```

### ⚙️ 기타

#### Health Check
```http
GET /health
```

#### 서비스 정보
```http
GET /
```

## 🔧 환경 설정

### 환경 변수

`common/config.py`에서 설정을 변경하거나, 환경 변수로 오버라이드할 수 있습니다:

```bash
# 서버 호스트/포트
export HOST=0.0.0.0
export PORT=8080

# 개발 모드 (코드 변경 시 자동 재시작)
export RELOAD=true
```

### CORS 설정

프로덕션 환경에서는 `common/config.py`에서 `CORS_ORIGINS`를 특정 도메인으로 제한하세요:

```python
CORS_ORIGINS: List[str] = [
    "http://localhost:3000",
    "https://your-frontend-domain.com"
]
```

## 🧪 테스트

### Heritage API 테스트
```bash
# 목록 조회
curl "http://localhost:8080/heritage/list?keyword=석굴암&page=1&size=5"

# 상세 정보
curl "http://localhost:8080/heritage/detail?ccbaKdcd=11&ccbaAsno=00240000&ccbaCtcd=27"
```

### AI API 테스트
```bash
# 모델 상태
curl "http://localhost:8080/ai/model/status"

# 이미지 추론 (예시)
curl -X POST "http://localhost:8080/ai/damage/infer" \
  -F "image=@test_image.jpg"
```

## 📝 아키텍처 개선 사항

### 이전 구조 (단일 파일)
```
server/
└── main.py  (282 lines, 모든 기능 포함)
```

### 현재 구조 (모듈화)
```
server/
├── main.py              (통합 진입점, ~90 lines)
├── heritage/            (국가유산 API 독립 모듈)
├── ai/                  (AI 탐지 독립 모듈)
└── common/              (공통 설정/미들웨어)
```

### 장점
- ✅ **관심사 분리**: 각 기능이 독립적인 모듈로 관리
- ✅ **유지보수성**: 코드 변경 시 영향 범위 최소화
- ✅ **확장성**: 새로운 기능 추가 용이
- ✅ **테스트 용이성**: 모듈별 단위 테스트 가능
- ✅ **협업**: 팀원이 독립적으로 모듈 작업 가능

## 🚦 프로덕션 배포

### Docker 배포 (추천)
```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Systemd 서비스 등록
```ini
[Unit]
Description=Heritage Services API
After=network.target

[Service]
User=www-data
WorkingDirectory=/path/to/server
ExecStart=/usr/bin/uvicorn main:app --host 0.0.0.0 --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
```

## 📚 추가 리소스

- FastAPI 공식 문서: https://fastapi.tiangolo.com/
- Transformers 문서: https://huggingface.co/docs/transformers/
- DETA 모델: https://huggingface.co/jozhang97/deta-resnet-50

## ⚠️ 주의사항

1. **모델 파일**: `ai/hanok_damage_model.pt` (552MB)가 반드시 있어야 AI 기능 동작
2. **메모리**: AI 모델 로딩 시 최소 1GB RAM 필요
3. **CORS**: 프로덕션 환경에서는 반드시 특정 도메인으로 제한
4. **인증**: 현재 인증 없음. 프로덕션에서는 JWT/OAuth 등 추가 필요

## 🐛 트러블슈팅

### AI 모델 로드 실패
```bash
# 모델 파일 경로 확인
ls -lh ai/hanok_damage_model.pt

# Python 경로 문제 시
export PYTHONPATH="${PYTHONPATH}:/home/dbs0510/heritage_services_app/server"
```

### 포트 이미 사용 중
```bash
# 8080 포트 사용 중인 프로세스 확인
lsof -i :8080

# 또는 다른 포트 사용
uvicorn main:app --port 8081
```

## 📞 문의

문제 발생 시 GitHub Issues에 등록해주세요.
