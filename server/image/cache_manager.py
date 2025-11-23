"""
간단한 디스크 기반 이미지 캐시

Firebase Storage 원본을 반복해서 다운로드하지 않도록
프록시된 이미지를 파일로 저장하고 재사용한다.
"""

from __future__ import annotations

import json
import time
from pathlib import Path
from threading import Lock
from typing import Optional, Tuple

# 캐시 파라미터 (메모리 캐시와 동일한 TTL 사용)
DEFAULT_TTL = 4 * 60 * 60  # 4시간
MAX_CACHE_ITEMS = 800
MAX_CACHE_SIZE_BYTES = 512 * 1024 * 1024  # 512MB


class DiskImageCache:
    """간단한 디스크 캐시 구현."""

    def __init__(self) -> None:
        self.cache_dir = Path(__file__).resolve().parent / ".cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._lock = Lock()
        self._last_cleanup = 0.0

    def _data_path(self, key: str) -> Path:
        return self.cache_dir / f"{key}.bin"

    def _meta_path(self, key: str) -> Path:
        return self.cache_dir / f"{key}.json"

    def _delete(self, key: str) -> None:
        try:
            self._data_path(key).unlink(missing_ok=True)  # type: ignore[attr-defined]
        except Exception:
            pass
        try:
            self._meta_path(key).unlink(missing_ok=True)  # type: ignore[attr-defined]
        except Exception:
            pass

    def get(self, key: str) -> Optional[Tuple[bytes, str]]:
        """디스크 캐시 조회."""
        data_path = self._data_path(key)
        meta_path = self._meta_path(key)
        if not data_path.exists() or not meta_path.exists():
            return None

        try:
            metadata = json.loads(meta_path.read_text())
            timestamp = float(metadata.get("timestamp", 0))
            ttl = int(metadata.get("ttl", DEFAULT_TTL))
        except Exception:
            self._delete(key)
            return None

        if time.time() - timestamp > ttl:
            self._delete(key)
            return None

        try:
            data = data_path.read_bytes()
        except FileNotFoundError:
            self._delete(key)
            return None

        content_type = metadata.get("content_type", "image/jpeg")
        return data, content_type

    def set(self, key: str, data: bytes, content_type: str) -> None:
        """캐시에 저장."""
        if not data:
            return

        with self._lock:
            try:
                self.cache_dir.mkdir(parents=True, exist_ok=True)
                self._data_path(key).write_bytes(data)
                metadata = {
                    "timestamp": time.time(),
                    "ttl": DEFAULT_TTL,
                    "size": len(data),
                    "content_type": content_type,
                }
                self._meta_path(key).write_text(json.dumps(metadata))
            except Exception:
                return

            self._cleanup_if_needed()

    def _cleanup_if_needed(self, force: bool = False) -> None:
        """TTL 및 최대 용량에 따라 정리."""
        now = time.time()
        if not force and now - self._last_cleanup < 120:
            return

        self._last_cleanup = now
        entries = []
        total_size = 0

        for meta_path in self.cache_dir.glob("*.json"):
            key = meta_path.stem
            data_path = self._data_path(key)
            if not data_path.exists():
                meta_path.unlink(missing_ok=True)
                continue

            try:
                metadata = json.loads(meta_path.read_text())
            except Exception:
                self._delete(key)
                continue

            timestamp = float(metadata.get("timestamp", 0))
            size = int(metadata.get("size", data_path.stat().st_size))

            if now - timestamp > DEFAULT_TTL:
                self._delete(key)
                continue

            entries.append((key, timestamp, size))
            total_size += size

        if len(entries) > MAX_CACHE_ITEMS or total_size > MAX_CACHE_SIZE_BYTES:
            entries.sort(key=lambda item: item[1])  # 오래된 항목부터 제거
            while entries and (
                len(entries) > MAX_CACHE_ITEMS or total_size > MAX_CACHE_SIZE_BYTES
            ):
                key, _, size = entries.pop(0)
                self._delete(key)
                total_size -= size


disk_cache = DiskImageCache()
