"""
Damage Detection Inference Module
노트북(visualize_test.ipynb)의 추론 로직을 추출하여 FastAPI 서버에 통합
"""
import os
import glob
import torch
from typing import List, Dict, Optional
from PIL import Image
from transformers import DetaImageProcessor, DetaForObjectDetection
from torchvision.ops import nms

# ==================== Configuration ====================
# 노트북과 동일한 설정값
# 모델 경로: 환경변수 또는 기본값 (server 폴더 기준)
# 1. 환경변수 MODEL_PATH 확인
# 2. ai/hanok_damage_model.pth (기본 모델 파일)
# 3. ai/best_model.pth (대체 경로)
# 4. hanok_damage_model_1108/best_model.pth (노트북 경로)
_default_paths = [
    "ai/hanok_damage_model.pth",  # 기본 모델 파일
    "ai/best_model.pth",  # 대체 경로
    "hanok_damage_model_1108/best_model.pth",  # 노트북 경로
]
MODEL_PATH = os.getenv("MODEL_PATH", _default_paths[0])
CLASS_THRESHOLDS = {
    0: 0.30,  # LABEL_0 (갈램)
    1: 0.25,  # LABEL_1 (균열)
    2: 0.15,  # LABEL_2 (부후)
    3: 0.25,  # LABEL_3 (압괴/터짐)
}
NMS_IOU = 0.1

CLASS_ID_TO_NAME = {
    0: "갈램",
    1: "균열",
    2: "부후",
    3: "압괴/터짐",
}

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ==================== Model Loading ====================
# 전역 변수로 모델과 프로세서 저장 (한 번만 로드)
_model = None
_processor = None


def _find_best_checkpoint(model_dir: str) -> str:
    """
    폴더 내에서 best_map이 가장 높은 체크포인트를 찾습니다
    (노트북의 find_best_checkpoint 함수와 동일)
    """
    checkpoint_files = glob.glob(os.path.join(model_dir, "*.pth"))
    
    if not checkpoint_files:
        raise FileNotFoundError(f"❌ {model_dir}에 .pth 파일이 없습니다!")
    
    best_checkpoint_path = None
    best_map_value = -1
    
    for ckpt_path in sorted(checkpoint_files):
        try:
            ckpt = torch.load(ckpt_path, map_location='cpu', weights_only=False)
            best_map = ckpt.get('best_map', -1)
            
            if isinstance(best_map, (int, float)) and best_map > best_map_value:
                best_map_value = best_map
                best_checkpoint_path = ckpt_path
        except Exception as e:
            print(f"⚠️ {os.path.basename(ckpt_path)}: 로드 실패 - {e}")
            continue
    
    if best_checkpoint_path:
        return best_checkpoint_path
    else:
        # best_map이 없으면 가장 최근 파일 사용
        return max(checkpoint_files, key=os.path.getmtime)


