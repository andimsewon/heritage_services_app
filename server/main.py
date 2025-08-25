# server/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx, xmltodict, os

KHS_BASE = "http://www.khs.go.kr/cha"

app = FastAPI(title="Heritage Proxy (debug-friendly)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)

def _pick(d, k, default=""):
    return d.get(k, default) if isinstance(d, dict) else default

def _first_non_empty(*vals):
    for v in vals:
      if isinstance(v, str) and v.strip():
        return v
    return ""

def _extract_items(xml_dict):
    """
    다양한 루트 구조를 모두 시도해서 item 리스트를 뽑는다.
    가능한 구조:
      result -> items -> item
      items -> item
      list  -> item
      result -> list -> item
      item (단일/리스트)
    """
    if not isinstance(xml_dict, dict):
        return []

    roots_to_try = [
        ["result", "items", "item"],
        ["result", "list", "item"],
        ["items", "item"],
        ["list", "item"],
        ["result", "item"],
        ["item"],
    ]
    for path in roots_to_try:
        cur = xml_dict
        ok = True
        for k in path:
            if isinstance(cur, dict) and k in cur:
                cur = cur[k]
            else:
                ok = False
                break
        if ok:
            if isinstance(cur, list):
                return cur
            if isinstance(cur, dict):
                return [cur]
    return []

@app.get("/health")
async def health():
    return {"ok": True}

@app.get("/heritage/list")
async def heritage_list(
    keyword: str | None = None,  # ccbaMnm1(유산명)
    kind: str | None = None,     # ccbaKdcd(종목 코드)
    region: str | None = None,   # ccbaCtcd(시·도 코드)
    page: int = 1,
    size: int = 20,
):
    # 시도별로 실제 스펙이 달라질 수 있어 파라미터 셋을 여러 개 시도
    param_variants = [
        {"pageIndex": str(page), "pageUnit": str(size)},
        {"pageNo": str(page), "numOfRows": str(size)},
        {},  # 마지막엔 페이지 파라미터 없이도 한 번
    ]
    base_common = {}
    if keyword: base_common["ccbaMnm1"] = keyword.strip()
    if kind:    base_common["ccbaKdcd"] = kind.strip()
    if region:  base_common["ccbaCtcd"] = region.strip()

    last_error = None
    for variant in param_variants:
        params = {**variant, **base_common}
        url = f"{KHS_BASE}/SearchKindOpenapiList.do"

        try:
            async with httpx.AsyncClient(timeout=12.0, headers={"User-Agent": "heritage-proxy/1.0"}) as client:
                r = await client.get(url, params=params)
            # 디버그 로그
            print(f"[LIST] GET {r.request.url} -> {r.status_code}")
            if r.status_code != 200:
                last_error = HTTPException(502, f"KHS error {r.status_code}")
                continue

            data = xmltodict.parse(r.text)
            items_node = _extract_items(data)
            print(f"[LIST] root keys: {list(data.keys())}  items: {len(items_node)}")

            # items 없으면 다음 variant 시도
            if not items_node:
                continue

            items = []
            for e in items_node:
                ccbaKdcd = _pick(e, "ccbaKdcd")
                ccbaAsno = _pick(e, "ccbaAsno")
                ccbaCtcd = _pick(e, "ccbaCtcd")

                kind_name = _first_non_empty(_pick(e, "ccmaName"), _pick(e, "gcodeName"))
                name = _pick(e, "ccbaMnm1", "미상")
                sojaeji = _first_non_empty(_pick(e, "ccbaLcto"), _pick(e, "ccbaLcad"), _pick(e, "loc"))
                addr = _first_non_empty(_pick(e, "ccbaCtcdNm"), _pick(e, "ccsiName"))

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

            # totalCount 추정 (루트마다 키가 달라서 안전하게)
            total = 0
            for k in ["totalCount", "totalCnt", "totalcount", "total"]:
                v = data.get("result", data).get(k) if isinstance(data.get("result", data), dict) else None
                if v and str(v).isdigit():
                    total = int(v)
                    break
            if total == 0:
                total = len(items)

            return {"items": items, "totalCount": total}

        except Exception as e:
            print(f"[LIST] variant error: {e}")
            last_error = HTTPException(502, f"proxy error: {e}")

    if last_error:
        raise last_error
    return {"items": [], "totalCount": 0}

@app.get("/heritage/detail")
async def heritage_detail(ccbaKdcd: str, ccbaAsno: str, ccbaCtcd: str):
    url = f"{KHS_BASE}/SearchKindOpenapiDt.do"
    params = {"ccbaKdcd": ccbaKdcd, "ccbaAsno": ccbaAsno, "ccbaCtcd": ccbaCtcd}
    async with httpx.AsyncClient(timeout=12.0, headers={"User-Agent": "heritage-proxy/1.0"}) as client:
        r = await client.get(url, params=params)
    print(f"[DETAIL] GET {r.request.url} -> {r.status_code}")
    if r.status_code != 200:
        raise HTTPException(502, f"KHS error {r.status_code}")
    data = xmltodict.parse(r.text)
    return data
