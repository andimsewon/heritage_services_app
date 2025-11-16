"""
이미지 프록시 라우터
Firebase Storage 이미지를 서버를 통해 프록시하여 CORS 문제 해결
"""

from fastapi import APIRouter, HTTPException, Response
from fastapi.responses import StreamingResponse
import httpx
import io
from typing import Optional
from functools import lru_cache
import hashlib
import time

router = APIRouter()

# 간단한 메모리 캐시 (LRU 방식)
_image_cache = {}
_cache_max_size = 100  # 최대 캐시 항목 수
_cache_ttl = 3600  # 1시간 (초)


def _get_cache_key(url: str) -> str:
    """URL을 기반으로 캐시 키 생성"""
    return hashlib.md5(url.encode()).hexdigest()


def _clean_cache():
    """오래된 캐시 항목 제거"""
    current_time = time.time()
    keys_to_remove = []
    
    for key, (data, timestamp) in _image_cache.items():
        if current_time - timestamp > _cache_ttl:
            keys_to_remove.append(key)
    
    for key in keys_to_remove:
        del _image_cache[key]
    
    # 캐시 크기 제한
    if len(_image_cache) > _cache_max_size:
        # 가장 오래된 항목 제거
        sorted_items = sorted(_image_cache.items(), key=lambda x: x[1][1])
        for key, _ in sorted_items[:len(_image_cache) - _cache_max_size]:
            del _image_cache[key]


@router.get("/proxy")
async def proxy_image(url: str, maxWidth: Optional[int] = None, maxHeight: Optional[int] = None, quality: Optional[int] = None):
    """
    Firebase Storage 이미지를 프록시하여 CORS 문제 해결
    
    Args:
        url: Firebase Storage 이미지 URL
        maxWidth: 최대 너비 (선택)
        maxHeight: 최대 높이 (선택)
        quality: 이미지 품질 (1-100, 선택)
        
    Returns:
        이미지 데이터 (StreamingResponse)
    """
    if not url:
        raise HTTPException(status_code=400, detail="URL이 필요합니다")
    
    # Firebase Storage URL 검증
    if not url.startswith("https://firebasestorage.googleapis.com/"):
        raise HTTPException(status_code=400, detail="유효하지 않은 Firebase Storage URL입니다")
    
    # 캐시 키 생성 (URL + 파라미터 포함)
    cache_key = _get_cache_key(f"{url}:{maxWidth}:{maxHeight}:{quality}")
    
    # 캐시 확인
    _clean_cache()
    if cache_key in _image_cache:
        cached_data, _ = _image_cache[cache_key]
        return StreamingResponse(
            io.BytesIO(cached_data),
            media_type="image/jpeg",
            headers={
                "Cache-Control": "public, max-age=31536000",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "*",
                "X-Cache": "HIT",
            }
        )
    
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=10.0)) as client:
            response = await client.get(url)
            response.raise_for_status()
            
            image_data = response.content
            
            # 이미지 리사이즈/압축 (PIL 사용)
            if maxWidth or maxHeight or quality:
                try:
                    from PIL import Image
                    img = Image.open(io.BytesIO(image_data))
                    
                    # 리사이즈
                    if maxWidth or maxHeight:
                        original_width, original_height = img.size
                        if maxWidth and maxHeight:
                            # 비율 유지하면서 리사이즈
                            ratio = min(maxWidth / original_width, maxHeight / original_height)
                            new_width = int(original_width * ratio)
                            new_height = int(original_height * ratio)
                        elif maxWidth:
                            ratio = maxWidth / original_width
                            new_width = maxWidth
                            new_height = int(original_height * ratio)
                        else:
                            ratio = maxHeight / original_height
                            new_width = int(original_width * ratio)
                            new_height = maxHeight
                        
                        if new_width < original_width or new_height < original_height:
                            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                    
                    # 품질 조정
                    output = io.BytesIO()
                    quality_value = quality if quality and 1 <= quality <= 100 else 85
                    img_format = img.format or "JPEG"
                    if img_format == "PNG":
                        img.save(output, format="PNG", optimize=True)
                    else:
                        img.save(output, format="JPEG", quality=quality_value, optimize=True)
                    image_data = output.getvalue()
                except Exception as e:
                    # 이미지 처리 실패 시 원본 사용
                    print(f"[Image Proxy] 이미지 처리 실패, 원본 사용: {e}")
            
            # 캐시에 저장
            if len(image_data) < 5 * 1024 * 1024:  # 5MB 이하만 캐시
                _image_cache[cache_key] = (image_data, time.time())
            
            # 이미지 데이터를 스트리밍으로 반환
            return StreamingResponse(
                io.BytesIO(image_data),
                media_type=response.headers.get("content-type", "image/jpeg"),
                headers={
                    "Cache-Control": "public, max-age=31536000",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET",
                    "Access-Control-Allow-Headers": "*",
                    "X-Cache": "MISS",
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
