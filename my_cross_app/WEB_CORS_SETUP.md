# 웹 CORS 문제 해결 가이드

## 문제 상황
Flutter 웹 앱에서 원격 서버(210.117.181.115:8080)의 FastAPI에 직접 요청할 때 CORS 오류가 발생합니다.

## 해결 방법

### 1. 프록시 서버 설치 및 실행

```bash
# Node.js 의존성 설치
npm install

# 프록시 서버 실행
npm start
```

### 2. Flutter 웹 앱 빌드 및 실행

```bash
# Flutter 웹 앱 빌드
flutter build web

# 프록시 서버가 실행 중이면 자동으로 Flutter 앱이 http://localhost:3000에서 실행됩니다
```

### 3. 개발 모드에서 실행

```bash
# 터미널 1: 프록시 서버 실행
npm start

# 터미널 2: Flutter 웹 앱 실행
flutter run -d chrome
```

## 작동 원리

1. **프록시 서버**: `http://localhost:3000`에서 실행
2. **API 요청**: Flutter 웹 앱 → `http://localhost:3000/api/*` → `http://210.117.181.115:8080/*`
3. **CORS 해결**: 프록시 서버가 CORS 헤더를 추가하여 브라우저 제한 우회

## 파일 구조

```
my_cross_app/
├── cors_proxy.js          # CORS 프록시 서버
├── package.json           # Node.js 의존성
├── lib/core/config/env.dart # 환경 설정 (웹에서 프록시 사용)
└── WEB_CORS_SETUP.md      # 이 가이드
```

## 주의사항

- 프록시 서버는 개발 환경에서만 사용하세요
- 프로덕션 배포 시에는 서버 측에서 CORS를 올바르게 설정해야 합니다
- 프록시 서버가 실행되지 않으면 API 요청이 실패합니다

## 대안 방법

서버 측에서 CORS를 허용하도록 FastAPI 설정을 수정할 수도 있습니다:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 또는 특정 도메인
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```
