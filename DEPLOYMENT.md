# 배포 가이드

## 올바른 배포 명령어

### 방법 1: 배포 스크립트 사용 (권장)

```bash
cd /home/carrotsw/heritage_services_app
./deploy.sh
```

### 방법 2: 수동 배포

```bash
# 1. Flutter 빌드
cd /home/carrotsw/heritage_services_app/my_cross_app
flutter clean && flutter build web --release

# 2. Docker 컨테이너 중지 및 제거
cd /home/carrotsw/heritage_services_app
docker-compose down heritage-web
docker rm -f heritage-web 2>/dev/null || true

# 3. heritage-api 빌드 (변경사항이 있는 경우)
docker-compose build --no-cache heritage-api

# 4. heritage-web 컨테이너 시작 (빌드된 파일이 자동으로 마운트됨)
docker-compose up -d heritage-web

# 5. 컨테이너 재시작 (필요한 경우)
docker-compose restart heritage-web
```

## 중요 사항

⚠️ **주의**: `heritage-web` 서비스는 `nginx:alpine` 이미지를 사용하므로 **빌드가 필요 없습니다**.
- `docker-compose build heritage-web` 명령어는 실행하지 마세요.
- 빌드된 파일은 `./my_cross_app/build/web` 디렉토리에 있고, 이것이 볼륨으로 마운트됩니다.

## 문제 해결

### 빌드 오류
- `Icons.assignment_add_outlined` → `Icons.assignment_outlined`로 수정됨
- `CardTheme` → `CardThemeData`로 수정됨

### Docker 오류
- `heritage-web`은 빌드가 필요 없는 서비스입니다.
- 빌드된 파일이 `./my_cross_app/build/web`에 있는지 확인하세요.

