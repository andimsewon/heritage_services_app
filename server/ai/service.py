"""
AI 손상 탐지 서비스
이미지 추론 로직
"""

import io
import torch
from torchvision.ops import nms
from PIL import Image
from fastapi import HTTPException
from .loader import (
    get_model,
    get_processor,
    get_id2label,
    get_id2label_korean,
    is_model_loaded,
)

# 노트북 설정과 동일한 클래스별 Threshold (visualize_test.ipynb 참고)
CLASS_THRESHOLDS = {
    0: 0.30,  # LABEL_0 (갈램)
    1: 0.25,  # LABEL_1 (균열)
    2: 0.15,  # LABEL_2 (부후)
    3: 0.25,  # LABEL_3 (압괴/터짐)
}

# NMS IoU Threshold (노트북과 동일)
NMS_IOU_THRESHOLD = 0.1


def _calculate_grade(detections: list[dict]) -> tuple[str, str]:
    """
    탐지 결과를 기반으로 손상 등급과 설명 메시지를 산출합니다.
    단순 휴리스틱: 최고 신뢰도를 기준으로 A~D 등급을 부여합니다.
    """
    if not detections:
        return "A", "관찰된 손상 징후가 없습니다."

    top = max(detections, key=lambda d: d.get("score", 0))
    score = float(top.get("score", 0))
    label = top.get("label") or "손상"

    if score >= 0.85:
        grade = "D"
        message = f"{label} 손상이 심각하여 즉시 보수가 필요합니다."
    elif score >= 0.75:
        grade = "C2"
        message = (
            f"{label} 손상이 명확히 관찰됩니다. 모니터링 및 예방 조치가 필요합니다."
        )
    elif score >= 0.6:
        grade = "C1"
        message = f"{label} 손상이 경미하게 관찰됩니다. 정기적 관찰이 필요합니다."
    elif score >= 0.5:
        grade = "B"
        message = f"{label} 손상이 의심됩니다. 지속적인 관찰과 예방 조치를 권장합니다."
    else:
        grade = "A"
        message = f"{label} 관련 이상 징후가 거의 없습니다."

    return grade, message


def _filter_by_class_threshold(boxes, scores, labels, class_thresholds):
    """클래스별로 다른 threshold 적용 (노트북과 동일한 로직)"""
    filtered_boxes = []
    filtered_scores = []
    filtered_labels = []

    for box, score, label in zip(boxes, scores, labels):
        label_int = int(label.item()) if torch.is_tensor(label) else int(label)
        # 해당 클래스의 threshold 가져오기 (기본값 0.5)
        threshold = class_thresholds.get(label_int, 0.5)

        if score >= threshold:
            filtered_boxes.append(box)
            filtered_scores.append(score)
            filtered_labels.append(label)

    return filtered_boxes, filtered_scores, filtered_labels


def _apply_nms(boxes, scores, labels, iou_threshold=0.5):
    """NMS 적용 (노트북과 동일한 로직)"""
    if len(boxes) == 0:
        return [], [], []

    # 텐서로 변환
    if not torch.is_tensor(boxes):
        boxes_tensor = torch.tensor(boxes, dtype=torch.float32)
    else:
        boxes_tensor = boxes
    if not torch.is_tensor(scores):
        scores_tensor = torch.tensor(scores, dtype=torch.float32)
    else:
        scores_tensor = scores
    if not torch.is_tensor(labels):
        labels_tensor = torch.tensor(labels, dtype=torch.int64)
    else:
        labels_tensor = labels

    keep_indices = []
    unique_labels = labels_tensor.unique()

    # 클래스별로 NMS 적용
    for label in unique_labels:
        mask = labels_tensor == label
        class_boxes = boxes_tensor[mask]
        class_scores = scores_tensor[mask]
        class_indices = torch.where(mask)[0]

        if len(class_boxes) > 0:
            keep = nms(class_boxes, class_scores, iou_threshold)
            keep_indices.extend(class_indices[keep].tolist())

    keep_indices = sorted(keep_indices)
    filtered_boxes = [boxes[i] for i in keep_indices]
    filtered_scores = [scores[i] for i in keep_indices]
    filtered_labels = [labels[i] for i in keep_indices]

    return filtered_boxes, filtered_scores, filtered_labels


async def detect_damage(image_bytes: bytes) -> dict:
    """
    이미지에서 손상 영역 탐지 (노트북 설정 적용)

    Args:
        image_bytes: 업로드된 이미지 바이트

    Returns:
        탐지된 객체 리스트 (label, score, bbox)
    """
    if not is_model_loaded():
        raise HTTPException(
            status_code=503,
            detail="AI 모델이 로드되지 않았습니다. 서버 로그를 확인해주세요.",
        )

    model = get_model()
    processor = get_processor()
    id2label = get_id2label()
    id2label_korean = get_id2label_korean()

    # 이미지 로드
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    # 전처리
    encoding = processor(images=img, return_tensors="pt")
    pixel_values = encoding["pixel_values"]

    # 추론 (낮은 threshold로 먼저 추출)
    with torch.no_grad():
        outputs = model.predict(pixel_values=pixel_values)
        results = processor.post_process_object_detection(
            outputs=outputs, target_sizes=[img.size[::-1]], threshold=0.05
        )

    # 결과 추출
    boxes = results[0]["boxes"].cpu()
    scores = results[0]["scores"].cpu()
    labels = results[0]["labels"].cpu()

    # 1. 클래스별 threshold 적용 (노트북과 동일)
    boxes, scores, labels = _filter_by_class_threshold(
        boxes, scores, labels, CLASS_THRESHOLDS
    )

    # 2. NMS 적용 (노트북과 동일)
    if len(boxes) > 0:
        boxes, scores, labels = _apply_nms(
            boxes, scores, labels, iou_threshold=NMS_IOU_THRESHOLD
        )

    # 결과 파싱 (한글 레이블 사용)
    detections = []
    for box, score, label in zip(boxes, scores, labels):
        label_int = int(label.item()) if torch.is_tensor(label) else int(label)
        # 한글 레이블 우선 사용, 없으면 영문 레이블
        label_name = id2label_korean.get(label_int) if id2label_korean else None
        if label_name is None:
            label_name = id2label.get(label_int, f"LABEL_{label_int}")

        detections.append(
            {
                "label": label_name,
                "label_id": label_int,  # 클래스 ID도 포함
                "score": float(score),
                "bbox": [
                    round(x, 2) for x in (box.tolist() if torch.is_tensor(box) else box)
                ],
            }
        )

    grade, explanation = _calculate_grade(detections)

    return {
        "detections": detections,
        "count": len(detections),
        "grade": grade,
        "explanation": explanation,
    }
