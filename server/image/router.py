"""
이미지 프록시 라우터
Firebase Storage 이미지를 서버를 통해 프록시하여 CORS 문제 해결
"""

from fastapi import APIRouter, HTTPException, Response
from fastapi.responses import StreamingResponse
import httpx
import io
from typing import Optional

router = APIRouter()


@router.get("/proxy")
async def proxy_image(url: str):
    """
    Firebase Storage 이미지를 프록시하여 CORS 문제 해결
    
    Args:
        url: Firebase Storage 이미지 URL
        
    Returns:
        이미지 데이터 (StreamingResponse)
    """
    if not url:
        raise HTTPException(status_code=400, detail="URL이 필요합니다")
    
    # Firebase Storage URL 검증
    if not url.startswith("https://firebasestorage.googleapis.com/"):
        raise HTTPException(status_code=400, detail="유효하지 않은 Firebase Storage URL입니다")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            
            # 이미지 데이터를 스트리밍으로 반환
            return StreamingResponse(
                io.BytesIO(response.content),
                media_type=response.headers.get("content-type", "image/jpeg"),
                headers={
                    "Cache-Control": "public, max-age=31536000",  # 1년 캐시
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET",
                    "Access-Control-Allow-Headers": "*",
                }
            )
            
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="이미지 로드 시간 초과")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"이미지 로드 실패: {e.response.status_code}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"이미지 프록시 오류: {str(e)}")


@router.get("/proxy/health")
async def proxy_health():
    """이미지 프록시 서비스 상태 확인"""
    return {"status": "ok", "service": "Image Proxy"}


@router.get("/proxy/info")
async def proxy_info():
    """이미지 프록시 서비스 정보"""
    return {
        "service": "Firebase Storage Image Proxy",
        "description": "Firebase Storage 이미지를 CORS 문제 없이 프록시",
        "usage": "/image/proxy?url=<firebase_storage_url>",
        "example": "/image/proxy?url=https://firebasestorage.googleapis.com/..."
    }
