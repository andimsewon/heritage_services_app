"""
AI Detection API 라우터
/ai/* 엔드포인트 정의
"""
from fastapi import APIRouter, UploadFile, File, HTTPException
from .service import detect_damage
from .loader import is_model_loaded, get_id2label, get_id2label_korean, get_model

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
    id2label_korean = get_id2label_korean()

    return {
        "status": "loaded",
        "available": True,
        "labels": id2label,
        "labels_korean": id2label_korean,  # 한글 레이블 추가
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
    try:
        contents = await image.read()
        
        # 이미지 크기 검증
        if len(contents) == 0:
            raise HTTPException(
                status_code=400,
                detail="이미지 데이터가 비어있습니다."
            )
        if len(contents) > 10 * 1024 * 1024:  # 10MB
            raise HTTPException(
                status_code=400,
                detail="이미지 크기가 너무 큽니다. (최대 10MB)"
            )
        
        return await detect_damage(contents)
    except HTTPException:
        # HTTPException은 그대로 전달
        raise
    except Exception as e:
        # 기타 예외는 500 에러로 변환하되 명확한 메시지 제공
        import traceback
        error_detail = str(e)
        print(f"[AI Router] 오류 발생: {error_detail}")
        print(f"[AI Router] 스택 트레이스:\n{traceback.format_exc()}")
        
        raise HTTPException(
            status_code=500,
            detail=f"이미지 처리 중 오류가 발생했습니다: {error_detail}"
        )
