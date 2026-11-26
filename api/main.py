"""Khởi chạy API demo, chờ máy chủ sẵn sàng rồi mở giao diện trong trình duyệt."""

import threading
import time
import urllib.error
import urllib.request
import webbrowser

from config import api_host, api_port
from server import create_server


def wait_until_ready(host, port, server_thread):
    """Kiểm tra máy chủ HTTP đã phản hồi trước khi mở trang demo."""
    url = "http://%s:%s/" % (host, port)
    for _ in range(50):
        if not server_thread.is_alive():
            return False
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                return response.status == 200
        except urllib.error.HTTPError:
            return True
        except (urllib.error.URLError, TimeoutError):
            time.sleep(0.1)
    return False


def main():
    """Tạo máy chủ nền và dọn dẹp gọn khi người dùng nhấn Ctrl+C."""
    host = api_host()
    port = api_port()
    try:
        server = create_server(host, port)
    except OSError as exc:
        print("Could not start the API at http://%s:%s: %s" % (host, port, exc))
        input("Press Enter to close...")
        return

    url = "http://%s:%s" % (host, port)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    print("Food Delivery API: %s" % url)
    print("Database: configured in api/.env")
    print("Press Ctrl+C in this window to stop the server.")

    try:
        if wait_until_ready(host, port, server_thread):
            webbrowser.open_new_tab(url)
        else:
            print("The API did not become ready.")
        server_thread.join()
    except KeyboardInterrupt:
        print("\nStopping API server...")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
