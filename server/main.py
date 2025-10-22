from fastapi import FastAPI
from contextlib import asynccontextmanager

# 라우터 임포트
from heritage.router import router as heritage_router
from ai.router import router as ai_router
from image.router import router as image_router

# 공통 설정
from common.config import settings
from common.middleware import setup_middleware

# AI 모델 로더
from ai.loader import load_ai_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    애플리케이션 생명주기 관리
    - startup: AI 모델 로드
    - shutdown: 리소스 정리
    """
    # Startup
    print("=" * 60)
    print(f"🚀 {settings.APP_TITLE} v{settings.APP_VERSION} 시작")
    print("=" * 60)

    # AI 모델 로드
    print("\n[Startup] AI 모델 로딩 중...")
    loaded = load_ai_model()
    if loaded:
        print("[Startup] ✅ AI 모델 로드 성공")
    else:
        print("[Startup] ⚠️  AI 모델 로드 실패 (AI 기능이 제한될 수 있습니다)")

    print("\n[Startup] 서버 준비 완료!")
    print(f"[Startup] 서버 주소: http://{settings.HOST}:{settings.PORT}")
    print(f"[Startup] API 문서: http://{settings.HOST}:{settings.PORT}/docs")
    print("=" * 60 + "\n")

    yield

    # Shutdown
    print("\n[Shutdown] 서버 종료 중...")


# FastAPI 앱 생성
app = FastAPI(
    title=settings.APP_TITLE,
    version=settings.APP_VERSION,
    description=settings.APP_DESCRIPTION,
    lifespan=lifespan,
)

# 미들웨어 설정 (CORS 등)
setup_middleware(app)

# 라우터 등록
app.include_router(heritage_router, prefix="/heritage", tags=["Heritage"])
app.include_router(ai_router, prefix="/ai", tags=["AI Detection"])
app.include_router(image_router, prefix="/image", tags=["Image Proxy"])


# 루트 엔드포인트
@app.get("/", tags=["Root"])
async def root():
    """API 루트 - 서버 정보 반환"""
    return {
        "service": settings.APP_TITLE,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
        "endpoints": {
            "heritage_list": "/heritage/list",
            "heritage_detail": "/heritage/detail",
            "ai_status": "/ai/model/status",
            "ai_infer": "/ai/damage/infer",
            "image_proxy": "/image/proxy",
        }
    }


@app.get("/health", tags=["Health"])
async def health():
    """헬스 체크 엔드포인트"""
    return {"status": "ok", "service": settings.APP_TITLE}


# 서버 직접 실행 (개발용)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
    )
