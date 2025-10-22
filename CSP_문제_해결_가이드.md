# 🔧 CSP 문제 해결 가이드 - blob: URL 허용

## 📋 **문제 원인**
- **CSP(Content-Security-Policy)**에서 `img-src 'self' data: https:`만 허용
- **Flutter Web**이 내부적으로 사용하는 `blob:` 이미지 URL이 차단됨
- 콘솔 에러: `Refused to load the image 'blob:http://…' because it violates … "img-src 'self' data: https:"`

## ✅ **해결 방법**

### 1. **Flutter 웹 앱 CSP 수정** (완료됨)
`my_cross_app/web/index.html`의 CSP 메타 태그를 다음과 같이 수정:

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  img-src 'self' data: https: http: blob:;
  media-src 'self' data: https: blob:;
  connect-src 'self' http: https: ws: wss:;
  script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval';
  style-src 'self' 'unsafe-inline';
  font-src 'self' data:;
  frame-ancestors 'self';
">
```

**핵심 변경사항**: `img-src`에 `blob:` 추가

### 2. **Nginx 설정** (배포 환경용)
`nginx.conf` 파일에 CSP 헤더 추가:

```nginx
add_header Content-Security-Policy "
  default-src 'self';
  img-src 'self' data: https: http: blob:;
  media-src 'self' data: https: blob:;
  connect-src 'self' http: https: ws: wss:;
  script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval';
  style-src 'self' 'unsafe-inline';
  font-src 'self' data:;
  frame-ancestors 'self';
" always;
```

### 3. **Docker Compose 배포**

#### A. 전체 서비스 배포
```bash
cd /home/carrotsw/heritage_services_app
docker-compose up -d
```

#### B. 웹 앱만 재배포 (CSP 변경사항 적용)
```bash
# 웹 컨테이너만 재빌드 및 재시작
docker-compose build --no-cache heritage-web
docker-compose up -d heritage-web
```

#### C. API 서버만 재배포 (이미지 프록시 기능 포함)
```bash
# API 서버만 재빌드 및 재시작
docker-compose build --no-cache heritage-api
docker-compose up -d heritage-api
```

### 4. **배포 확인**

#### A. 서비스 상태 확인
```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs heritage-web
docker-compose logs heritage-api
```

#### B. 웹 앱 접속 테스트
1. `http://210.117.181.115:3001/#/home` 접속
2. `Ctrl+Shift+R`로 강제 새로고침 (캐시 삭제)
3. 브라우저 개발자 도구(F12) → Console 탭에서 CSP 에러 확인
4. Network 탭에서 `blob:` 요청이 `(blocked:csp)` 없이 정상 로드되는지 확인

#### C. 이미지 프록시 테스트
```bash
# API 서버 상태 확인
curl http://210.117.181.115:8080/health
curl http://210.117.181.115:8080/image/proxy/health
```

## 🎯 **성공 기준**

### ✅ **성공 시나리오**
- 브라우저 콘솔에 CSP 관련 에러가 사라짐
- Network 탭에서 `blob:` 요청이 정상 로드됨
- 이미지가 깨진 아이콘 대신 실제 사진이 표시됨
- Firebase Storage 이미지와 FastAPI 프록시 이미지 모두 정상 표시

### ❌ **실패 시 체크리스트**
1. **CSP 설정 확인**: `img-src`에 `blob:`이 포함되어 있는지
2. **Nginx 설정 확인**: CSP 헤더가 올바르게 설정되었는지
3. **컨테이너 재시작**: 설정 변경 후 컨테이너가 재시작되었는지
4. **브라우저 캐시**: 강제 새로고침으로 캐시를 삭제했는지

## 🔍 **디버깅 방법**

### 1. **브라우저 개발자 도구**
- **Console**: CSP 에러 메시지 확인
- **Network**: `blob:` 요청 상태 확인
- **Security**: CSP 정책 확인

### 2. **서버 로그 확인**
```bash
# Nginx 로그
docker-compose logs heritage-web

# API 서버 로그
docker-compose logs heritage-api
```

### 3. **CSP 정책 테스트**
```bash
# CSP 헤더 확인
curl -I http://210.117.181.115:3001/
```

## 📁 **배포 파일 목록**

### 수정된 파일들
- ✅ `my_cross_app/web/index.html` - CSP 메타 태그 수정
- ✅ `nginx.conf` - Nginx CSP 헤더 설정
- ✅ `docker-compose.yml` - 컨테이너 설정
- ✅ `server/Dockerfile` - API 서버 컨테이너 설정
- ✅ `my_cross_app/build/web/` - CSP 수정된 웹 앱 빌드

### 배포 명령어
```bash
# 1. 전체 재배포
docker-compose down
docker-compose up -d

# 2. 웹 앱만 재배포 (CSP 변경사항)
docker-compose build --no-cache heritage-web
docker-compose up -d heritage-web

# 3. API 서버만 재배포 (이미지 프록시)
docker-compose build --no-cache heritage-api
docker-compose up -d heritage-api
```

이제 배포된 환경에서도 이미지가 정상적으로 표시될 것입니다! 🎉
