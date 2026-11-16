import threading


SESSIONS = {}
SESSIONS_LOCK = threading.Lock()


def create(token, session):
    with SESSIONS_LOCK:
        SESSIONS[token] = session


def get(token):
    with SESSIONS_LOCK:
        return SESSIONS.get(token)


def remove(token):
    with SESSIONS_LOCK:
        if token:
            SESSIONS.pop(token, None)
