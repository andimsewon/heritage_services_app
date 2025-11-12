#!/usr/bin/env python3
"""
AI 모델 로드 확인 및 진단 스크립트
FastAPI 서버와 독립적으로 모델 로드를 테스트합니다.
"""
import os
import sys

# 현재 디렉토리를 PYTHONPATH에 추가
sys.path.insert(0, os.path.dirname(__file__))

from ai.loader import (
    get_id2label,
    get_resolved_model_path,
    is_model_loaded,
    load_ai_model,
    resolve_model_path,
)


def check_dependencies():
    """필요한 의존성 확인"""
    print("\n" + "=" * 60)
    print("🔍 의존성 확인")
    print("=" * 60)

    try:
        import torch
        print(f"✅ PyTorch: {torch.__version__}")
        print(f"   - CUDA 사용 가능: {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            print(f"   - CUDA 버전: {torch.version.cuda}")
    except ImportError as e:
        print(f"❌ PyTorch: {e}")
        return False

    try:
        from transformers import DetaImageProcessor  # noqa: F401
        print("✅ Transformers: 설치됨")
    except ImportError as e:
        print(f"❌ Transformers: {e}")
        return False

    try:
        from PIL import Image  # noqa: F401
        print("✅ Pillow: 설치됨")
    except ImportError as e:
        print(f"❌ Pillow: {e}")
        return False

    return True


def check_model_file():
    """모델 파일 존재 여부 및 크기 확인"""
    print("\n" + "=" * 60)
    print("📁 모델 파일 확인")
    print("=" * 60)

    model_path = resolve_model_path()
    if not model_path:
        print("❌ 모델 경로를 찾을 수 없습니다. MODEL_PATH 환경변수 또는 server/ai 폴더를 확인하세요.")
        return False

    print(f"모델 경로: {model_path}")

    if not os.path.exists(model_path):
        print("❌ 모델 파일이 존재하지 않습니다!")
        print(f"   예상 위치: {model_path}")
        return False

    file_size = os.path.getsize(model_path)
    file_size_mb = file_size / (1024 * 1024)
    print("✅ 모델 파일 존재")
    print(f"   크기: {file_size_mb:.1f} MB")

    if file_size < 1024 * 1024:  # 1MB 미만
        print("⚠️  경고: 모델 파일이 너무 작습니다 (손상되었을 수 있음)")

    return True


def test_model_loading():
    """실제 모델 로드 테스트"""
    print("\n" + "=" * 60)
    print("🚀 모델 로드 테스트")
    print("=" * 60)

    print("모델 로딩 중...")
    success = load_ai_model()

    if success and is_model_loaded():
        print("✅ 모델 로드 성공!")

        resolved = get_resolved_model_path()
        if resolved:
            print(f"   사용된 모델: {resolved}")

        id2label = get_id2label()
        if id2label:
            print(f"\n클래스 레이블 ({len(id2label)}개):")
            for id, label in id2label.items():
                print(f"   {id}: {label}")

        return True
    else:
        print("❌ 모델 로드 실패!")
        return False


def test_api_status():
    """FastAPI 서버의 AI 모델 상태 확인"""
    print("\n" + "=" * 60)
    print("🌐 FastAPI 서버 AI 상태 확인")
    print("=" * 60)

    try:
        import requests
        response = requests.get("http://localhost:8080/ai/model/status", timeout=5)

        if response.status_code == 200:
            data = response.json()
            print("✅ FastAPI 응답:")
            print(f"   상태: {data.get('status')}")
            print(f"   사용 가능: {data.get('available')}")

            if data.get('labels'):
                print(f"   레이블: {data.get('labels')}")

            return data.get('available', False)
        else:
            print(f"❌ FastAPI 응답 오류: {response.status_code}")
            return False

    except requests.RequestException as e:
        print(f"❌ FastAPI 서버 연결 실패: {e}")
        print("   (서버가 실행 중인지 확인하세요)")
        return False
    except ImportError:
        print("⚠️  requests 라이브러리가 설치되지 않아 API 테스트를 건너뜁니다")
        return None


def main():
    """메인 진단 함수"""
    print("\n" + "=" * 60)
    print("🔧 AI 모델 로드 진단 도구")
    print("=" * 60)

    results = {
        "dependencies": check_dependencies(),
        "model_file": check_model_file(),
        "model_loading": False,
        "api_status": None,
    }

    if results["dependencies"] and results["model_file"]:
        results["model_loading"] = test_model_loading()

    results["api_status"] = test_api_status()

    # 최종 요약
    print("\n" + "=" * 60)
    print("📊 진단 요약")
    print("=" * 60)

    all_passed = True

    if results["dependencies"]:
        print("✅ 의존성 확인: 통과")
    else:
        print("❌ 의존성 확인: 실패")
        all_passed = False

    if results["model_file"]:
        print("✅ 모델 파일: 존재")
    else:
        print("❌ 모델 파일: 없음")
        all_passed = False

    if results["model_loading"]:
        print("✅ 모델 로드: 성공")
    else:
        print("❌ 모델 로드: 실패")
        all_passed = False

    if results["api_status"] is True:
        print("✅ FastAPI 상태: 모델 사용 가능")
    elif results["api_status"] is False:
        print("⚠️  FastAPI 상태: 모델 미사용 (재시작 필요)")
        all_passed = False
    else:
        print("⚠️  FastAPI 상태: 확인 불가")

    print("\n" + "=" * 60)

    if all_passed and results["api_status"] is True:
        print("✅ 모든 테스트 통과! AI 기능이 정상 작동합니다.")
        return 0
    else:
        print("⚠️  일부 테스트 실패. 위 메시지를 확인하세요.")

        if results["model_loading"] and results["api_status"] is False:
            print("\n💡 해결 방법:")
            print("   FastAPI 서버를 재시작하면 모델이 로드됩니다:")
            print("   1. 프로세스 종료: pkill -f 'uvicorn main:app'")
            print("   2. 서버 재시작: cd /home/dbs0510/heritage_services_app_dbs0510/server")
            print("                 python3 -m uvicorn main:app --host 0.0.0.0 --port 8080")

        return 1


if __name__ == "__main__":
    exit_code = main()
