"""
AI 모델 로더
모델 로딩 및 상태 관리
"""
import os
import glob
import torch
from transformers import DetaImageProcessor
from .model import CustomDeta

# 전역 변수
model = None
processor = None
id2label = None
id2label_korean = None


def _find_model_path():
    """
    모델 파일 경로 찾기
    1. 환경변수 MODEL_PATH 확인
    2. 폴더인 경우 best 모델 자동 선택
    3. 기본값: 현재 디렉토리의 .pt 또는 .pth 파일
    """
    # 환경변수로 모델 경로 지정 가능
    env_path = os.getenv("MODEL_PATH")
    if env_path:
        model_path = env_path
    else:
        # 기본값: 현재 디렉토리에서 모델 파일 찾기
        ai_dir = os.path.dirname(__file__)
        # .pt 또는 .pth 파일 찾기
        pt_files = glob.glob(os.path.join(ai_dir, "*.pt"))
        pth_files = glob.glob(os.path.join(ai_dir, "*.pth"))
        all_files = pt_files + pth_files
        
        if all_files:
            # 파일이 여러 개면 가장 최근 것 선택
            model_path = max(all_files, key=os.path.getmtime)
        else:
            # 기본 파일명 시도
            default_pt = os.path.join(ai_dir, "hanok_damage_model.pt")
            default_pth = os.path.join(ai_dir, "hanok_damage_model.pth")
            if os.path.exists(default_pt):
                model_path = default_pt
            elif os.path.exists(default_pth):
                model_path = default_pth
            else:
                return None
    
    # 폴더인 경우 best 모델 찾기
    if os.path.isdir(model_path):
        return _find_best_checkpoint(model_path)
    elif os.path.isfile(model_path):
        return model_path
    else:
        return None


def _find_best_checkpoint(model_dir):
    """
    폴더 내에서 best_map이 가장 높은 체크포인트를 찾습니다
    (노트북의 find_best_checkpoint 함수와 동일한 로직)
    """
    print(f"[AI] 모델 폴더에서 최적 모델 검색 중: {model_dir}")
    
    # 모든 .pth 파일 찾기
    checkpoint_files = glob.glob(os.path.join(model_dir, "*.pth"))
    checkpoint_files.extend(glob.glob(os.path.join(model_dir, "*.pt")))
    
    if not checkpoint_files:
        print(f"[AI] ⚠️  {model_dir}에 모델 파일(.pth/.pt)이 없습니다!")
        return None
    
    print(f"[AI] 발견된 체크포인트: {len(checkpoint_files)}개")
    
    best_checkpoint_path = None
    best_map_value = -1
    
    # 모든 체크포인트 분석
    for ckpt_path in sorted(checkpoint_files):
        try:
            ckpt = torch.load(ckpt_path, map_location='cpu', weights_only=False)
            epoch = ckpt.get('epoch', -1)
            best_map = ckpt.get('best_map', -1)
            
            filename = os.path.basename(ckpt_path)
            print(f"[AI]   📄 {filename} - Epoch: {epoch + 1 if epoch >= 0 else 'N/A'}, Best mAP: {best_map:.4f if best_map >= 0 else 'N/A'}")
            
            # best_map이 가장 높은 것 선택
            if isinstance(best_map, (int, float)) and best_map > best_map_value:
                best_map_value = best_map
                best_checkpoint_path = ckpt_path
                
        except Exception as e:
            print(f"[AI]   ⚠️  {os.path.basename(ckpt_path)}: 로드 실패 - {e}")
            continue
    
    if best_checkpoint_path:
        print(f"[AI] ✅ 최고 성능 모델 선택: {os.path.basename(best_checkpoint_path)} (Best mAP: {best_map_value:.4f})")
        return best_checkpoint_path
    else:
        # best_map이 없으면 가장 최근 파일 사용
        print(f"[AI] ⚠️  best_map 정보가 없어 가장 최근 체크포인트를 사용합니다.")
        best_checkpoint_path = max(checkpoint_files, key=os.path.getmtime)
        print(f"[AI] ✅ 선택된 모델: {os.path.basename(best_checkpoint_path)}")
        return best_checkpoint_path


