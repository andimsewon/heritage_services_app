"""
AI Detection API 라우터
/ai/* 엔드포인트 정의
"""
from fastapi import APIRouter, UploadFile, File
from .service import detect_damage
from .loader import is_model_loaded, get_id2label, get_model

router = APIRouter(tags=["AI Detection"])


@router.get("/model/status")
async def ai_model_status():
    """
    AI 모델 로딩 상태 확인

    Returns:
        - status: "loaded" 또는 "not_loaded"
        - available: 모델 사용 가능 여부
        - labels: 클래스 레이블 맵
        - device: 모델이 로드된 디바이스
    """
    if not is_model_loaded():
        return {"status": "not_loaded", "available": False}

    model = get_model()
    id2label = get_id2label()

    return {
        "status": "loaded",
        "available": True,
        "labels": id2label,
        "num_classes": len(id2label) if id2label else 0,
        "device": str(next(model.parameters()).device)
    }


@router.post("/damage/infer")
async def ai_damage_infer(image: UploadFile = File(...)):
    """
    이미지에서 손상 영역 탐지

    Args:
        - image: 업로드할 이미지 파일 (JPG, PNG 등)

    Returns:
        - detections: 탐지된 손상 영역 리스트
            - label: 손상 유형
            - score: 신뢰도 (0~1)
            - bbox: 바운딩 박스 [x1, y1, x2, y2]
        - count: 탐지된 객체 수
    """
    contents = await image.read()
    return await detect_damage(contents)
