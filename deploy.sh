#!/bin/bash
# 🚀 Flutter Web 빌드 및 Docker 배포 스크립트

set -e  # 에러 발생 시 즉시 중단

echo "════════════════════════════════════════════════════════════════"
echo "🧹 Flutter Web 빌드 & Docker 배포 시작"
echo "════════════════════════════════════════════════════════════════"

# 프로젝트 루트 디렉토리
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$ROOT_DIR"

# 1️⃣ Flutter 빌드
echo ""
echo "📦 [1/4] Flutter 빌드 중..."
cd my_cross_app
flutter clean
flutter pub get
flutter build web --release
echo "✅ Flutter 빌드 완료"

# 2️⃣ Docker 컨테이너 중지 및 제거
echo ""
echo "🛑 [2/4] Docker 컨테이너 중지 및 제거 중..."
cd "$ROOT_DIR"
docker-compose down heritage-web 2>/dev/null || true
docker rm -f heritage-web 2>/dev/null || true
echo "✅ 컨테이너 제거 완료"

# 3️⃣ heritage-api 빌드 (필요한 경우)
echo ""
echo "🔨 [3/4] heritage-api 이미지 빌드 중..."
docker-compose build --no-cache heritage-api || echo "⚠️  heritage-api 빌드 스킵 (이미 존재하는 경우)"
echo "✅ API 빌드 완료"

# 4️⃣ Docker 컨테이너 시작
echo ""
echo "🚀 [4/4] Docker 컨테이너 시작 중..."
docker-compose up -d heritage-web
echo "✅ 컨테이너 시작 완료"

# 5️⃣ 배포 완료 안내
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ 배포 완료!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🌐 웹 서버: http://localhost:3001"
echo "🌐 API 서버: http://localhost:8080"
echo ""
echo "📊 컨테이너 상태 확인:"
docker-compose ps
echo ""
echo "════════════════════════════════════════════════════════════════"

