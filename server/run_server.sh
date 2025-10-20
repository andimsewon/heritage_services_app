#!/bin/bash
# Heritage Services API 서버 실행 스크립트

echo "🚀 Heritage Services API 서버 시작..."
echo "================================================"
echo ""

# 가상환경 활성화 (필요한 경우)
# source venv/bin/activate

# 서버 실행
uvicorn main:app --host 0.0.0.0 --port 8080 --reload

# 옵션 설명:
# --host 0.0.0.0  : 모든 네트워크 인터페이스에서 접근 가능
# --port 8080     : 포트 8080 사용
# --reload        : 코드 변경 시 자동 재시작 (개발용)
