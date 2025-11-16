"""
AI 손상 탐지 서비스
이미지 추론 로직
"""

from __future__ import annotations

import io
import torch
from torchvision.ops import nms
from PIL import Image
from fastapi import HTTPException
from typing import List, Dict, Tuple
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


def _calculate_grade(detections: List[Dict]) -> Tuple[str, str]:
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
        # label을 안전하게 정수로 변환
        if torch.is_tensor(label):
            if label.numel() == 1:
                label_int = int(label.item())
            else:
                continue  # 유효하지 않은 label
        else:
            label_int = int(label)

        # 해당 클래스의 threshold 가져오기 (기본값 0.5)
        threshold = class_thresholds.get(label_int, 0.5)

        # score를 안전하게 비교
        if torch.is_tensor(score):
            if score.numel() == 1:
                score_value = score.item()
            else:
                continue  # 유효하지 않은 score
        else:
            score_value = float(score)

        if score_value >= threshold:
            filtered_boxes.append(box)
            filtered_scores.append(score)
            filtered_labels.append(label)

    return filtered_boxes, filtered_scores, filtered_labels


def _apply_nms(boxes, scores, labels, iou_threshold=0.5):
    """NMS 적용 (노트북과 동일한 로직)"""
    if len(boxes) == 0:
        return [], [], []

    def _prepare_tensor(values, dtype):
        """list/tuple/tensor 입력을 안전하게 텐서로 변환"""
        if torch.is_tensor(values):
            tensor = values.detach()
            if values.requires_grad:
                tensor = tensor.clone()
            return tensor.to(dtype=dtype)

        if not isinstance(values, (list, tuple)):
            return torch.tensor(values, dtype=dtype)

        if len(values) == 0:
            return torch.empty((0,), dtype=dtype)

        prepared = []
        for item in values:
            if torch.is_tensor(item):
                t = item.detach()
                if item.requires_grad:
                    t = t.clone()
                prepared.append(t.to(dtype=dtype))
            else:
                prepared.append(torch.tensor(item, dtype=dtype))

        try:
            return torch.stack(prepared)
        except RuntimeError:
            # 스택에 실패하면 (예: 스칼라 혼합) cat 대신 1D 텐서를 생성
            flattened = [
                item.item() if torch.is_tensor(item) and item.numel() == 1 else item
                for item in prepared
            ]
            return torch.tensor(flattened, dtype=dtype)

    # 텐서로 변환
    boxes_tensor = _prepare_tensor(boxes, torch.float32)
    scores_tensor = _prepare_tensor(scores, torch.float32)
    labels_tensor = _prepare_tensor(labels, torch.int64)

    # 디바이스 통일
    device = boxes_tensor.device
    scores_tensor = scores_tensor.to(device)
    labels_tensor = labels_tensor.to(device)

    keep_indices = []
    unique_labels = labels_tensor.unique()

    # 클래스별로 NMS 적용
    for label_tensor in unique_labels:
        # 텐서를 스칼라로 변환 (안전하게)
        if label_tensor.numel() == 1:
            label_value = label_tensor.item()
        else:
            continue  # 유효하지 않은 label

        mask = labels_tensor == label_value
        class_boxes = boxes_tensor[mask]
        class_scores = scores_tensor[mask]
        class_indices = torch.where(mask)[0]

        if len(class_boxes) > 0:
            keep = nms(class_boxes, class_scores, iou_threshold)

            # keep이 텐서인 경우 리스트로 변환
            if torch.is_tensor(keep):
                keep_list = keep.cpu().tolist()
            else:
                keep_list = list(keep) if isinstance(keep, (list, tuple)) else [keep]

            # class_indices를 안전하게 처리
            if torch.is_tensor(class_indices):
                # keep_list의 인덱스를 사용하여 class_indices에서 실제 인덱스 가져오기
                for keep_idx in keep_list:
                    if 0 <= keep_idx < len(class_indices):
                        original_idx = class_indices[keep_idx]
                        # original_idx가 텐서인 경우 스칼라로 변환
                        if torch.is_tensor(original_idx):
                            if original_idx.numel() == 1:
                                keep_indices.append(int(original_idx.item()))
                            else:
                                continue
                        else:
                            keep_indices.append(int(original_idx))
            else:
                # class_indices가 리스트인 경우
                keep_indices.extend(
                    [
                        int(class_indices[i])
                        for i in keep_list
                        if 0 <= i < len(class_indices)
                    ]
                )

    keep_indices = sorted(set(keep_indices))  # 중복 제거
    filtered_boxes = [boxes[i] for i in keep_indices if i < len(boxes)]
    filtered_scores = [scores[i] for i in keep_indices if i < len(scores)]
    filtered_labels = [labels[i] for i in keep_indices if i < len(labels)]

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

    try:
        model = get_model()
        processor = get_processor()
        id2label = get_id2label()
        id2label_korean = get_id2label_korean()

        # 모델 디바이스 확인 및 검증
        try:
            device = next(model.parameters()).device
            # 모델이 유효한지 확인
            if device is None:
                raise HTTPException(
                    status_code=503, detail="모델 디바이스가 유효하지 않습니다."
                )
        except StopIteration:
            raise HTTPException(
                status_code=503, detail="모델 파라미터를 확인할 수 없습니다."
            )
        except Exception as e:
            raise HTTPException(
                status_code=503, detail=f"모델 디바이스 확인 실패: {str(e)}"
            )

        # 이미지 파일 크기 검증 (10MB 제한)
        MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
        if len(image_bytes) > MAX_IMAGE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"이미지 크기가 너무 큽니다. (최대 {MAX_IMAGE_SIZE / (1024*1024):.0f}MB, 현재: {len(image_bytes) / (1024*1024):.2f}MB)",
            )

        # 이미지 로드 및 검증
        try:
            img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise HTTPException(
                status_code=400, detail=f"이미지를 로드할 수 없습니다: {str(e)}"
            )

        # 이미지 크기 검증 (해상도 제한)
        MAX_DIMENSION = 4096  # 최대 4096x4096
        width, height = img.size
        if width == 0 or height == 0:
            raise HTTPException(
                status_code=400, detail="이미지 크기가 유효하지 않습니다."
            )
        if width > MAX_DIMENSION or height > MAX_DIMENSION:
            # 큰 이미지는 리사이즈
            scale = min(MAX_DIMENSION / width, MAX_DIMENSION / height)
            new_width = int(width * scale)
            new_height = int(height * scale)
            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            print(
                f"[AI Service] 이미지 리사이즈: {width}x{height} -> {new_width}x{new_height}"
            )

        # 전처리
        try:
            encoding = processor(images=img, return_tensors="pt")
            pixel_values = encoding["pixel_values"]

            # 모델과 같은 디바이스로 이동 (중요!)
            pixel_values = pixel_values.to(device)
        except RuntimeError as e:
            # 메모리 부족 오류 처리
            error_msg = str(e).lower()
            if "out of memory" in error_msg or "cuda" in error_msg:
                raise HTTPException(
                    status_code=507,
                    detail="메모리 부족으로 이미지를 처리할 수 없습니다. 더 작은 이미지를 사용해주세요.",
                )
            raise HTTPException(
                status_code=500,
                detail=f"이미지 전처리 중 오류가 발생했습니다: {str(e)}",
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"이미지 전처리 중 오류가 발생했습니다: {str(e)}",
            )

        # 추론 (낮은 threshold로 먼저 추출)
        try:
            # 메모리 정리 (CUDA인 경우)
            if device.type == "cuda":
                torch.cuda.empty_cache()

            with torch.no_grad():
                outputs = model.predict(pixel_values=pixel_values)

                # target_sizes를 텐서로 변환하고 모델과 같은 디바이스로 이동
                target_sizes = torch.tensor([img.size[::-1]], dtype=torch.int32).to(
                    device
                )

                results = processor.post_process_object_detection(
                    outputs=outputs, target_sizes=target_sizes, threshold=0.05
                )

            # 추론 후 메모리 정리
            if device.type == "cuda":
                torch.cuda.empty_cache()
        except RuntimeError as e:
            # 메모리 부족 오류 처리
            error_msg = str(e).lower()
            if "out of memory" in error_msg or "cuda" in error_msg:
                # 메모리 정리 시도
                if device.type == "cuda":
                    torch.cuda.empty_cache()
                raise HTTPException(
                    status_code=507,
                    detail="메모리 부족으로 모델 추론을 수행할 수 없습니다. 더 작은 이미지를 사용해주세요.",
                )
            raise HTTPException(
                status_code=500, detail=f"모델 추론 중 오류가 발생했습니다: {str(e)}"
            )
        except Exception as e:
            # 메모리 정리
            if device.type == "cuda":
                torch.cuda.empty_cache()
            raise HTTPException(
                status_code=500, detail=f"모델 추론 중 오류가 발생했습니다: {str(e)}"
            )

        # 결과 추출 (안전하게 처리)
        try:
            if not results or len(results) == 0:
                raise HTTPException(
                    status_code=500, detail="모델 추론 결과가 비어있습니다."
                )

            result = results[0]
            if not isinstance(result, dict):
                raise HTTPException(
                    status_code=500, detail=f"예상치 못한 결과 형식: {type(result)}"
                )

            # 텐서를 안전하게 CPU로 이동
            boxes = result.get("boxes")
            scores = result.get("scores")
            labels = result.get("labels")

            if boxes is None or scores is None or labels is None:
                raise HTTPException(
                    status_code=500,
                    detail="결과에 필수 필드(boxes, scores, labels)가 없습니다.",
                )

            # 텐서인 경우 CPU로 이동, 아니면 그대로 사용
            if torch.is_tensor(boxes):
                boxes = boxes.cpu()
            if torch.is_tensor(scores):
                scores = scores.cpu()
            if torch.is_tensor(labels):
                labels = labels.cpu()
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=500, detail=f"결과 추출 중 오류가 발생했습니다: {str(e)}"
            )

        # 1. 클래스별 threshold 적용 (노트북과 동일)
        try:
            boxes, scores, labels = _filter_by_class_threshold(
                boxes, scores, labels, CLASS_THRESHOLDS
            )
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"클래스별 필터링 중 오류가 발생했습니다: {str(e)}",
            )

        # 2. NMS 적용 (노트북과 동일)
        if len(boxes) > 0:
            try:
                boxes, scores, labels = _apply_nms(
                    boxes, scores, labels, iou_threshold=NMS_IOU_THRESHOLD
                )
            except Exception as e:
                raise HTTPException(
                    status_code=500, detail=f"NMS 적용 중 오류가 발생했습니다: {str(e)}"
                )

        # 결과 파싱 (한글 레이블 사용) - 안전하게 처리
        detections = []
        try:
            # boxes, scores, labels를 리스트로 변환 (안전하게)
            if torch.is_tensor(boxes):
                boxes_list = boxes.tolist()
            elif isinstance(boxes, (list, tuple)):
                boxes_list = list(boxes)
            else:
                boxes_list = []

            if torch.is_tensor(scores):
                scores_list = scores.tolist()
            elif isinstance(scores, (list, tuple)):
                scores_list = list(scores)
            else:
                scores_list = []

            if torch.is_tensor(labels):
                labels_list = labels.tolist()
            elif isinstance(labels, (list, tuple)):
                labels_list = list(labels)
            else:
                labels_list = []

            for box, score, label in zip(boxes_list, scores_list, labels_list):
                # label을 안전하게 정수로 변환
                if torch.is_tensor(label):
                    label_int = int(label.item())
                elif isinstance(label, (int, float)):
                    label_int = int(label)
                else:
                    try:
                        label_int = int(label)
                    except (ValueError, TypeError):
                        continue  # 유효하지 않은 label은 건너뛰기

                # 한글 레이블 우선 사용, 없으면 영문 레이블
                label_name = id2label_korean.get(label_int) if id2label_korean else None
                if label_name is None:
                    label_name = id2label.get(label_int, f"LABEL_{label_int}")

                # box를 안전하게 리스트로 변환
                if torch.is_tensor(box):
                    bbox_list = box.tolist()
                elif isinstance(box, (list, tuple)):
                    bbox_list = list(box)
                else:
                    continue  # 유효하지 않은 box는 건너뛰기

                # score를 안전하게 float로 변환
                try:
                    if torch.is_tensor(score):
                        score_float = float(score.item())
                    else:
                        score_float = float(score)
                except (ValueError, TypeError):
                    continue  # 유효하지 않은 score는 건너뛰기

                detections.append(
                    {
                        "label": label_name,
                        "label_id": label_int,  # 클래스 ID도 포함
                        "score": score_float,
                        "bbox": [round(x, 2) for x in bbox_list],
                    }
                )
        except Exception as e:
            raise HTTPException(
                status_code=500, detail=f"결과 파싱 중 오류가 발생했습니다: {str(e)}"
            )

        grade, explanation = _calculate_grade(detections)

        return {
            "detections": detections,
            "count": len(detections),
            "grade": grade,
            "explanation": explanation,
        }
    except HTTPException:
        # HTTPException은 그대로 전달
        raise
    except Exception as e:
        # 예상치 못한 오류
        import traceback

        error_detail = str(e)
        print(f"[AI Service] 예상치 못한 오류: {error_detail}")
        print(f"[AI Service] 스택 트레이스:\n{traceback.format_exc()}")

        raise HTTPException(
            status_code=500, detail=f"손상 탐지 중 오류가 발생했습니다: {error_detail}"
        )
