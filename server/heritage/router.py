"""
Heritage API 라우터
/heritage/* 엔드포인트 정의
"""
from fastapi import APIRouter
from fastapi.responses import Response
from typing import Optional
from .service import fetch_heritage_list, fetch_heritage_detail

router = APIRouter(tags=["Heritage"])


@router.head("/list")
async def heritage_list_head():
    """
    국가유산 목록 HEAD 요청 (연결 확인용)
    """
    return Response(status_code=200)


@router.get("/list")
async def heritage_list(
    keyword: Optional[str] = None,
    kind: Optional[str] = None,
    region: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    """
    국가유산 목록 조회

    - **keyword**: 유산명 검색
    - **kind**: 종목 코드 (ccbaKdcd)
    - **region**: 지역 코드 (ccbaCtcd)
    - **page**: 페이지 번호 (기본값: 1)
    - **size**: 페이지당 항목 수 (기본값: 20)
    """
    return await fetch_heritage_list(keyword, kind, region, page, size)


@router.head("/detail")
async def heritage_detail_head():
    """
    국가유산 상세 정보 HEAD 요청 (연결 확인용)
    """
    return Response(status_code=200)


@router.get("/detail")
async def heritage_detail(ccbaKdcd: str, ccbaAsno: str, ccbaCtcd: str):
    """
    국가유산 상세 정보 조회

    - **ccbaKdcd**: 종목 코드
    - **ccbaAsno**: 지정번호
    - **ccbaCtcd**: 시도 코드
    """
    return await fetch_heritage_detail(ccbaKdcd, ccbaAsno, ccbaCtcd)