def load_ai_model():
    """AI 모델을 메모리에 로드"""
    global model, processor, id2label, id2label_korean

    try:
        # 모델 경로 찾기
        model_path = _find_model_path()
        if not model_path:
            print(f"[AI] ❌ 모델 파일을 찾을 수 없습니다!")
            print(f"[AI]    다음 위치를 확인해주세요:")
            print(f"[AI]    1. 환경변수 MODEL_PATH 설정")
            print(f"[AI]    2. {os.path.dirname(__file__)}/ 디렉토리에 .pt 또는 .pth 파일 배치")
            return False

        print(f"[AI] 모델 파일 로드 중: {model_path}")
        
        # 파일 존재 및 크기 확인
        if not os.path.exists(model_path):
            print(f"[AI] ❌ 모델 파일이 존재하지 않습니다: {model_path}")
            return False
        
        file_size = os.path.getsize(model_path)
        print(f"[AI] 모델 파일 크기: {file_size / (1024*1024):.2f} MB")
        
        # 파일 무결성 검사 (ZIP 아카이브인 경우)
        if model_path.endswith(('.pth', '.pt')):
            try:
                import zipfile
                with zipfile.ZipFile(model_path, 'r') as z:
                    z.testzip()
                print(f"[AI] ✅ ZIP 아카이브 무결성 검사 통과")
            except zipfile.BadZipFile:
                print(f"[AI] ⚠️  ZIP 아카이브 형식이 아닙니다 (정상일 수 있음)")
            except Exception as e:
                print(f"[AI] ⚠️  파일 검증 중 오류 (무시하고 계속): {str(e)[:100]}")
        
        # 여러 방법으로 모델 로드 시도
        checkpoint = None
        last_error = None
        
        # 방법 1: 기본 방법
        try:
            print(f"[AI] 로드 시도: 기본 방법 (weights_only=False)")
            checkpoint = torch.load(model_path, map_location="cpu", weights_only=False)
            print(f"[AI] ✅ 기본 방법으로 로드 성공!")
        except Exception as e:
            last_error = e
            print(f"[AI] ⚠️  기본 방법 실패: {str(e)[:200]}")
            
            # 방법 2: weights_only=True (보안 경고 무시)
            try:
                print(f"[AI] 로드 시도: weights_only=True")
                checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)
                print(f"[AI] ✅ weights_only=True로 로드 성공!")
            except Exception as e2:
                last_error = e2
                print(f"[AI] ⚠️  weights_only=True 실패: {str(e2)[:200]}")
                
                # 방법 3: 파일 핸들 직접 사용
                try:
                    print(f"[AI] 로드 시도: 파일 핸들 직접 사용")
                    with open(model_path, 'rb') as f:
                        checkpoint = torch.load(f, map_location="cpu", weights_only=False)
                    print(f"[AI] ✅ 파일 핸들로 로드 성공!")
                except Exception as e3:
                    last_error = e3
                    print(f"[AI] ⚠️  파일 핸들 방법 실패: {str(e3)[:200]}")
                    
                    # 방법 4: pickle 직접 사용 (최후의 수단)
                    try:
                        print(f"[AI] 로드 시도: pickle 직접 사용")
                        import pickle
                        with open(model_path, 'rb') as f:
                            # PyTorch의 특수 포맷 처리
                            unpickler = pickle.Unpickler(f)
                            unpickler.persistent_load = lambda pid: None  # persistent ID 무시
                            checkpoint = unpickler.load()
                        print(f"[AI] ✅ pickle 직접 사용으로 로드 성공!")
                    except Exception as e4:
                        last_error = e4
                        print(f"[AI] ⚠️  pickle 직접 사용 실패: {str(e4)[:200]}")
                        
                        # 방법 5: 파일 복사 후 재시도 (손상된 파일 복구 시도)
                        try:
                            print(f"[AI] 로드 시도: 임시 파일로 복사 후 재시도")
                            import shutil
                            import tempfile
                            with tempfile.NamedTemporaryFile(delete=False, suffix='.pth') as tmp_file:
                                tmp_path = tmp_file.name
                                shutil.copy2(model_path, tmp_path)
                                checkpoint = torch.load(tmp_path, map_location="cpu", weights_only=False)
                                os.unlink(tmp_path)
                            print(f"[AI] ✅ 임시 파일로 로드 성공!")
                        except Exception as e5:
                            last_error = e5
                            print(f"[AI] ⚠️  임시 파일 방법 실패: {str(e5)[:200]}")
        
        if checkpoint is None:
            print(f"[AI] ❌ 모든 로드 방법 실패")
            print(f"[AI] 마지막 오류: {last_error}")
            print(f"[AI] ⚠️  모델 파일이 손상되었을 수 있습니다.")
            print(f"[AI]    해결 방법:")
            print(f"[AI]    1. 모델 파일을 다시 다운로드/복사하세요")
            print(f"[AI]    2. 파일이 완전히 전송되었는지 확인하세요")
            print(f"[AI]    3. 파일 크기가 정상인지 확인하세요 (현재: {file_size / (1024*1024):.2f} MB)")
            import traceback
            traceback.print_exc()
            # 모델 로드 실패해도 서버는 계속 실행되도록 False 반환
            return False

        # 클래스 레이블 정보 추출
        if checkpoint.get("id2label"):
            num_classes = len(checkpoint["id2label"])
            id2label = checkpoint["id2label"]
        else:
            # num_classes 정보 확인
            num_classes = checkpoint.get("num_classes", 4)  # 기본값 4 (노트북과 동일)
            # 기본 레이블 이름 (LABEL_0, LABEL_1, ...)
            id2label = {i: f"LABEL_{i}" for i in range(num_classes)}
        
        # 한글 레이블 매핑 추가 (노트북 참고)
        # id2label_korean: 한글 이름 매핑
        id2label_korean = {
            0: "갈램",
            1: "균열",
            2: "부후",
            3: "압괴/터짐"
        }
        # num_classes가 4보다 작으면 해당 클래스만 매핑
        id2label_korean = {k: v for k, v in id2label_korean.items() if k < num_classes}

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
        else:
            print(f"[AI] ⚠️  체크포인트에 'model_state_dict' 키가 없습니다. 직접 로드 시도...")
            # state_dict가 직접 저장된 경우
            model.model.load_state_dict(checkpoint, strict=False)

        model.eval()

        # 이미지 전처리 프로세서 로드
        processor = DetaImageProcessor.from_pretrained("jozhang97/deta-resnet-50")

        print(f"[AI] ✅ 모델 로드 성공!")
        print(f"[AI]    클래스 수: {num_classes}개")
        print(f"[AI]    레이블: {id2label}")
        print(f"[AI]    한글 레이블: {id2label_korean}")
        if 'epoch' in checkpoint:
            print(f"[AI]    Epoch: {checkpoint['epoch'] + 1}")
        if 'best_map' in checkpoint:
            print(f"[AI]    Best mAP: {checkpoint['best_map']:.4f}")
        return True

    except Exception as e:
        import traceback
        print(f"[AI] ❌ 모델 로드 실패: {e}")
        traceback.print_exc()
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
