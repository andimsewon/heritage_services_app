"""
AI 손상 탐지 서비스
이미지 추론 로직
"""
import io
import torch
from PIL import Image
from fastapi import HTTPException
from .loader import get_model, get_processor, get_id2label, is_model_loaded


async def detect_damage(image_bytes: bytes) -> dict:
    """
    이미지에서 손상 영역 탐지

    Args:
        image_bytes: 업로드된 이미지 바이트

    Returns:
        탐지된 객체 리스트 (label, score, bbox)
    """
    if not is_model_loaded():
        raise HTTPException(
            status_code=503,
            detail="AI 모델이 로드되지 않았습니다. 서버 로그를 확인해주세요."
        )

    model = get_model()
    processor = get_processor()
    id2label = get_id2label()

    # 이미지 로드
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    # 전처리
    encoding = processor(images=img, return_tensors="pt")
    pixel_values = encoding["pixel_values"]

    # 추론
    with torch.no_grad():
        outputs = model.predict(pixel_values=pixel_values)
        results = processor.post_process_object_detection(
            outputs=outputs, target_sizes=[img.size[::-1]], threshold=0.3
        )

    # 결과 파싱
    detections = []
    for box, score, label in zip(
        results[0]["boxes"], results[0]["scores"], results[0]["labels"]
    ):
        detections.append({
            "label": id2label.get(int(label), str(label.item())),
            "score": float(score),
            "bbox": [round(x, 2) for x in box.tolist()]
        })

    return {"detections": detections, "count": len(detections)}
