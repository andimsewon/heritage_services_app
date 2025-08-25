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
│  │  ├─ env.dart               # PROXY_BASE 환경값(프록시 주소)
│  │  ├─ data/heritage_api.dart # 프록시 REST 클라이언트
│  │  └─ screens/
│  │     ├─ login_screen.dart
│  │     ├─ home_screen.dart
│  │     ├─ asset_select_screen.dart     # ③ 국가 유산 검색 (종목/지역/조건)
│  │     ├─ basic_info_screen.dart       # ④ 기본개요 (상세 API)
│  │     ├─ detail_survey_screen.dart    # ⑤ 상세조사(골격)
│  │     ├─ damage_model_screen.dart     # ⑥ 손상예측/모델(골격)
│  │     └─ damage_map_preview_screen.dart# ⑦ 손상지도(골격)
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

## 🧰 설치 & 실행

### 0) 리포 가져오기

```bash
git clone https://github.com/andimsewon/heritage_services_app.git
cd heritage_services_app
```

### 1) 서버(FastAPI) 실행

**이유**: 국가유산청 Open API는 XML만 제공 + 클라이언트 직접호출/브라우저 CORS 제약 →
**프록시 서버**에서 XML→JSON 변환 후 앱이 호출.

#### 필수 패키지 설치

```bash
cd server
python3 -m venv .venv        # 선택(권장)
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install "uvicorn[standard]" fastapi httpx xmltodict
```

#### 서버 실행

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8080
# 헬스체크: http://127.0.0.1:8080/health
```

#### 문서상 API 엔드포인트

* 목록: `GET /heritage/list`

  * query: `keyword`, `kind`, `region`, `page`, `size`
* 상세: `GET /heritage/detail`

  * query: `ccbaKdcd`, `ccbaAsno`, `ccbaCtcd`

---

### 2) 클라이언트(Flutter) 실행

```bash
cd ../my_cross_app
flutter pub get
```

#### (A) 웹(Chrome)

```bash
flutter run -d chrome --dart-define=PROXY_BASE=http://127.0.0.1:8080
```

#### (B) Android 에뮬레이터

```bash
flutter run -d emulator-5554 --dart-define=PROXY_BASE=http://10.0.2.2:8080
```

#### (C) iOS 시뮬레이터

```bash
flutter run -d ios --dart-define=PROXY_BASE=http://127.0.0.1:8080
```

`lib/env.dart` (예시)

```dart
class Env {
  static const proxyBase = String.fromEnvironment(
    'PROXY_BASE',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
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
* `lib/data/heritage_api.dart`: 프록시 호출 래퍼
* `lib/screens/asset_select_screen.dart`: 국가유산 검색 리스트
* `lib/screens/basic_info_screen.dart`: 상세정보 표시

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
