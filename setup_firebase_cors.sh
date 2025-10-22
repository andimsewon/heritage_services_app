#!/bin/bash

# Firebase Storage CORS 설정 스크립트
# Firebase CLI가 설치되어 있어야 합니다: npm install -g firebase-tools

echo "🔥 Firebase Storage CORS 설정을 시작합니다..."

# Firebase 프로젝트 ID 확인
PROJECT_ID="heritageservices-23a6c"

echo "📋 프로젝트 ID: $PROJECT_ID"

# Firebase CLI 로그인 확인
if ! firebase projects:list > /dev/null 2>&1; then
    echo "❌ Firebase CLI에 로그인되어 있지 않습니다."
    echo "다음 명령어로 로그인하세요: firebase login"
    exit 1
fi

# CORS 설정 파일이 존재하는지 확인
if [ ! -f "firebase_storage_cors.json" ]; then
    echo "❌ firebase_storage_cors.json 파일을 찾을 수 없습니다."
    exit 1
fi

echo "🚀 Firebase Storage CORS 설정을 적용합니다..."

# Firebase Storage CORS 설정 적용
gsutil cors set firebase_storage_cors.json gs://$PROJECT_ID.appspot.com

if [ $? -eq 0 ]; then
    echo "✅ Firebase Storage CORS 설정이 성공적으로 적용되었습니다!"
    echo "📝 설정 내용:"
    cat firebase_storage_cors.json
    echo ""
    echo "🔄 브라우저 캐시를 지우고 페이지를 새로고침하세요."
else
    echo "❌ CORS 설정 적용에 실패했습니다."
    echo "Firebase CLI와 gsutil이 설치되어 있는지 확인하세요."
    echo "설치 방법:"
    echo "  - Firebase CLI: npm install -g firebase-tools"
    echo "  - gsutil: https://cloud.google.com/storage/docs/gsutil_install"
fi
