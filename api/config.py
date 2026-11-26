"""Đọc cấu hình API và biến môi trường tùy chọn từ api/.env."""

import os
from pathlib import Path


API_DIR = Path(__file__).resolve().parent
MAX_BODY_SIZE = 1024 * 1024


def load_local_env():
    """Nạp KEY=VALUE đơn giản; biến môi trường có sẵn được ưu tiên."""
    env_file = API_DIR / ".env"
    if not env_file.exists():
        return
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


load_local_env()


def api_host():
    """Trả địa chỉ bind của máy chủ demo."""
    return os.getenv("API_HOST", "127.0.0.1")


def api_port():
    """Trả cổng HTTP của máy chủ demo."""
    return int(os.getenv("API_PORT", "8000"))
