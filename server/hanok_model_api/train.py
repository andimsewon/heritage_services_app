#!/usr/bin/env python3

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import torchvision
import os
import albumentations as A
import numpy as np
from tqdm import tqdm
import random
from transformers import DetaImageProcessor, DetaForObjectDetection
from collections import Counter
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from pycocotools.coco import COCO
from pycocotools.cocoeval import COCOeval
import json
import torchvision.ops as ops
import argparse


# 설정
IMG_FOLDER = '/workspace/hanok/data'
BATCH_SIZE = 2
EVAL_THRESHOLD = 0.05
EPOCHS = 30


class CocoDetection(torchvision.datasets.CocoDetection):
    """커스텀 CocoDetection 클래스 + Data Augmentation 처리"""
    
    def __init__(self, img_folder, processor, file_name, transform=None, eval=False):
        ann_file = file_name
        super(CocoDetection, self).__init__(img_folder, ann_file)
        self.processor = processor
        self.transform = transform
        self.augmented_data = []
        self.origin_data = []
        self.add_ids = len(self.ids)
        
        if not eval:
            print("Applying augmentations to entire dataset...")

        for idx in tqdm(range(len(self))):
            img, anns = super(CocoDetection, self).__getitem__(idx)
            img_np = np.array(img)

            # COCO → Pascal VOC 변환
            bboxes = []
            category_ids = []
            for ann in anns:
                x, y, w, h = ann['bbox']
                x_min, y_min, x_max, y_max = x, y, x + w, y + h
                bboxes.append([x_min, y_min, x_max, y_max])
                category_ids.append(ann['category_id'])

            image_id = self.ids[idx]
            target = {'image_id': image_id, 'annotations': anns}
            self.origin_data.append((img_np, target))
            
            # Augmentation 적용 (평가 시에는 스킵)
            if self.transform and not eval:
                contains_class_2 = any(cat_id == 2 for cat_id in category_ids)
                n_aug = 5 if contains_class_2 else 1

                for _ in range(n_aug):
                    trans_fun = random.choice(self.transform)
                    augmented = trans_fun(image=img_np, bboxes=bboxes, category_ids=category_ids)

                    if len(augmented['bboxes']) == 0:
                        continue

                    # 유효하지 않은 bbox 제거
                    valid_bboxes = []
                    valid_cats = []
                    for bbox, cat_id in zip(augmented['bboxes'], augmented['category_ids']):
                        x_min, y_min, x_max, y_max = bbox
                        w, h = x_max - x_min, y_max - y_min
                        if w > 1 and h > 1:
                            valid_bboxes.append([x_min, y_min, x_max, y_max])
                            valid_cats.append(cat_id)

                    if len(valid_bboxes) == 0:
                        continue

                    # Pascal VOC → COCO 형식 복원
                    aug_anns = []
                    for bbox, cat_id in zip(augmented['bboxes'], augmented['category_ids']):
                        x_min, y_min, x_max, y_max = bbox
                        w, h = x_max - x_min, y_max - y_min
                        area = w * h
                        aug_anns.append({
                            'bbox': [x_min, y_min, w, h],
                            'category_id': cat_id,
                            'area': area,
                            'iscrowd': 0
                        })

                    aug_image_id = self.add_ids
                    self.add_ids += 1
                    target = {'image_id': aug_image_id, 'annotations': aug_anns}
                    self.augmented_data.append((augmented['image'], target))

        self.final_data = self.origin_data + self.augmented_data

    def __getitem__(self, idx):
        img_np, target = self.final_data[idx]
        encoding = self.processor(images=img_np, annotations=target, return_tensors="pt")
        pixel_values = encoding["pixel_values"].squeeze()
        labels = encoding["labels"][0]
        return pixel_values, labels


