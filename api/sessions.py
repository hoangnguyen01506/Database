"""Kho phiên đăng nhập trong bộ nhớ; phiên sẽ mất khi API khởi động lại."""

import threading


SESSIONS = {}
SESSIONS_LOCK = threading.Lock()


def create(token, session):
    """Lưu phiên dưới token trong vùng được khóa đồng bộ."""
    with SESSIONS_LOCK:
        SESSIONS[token] = session


def get(token):
    """Lấy phiên theo token; trả None nếu token không tồn tại."""
    with SESSIONS_LOCK:
        return SESSIONS.get(token)


def remove(token):
    """Xóa token khỏi kho phiên nếu token được cung cấp."""
    with SESSIONS_LOCK:
        if token:
            SESSIONS.pop(token, None)
