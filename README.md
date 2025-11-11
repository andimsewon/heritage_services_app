# 국가유산 모니터링 조사·등록 시스템 (Flutter + FastAPI)

국가유산청 Open API를 바탕으로 **현장 조사·등록 업무**를 돕는 크로스플랫폼 앱입니다.
클라이언트는 **Flutter**, 외부 XML API를 브라우저/앱에서 안전하게 쓰기 위해 **FastAPI 프록시**를 둔 구조입니다.

> 현재 구현 핵심
>
> * ② 홈 화면
> * ③ **국가 유산 검색**(종목/지역/조건) + 표 4열(종목/유산명/소재지/주소)
> * ④ **기본개요 상세**(국가유산청 상세 API 기반)
> * ⑤\~⑦ 화면 골격/라우팅 구성

---

## 🔧 개발 환경(권장 버전)

* **OS**: macOS 13+ / Windows 10+ (개발은 macOS 기준 예시)
* **Flutter**: `3.35.1`

  * **Dart**: `3.9.0`
  * Android Studio: `2025.1` (Flutter/Dart 플러그인 설치)
  * Xcode (iOS 필요 시): 최신 / CocoaPods 설치
* **Python**: `3.10+`

  * FastAPI, Uvicorn, httpx, xmltodict

> 확인:
> `flutter doctor -v` 로 Flutter/Chrome/Android 장치가 보여야 함.

---

## 📦 리포 구조

```
heritage_services_app/
├─ my_cross_app/                 # Flutter 앱
│  ├─ lib/
│  │  ├─ app/                    # HeritageApp, Router
│  │  ├─ core/                   # Env, shared services & widgets
│  │  ├─ features/               # 흐름별 화면/위젯/로직 (auth, heritage 등)
│  │  ├─ models/                 # 공통 데이터 모델
│  │  ├─ utils/                  # 날짜 포맷 등 헬퍼
│  │  └─ main.dart               # 앱 진입점
│  ├─ pubspec.yaml
│  └─ (android/ ios/ web/ 등 Flutter 표준)
└─ server/                      # FastAPI 프록시 (XML→JSON, CORS 해결)
   └─ main.py
```

아키텍처 개요:

```
Flutter(Web/Android/iOS)  ──(HTTP, PROXY_BASE)──▶  FastAPI(127.0.0.1:8080)
                                             └──▶  국가유산청 Open API(XML)
```

---


## 🚀 서버 실행 방법

### 1. 사전 요구사항

- Python 3.9 이상
- pip (Python 패키지 관리자)

### 2. 의존성 설치

```bash
# server 디렉토리로 이동
cd server

# 필요한 패키지 설치
python3 -m pip install -r requirements.txt
```

### 3. 서버 실행

```bash
# FastAPI 서버 실행 (개발 모드)
python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

### 4. 서버 상태 확인

서버가 정상적으로 실행되었는지 확인:

```bash
# Health check API 호출
curl http://localhost:8080/health
```

정상 응답:
```json
{"ok": true}
```

## 📡 API 엔드포인트

### 기본 정보
- **서버 주소**: `http://localhost:8080`
- **API 문서**: `http://localhost:8080/docs` (Swagger UI)
- **ReDoc 문서**: `http://localhost:8080/redoc`

### 주요 API

#### 1. Health Check
```bash
GET /health
```

#### 2. 문화재 목록 조회
```bash
GET /heritage/list?keyword=불국사&page=1&size=20
```

#### 3. 문화재 상세 정보
```bash
GET /heritage/detail?ccbaKdcd=11&ccbaAsno=1&ccbaCtcd=11
```

#### 4. AI 모델 상태 확인
```bash
GET /ai/model/status
```

#### 5. AI 손상 탐지
```bash
POST /ai/damage/infer
Content-Type: multipart/form-data
```

## 🔧 설정

### CORS 설정
서버는 모든 Origin에서의 요청을 허용하도록 설정되어 있습니다:
- `allow_origins=["*"]`
- `allow_methods=["*"]`
- `allow_headers=["*"]`

### AI 모델
- 모델 파일: `hanok_damage_model.pt`
- 모델이 없어도 서버는 정상 실행되며, AI 기능만 비활성화됩니다.

## 🐛 문제 해결

### 1. 포트 충돌
```bash
# 8080 포트가 사용 중인 경우 다른 포트 사용
python3 -m uvicorn main:app --host 0.0.0.0 --port 8081 --reload
```

