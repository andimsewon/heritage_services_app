# 🐳 Docker 배포 가이드

Heritage Services App을 Docker로 배포하고 Flutter 앱과 연동하는 방법

---

## 📋 사전 요구사항

### 1. Docker 설치
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Docker 서비스 시작
sudo systemctl start docker
sudo systemctl enable docker

# 현재 사용자를 docker 그룹에 추가 (sudo 없이 실행)
sudo usermod -aG docker $USER
# 로그아웃 후 다시 로그인 필요
```

### 2. 파일 구조 확인
```
heritage_services_app/
├── docker-compose.yml          # ✅ Docker Compose 설정
├── server/
│   ├── Dockerfile              # ✅ Docker 이미지 빌드 파일
│   ├── .dockerignore           # ✅ 제외할 파일 목록
│   ├── main.py                 # FastAPI 앱
│   ├── requirements.txt        # Python 의존성
│   ├── heritage/               # 국가유산 API 모듈
│   ├── ai/                     # AI 손상 탐지 모듈
│   │   └── hanok_damage_model.pt  # ⚠️ 552MB 모델 파일 필수!
│   └── common/                 # 공통 설정
│
└── my_cross_app/
    └── lib/
        └── env.dart            # ✅ Docker 엔드포인트로 업데이트됨
```

---

## 🚀 빠른 시작 (3단계)

### 1️⃣ Docker 컨테이너 빌드 및 실행

```bash
# 프로젝트 루트 디렉토리로 이동
cd /home/dbs0510/heritage_services_app

# Docker Compose로 빌드 및 실행 (한 번에!)
docker-compose up --build -d
```

**명령어 설명:**
- `--build`: Docker 이미지 새로 빌드
- `-d`: 백그라운드에서 실행 (detached mode)

### 2️⃣ 서버 상태 확인

```bash
# 컨테이너 실행 확인
docker ps

# 로그 확인
docker-compose logs -f

# 헬스체크
curl http://localhost:8080/health
```

**예상 출력:**
```json
{"status": "ok", "service": "Heritage Services API"}
```

### 3️⃣ Flutter 앱 실행

```bash
# Flutter 앱 디렉토리로 이동
cd my_cross_app

# 웹으로 실행 (Docker의 localhost:8080에 자동 연결)
flutter run -d chrome

# 안드로이드 에뮬레이터로 실행 (Docker의 10.0.2.2:8080에 자동 연결)
flutter run -d emulator-5554
```

## ♻️ 안전한 재배포 스크립트

Flutter 웹 번들을 다시 만들고 Docker 컨테이너를 깨끗하게 재시작해야 할 때는 중간에 끊기지 않는 순서가 중요합니다. `scripts/redeploy_web.sh`를 실행하면 Flutter 정리/빌드 → docker-compose down → 기존 컨테이너 강제 제거 → API 이미지 무캐시 빌드 → heritage-web 재기동까지 한 번에 처리하므로 `heritage-api` 이름 충돌 오류를 예방할 수 있습니다.

```bash
./scripts/redeploy_web.sh                # Flutter + Docker 모두 수행
./scripts/redeploy_web.sh --skip-flutter # Flutter 결과가 이미 있으면 Docker만
./scripts/redeploy_web.sh --flutter-only # Docker는 건드리지 않고 Flutter만
```

> 내부적으로 `docker-compose down --remove-orphans` 와 `docker rm -f heritage-api heritage-web`을 호출하여 기존 컨테이너가 남아 있어도 안전하게 정리한 뒤 재배포합니다.


---

## 📡 네트워크 구성

### 개발 환경 (로컬)

```
┌─────────────────────────────────────────────────┐
│  호스트 머신 (localhost)                         │
│                                                  │
│  ┌────────────────────┐                          │
│  │ Docker Container   │                          │
│  │ heritage-api       │                          │
│  │ Port: 8080         │                          │
│  └────────────────────┘                          │
│           ↑                                      │
│           │ HTTP                                 │
│           │                                      │
│  ┌────────┴────────┐     ┌──────────────────┐  │
│  │ Flutter Web     │     │ Flutter Android  │  │
│  │ localhost:8080  │     │ 10.0.2.2:8080    │  │
│  └─────────────────┘     └──────────────────┘  │
└─────────────────────────────────────────────────┘
```

### 엔드포인트 자동 설정

| 플랫폼 | 엔드포인트 | 설명 |
|--------|-----------|------|
| 🌐 Web | `http://localhost:8080` | Docker 컨테이너 직접 접근 |
| 🤖 Android (에뮬레이터) | `http://10.0.2.2:8080` | 에뮬레이터→호스트 머신 브릿지 |
| 🍎 iOS (시뮬레이터) | `http://localhost:8080` | Docker 컨테이너 직접 접근 |
| 🖥️ Desktop | `http://localhost:8080` | Docker 컨테이너 직접 접근 |

