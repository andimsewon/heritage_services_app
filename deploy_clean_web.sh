#!/bin/bash
# 🚀 Flutter Web 클린 배포 스크립트 (HTML 렌더러 전용)
# HTTP 환경에서 CanvasKit 충돌 방지

set -e  # 에러 발생 시 즉시 중단

echo "════════════════════════════════════════════════════════════════"
echo "🧹 Flutter Web 클린 빌드 & 배포 시작"
echo "════════════════════════════════════════════════════════════════"

# 1️⃣ Flutter 프로젝트로 이동
cd /home/dbs0510/heritage_services_app_dbs0510/my_cross_app

# 2️⃣ 기존 빌드 캐시 완전 삭제
echo ""
echo "📦 [1/5] 기존 빌드 캐시 삭제 중..."
flutter clean
rm -rf build
rm -rf .dart_tool
echo "✅ 캐시 삭제 완료"

# 3️⃣ HTML 렌더러로 새로 빌드 (CanvasKit 제외)
echo ""
echo "🔨 [2/5] HTML 렌더러로 빌드 중..."
flutter build web --pwa-strategy=none
echo "✅ 빌드 완료"

# 4️⃣ Service Worker 및 CanvasKit 파일 제거 + HTML 렌더러 강제 설정
echo ""
echo "🗑️  [3/5] 불필요한 파일 제거 및 렌더러 수정 중..."
cd build/web
rm -f flutter_service_worker.js
rm -rf canvaskit

# 🔥 핵심: flutter_bootstrap.js에서 "canvaskit" → "html"로 강제 변경
sed -i 's/"renderer":"canvaskit"/"renderer":"html"/g' flutter_bootstrap.js

# 검증
if grep -q '"renderer":"html"' flutter_bootstrap.js; then
  echo "✅ HTML 렌더러로 변경 완료"
else
  echo "⚠️  렌더러 변경 실패 - 수동 확인 필요"
fi

echo "✅ Service Worker & CanvasKit 제거 완료"

# 5️⃣ Docker 컨테이너 재시작 (Nginx 캐시 자동 클리어)
echo ""
echo "🔄 [4/5] Docker 컨테이너 재시작 중..."
cd /home/dbs0510/heritage_services_app_dbs0510
docker-compose restart heritage-web
echo "✅ 컨테이너 재시작 완료"

# 6️⃣ 배포 완료 안내
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ [5/5] 배포 완료!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🌐 서버 주소: http://210.117.181.115:3001"
echo ""
echo "⚠️  중요: 브라우저 캐시를 반드시 삭제하세요!"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  🔧 브라우저 Service Worker 삭제 방법:                      │"
echo "│                                                             │"
echo "│  1️⃣  Chrome 주소창에 입력:                                  │"
echo "│      chrome://serviceworker-internals                      │"
echo "│                                                             │"
echo "│  2️⃣  'heritage' 검색 → Unregister 클릭                      │"
echo "│                                                             │"
echo "│  3️⃣  F12 → Application 탭 → Storage →                       │"
echo "│      'Clear site data' 클릭                                │"
echo "│                                                             │"
echo "│  4️⃣  Ctrl + Shift + R (강력 새로고침)                       │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "════════════════════════════════════════════════════════════════"
