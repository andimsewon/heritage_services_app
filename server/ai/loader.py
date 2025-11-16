"""
AI 모델 로더
모델 로딩 및 상태 관리
"""

import glob
import os
import pickle
import shutil
import sys
import tempfile
import traceback
import zipfile
from pathlib import Path

import torch
from transformers import DetaImageProcessor

from .model import CustomDeta

# 상수 정의
AI_DIR = Path(__file__).resolve().parent
DEFAULT_NUM_CLASSES = 4
KOREAN_LABELS = {0: "갈램", 1: "균열", 2: "부후", 3: "압괴/터짐"}
DETA_MODEL_NAME = "jozhang97/deta-resnet-50"

PREFERRED_MODEL_HINTS = [
    "hanok_damage_model.pth",
    "hanok_damage_model.pt",
    "best_model.pth",
    "best_model.pt",
    "models/hanok_damage_model.pth",
    "models/hanok_damage_model.pt",
    "models/best_model.pth",
    "models/best_model.pt",
    "hanok_damage_model_1108/best_model.pth",
    "hanok_damage_model_1108/best_model.pt",
]

# 전역 변수
model = None
processor = None
id2label = None
id2label_korean = None
resolved_model_path = None


def _resolve_path_hint(path_hint):
    """지정된 경로(파일 또는 폴더)를 실제 모델 파일 경로로 변환"""
    if not path_hint:
        return None

    candidate = Path(path_hint)
    if not candidate.is_absolute():
        candidate = AI_DIR / candidate

    if candidate.is_dir():
        return _find_best_checkpoint(str(candidate))
    if candidate.is_file():
        return str(candidate)
    return None


def _find_model_path():
    """
    모델 파일 경로 찾기
    1. 환경변수 MODEL_PATH 확인
    2. PREFERRED_MODEL_HINTS 순서대로 검색
    3. 기본값: 현재 디렉토리의 가장 최근 .pt 또는 .pth 파일
    """
    env_path = os.getenv("MODEL_PATH")
    if env_path:
        resolved = _resolve_path_hint(env_path)
        if resolved:
            return resolved
        print(f"[AI] ⚠️  환경변수 MODEL_PATH 경로를 찾을 수 없습니다: {env_path}")

    for hint in PREFERRED_MODEL_HINTS:
        resolved = _resolve_path_hint(hint)
        if resolved:
            return resolved

    pt_files = glob.glob(str(AI_DIR / "*.pt"))
    pth_files = glob.glob(str(AI_DIR / "*.pth"))
    all_files = pt_files + pth_files

    if all_files:
        return max(all_files, key=os.path.getmtime)

    return None


def _find_best_checkpoint(model_dir):
    """폴더 내에서 best_map이 가장 높은 체크포인트를 찾습니다"""
    print(f"[AI] 모델 폴더에서 최적 모델 검색 중: {model_dir}")

    checkpoint_files = glob.glob(os.path.join(model_dir, "*.pth"))
    checkpoint_files.extend(glob.glob(os.path.join(model_dir, "*.pt")))

    if not checkpoint_files:
        print(f"[AI] ⚠️  {model_dir}에 모델 파일(.pth/.pt)이 없습니다!")
        return None

    print(f"[AI] 발견된 체크포인트: {len(checkpoint_files)}개")

    best_checkpoint_path = None
    best_map_value = -1

    for ckpt_path in sorted(checkpoint_files):
        try:
            ckpt = torch.load(ckpt_path, map_location="cpu", weights_only=False)
            epoch = ckpt.get("epoch", -1)
            best_map = ckpt.get("best_map", -1)

            filename = os.path.basename(ckpt_path)
            epoch_str = epoch + 1 if epoch >= 0 else "N/A"
            map_str = f"{best_map:.4f}" if best_map >= 0 else "N/A"
            print(f"[AI]   📄 {filename} - Epoch: {epoch_str}, Best mAP: {map_str}")

            if isinstance(best_map, (int, float)) and best_map > best_map_value:
                best_map_value = best_map
                best_checkpoint_path = ckpt_path

        except Exception as e:
            print(f"[AI]   ⚠️  {os.path.basename(ckpt_path)}: 로드 실패 - {e}")
            continue

    if best_checkpoint_path:
        print(
            f"[AI] ✅ 최고 성능 모델 선택: {os.path.basename(best_checkpoint_path)} "
            f"(Best mAP: {best_map_value:.4f})"
        )
        return best_checkpoint_path

    # best_map이 없으면 가장 최근 파일 사용
    print("[AI] ⚠️  best_map 정보가 없어 가장 최근 체크포인트를 사용합니다.")
    best_checkpoint_path = max(checkpoint_files, key=os.path.getmtime)
    print(f"[AI] ✅ 선택된 모델: {os.path.basename(best_checkpoint_path)}")
    return best_checkpoint_path


