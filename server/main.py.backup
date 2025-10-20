from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import httpx, xmltodict, io, os
from typing import Optional
from PIL import Image
import torch
import torch.nn as nn
from transformers import DetaImageProcessor, DetaForObjectDetection
from transformers import DetaConfig

KHS_BASE = "http://www.khs.go.kr/cha"

app = FastAPI(title="Heritage Proxy (with AI)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # 모든 Origin 허용
    allow_credentials=True,
    allow_methods=["*"],      # 모든 메소드 허용
    allow_headers=["*"],      # 모든 헤더 허용
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
            async with httpx.AsyncClient(
                timeout=12.0,
                headers={"User-Agent": "heritage-proxy/1.0"},
                follow_redirects=True,    # ✅ 리다이렉트 자동 처리
            ) as client:
                r = await client.get(url, params=params)
            print(f"[LIST] GET {r.request.url} -> {r.status_code}")
            if r.status_code != 200:
                last_error = HTTPException(502, f"KHS error {r.status_code}")
                continue

            data = xmltodict.parse(r.text)
            items_node = _extract_items(data)
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
    async with httpx.AsyncClient(
        timeout=12.0,
        headers={"User-Agent": "heritage-proxy/1.0"},
        follow_redirects=True,   # ✅ 리다이렉트 자동 처리
    ) as client:
        r = await client.get(url, params=params)
    if r.status_code != 200:
        raise HTTPException(502, f"KHS error {r.status_code}")
    data = xmltodict.parse(r.text)
    return data

# -----------------------------
# AI 모델 정의 (CustomDeta)
# -----------------------------

class CustomDeta(nn.Module):
    def __init__(self, num_labels):
        super(CustomDeta, self).__init__()
        # config만 불러온 뒤 num_labels 수정
        config = DetaConfig.from_pretrained("jozhang97/deta-resnet-50")
        config.num_labels = int(num_labels)

        # 여기서 모델 초기화 (pretrained weight 불러오지 않음)
        self.model = DetaForObjectDetection(config)

    def forward(self, pixel_values, pixel_mask=None, labels=None):
        return self.model(pixel_values=pixel_values, pixel_mask=pixel_mask, labels=labels)

    def predict(self, pixel_values, pixel_mask=None):
        return self.model(pixel_values=pixel_values, pixel_mask=pixel_mask)

# -----------------------------
# AI 모델 로드 함수
# -----------------------------
MODEL_PATH = "hanok_damage_model.pt"
model, processor, id2label = None, None, None

def load_ai_model():
    global model, processor, id2label
    try:
        if not os.path.exists(MODEL_PATH):
            print(f"[AI] 모델 파일이 존재하지 않습니다: {MODEL_PATH}")
            return False

        checkpoint = torch.load(MODEL_PATH, map_location="cpu", weights_only=False)
        if checkpoint.get("id2label"):
            num_classes = len(checkpoint["id2label"])
            id2label = checkpoint["id2label"]
        else:
            num_classes = checkpoint.get("num_classes", 5)
            id2label = {i: f"class_{i}" for i in range(num_classes)}

        model = CustomDeta(num_labels=num_classes)

        if "model_state_dict" in checkpoint:
            state_dict = checkpoint["model_state_dict"]
            for k, v in state_dict.items():
                if isinstance(v, torch.Tensor):
                    state_dict[k] = v.to(torch.float32)
            model.model.load_state_dict(state_dict, strict=False)

        model.eval()
        processor = DetaImageProcessor.from_pretrained("jozhang97/deta-resnet-50")

        print(f"[AI] 모델 로드 성공! (클래스 {num_classes})")
        return True

    except Exception as e:
        import traceback
        print(f"[AI] 모델 로드 실패: {e}")
        traceback.print_exc()
        model, processor, id2label = None, None, None
        return False

# FastAPI startup 이벤트에서 모델 로드
@app.on_event("startup")
async def startup_event():
    loaded = load_ai_model()
    if not loaded:
        print("[AI] 경고: 모델 로드 실패")

# -----------------------------
# AI 상태 확인 API
# -----------------------------
@app.get("/ai/model/status")
async def ai_model_status():
    if model is None or processor is None:
        return {"status": "not_loaded", "available": False}
    return {
        "status": "loaded",
        "available": True,
        "labels": id2label,
        "device": str(next(model.parameters()).device)
    }

# -----------------------------
# AI 손상 탐지 API
# -----------------------------
@app.post("/ai/damage/infer")
async def ai_damage_infer(image: UploadFile = File(...)):
    if model is None or processor is None:
        raise HTTPException(status_code=503, detail="AI 모델이 로드되지 않았습니다.")

    contents = await image.read()
    img = Image.open(io.BytesIO(contents)).convert("RGB")

    encoding = processor(images=img, return_tensors="pt")
    pixel_values = encoding["pixel_values"]

    with torch.no_grad():
        outputs = model.predict(pixel_values=pixel_values)
        results = processor.post_process_object_detection(
            outputs=outputs, target_sizes=[img.size[::-1]], threshold=0.3
        )

    detections = []
    for box, score, label in zip(results[0]["boxes"], results[0]["scores"], results[0]["labels"]):
        detections.append({
            "label": id2label.get(int(label), str(label.item())),
            "score": float(score),
            "bbox": [round(x, 2) for x in box.tolist()]
        })

    return {"detections": detections}