def get_augmentation_transforms():
    """Augmentation 변환 정의"""
    return [
        # 좌우 반전
        A.Compose([A.HorizontalFlip(p=1)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 흑백 + 밝기 대비 변화
        A.Compose([A.ToGray(p=1.0), A.RandomBrightnessContrast(p=1)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 이동/확대/회전
        A.Compose([A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.1, rotate_limit=30, p=1)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 블러 + 대비
        A.Compose([A.GaussianBlur(blur_limit=(3, 7), p=1.0), A.RandomBrightnessContrast(p=1.0)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 작은 스케일 변화
        A.Compose([A.RandomScale(scale_limit=0.2, p=1.0), A.HorizontalFlip(p=0.5)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 색상 왜곡
        A.Compose([A.RGBShift(r_shift_limit=20, g_shift_limit=20, b_shift_limit=20, p=1.0), 
                   A.RandomBrightnessContrast(p=1.0)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
        
        # 그리드 왜곡
        A.Compose([A.GridDistortion(p=1.0)], 
                 bbox_params=A.BboxParams(format='pascal_voc', label_fields=['category_ids'], min_visibility=0.3)),
    ]


class CustomDeta(nn.Module):
    """커스텀 DETA 모델"""
    
    def __init__(self, num_labels):
        super(CustomDeta, self).__init__()
        self.model = DetaForObjectDetection.from_pretrained(
            "jozhang97/deta-resnet-50",
            num_labels=num_labels,
            auxiliary_loss=True,
            ignore_mismatched_sizes=True
        )

    def forward(self, pixel_values, pixel_mask, labels):
        return self.model(pixel_values=pixel_values, pixel_mask=pixel_mask, labels=labels)

    def predict(self, pixel_values, pixel_mask):
        return self.model(pixel_values=pixel_values, pixel_mask=pixel_mask)


def collate_fn(batch, processor):
    """데이터 로더 collate 함수"""
    pixel_values = [item[0] for item in batch]
    encoding = processor.pad(pixel_values, return_tensors="pt")
    labels = [item[1] for item in batch]
    return {
        'pixel_values': encoding['pixel_values'],
        'pixel_mask': encoding['pixel_mask'],
        'labels': labels
    }


def train_loop(dataloader, model, optimizer, device):
    """학습 루프"""
    model.train()
    total_loss = 0
    num_batches = 0
    
    for batch in tqdm(dataloader, desc="Training"):
        pixel_values = batch['pixel_values'].to(device)
        pixel_mask = batch['pixel_mask'].to(device)
        labels = [{k: v.to(device) for k, v in t.items()} for t in batch["labels"]]

        optimizer.zero_grad()
        output = model(pixel_values, pixel_mask, labels)
        loss = output.loss
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item()
        num_batches += 1

    return total_loss / num_batches


def apply_nms_to_result(result, iou_threshold=0.5, score_threshold=0.1):
    """NMS 적용"""
    if len(result["boxes"]) == 0:
        return result
    
    boxes = torch.tensor(result["boxes"], dtype=torch.float32)
    scores = torch.tensor(result["scores"], dtype=torch.float32)
    labels = torch.tensor(result["labels"], dtype=torch.int64)
    
    score_mask = scores >= score_threshold
    boxes, scores, labels = boxes[score_mask], scores[score_mask], labels[score_mask]
    
    if len(boxes) == 0:
        return {"boxes": [], "scores": [], "labels": []}
    
    final_boxes, final_scores, final_labels = [], [], []
    unique_labels = torch.unique(labels)
    
    for label in unique_labels:
        label_mask = labels == label
        label_boxes, label_scores = boxes[label_mask], scores[label_mask]
        
        if len(label_boxes) > 0:
            keep_indices = ops.nms(label_boxes, label_scores, iou_threshold)
            final_boxes.extend(label_boxes[keep_indices].tolist())
            final_scores.extend(label_scores[keep_indices].tolist())
            final_labels.extend([label.item()] * len(keep_indices))
    
    return {"boxes": final_boxes, "scores": final_scores, "labels": final_labels}


def eval_loop(dataloader, model, processor, coco_gt_json_path, device, save_path="predictions.json", 
              threshold=EVAL_THRESHOLD, apply_nms=True):
    """평가 루프"""
    model.eval()
    coco_predictions = []

    with torch.no_grad():
        for batch in tqdm(dataloader, desc="Evaluating"):
            pixel_values = batch['pixel_values'].to(device)
            pixel_mask = batch.get('pixel_mask')
            if pixel_mask is not None:
                pixel_mask = pixel_mask.to(device)

            outputs = model.predict(pixel_values=pixel_values, pixel_mask=pixel_mask)
            
            w, h = batch["labels"][0]['size']
            image_id = int(batch["labels"][0]['image_id'][0])

            results = processor.post_process_object_detection(
                outputs=outputs, target_sizes=[(w, h)], threshold=threshold
            )

            result = results[0]
            if apply_nms:
                result = apply_nms_to_result(result, iou_threshold=0.5, score_threshold=threshold)

            for box, score, label in zip(result["boxes"], result["scores"], result["labels"]):
                x, y, x2, y2 = box
                w_box, h_box = x2 - x, y2 - y
                coco_predictions.append({
                    "image_id": image_id,
                    "category_id": int(label),
                    "bbox": [x, y, w_box, h_box],
                    "score": float(score)
                })

    # 예측 저장
    with open(save_path, "w") as f:
        json.dump(coco_predictions, f)

    print(f"Saved predictions to {save_path}")
    print(f"총 예측 개수: {len(coco_predictions)}")

    # 예측이 없는 경우 처리
    if len(coco_predictions) == 0:
        print("예측 결과가 없습니다. 임계값을 낮춰보세요.")
        return 0.0, 0.0

    # COCO 평가
    try:
        coco_gt = COCO(coco_gt_json_path)
        coco_dt = coco_gt.loadRes(save_path)
        coco_eval = COCOeval(coco_gt, coco_dt, iouType='bbox')
        coco_eval.params.iouThrs = np.linspace(0.1, 0.5, 5)
        coco_eval.evaluate()
        coco_eval.accumulate()
        coco_eval.summarize()
        return coco_eval.stats[0], coco_eval.stats[6]
    except Exception as e:
        print(f"COCO 평가 중 오류: {e}")
        return 0.0, 0.0


def train_and_evaluate(model, train_loader, val_loader, processor, coco_gt_json_path,
                       optimizer, device, num_epochs=10, model_save_path="best_model"):
    """전체 학습 및 평가"""
    best_map = 0.0
    best_epoch = -1

    for epoch in range(num_epochs):
        print(f"\nEpoch {epoch + 1}/{num_epochs}")
        
        # 학습
        avg_loss = train_loop(train_loader, model, optimizer, device)
        print(f"Average training loss: {avg_loss:.4f}")

        # 평가
        precision, recall = eval_loop(val_loader, model, processor, coco_gt_json_path, device)
        current_map = precision
        
        print(f"COCO mAP: {precision:.4f}, Recall: {recall:.4f}")

        # 최고 성능 모델 저장
        if current_map > best_map:
            best_map = current_map
            best_epoch = epoch
            
            # ML Backend 호환 형태로 저장
            checkpoint = {
                'model_state_dict': model.model.state_dict(),
                'processor_state': None,
                'id2label': None,  # 나중에 설정
                'num_classes': None,  # 나중에 설정
                'best_map': best_map,
                'epoch': epoch,
                'optimizer_state_dict': optimizer.state_dict()
            }
            
            torch.save(checkpoint, f"{model_save_path}_ml_backend.pt")
            print(f"Best model saved: {model_save_path}_ml_backend.pt (mAP = {best_map:.4f})")

    print(f"\nTraining complete. Best epoch: {best_epoch + 1}, Best mAP: {best_map:.4f}")
    return model


def validate_dataset(dataset, name="dataset"):
    """데이터셋 유효성 검사"""
    print(f"\n데이터셋 검증 ({name}):")
    print(f"- 총 이미지 수: {len(dataset.final_data)}")
    print(f"- 원본 데이터: {len(dataset.origin_data)}")
    print(f"- 증강 데이터: {len(dataset.augmented_data)}")
    
    empty_annotations = sum(1 for _, target in dataset.final_data if len(target['annotations']) == 0)
    print(f"- 빈 어노테이션: {empty_annotations}개")
    
    invalid_boxes = 0
    for _, target in dataset.final_data:
        for ann in target['annotations']:
            x, y, w, h = ann['bbox']
            if w <= 0 or h <= 0:
                invalid_boxes += 1
    print(f"- 유효하지 않은 박스: {invalid_boxes}개")


def count_categories(dataset, name="dataset"):
    """클래스 분포 출력"""
    cat_counter = Counter()
    for _, target in dataset.final_data:
        for ann in target["annotations"]:
            cat_counter[ann["category_id"]] += 1

    print(f"\n{name} 클래스 분포:")
    for k, v in sorted(cat_counter.items()):
        print(f"  Class {k}: {v}개")


def main():
    parser = argparse.ArgumentParser(description='한옥 손상 감지 모델 학습')
    parser.add_argument('--data_dir', type=str, default='/workspace/hanok/data', help='데이터 디렉토리')
    parser.add_argument('--epochs', type=int, default=30, help='학습 에포크 수')
    parser.add_argument('--batch_size', type=int, default=2, help='배치 크기')
    parser.add_argument('--lr', type=float, default=1e-4, help='학습률')
    parser.add_argument('--lr_backbone', type=float, default=1e-5, help='백본 학습률')
    parser.add_argument('--weight_decay', type=float, default=1e-4, help='가중치 감쇠')
    parser.add_argument('--eval_threshold', type=float, default=0.05, help='평가 임계값')
    parser.add_argument('--save_path', type=str, default='hanok_damage_model', help='모델 저장 경로')
    parser.add_argument('--no_cuda', action='store_true', help='CUDA 사용 안함')
    
    args = parser.parse_args()
    
    # 디바이스 설정
    device = torch.device("cuda" if torch.cuda.is_available() and not args.no_cuda else "cpu")
    print(f"사용할 디바이스: {device}")
    
    # Processor 로드
    processor = DetaImageProcessor.from_pretrained("jozhang97/deta-resnet-50")
    
    # Augmentation 변환
    transform = get_augmentation_transforms()
    
    # 데이터셋 로드
    print("데이터셋 로딩 중...")
    train_dataset = CocoDetection(
        img_folder=args.data_dir, 
        processor=processor, 
        file_name='data/train.json', 
        transform=transform
    )
    val_dataset = CocoDetection(
        img_folder=args.data_dir, 
        processor=processor, 
        file_name='data/val.json', 
        eval=True
    )
    test_dataset = CocoDetection(
        img_folder=args.data_dir, 
        processor=processor, 
        file_name='data/test.json', 
        eval=True
    )
    
    # 데이터셋 검증
    validate_dataset(train_dataset, "Train")
    validate_dataset(val_dataset, "Validation")
    validate_dataset(test_dataset, "Test")
    
    # 클래스 분포 출력
    count_categories(train_dataset, "Train")
    count_categories(val_dataset, "Validation")
    count_categories(test_dataset, "Test")
    
    # 클래스 매핑
    cats = train_dataset.coco.cats
    id2label = {k: v['name'] for k, v in cats.items()}
    print(f"\n클래스 매핑: {id2label}")
    
    # 데이터 로더
    train_dataloader = DataLoader(
        train_dataset,
        collate_fn=lambda batch: collate_fn(batch, processor),
        batch_size=args.batch_size,
        shuffle=True
    )
    val_dataloader = DataLoader(
        val_dataset,
        collate_fn=lambda batch: collate_fn(batch, processor),
        batch_size=1
    )
    test_dataloader = DataLoader(
        test_dataset,
        collate_fn=lambda batch: collate_fn(batch, processor),
        batch_size=1
    )
    
    # 모델 생성
    model = CustomDeta(num_labels=len(id2label))
    model.to(device)
    
    # Optimizer 설정
    param_dicts = [
        {
            "params": [p for n, p in model.named_parameters()
                      if "backbone" not in n and p.requires_grad]
        },
        {
            "params": [p for n, p in model.named_parameters()
                      if "backbone" in n and p.requires_grad],
            "lr": args.lr_backbone,
        },
    ]
    optimizer = torch.optim.AdamW(param_dicts, lr=args.lr, weight_decay=args.weight_decay)
    
    # 학습 실행
    print(f"\n학습 시작 (에포크: {args.epochs})")
    trained_model = train_and_evaluate(
        model=model,
        train_loader=train_dataloader,
        val_loader=val_dataloader,
        processor=processor,
        coco_gt_json_path="data/val.json",
        optimizer=optimizer,
        device=device,
        num_epochs=args.epochs,
        model_save_path=args.save_path
    )
    
    # 체크포인트에 클래스 정보 추가
    checkpoint_path = f"{args.save_path}_ml_backend.pt"
    if os.path.exists(checkpoint_path):
        checkpoint = torch.load(checkpoint_path)
        checkpoint['id2label'] = id2label
        checkpoint['num_classes'] = len(id2label)
        torch.save(checkpoint, checkpoint_path)
        print(f"클래스 정보가 체크포인트에 추가되었습니다: {checkpoint_path}")
    
    # 테스트 평가
    print("\n테스트셋 평가 중...")
    eval_loop(test_dataloader, trained_model, processor, "data/test.json", device, 
              save_path="test_predictions.json", threshold=0.3)
    
    print("학습 완료!")


if __name__ == "__main__":
    main()