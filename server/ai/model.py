"""
AI 모델 정의
CustomDeta 모델 클래스
"""
import torch.nn as nn
from transformers import DetaConfig, DetaForObjectDetection


class CustomDeta(nn.Module):
    """커스텀 DETA 객체 탐지 모델"""

    def __init__(self, num_labels):
        super(CustomDeta, self).__init__()
        # config만 불러온 뒤 num_labels 수정
        config = DetaConfig.from_pretrained("jozhang97/deta-resnet-50")
        config.num_labels = int(num_labels)

        # 여기서 모델 초기화 (pretrained weight 불러오지 않음)
        self.model = DetaForObjectDetection(config)

    def forward(self, pixel_values, pixel_mask=None, labels=None):
        return self.model(
            pixel_values=pixel_values, pixel_mask=pixel_mask, labels=labels
        )

    def predict(self, pixel_values, pixel_mask=None):
        return self.model(pixel_values=pixel_values, pixel_mask=pixel_mask)
