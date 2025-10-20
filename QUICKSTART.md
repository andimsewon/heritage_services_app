# 🚀 빠른 시작 가이드

Heritage Services App을 **3분 안에** 실행하는 방법

---

## ⚡ 3단계로 시작하기

### 1️⃣ Docker로 백엔드 서버 실행

```bash
cd /home/dbs0510/heritage_services_app

# Docker 컨테이너 빌드 및 실행 (최초 1회만 빌드)
docker-compose up --build -d

# ✅ 서버 실행 확인
curl http://localhost:8080/health
```

**예상 출력:**
```json
{"status":"ok","service":"Heritage Services API"}
```

---

### 2️⃣ Flutter 앱 실행

```bash
cd my_cross_app

# 웹으로 실행
flutter run -d chrome

# 또는 안드로이드로 실행
flutter run -d android
```

**자동 연결됨:**
- 웹: `http://localhost:8080`
- 안드로이드 에뮬레이터: `http://10.0.2.2:8080`

---

### 3️⃣ 로그인 및 테스트

1. **로그인 화면**에서:
   - 이메일: `admin@heritage.local`
   - 비밀번호: `admin123!`

2. **홈 화면** → **조사 시스템** 클릭

3. **유산 검색**: "불국사" 검색해보기

4. **AI 손상 탐지**: 사진 찍어서 분석해보기

---

## 🎯 완료!

이제 다음 기능을 사용할 수 있습니다:

- ✅ 국가유산 검색 및 상세 정보
- ✅ AI 기반 손상 탐지
- ✅ 조사 양식 작성
- ✅ Firebase 사진 업로드

---

## 📚 상세 문서

- [Docker 배포 가이드](DOCKER_DEPLOYMENT.md)
- [서버 API 문서](http://localhost:8080/docs)
- [프로젝트 README](README.md)

---

## 🛑 서버 중지

```bash
cd /home/dbs0510/heritage_services_app
docker-compose down
```

---

## 🐛 문제 해결

### 포트 8080이 사용 중이면?
```bash
# 8080 포트 사용 프로세스 찾기
sudo lsof -i :8080

# 프로세스 종료
sudo kill -9 <PID>
```

### Flutter 앱이 서버에 연결 안 되면?
```bash
# 서버 로그 확인
docker-compose logs -f

# 네트워크 확인
curl http://localhost:8080/health
```

### AI 모델 로드 실패?
```bash
# 모델 파일 확인 (552MB)
ls -lh server/ai/hanok_damage_model.pt

# Docker 재빌드
docker-compose up --build -d
```

---

**🎉 즐거운 개발 되세요!**
