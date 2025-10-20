"""
미들웨어 설정
CORS 및 기타 미들웨어
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import settings


def setup_middleware(app: FastAPI):
    """FastAPI 앱에 미들웨어 추가"""

    # CORS 미들웨어
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=settings.CORS_CREDENTIALS,
        allow_methods=settings.CORS_METHODS,
        allow_headers=settings.CORS_HEADERS,
    )

    print(f"[Middleware] CORS 설정 완료 (Origins: {settings.CORS_ORIGINS})")