### 2. 의존성 설치 오류
```bash
# pip 업그레이드
python3 -m pip install --upgrade pip

# 가상환경 사용 권장
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 또는
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

### 3. 권한 오류
```bash
# 사용자 설치 디렉토리 사용
python3 -m pip install --user -r requirements.txt
```

## 📱 Flutter 앱 연결

Flutter 앱에서 이 서버를 사용하려면:

1. **로컬 개발**: `http://localhost:8080`
2. **Android 에뮬레이터**: `http://10.0.2.2:8080`
3. **웹**: `http://localhost:8080` (CORS 설정됨)

## 🔄 개발 모드

`--reload` 옵션으로 코드 변경 시 자동 재시작:
```bash
python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

## 📦 배포

### 프로덕션 모드
```bash
python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --workers 4
```

### Docker 사용
```bash
# Dockerfile이 있는 경우
docker build -t heritage-api .
docker run -p 8080:8080 heritage-api
```

---

## 🖥️ 화면 플로우

1. 로그인 화면 (①)
   * 임시 관리자 계정으로 접속 가능.
   * 단순 진입 검증만 수행.
     
2. 홈 화면 (②)
   * “조사·등록 시스템” 버튼 제공.
   * 클릭 시 국가유산 검색(③) 화면으로 이동.
     
3. 국가 유산 검색 (③)
   * 종목 / 지역 / 키워드(유산명)로 조건 검색.
   * 국가유산청 Open API /heritage/list 연동.
   * 표 형식 리스트: 종목 | 유산명 | 소재지 | 주소.
   * 무한 스크롤(페이지네이션) 구현.
   * 항목 클릭 → 해당 ccbaKdcd/ccbaAsno/ccbaCtcd를 상세화면(④)으로 전달.

4. 기본개요 상세 (④)
   * /heritage/detail API 연동.
   * 주요 정보 표시:
   * 종목, 지정(등록)일, 소유자, 관리자
   * 소재지(요약/상세)
   * 분류(gcode/bcode/mcode/scode)
   * 수량, 시대
   * 식별자(연계번호, 코드 키)
   * 좌표(위도/경도)
   * 보존관리 이력은 아직 목업 영역으로 대체.

5. 상세조사 (⑤)
   * UI 골격만 구성됨.
   * 추후 손상부 조사 등록 로직 추가 예정.

6. 손상예측/모델 (⑥)
   * UI 골격만 구성됨.
   * 추후 AI 모델 연동 예정.

7. 손상지도 (⑦)
   * UI 골격만 구성됨.
   * 추후 지도/좌표 기반 시각화 연동 예정.

---

## 📚 국가유산청 코드 샘플

* 종목코드(ccbaKdcd): 11 국보, 12 보물, 13 사적, 15 천연기념물 …
* 시도코드(ccbaCtcd): 11 서울, 24 전북, 34 충남, 48 경남 …

---

## 🔌 주요 코드

* `server/main.py`: 목록/상세 API 프록시, XML→JSON 변환
* `lib/features/heritage_list/data/heritage_api.dart`: 프록시 호출 래퍼
* `lib/features/heritage_list/presentation/asset_select_screen.dart`: 국가유산 검색 리스트
* `lib/features/heritage_detail/presentation/basic_info_screen.dart`: 상세정보 표시

---

## 🏗️ 빌드

* Web:

```bash
flutter build web --dart-define=PROXY_BASE=https://<프록시주소>
```

* Android APK:

```bash
flutter build apk --dart-define=PROXY_BASE=https://<프록시주소>
```

* iOS:

```bash
flutter build ios --dart-define=PROXY_BASE=https://<프록시주소>
```

---

## ❗️문제 해결

* 목록이 안 나올 때: 서버 로그 확인
* `Error loading ASGI app`: uvicorn 실행경로 확인
* `No macOS desktop project configured`: 웹/안드로이드 실행 권장
* CORS 에러: 프록시 주소 사용 필수
* `package:http/http.dart` 빨간 줄: pubspec.yaml에 `http: ^1.2.2` 추가 후 `flutter pub get`

---

## 🗺️ 로드맵

* 종목/지역 코드 서버 제공 → 드롭다운 자동화
* 상세 화면에 대표 이미지 추가
* 보존관리 이력 API 연동
* 손상조사/모델링/지도 단계 개발
