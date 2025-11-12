# 📁 프로젝트 구조

Heritage Services App의 최종 정리된 구조

---

## 🎯 전체 구조

```
heritage_services_app/
├── 📄 README.md                       # 프로젝트 개요
├── 📄 QUICKSTART.md                   # 3분 빠른 시작 가이드 ⭐
├── 📄 DOCKER_DEPLOYMENT.md            # Docker 상세 배포 가이드
├── 📄 PROJECT_STRUCTURE.md            # 이 파일
│
├── 🐳 docker-compose.yml              # Docker Compose 설정
│
├── 📱 my_cross_app/                   # Flutter 크로스플랫폼 앱
│   ├── lib/
│   │   ├── app/                      # HeritageApp + 전역 라우터
│   │   ├── core/                     # config, services, 공용 UI/위젯
│   │   ├── features/                 # 화면·위젯·서비스 (흐름 기준 모듈)
│   │   ├── models/                   # 데이터 모델
│   │   ├── utils/                    # 포맷터/헬퍼
│   │   └── main.dart                 # 앱 진입점
│   ├── pubspec.yaml                   # Flutter 의존성
│   ├── android/                       # 안드로이드 빌드
│   ├── ios/                           # iOS 빌드
│   ├── web/                           # 웹 빌드
│   └── linux/                         # Linux 빌드
│
└── 🖥️ server/                         # FastAPI 백엔드 서버
    ├── 📄 README.md                   # 서버 API 문서
    ├── 🐳 Dockerfile                  # Docker 이미지 빌드
    ├── 🚫 .dockerignore               # Docker 빌드 제외 파일
    ├── 📜 requirements.txt            # Python 의존성
    ├── 🚀 run_server.sh              # 서버 실행 스크립트
    ├── 🎯 main.py                     # FastAPI 앱 진입점
    ├── 📋 main.py.backup              # 이전 버전 백업
    │
    ├── 🏛️ heritage/                   # 국가유산 API 모듈
    │   ├── __init__.py
    │   ├── router.py                  # /heritage/* 라우트
    │   ├── service.py                 # 비즈니스 로직
    │   └── utils.py                   # XML 파싱 유틸
    │
    ├── 🤖 ai/                          # AI 손상 탐지 모듈
    │   ├── __init__.py
    │   ├── router.py                  # /ai/* 라우트
    │   ├── model.py                   # CustomDeta 모델
    │   ├── service.py                 # 추론 로직
    │   ├── loader.py                  # 모델 로딩 관리
    │   └── hanok_damage_model.pth      # 🎓 PyTorch 모델 (552MB) ✅
    │
    ├── ⚙️ common/                      # 공통 모듈
    │   ├── __init__.py
    │   ├── config.py                  # 환경 설정
    │   └── middleware.py              # CORS 미들웨어
    │
    ├── 📊 data/                        # 학습 데이터 (선택)
    │   ├── train.json                 # 훈련 데이터셋
    │   ├── val.json                   # 검증 데이터셋
    │   ├── test.json                  # 테스트 데이터셋
    │   ├── result.json                # 처리 결과
    │   ├── remapped_result.json       # 리맵핑 결과
    │   ├── resized_result.json        # 리사이즈 결과
    │   └── images/                    # 이미지 파일들
    │
    └── 🖼️ images/                      # 추가 이미지 리소스
```

---

## ✅ 정리 완료된 사항

### 1. 불필요한 파일 제거
- ❌ `/services/` 폴더 (빈 폴더) → 삭제
- ❌ `server/app.py` (사용 안 함) → 삭제
- ❌ `server/run_server.py` (중복) → 삭제
- ❌ `server/__pycache__/` (캐시) → 삭제

### 2. 파일 정리
- ✅ 학습 데이터 JSON 파일들 → `server/data/` 폴더로 이동
- ✅ AI 모델 파일 → `server/ai/hanok_damage_model.pth` (552MB)
- ✅ 모든 코드 모듈화 완료

### 3. 추가된 문서
- ✅ `QUICKSTART.md` - 빠른 시작 가이드
- ✅ `DOCKER_DEPLOYMENT.md` - Docker 배포 상세 가이드
- ✅ `PROJECT_STRUCTURE.md` - 프로젝트 구조 문서
- ✅ `server/README.md` - 서버 API 문서

---

## 📦 핵심 파일 설명

### Backend (Server)

| 파일 | 역할 | 필수 여부 |
|------|------|-----------|
| `main.py` | FastAPI 앱 진입점, 라우터 통합 | ✅ 필수 |
| `Dockerfile` | Docker 이미지 빌드 설정 | ✅ 필수 |
| `requirements.txt` | Python 의존성 목록 | ✅ 필수 |
| `run_server.sh` | 서버 실행 스크립트 | ⭐ 권장 |
| | |
| `heritage/router.py` | 국가유산 API 라우트 | ✅ 필수 |
| `heritage/service.py` | 국가유산 비즈니스 로직 | ✅ 필수 |
| `heritage/utils.py` | XML 파싱 유틸 | ✅ 필수 |
| | |
| `ai/router.py` | AI API 라우트 | ✅ 필수 |
| `ai/model.py` | CustomDeta 모델 정의 | ✅ 필수 |
| `ai/service.py` | 이미지 추론 로직 | ✅ 필수 |
| `ai/loader.py` | 모델 로딩 관리 | ✅ 필수 |
| `ai/hanok_damage_model.pth` | PyTorch 모델 (552MB) | ✅ 필수 |
| | |
| `common/config.py` | 환경 설정 (CORS, 포트) | ✅ 필수 |
| `common/middleware.py` | CORS 미들웨어 | ✅ 필수 |
| | |
| `data/*.json` | 학습 데이터 (개발용) | ❌ 선택 |
| `images/` | 이미지 리소스 | ❌ 선택 |

