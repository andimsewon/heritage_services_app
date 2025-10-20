"""
AI 모델 로더
모델 로딩 및 상태 관리
"""
import os
import torch
from transformers import DetaImageProcessor
from .model import CustomDeta

# 모델 파일 경로 (현재 파일 기준 상대 경로)
MODEL_PATH = os.path.join(os.path.dirname(__file__), "hanok_damage_model.pt")

# 전역 변수
model = None
processor = None
id2label = None


def load_ai_model():
    """AI 모델을 메모리에 로드"""
    global model, processor, id2label

    try:
        if not os.path.exists(MODEL_PATH):
            print(f"[AI] 모델 파일이 존재하지 않습니다: {MODEL_PATH}")
            return False

        checkpoint = torch.load(MODEL_PATH, map_location="cpu", weights_only=False)

        # 클래스 레이블 정보 추출
        if checkpoint.get("id2label"):
            num_classes = len(checkpoint["id2label"])
            id2label = checkpoint["id2label"]
        else:
            num_classes = checkpoint.get("num_classes", 5)
            id2label = {i: f"class_{i}" for i in range(num_classes)}

        # 모델 초기화
        model = CustomDeta(num_labels=num_classes)

        # state_dict 로드
        if "model_state_dict" in checkpoint:
            state_dict = checkpoint["model_state_dict"]
            # float32로 변환
            for k, v in state_dict.items():
                if isinstance(v, torch.Tensor):
                    state_dict[k] = v.to(torch.float32)
            model.model.load_state_dict(state_dict, strict=False)

        model.eval()

        # 이미지 전처리 프로세서 로드
        processor = DetaImageProcessor.from_pretrained("jozhang97/deta-resnet-50")

        print(f"[AI] 모델 로드 성공! (클래스 {num_classes}개)")
        print(f"[AI] 레이블: {id2label}")
        return True

    except Exception as e:
        import traceback
        print(f"[AI] 모델 로드 실패: {e}")
        traceback.print_exc()
        model, processor, id2label = None, None, None
        return False


def get_model():
    """현재 로드된 모델 반환"""
    return model


def get_processor():
    """현재 로드된 프로세서 반환"""
    return processor


def get_id2label():
    """현재 로드된 레이블 맵 반환"""
    return id2label


def is_model_loaded():
    """모델 로드 여부 확인"""
    return model is not None and processor is not None