def _setup_numpy_compatibility():
    """numpy 버전 호환성 문제 해결 (numpy._core -> numpy.core 매핑)"""
    try:
        import numpy.core as numpy_core

        if "numpy._core" not in sys.modules:
            sys.modules["numpy._core"] = numpy_core
            sys.modules["numpy._core._multiarray_umath"] = numpy_core._multiarray_umath
    except Exception:
        pass  # 실패해도 계속 진행


def _validate_model_file(model_path):
    """모델 파일 존재 여부 및 무결성 검사"""
    if not os.path.exists(model_path):
        print(f"[AI] ❌ 모델 파일이 존재하지 않습니다: {model_path}")
        return False

    file_size = os.path.getsize(model_path)
    print(f"[AI] 모델 파일 크기: {file_size / (1024 * 1024):.2f} MB")

    # ZIP 아카이브 무결성 검사
    if model_path.endswith((".pth", ".pt")):
        try:
            with zipfile.ZipFile(model_path, "r") as z:
                z.testzip()
            print("[AI] ✅ ZIP 아카이브 무결성 검사 통과")
        except zipfile.BadZipFile:
            print("[AI] ⚠️  ZIP 아카이브 형식이 아닙니다 (정상일 수 있음)")
        except Exception as e:
            print(f"[AI] ⚠️  파일 검증 중 오류 (무시하고 계속): {str(e)[:100]}")

    return True


def _load_checkpoint_with_fallback(model_path):
    """여러 방법으로 체크포인트 로드 시도"""
    load_methods = [
        (
            "기본 방법 (weights_only=False)",
            lambda: torch.load(model_path, map_location="cpu", weights_only=False),
        ),
        (
            "weights_only=True",
            lambda: torch.load(model_path, map_location="cpu", weights_only=True),
        ),
        ("파일 핸들 직접 사용", lambda: _load_with_file_handle(model_path)),
        ("pickle 직접 사용", lambda: _load_with_pickle(model_path)),
        ("임시 파일로 복사 후 재시도", lambda: _load_with_temp_file(model_path)),
    ]

    last_error = None
    for method_name, load_func in load_methods:
        try:
            print(f"[AI] 로드 시도: {method_name}")
            checkpoint = load_func()
            print(f"[AI] ✅ {method_name}으로 로드 성공!")
            return checkpoint
        except Exception as e:
            last_error = e
            error_msg = str(e)[:200]
            print(f"[AI] ⚠️  {method_name} 실패: {error_msg}")

    print("[AI] ❌ 모든 로드 방법 실패")
    if last_error:
        print(f"[AI] 마지막 오류: {last_error}")
    return None


def _load_with_file_handle(model_path):
    """파일 핸들을 직접 사용하여 로드"""
    with open(model_path, "rb") as f:
        return torch.load(f, map_location="cpu", weights_only=False)


