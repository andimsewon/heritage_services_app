from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx, os
import xmltodict

KHS_BASE = "http://www.khs.go.kr/cha"

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 배포 시 도메인 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 국가유산 목록(검색어/페이징)
@app.get("/heritage/list")
async def heritage_list(keyword: str | None = None, page: int = 1, size: int = 20):
    params = {
        "pageIndex": str(page),      # ※ 실제 파라미터명이 pageIndex/numOfRows가 아닐 수 있음(스펙 확인 필요)
        "pageUnit": str(size),
    }
    if keyword:
        params["ccbaMnm1"] = keyword  # 일반적으로 명칭(ccbaMnm1) 키워드로 필터

    url = f"{KHS_BASE}/SearchKindOpenapiList.do"
    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(url, params=params)
    if r.status_code != 200:
        raise HTTPException(502, f"KHS error {r.status_code}")

    # XML → dict → 우리가 쓰기 좋은 JSON 형태로 가공
    data = xmltodict.parse(r.text)
    # 응답 구조는 데이터셋/시점에 따라 조금씩 다름 → 안전하게 파고들기
    body = data.get("result", data)  # 보호적 접근
    rows = body.get("items", {}).get("item", [])
    if isinstance(rows, dict):  # 단일 항목이면 dict로 옴
        rows = [rows]

    def pick(x, k, alt=None):
        v = x.get(k)
        return v if v is not None else alt

    items = []
    for e in rows:
        items.append({
            "id": f"{pick(e,'ccbaKdcd','')}-{pick(e,'ccbaAsno','')}-{pick(e,'ccbaCtcd','')}",
            "name": pick(e, "ccbaMnm1", "미상"),
            "region": pick(e, "ccbaCtcdNm", pick(e,"ccsiName","지역미상")),
            "code": pick(e, "ccbaKdcd", "코드미상"),
            "ccbaKdcd": pick(e, "ccbaKdcd", ""),
            "ccbaAsno": pick(e, "ccbaAsno", ""),
            "ccbaCtcd": pick(e, "ccbaCtcd", ""),
        })

    # totalCount가 없을 수 있으니 대략 추정
    total = int(body.get("totalCount", len(items)))
    return {"items": items, "totalCount": total}

# 상세
@app.get("/heritage/detail")
async def heritage_detail(ccbaKdcd: str, ccbaAsno: str, ccbaCtcd: str):
    url = f"{KHS_BASE}/SearchKindOpenapiDt.do"
    params = {"ccbaKdcd": ccbaKdcd, "ccbaAsno": ccbaAsno, "ccbaCtcd": ccbaCtcd}
    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(url, params=params)
    if r.status_code != 200:
        raise HTTPException(502, f"KHS error {r.status_code}")
    data = xmltodict.parse(r.text)
    return data  # 필요 시 여기서도 가공해서 깔끔한 JSON으로
