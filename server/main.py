# server/main.py
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import httpx, xmltodict, io, os
from typing import Optional
from PIL import Image
import torch
from torchvision import transforms
from pathlib import Path

KHS_BASE = "http://www.khs.go.kr/cha"

app = FastAPI(title="Heritage Proxy (debug-friendly)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)

# -----------------------------
# 유틸 함수
# -----------------------------
def _pick(d, k, default=""):
    return d.get(k, default) if isinstance(d, dict) else default

def _first_non_empty(*vals):
    for v in vals:
        if isinstance(v, str) and v.strip():
            return v
    return ""

def _extract_items(xml_dict):
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

# -----------------------------
# Health check
# -----------------------------
@app.get("/health")
async def health():
    return {"ok": True}

# -----------------------------
# Heritage list API
# -----------------------------
@app.get("/heritage/list")
async def heritage_list(
        keyword: Optional[str] = None,
        kind:    Optional[str] = None,
        region:  Optional[str] = None,
        page: int = 1,
        size: int = 20,
):
    param_variants = [
        {"pageIndex": str(page), "pageUnit": str(size)},
        {"pageNo": str(page), "numOfRows": str(size)},
        {},
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
            print(f"[LIST] GET {r.request.url} -> {r.status_code}")
            if r.status_code != 200:
                last_error = HTTPException(502, f"KHS error {r.status_code}")
                continue

            data = xmltodict.parse(r.text)
            items_node = _extract_items(data)
            print(f"[LIST] root keys: {list(data.keys())}  items: {len(items_node)}")

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

# -----------------------------
# Heritage detail API
# -----------------------------
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

# -----------------------------
# AI 모델 로드 (앱 시작 시 1회)
# -----------------------------
# 모델 파일은 서버 디렉토리 기준으로 로드
BASE_DIR = Path(__file__).resolve().parent
MODEL_FILENAME = "hanok_damage_model_ml_backend.pt"
MODEL_PATH = str((BASE_DIR / MODEL_FILENAME).resolve())

# 클래스 이름 테이블 (학습할 때 정의한 순서와 동일해야 함)
CLASS_LABELS = ["갈라짐", "박락", "변색", "균열", "기타"]

# 디바이스 선택: 우선순위 MPS(macOS) > CUDA > CPU
if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
    DEVICE = torch.device("mps")
elif torch.cuda.is_available():
    DEVICE = torch.device("cuda")
else:
    DEVICE = torch.device("cpu")

model = None
model_type = "unknown"

try:
    # TorchScript 우선 로드 (배포 친화적)
    try:
        model = torch.jit.load(MODEL_PATH, map_location=DEVICE)
        model_type = "torchscript"
    except Exception:
        # 일반 PyTorch nn.Module 체크포인트 로드
        model = torch.load(MODEL_PATH, map_location=DEVICE)
        model_type = "eager"

    model.eval()
    if hasattr(model, "to"):
        model.to(DEVICE)

    preprocess = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                             std=[0.229, 0.224, 0.225])
    ])

    # 가벼운 워밍업 (선택적): 작은 텐서로 1회 호출
    try:
        with torch.no_grad():
            _ = model(torch.zeros(1, 3, 224, 224, device=DEVICE))
    except Exception:
        pass

    print(f"[AI] 모델 로드 완료: {MODEL_PATH}  device={DEVICE}  type={model_type}")
except Exception as e:
    print(f"[AI] 모델 로드 실패: {e}")
    model = None

# -----------------------------
# AI 손상 탐지 API
# -----------------------------
@app.post("/ai/damage/infer")
async def ai_damage_infer(image: UploadFile = File(...)):
    """
    업로드된 이미지에서 손상 부위를 탐지하는 AI API.
    hanok_damage_model_ml_backend.pt 모델을 사용해 실제 추론 수행.
    """
    if model is None:
        raise HTTPException(status_code=500, detail="모델이 로드되지 않았습니다.")

    try:
        contents = await image.read()
        img = Image.open(io.BytesIO(contents)).convert("RGB")
        tensor = preprocess(img).unsqueeze(0).to(DEVICE)

        with torch.no_grad():
            outputs = model(tensor)
            if isinstance(outputs, (list, tuple)):
                outputs = outputs[0]
            probs = torch.softmax(outputs, dim=1)[0]
            score, pred = torch.max(probs, 0)

        # 클래스 라벨 매핑
        class_id = pred.item()
        label = CLASS_LABELS[class_id] if class_id < len(CLASS_LABELS) else f"unknown_{class_id}"

        # 전체 클래스 확률 테이블
        all_scores = [
            {
                "class_id": idx,
                "label": CLASS_LABELS[idx] if idx < len(CLASS_LABELS) else f"unknown_{idx}",
                "score": float(probs[idx].item()),
            }
            for idx in range(probs.shape[0])
        ]

        return {
            "detections": [
                {
                    "label": label,
                    "score": float(score),
                    "class_id": class_id
                }
            ],
            "scores": all_scores,
            "meta": {
                "model_path": MODEL_PATH,
                "device": str(DEVICE),
                "model_type": model_type,
                "input_size": [224, 224],
                "filename": image.filename,
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"추론 오류: {e}")