def _load_with_pickle(model_path):
    """pickle을 직접 사용하여 로드"""
    with open(model_path, "rb") as f:
        unpickler = pickle.Unpickler(f)
        unpickler.persistent_load = lambda pid: None  # persistent ID 무시
        return unpickler.load()


def _load_with_temp_file(model_path):
    """임시 파일로 복사 후 재시도"""
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pth") as tmp_file:
        tmp_path = tmp_file.name
        try:
            shutil.copy2(model_path, tmp_path)
            checkpoint = torch.load(tmp_path, map_location="cpu", weights_only=False)
            return checkpoint
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)


def _extract_labels(checkpoint):
    """체크포인트에서 레이블 정보 추출"""
    if checkpoint.get("id2label"):
        num_classes = len(checkpoint["id2label"])
        id2label = checkpoint["id2label"]
    else:
        num_classes = checkpoint.get("num_classes", DEFAULT_NUM_CLASSES)
        id2label = {i: f"LABEL_{i}" for i in range(num_classes)}

    # 한글 레이블 매핑
    id2label_korean = {k: v for k, v in KOREAN_LABELS.items() if k < num_classes}

    return num_classes, id2label, id2label_korean


def _load_model_state(model, checkpoint):
    """모델에 체크포인트 state_dict 로드"""
    if "model_state_dict" in checkpoint:
        state_dict = checkpoint["model_state_dict"]
        # float32로 변환
        for k, v in state_dict.items():
            if isinstance(v, torch.Tensor):
                state_dict[k] = v.to(torch.float32)
        model.model.load_state_dict(state_dict, strict=False)
    else:
        print(
            "[AI] ⚠️  체크포인트에 'model_state_dict' 키가 없습니다. 직접 로드 시도..."
        )
        model.model.load_state_dict(checkpoint, strict=False)


def _print_model_info(checkpoint, num_classes, id2label, id2label_korean):
    """모델 정보 출력"""
    print("[AI] ✅ 모델 로드 성공!")
    print(f"[AI]    클래스 수: {num_classes}개")
    print(f"[AI]    레이블: {id2label}")
    print(f"[AI]    한글 레이블: {id2label_korean}")

    if "epoch" in checkpoint:
        print(f"[AI]    Epoch: {checkpoint['epoch'] + 1}")
    if "best_map" in checkpoint:
        print(f"[AI]    Best mAP: {checkpoint['best_map']:.4f}")


def _select_device():
    """최적의 디바이스 선택 (CUDA -> CPU 폴백)"""
    if torch.cuda.is_available():
        try:
            # CUDA 메모리 정리
            torch.cuda.empty_cache()
            device = torch.device("cuda")
            print(f"[AI] ✅ CUDA 디바이스 사용: {torch.cuda.get_device_name(0)}")
            return device
        except Exception as e:
            print(f"[AI] ⚠️  CUDA 사용 실패, CPU로 폴백: {e}")
    else:
        print("[AI] ℹ️  CUDA를 사용할 수 없어 CPU를 사용합니다.")
    return torch.device("cpu")