def _load_model():
    """모델과 프로세서를 로드 (모듈 import 시 한 번만 실행)"""
    global _model, _processor
    
    if _model is not None and _processor is not None:
        return  # 이미 로드됨
    
    print(f"[Damage Inference] 모델 로드 중...")
    print(f"[Damage Inference] Device: {device}")
    
    # MODEL_PATH가 폴더인지 파일인지 확인
    server_dir = os.path.dirname(os.path.abspath(__file__))
    actual_model_path = None
    
    # 절대 경로인 경우
    if os.path.isabs(MODEL_PATH):
        if os.path.isdir(MODEL_PATH):
            actual_model_path = _find_best_checkpoint(MODEL_PATH)
        elif os.path.isfile(MODEL_PATH):
            actual_model_path = MODEL_PATH
    
    # 상대 경로인 경우 (server 폴더 기준)
    if actual_model_path is None:
        possible_path = os.path.join(server_dir, MODEL_PATH)
        if os.path.isdir(possible_path):
            actual_model_path = _find_best_checkpoint(possible_path)
        elif os.path.isfile(possible_path):
            actual_model_path = possible_path
    
    # 기본 경로들 시도
    if actual_model_path is None:
        for default_path in _default_paths:
            possible_path = os.path.join(server_dir, default_path)
            if os.path.isfile(possible_path):
                actual_model_path = possible_path
                break
            # 폴더인 경우
            if os.path.isdir(possible_path):
                try:
                    actual_model_path = _find_best_checkpoint(possible_path)
                    break
                except:
                    continue
    
    if actual_model_path is None or not os.path.exists(actual_model_path):
        raise FileNotFoundError(
            f"❌ 모델 경로를 찾을 수 없습니다: {MODEL_PATH}\n"
            f"   시도한 경로: {os.path.join(server_dir, MODEL_PATH)}\n"
            f"   기본 경로들: {[os.path.join(server_dir, p) for p in _default_paths]}"
        )
    
    print(f"[Damage Inference] 모델 파일: {actual_model_path}")
    
    # Processor & Model 로드 (노트북과 동일)
    _processor = DetaImageProcessor.from_pretrained("jozhang97/deta-resnet-50")
    _model = DetaForObjectDetection.from_pretrained(
        "jozhang97/deta-resnet-50",
        num_labels=4,
        ignore_mismatched_sizes=True
    )
    
    # 체크포인트 로드
    checkpoint = torch.load(actual_model_path, map_location=device, weights_only=False)
    _model.load_state_dict(checkpoint['model_state_dict'])
    _model.to(device)
    _model.eval()
    
    print(f"[Damage Inference] ✅ 모델 로드 완료")
    if 'epoch' in checkpoint:
        print(f"[Damage Inference] Epoch: {checkpoint['epoch'] + 1}")
    if 'best_map' in checkpoint:
        print(f"[Damage Inference] Best mAP: {checkpoint.get('best_map', 'N/A')}")


# 모듈 import 시 자동으로 모델 로드
try:
    _load_model()
except Exception as e:
    print(f"[Damage Inference] ⚠️  모델 로드 실패: {e}")
    print(f"[Damage Inference] 서버 시작은 계속되지만 AI 기능이 제한됩니다.")


# ==================== Helper Functions ====================
def apply_class_thresholds(
    boxes: torch.Tensor,
    scores: torch.Tensor,
    labels: torch.Tensor,
    class_thresholds: Dict[int, float],
) -> Dict[str, torch.Tensor]:
    """
    클래스별 threshold를 적용하여 필터링
    (노트북의 apply_class_specific_thresholds_overlay 로직)
    """
    filtered_boxes = []
    filtered_scores = []
    filtered_labels = []

    for box, score, label in zip(boxes, scores, labels):
        label_int = int(label.item()) if torch.is_tensor(label) else int(label)
        threshold = class_thresholds.get(label_int, 0.5)

        if score >= threshold:
            filtered_boxes.append(box)
            filtered_scores.append(score)
            filtered_labels.append(label)

    if len(filtered_boxes) == 0:
        return {
            'boxes': torch.tensor([], dtype=torch.float32),
            'scores': torch.tensor([], dtype=torch.float32),
            'labels': torch.tensor([], dtype=torch.int64)
        }

    if isinstance(filtered_boxes[0], torch.Tensor):
        return {
            'boxes': torch.stack(filtered_boxes),
            'scores': torch.tensor(filtered_scores, dtype=torch.float32),
            'labels': torch.tensor(filtered_labels, dtype=torch.int64)
        }
    else:
        return {
            'boxes': torch.tensor(filtered_boxes, dtype=torch.float32),
            'scores': torch.tensor(filtered_scores, dtype=torch.float32),
            'labels': torch.tensor(filtered_labels, dtype=torch.int64)
        }


