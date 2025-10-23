# 🔧 Service Worker 및 CSP 오류 해결 가이드

## 🚨 **발생한 오류들**

### 1. Service Worker API unavailable 오류
```
Exception while loading service worker: Error: Service Worker API unavailable.
The current context is NOT secure.
```

### 2. Google Analytics CSP 위반 오류
```
Refused to load the script 'https://www.googletagmanager.com/gtag/js?l=dataLayer&id=G-4RG8QBWDPG' 
because it violates the following Content Security Policy directive
```

## ✅ **해결 방법**

### A. Service Worker 비활성화
- **파일**: `my_cross_app/build/web/flutter_bootstrap.js`
- **변경사항**: Service Worker 설정을 주석 처리하여 HTTP 환경에서 오류 방지

```javascript
_flutter.loader.load({
  // Service Worker 비활성화 (HTTP 환경에서 오류 방지)
  // serviceWorkerSettings: {
  //   serviceWorkerVersion: "3970512152"
  // }
});
```

### B. Google Analytics 제거
- **파일**: `my_cross_app/web/index.html`
- **변경사항**: Firebase Analytics 관련 코드 제거

```javascript
// Analytics 제거된 Firebase 설정
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.3.0/firebase-app.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/12.3.0/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/12.3.0/firebase-storage.js";
// Analytics import 제거됨

const firebaseConfig = {
  // measurementId 제거됨
  apiKey: "AIzaSyAg4BcMA1qeRgQfV9pTxbeiwSeo4vSiP18",
  authDomain: "heritageservices-23a6c.firebaseapp.com",
  projectId: "heritageservices-23a6c",
  storageBucket: "heritageservices-23a6c.firebasestorage.app",
  messagingSenderId: "661570902154",
  appId: "1:661570902154:web:17d16562436aa476da3573"
};
```

### C. CSP 설정 강화
- **파일**: `my_cross_app/web/index.html` 및 `nginx.conf`
- **변경사항**: `script-src-elem` 지시어 추가

```html
<meta http-equiv="Content-Security-Policy" content="default-src *; img-src * data: blob:; media-src * data: blob:; connect-src *; script-src * 'unsafe-inline' 'unsafe-eval'; style-src * 'unsafe-inline'; font-src * data:; frame-ancestors *; script-src-elem * 'unsafe-inline' 'unsafe-eval';">
```

## 🚀 **배포 실행 명령어**

### 1. **새 배포 파일 업로드**
```bash
# service_worker_fix.tar.gz 파일을 서버에 업로드
scp service_worker_fix.tar.gz user@210.117.181.115:/path/to/deployment/
```

### 2. **서버에서 배포 실행**
```bash
# 서버 접속
ssh user@210.117.181.115

# 기존 서비스 중지
docker-compose down

# 새 파일 압축 해제
tar -xzf service_worker_fix.tar.gz

# 웹 앱 파일 복사
cp -r my_cross_app/build/web/* /path/to/your/web/directory/

# Nginx 설정 적용
cp nginx.conf /etc/nginx/conf.d/default.conf
nginx -t
systemctl restart nginx

# Docker 컨테이너 재시작
docker-compose up -d
```

### 3. **테스트 및 확인**
```bash
# 웹 앱 접속
# http://210.117.181.115:3001/#/home

# 브라우저 개발자 도구에서 확인
# F12 → Console 탭에서 오류 확인
# - Service Worker 오류가 사라져야 함
# - Google Analytics CSP 오류가 사라져야 함
```

## 📁 **수정된 파일 목록**

1. **`my_cross_app/build/web/flutter_bootstrap.js`**
   - Service Worker 설정 비활성화

2. **`my_cross_app/web/index.html`**
   - Google Analytics 제거
   - CSP 설정에 `script-src-elem` 추가

3. **`nginx.conf`**
   - CSP 헤더에 `script-src-elem` 지시어 추가

## 🎯 **예상 결과**

배포 완료 후:
- ✅ Service Worker 오류가 완전히 사라짐
- ✅ Google Analytics CSP 위반 오류가 사라짐
- ✅ 웹 앱이 HTTP 환경에서 정상 작동
- ✅ 모든 기능이 오류 없이 작동

## 🔍 **문제 해결**

### 여전히 오류가 발생한다면:
1. **브라우저 캐시 완전 삭제**: `Ctrl+Shift+Delete`
2. **시크릿 모드에서 테스트**: 새 시크릿 창에서 접속
3. **컨테이너 재시작**: `docker-compose restart heritage-web`
4. **Nginx 설정 확인**: `nginx -t`로 설정 문법 확인

이제 오류 없는 웹 앱을 배포할 수 있습니다! 🚀