def load_ai_model(max_retries=3, retry_delay=2):
    """
    AI 모델을 메모리에 로드 (재시도 로직 포함)

    Args:
        max_retries: 최대 재시도 횟수
        retry_delay: 재시도 간 대기 시간 (초)
    """
    global model, processor, id2label, id2label_korean, resolved_model_path

    for attempt in range(max_retries):
        try:
            if attempt > 0:
                print(f"[AI] 🔄 모델 로드 재시도 {attempt}/{max_retries-1}...")
                import time

                time.sleep(retry_delay * attempt)  # 지수 백오프

            # 모델 경로 찾기
            model_path = _find_model_path()
            if not model_path:
                if attempt == max_retries - 1:
                    print("[AI] ❌ 모델 파일을 찾을 수 없습니다!")
                    print("[AI]    다음 위치를 확인해주세요:")
                    print("[AI]    1. 환경변수 MODEL_PATH 설정")
                    print(f"[AI]    2. {AI_DIR}/ 디렉토리에 .pt 또는 .pth 파일 배치")
                    return False
                continue

            resolved_model_path = model_path
            print(f"[AI] 모델 파일 로드 중: {model_path}")

            # 파일 검증
            if not _validate_model_file(model_path):
                if attempt == max_retries - 1:
                    resolved_model_path = None
                    return False
                continue

            # numpy 호환성 설정
            _setup_numpy_compatibility()

            # 체크포인트 로드
            checkpoint = _load_checkpoint_with_fallback(model_path)
            if checkpoint is None:
                if attempt == max_retries - 1:
                    file_size = os.path.getsize(model_path)
                    print("[AI] ⚠️  모델 파일이 손상되었을 수 있습니다.")
                    print("[AI]    해결 방법:")
                    print("[AI]    1. 모델 파일을 다시 다운로드/복사하세요")
                    print("[AI]    2. 파일이 완전히 전송되었는지 확인하세요")
                    print(
                        f"[AI]    3. 파일 크기가 정상인지 확인하세요 (현재: {file_size / (1024*1024):.2f} MB)"
                    )
                    traceback.print_exc()
                    resolved_model_path = None
                    return False
                continue

            # 레이블 정보 추출
            num_classes, id2label, id2label_korean = _extract_labels(checkpoint)

            # 디바이스 선택
            device = _select_device()

            # 모델 초기화 및 로드
            try:
                model = CustomDeta(num_labels=num_classes)
                _load_model_state(model, checkpoint)

                # 모델을 선택된 디바이스로 이동
                model = model.to(device)
                model.eval()

                # 메모리 정리
                if device.type == "cuda":
                    torch.cuda.empty_cache()
            except RuntimeError as e:
                error_msg = str(e).lower()
                if "out of memory" in error_msg or "cuda" in error_msg:
                    print(f"[AI] ⚠️  GPU 메모리 부족, CPU로 폴백 시도...")
                    device = torch.device("cpu")
                    model = CustomDeta(num_labels=num_classes)
                    _load_model_state(model, checkpoint)
                    model = model.to(device)
                    model.eval()
                else:
                    raise

            # 이미지 전처리 프로세서 로드 (재시도 포함)
            processor = None
            for proc_attempt in range(3):
                try:
                    processor = DetaImageProcessor.from_pretrained(DETA_MODEL_NAME)
                    break
                except Exception as e:
                    if proc_attempt == 2:
                        raise
                    print(f"[AI] ⚠️  프로세서 로드 실패, 재시도 {proc_attempt+1}/3: {e}")
                    import time

                    time.sleep(1)

            if processor is None:
                raise RuntimeError("프로세서 로드 실패")

            # 모델 정보 출력
            _print_model_info(checkpoint, num_classes, id2label, id2label_korean)
            print(f"[AI] ✅ 모델이 {device}에 성공적으로 로드되었습니다!")

            return True

        except Exception as e:
            error_msg = str(e)
            print(
                f"[AI] ❌ 모델 로드 실패 (시도 {attempt+1}/{max_retries}): {error_msg}"
            )
            if attempt == max_retries - 1:
                traceback.print_exc()
                model, processor, id2label, id2label_korean, resolved_model_path = (
                    None,
                    None,
                    None,
                    None,
                    None,
                )
                return False
            # 다음 시도를 위해 전역 변수 초기화
            model, processor, id2label, id2label_korean = None, None, None, None

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


def get_id2label_korean():
    """현재 로드된 한글 레이블 맵 반환"""
    return id2label_korean


def is_model_loaded():
    """모델 로드 여부 확인"""
    return model is not None and processor is not None


def get_resolved_model_path():
    """마지막으로 로드에 사용된 모델 경로 반환"""
    return resolved_model_path


def resolve_model_path():
    """현재 설정에서 탐색된 모델 경로 반환 (로드 없이)"""
    return _find_model_path()