**✨ 수동 오버라이드:**
```bash
# 원격 서버 사용
flutter run -d chrome --dart-define=API_BASE=http://210.117.181.115:8080

# 다른 포트 사용
flutter run -d chrome --dart-define=API_BASE=http://localhost:9000
```

---

## 🛠️ Docker 명령어 모음

### 기본 작업

```bash
# 컨테이너 시작 (이미 빌드된 이미지)
docker-compose up -d

# 컨테이너 중지
docker-compose down

# 컨테이너 재시작
docker-compose restart

# 로그 실시간 확인
docker-compose logs -f heritage-api

# 컨테이너 내부 접근 (디버깅용)
docker exec -it heritage-services-api bash
```

### 빌드 관련

```bash
# 이미지 강제 재빌드 (캐시 무시)
docker-compose build --no-cache

# 재빌드 후 실행
docker-compose up --build -d

# 이미지 삭제 후 재빌드
docker-compose down --rmi all
docker-compose up --build -d
```

### 디버깅

```bash
# 컨테이너 상태 확인
docker ps -a

# 포트 바인딩 확인
docker port heritage-services-api

# 리소스 사용량 확인
docker stats heritage-services-api

# 네트워크 확인
docker network inspect heritage_heritage-network
```

---

## 🔧 고급 설정

### 1. 포트 변경

**docker-compose.yml 수정:**
```yaml
services:
  heritage-api:
    ports:
      - "9000:8080"  # 호스트 포트:컨테이너 포트
```

**Flutter env.dart 수정:**
```dart
static const String dockerPort = '9000';
```

### 2. 환경 변수 추가

**docker-compose.yml에 환경 변수 추가:**
```yaml
services:
  heritage-api:
    environment:
      - HOST=0.0.0.0
      - PORT=8080
      - RELOAD=false
      - LOG_LEVEL=info  # 로그 레벨 설정
```

### 3. 볼륨 마운트 (모델 파일 외부 관리)

```yaml
services:
  heritage-api:
    volumes:
      - ./server/ai/hanok_damage_model.pt:/app/ai/hanok_damage_model.pt:ro
```

### 4. GPU 지원 (NVIDIA GPU)

**docker-compose.yml:**
```yaml
services:
  heritage-api:
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
```

**Dockerfile 변경 (PyTorch GPU 버전):**
```dockerfile
# requirements.txt에서 torch 제거 후
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
```

---

## 🌐 프로덕션 배포

### 원격 서버에 배포

#### 1. 서버에 코드 배포
```bash
# Git으로 코드 푸시
git push origin main

# 서버에서 코드 풀
ssh user@your-server
cd /path/to/heritage_services_app
git pull origin main
```

#### 2. Docker 실행
```bash
# 서버에서
docker-compose up --build -d
```

#### 3. Flutter 앱 설정 업데이트
```bash
# 프로덕션 서버 URL로 빌드
flutter build web --dart-define=API_BASE=http://your-server-ip:8080
flutter build apk --dart-define=API_BASE=http://your-server-ip:8080
```

### Nginx 리버스 프록시 (선택사항)

**nginx.conf:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 🧪 테스트

### 1. API 테스트