def apply_per_class_nms(
    boxes: torch.Tensor,
    scores: torch.Tensor,
    labels: torch.Tensor,
    iou_threshold: float,
) -> Dict[str, torch.Tensor]:
    """
    클래스별로 NMS를 적용
    (노트북의 apply_nms_overlay 로직)
    """
    if len(boxes) == 0:
        return {
            'boxes': torch.tensor([], dtype=torch.float32),
            'scores': torch.tensor([], dtype=torch.float32),
            'labels': torch.tensor([], dtype=torch.int64)
        }

    # 텐서로 변환
    if not torch.is_tensor(boxes):
        boxes = torch.tensor(boxes, dtype=torch.float32)
    if not torch.is_tensor(scores):
        scores = torch.tensor(scores, dtype=torch.float32)
    if not torch.is_tensor(labels):
        labels = torch.tensor(labels, dtype=torch.int64)

    keep_indices = []
    unique_labels = labels.unique()

    # 클래스별로 NMS 적용
    for label in unique_labels:
        mask = labels == label
        class_boxes = boxes[mask]
        class_scores = scores[mask]
        class_indices = torch.where(mask)[0]

        if len(class_boxes) > 0:
            keep = nms(class_boxes, class_scores, iou_threshold)
            keep_indices.extend(class_indices[keep].tolist())

    keep_indices = sorted(keep_indices)

    return {
        'boxes': boxes[keep_indices],
        'scores': scores[keep_indices],
        'labels': labels[keep_indices]
    }


# ==================== Core Inference Function ====================
def infer_damage(image: Image.Image) -> List[Dict]:
    """
    Run the damage detection model on a single PIL image and return a list of detections.
    
    Args:
        image: PIL Image (RGB)
    
    Returns:
        List of detection dicts, each with:
        - 'label_id': int (0-3)
        - 'label': str (Korean name, e.g., '갈램')
        - 'score': float
        - 'x': float  # normalized center x in [0, 1]
        - 'y': float  # normalized center y in [0, 1]
        - 'w': float  # normalized width  in [0, 1]
        - 'h': float  # normalized height in [0, 1]
    """
    if _model is None or _processor is None:
        raise RuntimeError("모델이 로드되지 않았습니다. 서버 로그를 확인하세요.")
    
    # 이미지 전처리
    image = image.convert("RGB")
    inputs = _processor(images=image, return_tensors="pt")
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    # 추론
    with torch.no_grad():
        outputs = _model(**inputs)
    
    # 후처리 (노트북과 동일: threshold=0.05로 먼저 추출)
    base_threshold = 0.05
    target_sizes = torch.tensor([image.size[::-1]]).to(device)
    results = _processor.post_process_object_detection(
        outputs,
        threshold=base_threshold,
        target_sizes=target_sizes
    )[0]
    
    # Prediction boxes, scores, labels 가져오기
    pred_boxes = results['boxes'].cpu()
    pred_scores = results['scores'].cpu()
    pred_labels = results['labels'].cpu()
    
    # 클래스별 threshold 적용
    filtered = apply_class_thresholds(
        pred_boxes, pred_scores, pred_labels, CLASS_THRESHOLDS
    )
    pred_boxes = filtered['boxes']
    pred_scores = filtered['scores']
    pred_labels = filtered['labels']
    
    # NMS 적용
    if len(pred_boxes) > 0:
        nms_result = apply_per_class_nms(
            pred_boxes, pred_scores, pred_labels, iou_threshold=NMS_IOU
        )
        pred_boxes = nms_result['boxes']
        pred_scores = nms_result['scores']
        pred_labels = nms_result['labels']
    
    # 결과 변환: [x1, y1, x2, y2] → normalized center format [x, y, w, h]
    detections = []
    width, height = image.size
    
    for box, score, label in zip(pred_boxes, pred_scores, pred_labels):
        label_int = int(label.item()) if torch.is_tensor(label) else int(label)
        
        # 유효한 클래스 ID만 필터링
        if label_int not in CLASS_ID_TO_NAME:
            continue
        
        # 박스 좌표 변환
        x1, y1, x2, y2 = box.tolist() if torch.is_tensor(box) else box
        
        # Normalized center format
        x_center = (x1 + x2) / 2.0 / width
        y_center = (y1 + y2) / 2.0 / height
        w = (x2 - x1) / width
        h = (y2 - y1) / height
        
        detections.append({
            'label_id': label_int,
            'label': CLASS_ID_TO_NAME[label_int],
            'score': float(score.item() if torch.is_tensor(score) else score),
            'x': float(x_center),
            'y': float(y_center),
            'w': float(w),
            'h': float(h),
        })
    
    return detections

