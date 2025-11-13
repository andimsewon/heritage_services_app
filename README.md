# 국가유산 모니터링 조사·등록 시스템

국가유산청 Open API를 기반으로 한 **현장 조사·등록 업무 지원 크로스플랫폼 애플리케이션**입니다. Flutter로 개발된 프론트엔드와 FastAPI 백엔드로 구성되어 있으며, **AI 기반 손상 탐지 기능**과 **Firebase 실시간 데이터베이스**를 통합한 종합 관리 시스템입니다.

---

## 📋 목차

- [프로젝트 개요](#프로젝트-개요)
- [주요 기능](#주요-기능)
- [기술 스택](#기술-스택)
- [시스템 아키텍처](#시스템-아키텍처)
- [AI 모델 상세](#ai-모델-상세)
- [데이터 구조](#데이터-구조)
- [주요 화면 및 워크플로우](#주요-화면-및-워크플로우)
- [설치 및 실행](#설치-및-실행)
- [배포 가이드](#배포-가이드)
- [API 문서](#api-문서)

---

## 🎯 프로젝트 개요

### 목적
국가유산(문화재)의 체계적인 모니터링과 보존 관리를 위해 현장 조사 데이터를 디지털화하고, AI 기술을 활용하여 손상 상태를 자동으로 분석·평가하는 통합 관리 시스템을 제공합니다.

### 핵심 가치
- **디지털 전환**: 종이 기반 조사 기록을 디지털 데이터베이스로 전환
- **AI 자동화**: 이미지 기반 손상 탐지로 조사 효율성 향상
- **실시간 협업**: Firebase를 통한 실시간 데이터 동기화 및 협업 지원
- **크로스플랫폼**: 웹, Android, iOS에서 동일한 경험 제공

---

## ✨ 주요 기능

### 1. 국가유산 검색 및 조회
- **다중 조건 검색**: 종목(국보, 보물, 사적 등), 지역, 키워드(유산명)로 검색
- **국가유산청 Open API 연동**: 실시간 문화재 정보 조회
- **무한 스크롤 페이지네이션**: 대량 데이터 효율적 로딩
- **수동 등록 지원**: OpenAPI에 없는 문화재 직접 등록 가능

### 2. 상세 정보 관리
- **기본 정보 표시**: 종목, 지정일, 소유자, 관리자, 소재지, 좌표 등
- **3단계 탭 구조**:
  - **현장 조사**: 기본 정보, 메타 정보, 위치 현황, 현황 사진, 손상부 조사
  - **조사자 의견**: 보존관리 이력, 조사 결과, 보존 사항, 관리사항
  - **종합진단**: 손상부 종합, 조사자 의견 확인, 등급 분류, AI 예측

### 3. 손상부 조사 (핵심 기능)
#### 3.1 AI 기반 자동 손상 탐지
- **4가지 손상 유형 자동 탐지**:
  - 갈램 (갈라짐)
  - 균열 (크랙)
  - 부후 (부식/부패)
  - 압괴/터짐 (파손)
- **바운딩 박스 시각화**: 탐지된 손상 영역을 이미지에 직접 표시
- **신뢰도 점수**: 각 탐지 결과에 대한 AI 신뢰도 표시 (0~1)
- **자동 등급 산정**: 탐지 결과를 기반으로 A~D 등급 자동 부여

#### 3.2 조사 프로세스
1. **조사 등록**: 부재명, 부재번호, 향(방향) 선택
2. **사진 촬영/선택**: 카메라 또는 갤러리에서 이미지 선택
3. **AI 자동 분석**: 서버로 이미지 전송 → AI 모델 추론 → 결과 반환
4. **결과 확인**: 바운딩 박스와 함께 탐지 결과 확인
5. **정보 입력**: 손상 위치, 손상 현상, 조사자 의견, 등급 입력
6. **저장**: Firebase에 이미지, 탐지 결과, 메타데이터 저장

#### 3.3 손상부 조사 UI
- **통계 대시보드**: 총 조사 수, 감지된 손상 수, 등급별 분포
- **인터랙티브 테이블**: 조사 목록을 테이블 형식으로 표시 (선택, 사진, 위치, 손상 유형, 등급, 조사일시, 의견)
- **썸네일 카드 뷰**: 4:3 고정 비율 썸네일, 바운딩 박스 오버레이, 클릭 시 전체화면 뷰어
- **전체화면 뷰어**: 원본 이미지, 모든 바운딩 박스, 메타데이터 표시

### 4. 현황 사진 관리
- **사진 업로드**: Firebase Storage에 이미지 저장
- **실시간 스트림**: Firestore 실시간 업데이트 반영
- **이미지 최적화**: 프록시를 통한 리사이징 및 캐싱
- **삭제 기능**: 문서 및 스토리지 파일 동시 삭제

### 5. 조사자 의견 관리
- **섹션별 편집 제어**: 저장 후 수정 모드로 전환 필요
- **수정 이력 추적**: Firebase에 수정자, 변경 필드, 타임스탬프 저장
- **실시간 이력 조회**: StreamBuilder를 통한 실시간 수정 이력 표시
- **보존 사항 자동 연결**: 손상부 조사 데이터가 자동으로 보존 사항에 반영

### 6. 보존관리 이력
- **이력 불러오기**: 기존 보존관리 이력 데이터 동기화
- **Firebase 연동**: 실시간 이력 데이터 조회 및 표시

---

## 🛠 기술 스택

### Frontend
- **Flutter 3.35.1** (Dart 3.9.0)
  - 크로스플랫폼 개발 (Web, Android, iOS)
  - Material Design 3
  - 반응형 레이아웃 (`ResponsivePage`, `LayoutBuilder`)
- **Firebase**
  - **Firestore**: 실시간 데이터베이스 (조사 데이터, 이력 관리)
  - **Storage**: 이미지 파일 저장 및 관리
  - **StreamBuilder**: 실시간 데이터 동기화
- **상태 관리**: StatefulWidget, ChangeNotifier, ViewModel 패턴
- **이미지 처리**: `OptimizedImage` (캐싱, 리사이징), `ImagePicker`

### Backend
- **FastAPI** (Python 3.10+)
  - RESTful API 서버
  - XML → JSON 변환 (국가유산청 API)
  - CORS 미들웨어
  - Swagger/ReDoc 자동 문서화
- **AI/ML**
  - **PyTorch**: 딥러닝 프레임워크
  - **DETA (Detection Transformer)**: 객체 탐지 모델
    - 백본: ResNet-50
    - 작업: 한옥 손상 영역 탐지
    - 클래스 수: 4개 (갈램, 균열, 부후, 압괴/터짐)
  - **Transformers**: DetaImageProcessor
  - **Torchvision**: NMS (Non-Maximum Suppression)

### Infrastructure
- **Docker**: 컨테이너화 및 배포
- **Docker Compose**: 멀티 컨테이너 오케스트레이션
- **Nginx**: 리버스 프록시 및 정적 파일 서빙

---

## 🏗 시스템 아키텍처

### 전체 구조
```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Client (Web/Android/iOS)          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  UI Layer    │  │  State Mgmt  │  │  Services    │     │
│  │  (Screens,   │  │  (ViewModels)│  │  (Firebase,  │     │
│  │   Widgets)   │  │              │  │   API)       │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP/REST
                            │
┌─────────────────────────────────────────────────────────────┐
│              FastAPI Backend (Port 8080)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Heritage    │  │  AI Service  │  │  Image       │     │
│  │  API Proxy   │  │  (PyTorch)   │  │  Processing  │     │
│  │  (XML→JSON)  │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │                              │
    ┌────▼────┐                    ┌────▼────┐
    │ 국가유산청 │                    │ Firebase │
    │ Open API │                    │ Firestore│
    │  (XML)   │                    │ Storage  │
    └──────────┘                    └──────────┘
```

### 데이터 흐름

#### 1. 국가유산 검색
```
사용자 입력 (종목/지역/키워드)
    ↓
Flutter: HeritageApi.searchHeritage()
    ↓
FastAPI: /heritage/list
    ↓
국가유산청 Open API (XML)
    ↓
FastAPI: XML → JSON 변환
    ↓
Flutter: 리스트 표시
```

#### 2. 손상부 조사 (AI 탐지)
```
사용자: 사진 선택/촬영
    ↓
Flutter: ImagePicker → Uint8List
    ↓
Flutter: AiDetectionService.detectDamage()
    ↓
FastAPI: POST /ai/damage/infer (multipart/form-data)
    ↓
AI Service: 이미지 전처리 (DetaImageProcessor)
    ↓
PyTorch Model: CustomDeta 추론
    ↓
후처리: 클래스별 Threshold → NMS
    ↓
결과 반환: {detections, grade, explanation}
    ↓
Flutter: 바운딩 박스 시각화
    ↓
사용자: 정보 입력 (위치, 현상, 의견)
    ↓
Firebase: Firestore + Storage 저장
```

#### 3. 실시간 데이터 동기화
```
Firebase Firestore 변경
    ↓
StreamBuilder 자동 업데이트
    ↓
UI 자동 리빌드
    ↓
사용자에게 실시간 반영
```

---

## 🤖 AI 모델 상세

### 모델 아키텍처
- **기반 모델**: DETA (Detection Transformer)
- **백본 네트워크**: ResNet-50
- **작업 유형**: 객체 탐지 (Object Detection)
- **입력**: RGB 이미지 (임의 크기)
- **출력**: 바운딩 박스 + 클래스 + 신뢰도

### 탐지 클래스
| ID | 클래스명 | 한글명 | Threshold |
|----|---------|--------|-----------|
| 0 | LABEL_0 | 갈램 | 0.30 |
| 1 | LABEL_1 | 균열 | 0.25 |
| 2 | LABEL_2 | 부후 | 0.15 |
| 3 | LABEL_3 | 압괴/터짐 | 0.25 |

### 처리 파이프라인

#### 1. 이미지 전처리
```python
이미지 바이트 → PIL Image (RGB) → DetaImageProcessor
→ pixel_values 텐서 (배치 차원 포함)
```

#### 2. 모델 추론
```python
pixel_values → CustomDeta 모델 → 객체 탐지 결과
```

#### 3. 후처리
1. **초기 필터링**: 낮은 threshold (0.05)로 후보 추출
2. **클래스별 Threshold 적용**: 각 손상 유형별 다른 기준 적용
3. **NMS (Non-Maximum Suppression)**: 
   - IoU threshold: 0.1
   - 클래스별 독립 적용
   - 중복 탐지 제거

#### 4. 등급 산정
| 신뢰도 범위 | 등급 | 설명 |
|-----------|------|------|
| ≥ 0.85 | D | 심각한 손상, 즉시 보수 필요 |
| 0.75 ~ 0.85 | C2 | 명확한 손상, 모니터링 및 예방 조치 필요 |
| 0.6 ~ 0.75 | C1 | 경미한 손상, 정기적 관찰 필요 |
| 0.5 ~ 0.6 | B | 손상 의심, 지속적 관찰 필요 |
| < 0.5 | A | 이상 징후 거의 없음 |

### 응답 형식
```json
{
  "detections": [
    {
      "label": "균열",
      "label_id": 1,
      "score": 0.85,
      "bbox": [x1, y1, x2, y2]
    }
  ],
  "count": 3,
  "grade": "C2",
  "explanation": "균열 손상이 명확히 관찰됩니다. 모니터링 및 예방 조치가 필요합니다."
}
```

### 모델 파일
- **위치**: `server/ai/hanok_damage_model.pth` (기본)
- **크기**: 약 552MB
- **형식**: PyTorch 체크포인트
- **자동 검색**: 환경변수 `MODEL_PATH` 또는 기본 경로에서 자동 로드

---

## 💾 데이터 구조

### Firebase Firestore 구조

#### 1. Heritage 컬렉션
```
heritages/
  {heritageId}/
    ├── damage_surveys/          # 손상부 조사
    │   └── {surveyId}/
    │       ├── imageUrl: string
    │       ├── detections: array
    │       ├── location: string
    │       ├── phenomenon: string
    │       ├── severityGrade: string (A~F)
    │       ├── inspectorOpinion: string
    │       ├── timestamp: string (ISO8601)
    │       └── ...
    │
    ├── photos/                  # 현황 사진
    │   └── {photoId}/
    │       ├── url: string
    │       ├── timestamp: string
    │       └── ...
    │
    ├── detail_surveys/          # 상세 조사
    │   └── {surveyId}/
    │       └── ...
    │
    └── edit_history/            # 수정 이력
        └── {historyId}/
            ├── sectionType: string
            ├── editor: string
            ├── changedFields: array
            └── timestamp: Timestamp
```

#### 2. 손상부 조사 문서 구조
```dart
{
  'imageUrl': 'https://firebasestorage...',
  'url': 'https://firebasestorage...',  // 동일 (호환성)
  'detections': [
    {
      'label': '균열',
      'label_id': 1,
      'score': 0.85,
      'bbox': [x1, y1, x2, y2]  // 절대 좌표 (픽셀)
    }
  ],
  'location': '동쪽 벽면',
  'phenomenon': '수직 균열',
  'severityGrade': 'C2',
  'inspectorOpinion': '조사자 의견...',
  'timestamp': '2024-01-15T10:30:00Z',
  'width': 1920,   // 원본 이미지 너비
  'height': 1080,  // 원본 이미지 높이
  'heritageName': '불국사',
  'desc': '손상부 조사'
}
```

#### 3. 수정 이력 문서 구조
```dart
{
  'sectionType': 'inspectionResult' | 'preservationItems' | 'management',
  'editor': '관리자명',
  'changedFields': ['field1', 'field2'],
  'timestamp': Timestamp,
  'createdAt': '2024-01-15T10:30:00Z'
}
```

### Firebase Storage 구조
```
gs://{bucket}/
  heritages/
    {heritageId}/
      ├── damage_surveys/
      │   └── {uuid}.jpg
      └── photos/
          └── {uuid}.jpg
```

---

## 📱 주요 화면 및 워크플로우

### 1. 로그인 화면
- **기능**: 관리자 계정으로 접속
- **검증**: 단순 진입 검증 (프로덕션에서는 Firebase Auth 연동 권장)

### 2. 홈 화면
- **기능**: "조사·등록 시스템" 버튼 제공
- **이동**: 국가유산 검색 화면으로 이동

### 3. 국가유산 검색 화면
- **검색 조건**:
  - 종목 (국보, 보물, 사적, 천연기념물 등)
  - 지역 (서울, 전북, 경남 등)
  - 키워드 (유산명)
- **표시 정보**: 종목 | 유산명 | 소재지 | 주소
- **기능**:
  - 무한 스크롤 페이지네이션
  - 항목 클릭 → 상세 화면 이동
  - 수동 등록 (OpenAPI에 없는 문화재)

### 4. 기본 정보 상세 화면 (핵심)

#### 4.1 탭 구조
- **현장 조사** (Tab 1)
  - 기본 정보
  - 메타 정보 (조사 일자, 조사 기관, 조사자)
  - 위치 현황
  - 현황 사진 (Firebase Storage 연동)
  - 손상부 조사 (AI 탐지 포함)

- **조사자 의견** (Tab 2)
  - 보존관리 이력 (불러오기 버튼)
  - 조사 결과 (편집 가능/읽기 전용 제어)
  - 보존 사항 (손상부 조사 자동 연결)
  - 관리사항 (편집 가능/읽기 전용 제어)
  - 수정 이력 (Firebase 실시간 조회)

- **종합진단** (Tab 3)
  - 손상부 종합
  - 조사자 의견 확인
  - 등급 분류
  - AI 예측 기능

#### 4.2 손상부 조사 섹션
- **통계 대시보드**:
  - 총 조사 수
  - 감지된 손상 수
  - 등급별 분포 (A, B, C1, C2, D)
- **인터랙티브 테이블**:
  - 선택 (라디오 버튼)
  - 사진 (썸네일)
  - 위치
  - 손상 유형
  - 등급 (색상 배지)
  - 조사일시 (YYYY-MM-DD HH:mm)
  - 조사자 의견 (감지 개수 배지 포함)
- **썸네일 카드 뷰**:
  - 4:3 고정 비율
  - 바운딩 박스 오버레이
  - 위치, 손상 현상, 감지 개수, 날짜 표시
  - 클릭 시 전체화면 뷰어
- **버튼**:
  - 조사 등록
  - 심화조사 (선택 필요)

#### 4.3 손상부 조사 다이얼로그
1. **조사 등록 단계**:
   - 부재명 선택
   - 부재번호 입력
   - 향(방향) 선택
2. **손상부 조사 단계**:
   - 전년도 조사 사진 표시 (있는 경우)
   - 이번 조사 사진 등록 (카메라/갤러리)
   - AI 자동 분석 (로딩 표시)
   - 바운딩 박스 시각화
3. **감지 결과 확인**:
   - 탐지된 손상 목록
   - 신뢰도 점수
   - 자동 등급 산정
4. **정보 입력**:
   - 손상 위치
   - 손상 현상
   - 손상 분류 (표준 용어 선택)
   - 손상 등급 (A~F)
   - 조사자 의견
5. **저장**: Firebase에 모든 데이터 저장

---

## 🚀 설치 및 실행

### 사전 요구사항
- **Flutter**: 3.35.1 이상
- **Dart**: 3.9.0 이상
- **Python**: 3.10 이상
- **Firebase 프로젝트**: Firestore 및 Storage 설정 완료

### 1. 저장소 클론
```bash
git clone <repository-url>
cd heritage_services_app
```

### 2. 백엔드 서버 설정

#### 2.1 의존성 설치
```bash
cd server
python3 -m pip install -r requirements.txt
```

#### 2.2 AI 모델 파일 배치
```bash
# 모델 파일을 server/ai/ 디렉토리에 복사
cp /path/to/model.pth server/ai/hanok_damage_model.pth
```

#### 2.3 환경변수 설정 (선택)
```bash
export MODEL_PATH="/path/to/model.pth"  # 모델 경로 지정
export API_BASE="http://localhost:8080"  # API 기본 주소
```

#### 2.4 서버 실행
```bash
# 방법 1: 스크립트 사용 (권장)
./run_server.sh

# 방법 2: 직접 실행
python3 -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload

# 방법 3: Python으로 실행
python3 main.py
```

#### 2.5 서버 상태 확인
```bash
curl http://localhost:8080/health
# 응답: {"ok": true}
```

### 3. Flutter 앱 설정

#### 3.1 의존성 설치
```bash
cd my_cross_app
flutter pub get
```

#### 3.2 Firebase 설정
1. `google-services.json` (Android) 및 `GoogleService-Info.plist` (iOS) 파일 배치
2. `lib/firebase_options.dart` 파일 확인 (자동 생성됨)

#### 3.3 환경변수 설정
`lib/core/config/env.dart` 파일에서 API 주소 설정:
```dart
static const String proxyBase = 'http://localhost:8080';
static const String aiBase = 'http://localhost:8080';
```

또는 빌드 시 지정:
```bash
flutter run -d chrome \
  --dart-define=API_BASE=http://localhost:8080 \
  --dart-define=AI_BASE=http://localhost:8080
```

#### 3.4 앱 실행
```bash
# 웹
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 4. 개발 모드
- **Hot Reload**: 코드 변경 시 자동 반영 (`r` 키)
- **Hot Restart**: 전체 재시작 (`R` 키)
- **서버 자동 재시작**: `--reload` 옵션 사용

---

## 🐳 배포 가이드

### Docker Compose 사용 (권장)

#### 1. 빌드 및 실행
```bash
# Flutter 웹 빌드
cd my_cross_app
flutter build web --release

# Docker Compose로 전체 스택 실행
cd ..
docker-compose up -d --build
```

#### 2. 서비스 확인
- **웹 앱**: http://localhost:80
- **API 서버**: http://localhost:8080
- **API 문서**: http://localhost:8080/docs

#### 3. 로그 확인
```bash
docker-compose logs -f heritage-web
docker-compose logs -f heritage-api
```

#### 4. 재배포
```bash
# 웹 앱만 재빌드
cd my_cross_app
flutter build web --release
cd ..
docker-compose restart heritage-web

# 전체 재빌드
docker-compose up -d --build
```

### 수동 배포

#### 1. 백엔드 배포
```bash
cd server
# 프로덕션 모드 (워커 4개)
uvicorn main:app --host 0.0.0.0 --port 8080 --workers 4
```

#### 2. 프론트엔드 배포
```bash
cd my_cross_app
flutter build web --release
# build/web 디렉토리를 웹 서버에 배치
```

---

## 📡 API 문서

### 기본 정보
- **서버 주소**: `http://localhost:8080`
- **Swagger UI**: `http://localhost:8080/docs`
- **ReDoc**: `http://localhost:8080/redoc`

### 주요 엔드포인트

#### 1. Health Check
```http
GET /health
```
**응답**:
```json
{"ok": true}
```

#### 2. 국가유산 목록 조회
```http
GET /heritage/list?keyword={유산명}&kind={종목코드}&region={지역코드}&page=1&size=20
```
**예시**:
```bash
curl "http://localhost:8080/heritage/list?keyword=불국사&page=1&size=10"
```

#### 3. 국가유산 상세 정보
```http
GET /heritage/detail?ccbaKdcd={종목코드}&ccbaAsno={지정번호}&ccbaCtcd={시도코드}
```

#### 4. AI 모델 상태 확인
```http
GET /ai/model/status
```
**응답**:
```json
{
  "loaded": true,
  "model_path": "server/ai/hanok_damage_model.pth",
  "num_classes": 4,
  "device": "cuda"
}
```

#### 5. AI 손상 탐지
```http
POST /ai/damage/infer
Content-Type: multipart/form-data

file: <이미지 파일>
```
**응답**:
```json
{
  "detections": [
    {
      "label": "균열",
      "label_id": 1,
      "score": 0.85,
      "bbox": [100, 200, 300, 400]
    }
  ],
  "count": 1,
  "grade": "C2",
  "explanation": "균열 손상이 명확히 관찰됩니다..."
}
```

---

## 🔧 문제 해결

### 1. 모델 로드 실패
**증상**: `[AI] ❌ 모델 파일을 찾을 수 없습니다!`

**해결**:
1. 모델 파일이 `server/ai/` 디렉토리에 있는지 확인
2. 파일 확장자가 `.pth` 또는 `.pt`인지 확인
3. 환경변수 `MODEL_PATH` 확인

### 2. CORS 에러
**증상**: 브라우저 콘솔에 CORS 관련 오류

**해결**:
- FastAPI 서버의 CORS 설정 확인 (`common/middleware.py`)
- 프록시 주소 사용 확인

### 3. Firebase 연결 실패
**증상**: Firestore 데이터가 로드되지 않음

**해결**:
1. `google-services.json` 파일 확인
2. Firebase 프로젝트 설정 확인
3. Firestore 규칙 확인 (개발 모드: 읽기/쓰기 허용)

### 4. 이미지 업로드 실패
**증상**: Firebase Storage 업로드 오류

**해결**:
1. Storage 규칙 확인
2. CORS 설정 확인 (`firebase_storage_cors.json`)
3. 네트워크 연결 확인

---

## 📚 추가 문서

- [QUICKSTART.md](./QUICKSTART.md) - 3분 빠른 시작 가이드
- [DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md) - Docker 상세 배포 가이드
- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - 프로젝트 구조 상세
- [server/README.md](./server/README.md) - 서버 API 문서
- [server/ai/README_MODEL.md](./server/ai/README_MODEL.md) - AI 모델 상세 가이드

---

## 🗺 로드맵

### 단기 (완료)
- ✅ 국가유산 검색 및 상세 정보 조회
- ✅ AI 기반 손상 탐지
- ✅ Firebase 실시간 데이터 동기화
- ✅ 손상부 조사 UI/UX 개선
- ✅ 수정 이력 추적

### 중기 (진행 중)
- 🔄 종목/지역 코드 서버 제공
- 🔄 상세 화면 대표 이미지 추가
- 🔄 보존관리 이력 API 연동
- 🔄 AI 예측 기능 고도화

### 장기 (계획)
- 📋 손상 지도 시각화
- 📋 모바일 앱 최적화
- 📋 오프라인 모드 지원
- 📋 다국어 지원

---

## 📄 라이선스

이 프로젝트는 내부 사용을 위한 프로젝트입니다.

---

## 👥 기여

프로젝트 개선을 위한 제안 및 버그 리포트는 이슈 트래커를 통해 제출해주세요.

---

**마지막 업데이트**: 2024년 1월