```bash
# 헬스체크
curl http://localhost:8080/health

# 서비스 정보
curl http://localhost:8080/

# 유산 목록 조회
curl "http://localhost:8080/heritage/list?keyword=불국사&page=1&size=5"

# AI 모델 상태
curl http://localhost:8080/ai/model/status

# 이미지 손상 탐지 (테스트 이미지 필요)
curl -X POST "http://localhost:8080/ai/damage/infer" \
  -F "image=@/path/to/test_image.jpg"
```

### 2. Swagger UI 접속

브라우저에서: http://localhost:8080/docs

---

## 🐛 트러블슈팅

### 문제 1: 포트 8080이 이미 사용 중

**증상:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:8080: bind: address already in use
```

**해결:**
```bash
# 8080 포트 사용 중인 프로세스 확인
sudo lsof -i :8080

# 프로세스 종료
sudo kill -9 <PID>

# 또는 docker-compose.yml에서 다른 포트 사용
ports:
  - "8081:8080"
```

### 문제 2: 모델 파일 누락

**증상:**
```
[AI] 모델 파일이 존재하지 않습니다: /app/ai/hanok_damage_model.pt
```

**해결:**
```bash
# 모델 파일 존재 확인
ls -lh server/ai/hanok_damage_model.pt

# 파일이 없으면 원래 위치에서 복사
cp hanok_damage_model_ml_backend.pt server/ai/hanok_damage_model.pt

# Docker 이미지 재빌드
docker-compose up --build -d
```

### 문제 3: Flutter 앱이 서버에 연결 안 됨

**안드로이드 에뮬레이터:**
```bash
# localhost 대신 10.0.2.2 사용
flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
```

**실제 안드로이드 기기:**
```bash
# 호스트 머신의 IP 주소 확인
ifconfig  # 또는 ip addr show

# 호스트 IP로 연결
flutter run -d android --dart-define=API_BASE=http://192.168.x.x:8080
```

### 문제 4: Docker 빌드 시 메모리 부족

**해결:**
```bash
# Docker 메모리 제한 증가 (Docker Desktop 설정)
# 또는 빌드 시 메모리 제한 늘리기
docker build --memory 4g -t heritage-api ./server
```

### 문제 5: CORS 오류

**증상:**
```
Access to fetch at 'http://localhost:8080/heritage/list' from origin
'http://localhost:3000' has been blocked by CORS policy
```

**해결:**

이미 `common/config.py`에서 CORS가 허용되어 있습니다. 만약 문제가 계속되면:

```python
# common/config.py
CORS_ORIGINS: List[str] = [
    "http://localhost:3000",
    "http://localhost:8080",
    "*"  # 개발 중에만 사용
]
```

---

## 📊 성능 최적화

### 1. Docker 이미지 크기 줄이기

**Multi-stage build (고급):**
```dockerfile
# 빌드 스테이지
FROM python:3.10 as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# 실행 스테이지
FROM python:3.10-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### 2. 로그 관리

```bash
# 로그 로테이션 설정
docker-compose logs --tail=100 -f

# 로그 파일로 저장
docker-compose logs > app.log 2>&1
```

---

## 📝 체크리스트

배포 전 확인사항:

- [ ] Docker 및 Docker Compose 설치 완료
- [ ] 모델 파일 `server/ai/hanok_damage_model.pt` 존재 확인 (552MB)
- [ ] `docker-compose up --build -d` 실행 성공
- [ ] `curl http://localhost:8080/health` 응답 확인
- [ ] Swagger UI (http://localhost:8080/docs) 접근 가능
- [ ] Flutter 앱 실행 및 API 통신 성공
- [ ] AI 모델 로딩 성공 (`/ai/model/status` 확인)

---

## 🎉 완료!

이제 다음과 같이 사용할 수 있습니다:

1. **백엔드 서버**: Docker 컨테이너로 실행 중 (포트 8080)
2. **Flutter 앱**: 자동으로 Docker 서버에 연결
3. **API 문서**: http://localhost:8080/docs

질문이나 문제가 있으면 GitHub Issues에 등록해주세요!
