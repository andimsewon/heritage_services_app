"""
Heritage API 비즈니스 로직
국가유산청 API 호출 및 데이터 변환
"""
import httpx
import xmltodict
from fastapi import HTTPException
from typing import Optional
from .utils import pick, first_non_empty, extract_items

KHS_BASE = "http://www.khs.go.kr/cha"


async def fetch_heritage_list(
    keyword: Optional[str] = None,
    kind: Optional[str] = None,
    region: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> dict:
    """국가유산 목록 조회"""
    param_variants = [
        {"pageIndex": str(page), "pageUnit": str(size)},
        {"pageNo": str(page), "numOfRows": str(size)},
        {},
    ]

    base_common = {}
    if keyword:
        base_common["ccbaMnm1"] = keyword.strip()
    if kind:
        base_common["ccbaKdcd"] = kind.strip()
    if region:
        base_common["ccbaCtcd"] = region.strip()

    last_error = None

    for variant in param_variants:
        params = {**variant, **base_common}
        url = f"{KHS_BASE}/SearchKindOpenapiList.do"

        try:
            async with httpx.AsyncClient(
                timeout=12.0,
                headers={"User-Agent": "heritage-proxy/1.0"},
                follow_redirects=True,
            ) as client:
                r = await client.get(url, params=params)

            print(f"[LIST] GET {r.request.url} -> {r.status_code}")

            if r.status_code != 200:
                last_error = HTTPException(502, f"KHS error {r.status_code}")
                continue

            data = xmltodict.parse(r.text)
            items_node = extract_items(data)

            if not items_node:
                continue

            items = []
            for e in items_node:
                ccbaKdcd = pick(e, "ccbaKdcd")
                ccbaAsno = pick(e, "ccbaAsno")
                ccbaCtcd = pick(e, "ccbaCtcd")
                kind_name = first_non_empty(pick(e, "ccmaName"), pick(e, "gcodeName"))
                name = pick(e, "ccbaMnm1", "미상")
                sojaeji = first_non_empty(
                    pick(e, "ccbaLcto"), pick(e, "ccbaLcad"), pick(e, "loc")
                )
                addr = first_non_empty(pick(e, "ccbaCtcdNm"), pick(e, "ccsiName"))

                items.append({
                    "id": f"{ccbaKdcd}-{ccbaAsno}-{ccbaCtcd}",
                    "kindCode": ccbaKdcd,
                    "kindName": kind_name,
                    "name": name,
                    "sojaeji": sojaeji,
                    "addr": addr,
                    "ccbaKdcd": ccbaKdcd,
                    "ccbaAsno": ccbaAsno,
                    "ccbaCtcd": ccbaCtcd,
                })

            # 전체 개수 추출
            total = 0
            for k in ["totalCount", "totalCnt", "totalcount", "total"]:
                result_dict = data.get("result", data)
                v = result_dict.get(k) if isinstance(result_dict, dict) else None
                if v and str(v).isdigit():
                    total = int(v)
                    break
            if total == 0:
                total = len(items)

            return {"items": items, "totalCount": total}

        except Exception as e:
            last_error = HTTPException(502, f"proxy error: {e}")

    if last_error:
        raise last_error
    return {"items": [], "totalCount": 0}


async def fetch_heritage_detail(
    ccbaKdcd: str,
    ccbaAsno: str,
    ccbaCtcd: str
) -> dict:
    """국가유산 상세 정보 조회"""
    url = f"{KHS_BASE}/SearchKindOpenapiDt.do"
    params = {"ccbaKdcd": ccbaKdcd, "ccbaAsno": ccbaAsno, "ccbaCtcd": ccbaCtcd}

    async with httpx.AsyncClient(
        timeout=12.0,
        headers={"User-Agent": "heritage-proxy/1.0"},
        follow_redirects=True,
    ) as client:
        r = await client.get(url, params=params)

    if r.status_code != 200:
        raise HTTPException(502, f"KHS error {r.status_code}")

    data = xmltodict.parse(r.text)
    return data
