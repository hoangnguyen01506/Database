"""Lớp nền dùng chung: đọc JSON, quản lý phiên và chuẩn hóa lỗi API."""

import json
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler

import mysql.connector
from mysql.connector import Error as MySQLError

from config import MAX_BODY_SIZE
from database import DatabaseRoleConfigurationError, query_all, query_one
from errors import APIError
from sessions import get as get_session, remove as remove_session


class BaseHandler(BaseHTTPRequestHandler):
    """Cung cấp các thao tác HTTP và truy vấn dùng chung cho mọi route."""

    server_version = "FoodDeliveryAPI/1.0"

    def log_message(self, format_string, *args):
        """Ghi log yêu cầu HTTP theo định dạng gọn của máy chủ demo."""
        print("%s - %s" % (self.address_string(), format_string % args))

    def send_json(self, status, payload, headers=None):
        """Mã hóa và gửi phản hồi JSON."""
        body = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if headers:
            for name, value in headers.items():
                self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, status, message):
        """Trả lỗi API theo cùng một cấu trúc JSON."""
        self.send_json(status, {"error": message})

    def read_json(self):
        """Đọc body JSON có giới hạn kích thước và báo lỗi dữ liệu không hợp lệ."""
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise APIError(HTTPStatus.BAD_REQUEST, "Invalid Content-Length") from exc
        if size < 0 or size > MAX_BODY_SIZE:
            raise APIError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "Request body is too large")
        raw_body = self.rfile.read(size)
        if not raw_body:
            return {}
        try:
            value = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise APIError(HTTPStatus.BAD_REQUEST, "Request body must be valid JSON") from exc
        if not isinstance(value, dict):
            raise APIError(HTTPStatus.BAD_REQUEST, "Request body must be a JSON object")
        return value

    def session_token(self):
        """Lấy token đăng nhập từ header Bearer hoặc cookie."""
        authorization = self.headers.get("Authorization", "")
        if authorization.startswith("Bearer "):
            return authorization[7:].strip()
        cookie = SimpleCookie()
        cookie.load(self.headers.get("Cookie", ""))
        if "food_delivery_session" in cookie:
            return cookie["food_delivery_session"].value
        return None

    def current_session(self, required_role=None):
        """Trả phiên hiện tại, đồng thời kiểm tra đăng nhập và role nếu cần."""
        session = get_session(self.session_token())
        if session is None:
            raise APIError(HTTPStatus.UNAUTHORIZED, "Please log in first")
        if required_role and session["role"] != required_role:
            raise APIError(HTTPStatus.FORBIDDEN, "This action is not allowed for your account role")
        return session

    def query_all(self, sql, parameters=()):
        """Chạy truy vấn đọc bằng tài khoản MySQL tương ứng với phiên."""
        return query_all(sql, parameters, self.database_role())

    def query_one(self, sql, parameters=()):
        """Chạy truy vấn đọc và trả về tối đa một dòng."""
        return query_one(sql, parameters, self.database_role())

    def database_role(self):
        """Chọn role ứng dụng; yêu cầu công khai dùng tài khoản Customer."""
        session = get_session(self.session_token())
        return session["role"] if session else "Customer"

    def logout(self):
        """Xóa phiên hiện tại và xác nhận đăng xuất."""
        remove_session(self.session_token())
        self.send_json(HTTPStatus.OK, {"message": "Logged out"})

    def handle_request(self):
        """Chuyển ngoại lệ route/database thành phản hồi HTTP phù hợp."""
        try:
            self.dispatch()
        except APIError as exc:
            self.send_error_json(exc.status, exc.message)
        except DatabaseRoleConfigurationError as exc:
            print("Database role configuration failed: %s" % exc)
            self.send_error_json(HTTPStatus.SERVICE_UNAVAILABLE, str(exc))
        except MySQLError as exc:
            if exc.errno == 1644:
                self.send_error_json(HTTPStatus.CONFLICT, str(exc.msg))
            else:
                print("Database request failed: code=%s state=%s" % (exc.errno, exc.sqlstate))
                self.send_error_json(HTTPStatus.SERVICE_UNAVAILABLE, "Database request failed")
        except (BrokenPipeError, ConnectionResetError):
            return
        except Exception as exc:
            print("API request failed: %s" % type(exc).__name__)
            self.send_error_json(HTTPStatus.INTERNAL_SERVER_ERROR, "Internal server error")

    def do_GET(self):
        """Điểm vào cho mọi yêu cầu GET."""
        self.handle_request()

    def do_POST(self):
        """Điểm vào cho mọi yêu cầu POST."""
        self.handle_request()

    def do_DELETE(self):
        """Điểm vào cho mọi yêu cầu DELETE."""
        self.handle_request()
