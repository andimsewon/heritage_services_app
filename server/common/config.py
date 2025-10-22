"""
애플리케이션 설정
환경 변수 및 글로벌 설정
"""
import os
from typing import List

class Settings:
    """애플리케이션 설정"""

    # API 기본 정보
    APP_TITLE: str = "Heritage Services API"
    APP_VERSION: str = "2.0.0"
    APP_DESCRIPTION: str = """
    국가유산 관리 및 AI 손상 탐지 통합 API

    ## 기능
    - 국가유산청 API 프록시 (XML → JSON 변환)
    - PyTorch 기반 한옥 손상 탐지
    - CORS 지원
    """

    # CORS 설정
    CORS_ORIGINS: List[str] = [
        "http://210.117.181.115:3001",
        "http://localhost:3001",
        "http://127.0.0.1:3001",
        "vscode-webview://*",  # VSCode 편집기 미리보기
    ]
    CORS_CREDENTIALS: bool = True
    CORS_METHODS: List[str] = ["*"]
    CORS_HEADERS: List[str] = ["*"]

    # 국가유산청 API
    KHS_BASE_URL: str = "http://www.khs.go.kr/cha"

    # 서버 설정
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8080"))
    RELOAD: bool = os.getenv("RELOAD", "false").lower() == "true"


settings = Settings()