### Frontend (Flutter)

| 파일 | 역할 | 필수 여부 |
|------|------|-----------|
| `lib/main.dart` | Flutter 앱 진입점 | ✅ 필수 |
| `lib/app/` | HeritageApp + 라우터 | ✅ 필수 |
| `lib/core/` | Env, 공용 서비스/위젯 | ✅ 필수 |
| `lib/features/` | 화면 · 위젯 · 도메인 로직 모듈 | ✅ 필수 |
| `pubspec.yaml` | Flutter 의존성 | ✅ 필수 |

### Docker

| 파일 | 역할 | 필수 여부 |
|------|------|-----------|
| `docker-compose.yml` | Docker 컨테이너 설정 | ✅ 필수 |
| `server/Dockerfile` | 이미지 빌드 명령 | ✅ 필수 |
| `server/.dockerignore` | 빌드 제외 파일 | ⭐ 권장 |

---

## 🔍 모듈별 상세 구조

### Heritage 모듈 (국가유산 API)
```
heritage/
├── __init__.py          # 모듈 초기화
├── router.py            # 엔드포인트 정의
│   ├── GET /list        # 유산 목록 조회
│   └── GET /detail      # 유산 상세 정보
├── service.py           # 비즈니스 로직
│   ├── fetch_heritage_list()
│   └── fetch_heritage_detail()
└── utils.py             # 유틸 함수
    ├── pick()           # 딕셔너리 안전 추출
    ├── first_non_empty() # 첫 비어있지 않은 값
    └── extract_items()  # XML 아이템 추출
```

### AI 모듈 (손상 탐지)
```
ai/
├── __init__.py          # 모듈 초기화
├── router.py            # 엔드포인트 정의
│   ├── GET /model/status    # 모델 상태
│   └── POST /damage/infer   # 손상 탐지
├── model.py             # CustomDeta 클래스
├── service.py           # 추론 로직
│   └── detect_damage()  # 이미지 손상 분석
├── loader.py            # 모델 관리
│   ├── load_ai_model()  # 모델 로딩
│   ├── get_model()      # 모델 반환
│   └── is_model_loaded() # 로딩 상태
└── hanok_damage_model.pth # PyTorch 체크포인트
```

### Common 모듈 (공통)
```
common/
├── __init__.py          # 모듈 초기화
├── config.py            # Settings 클래스
│   ├── APP_TITLE, APP_VERSION
│   ├── CORS_ORIGINS
│   ├── HOST, PORT
│   └── KHS_BASE_URL
└── middleware.py        # 미들웨어 설정
    └── setup_middleware() # CORS 추가
```

---

## 🚀 실행 방법

### 1. Docker로 실행 (추천)
```bash
cd /home/dbs0510/heritage_services_app

# 서버 시작
docker-compose up -d

# Flutter 실행
cd my_cross_app
flutter run -d chrome
```

### 2. 직접 실행 (개발 모드)
```bash
# 백엔드
cd server
./run_server.sh

# Flutter (새 터미널)
cd my_cross_app
flutter run -d chrome
```

---

## 📊 코드 통계

### Backend (Server)
- **총 Python 파일**: 10개
- **총 라인 수**: ~150줄 (모듈화 전 282줄에서 개선)
- **모듈**: 3개 (heritage, ai, common)
- **엔드포인트**: 6개

### Frontend (Flutter)
- **총 Dart 파일**: 20+개
- **화면**: 7개
- **서비스**: 5개
- **위젯**: 3개

---

## 🎯 다음 단계 (선택)

### 코드 개선
- [ ] 단위 테스트 추가 (pytest, flutter test)
- [ ] API 인증 구현 (JWT)
- [ ] 로깅 시스템 추가
- [ ] 에러 핸들링 강화

### 배포
- [ ] CI/CD 파이프라인 (GitHub Actions)
- [ ] Kubernetes 배포
- [ ] 프로덕션 환경 설정
- [ ] 모니터링 (Prometheus, Grafana)

### 기능 추가
- [ ] 5-7번 화면 완성
- [ ] 실시간 협업 기능
- [ ] 오프라인 모드 지원
- [ ] 다국어 지원

---

## 📞 참고 문서

- [빠른 시작](QUICKSTART.md)
- [Docker 배포](DOCKER_DEPLOYMENT.md)
- [서버 API](server/README.md)
- [Swagger UI](http://localhost:8080/docs)
