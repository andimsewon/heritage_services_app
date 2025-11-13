# 🚀 빌드 및 배포 명령어 가이드

## 전체 배포 (한 번에 실행)

```bash
cd /home/carrotsw/heritage_services_app
./deploy.sh
```

---

## 단계별 수동 실행

### 1️⃣ Flutter Web 빌드

```bash
cd /home/carrotsw/heritage_services_app/my_cross_app
flutter clean
flutter pub get
flutter build web --release
```

### 2️⃣ Docker 컨테이너 중지 및 제거

```bash
cd /home/carrotsw/heritage_services_app
docker-compose down heritage-web
docker rm -f heritage-web 2>/dev/null || true
```

### 3️⃣ API 이미지 빌드 (필요한 경우)

```bash
cd /home/carrotsw/heritage_services_app
docker-compose build --no-cache heritage-api
```

### 4️⃣ Docker 컨테이너 시작

```bash
cd /home/carrotsw/heritage_services_app
docker-compose up -d heritage-web heritage-api
```

### 5️⃣ 컨테이너 상태 확인

```bash
docker-compose ps
```

---

## 빠른 재배포 (빌드만 다시)

Flutter 앱만 변경된 경우:

```bash
cd /home/carrotsw/heritage_services_app/my_cross_app
flutter build web --release
cd ..
docker-compose restart heritage-web
```

---

## 컨테이너 로그 확인

```bash
# 웹 서버 로그
docker logs heritage-web

# API 서버 로그
docker logs heritage-api

# 실시간 로그 확인
docker logs -f heritage-web
docker logs -f heritage-api
```

---

## 컨테이너 중지

```bash
cd /home/carrotsw/heritage_services_app
docker-compose down
```

---

## 컨테이너 재시작

```bash
cd /home/carrotsw/heritage_services_app
docker-compose restart
```

---

## 접속 정보

- **웹 서버**: http://localhost:3001
- **API 서버**: http://localhost:8080

