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
    server_version = "FoodDeliveryAPI/1.0"

    def log_message(self, format_string, *args):
        print("%s - %s" % (self.address_string(), format_string % args))

    def send_json(self, status, payload, headers=None):
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
        self.send_json(status, {"error": message})

    def read_json(self):
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
        authorization = self.headers.get("Authorization", "")
        if authorization.startswith("Bearer "):
            return authorization[7:].strip()
        cookie = SimpleCookie()
        cookie.load(self.headers.get("Cookie", ""))
        if "food_delivery_session" in cookie:
            return cookie["food_delivery_session"].value
        return None

    def current_session(self, required_role=None):
        session = get_session(self.session_token())
        if session is None:
            raise APIError(HTTPStatus.UNAUTHORIZED, "Please log in first")
        if required_role and session["role"] != required_role:
            raise APIError(HTTPStatus.FORBIDDEN, "This action is not allowed for your account role")
        return session

    def query_all(self, sql, parameters=()):
        return query_all(sql, parameters, self.database_role())

    def query_one(self, sql, parameters=()):
        return query_one(sql, parameters, self.database_role())

    def database_role(self):
        session = get_session(self.session_token())
        return session["role"] if session else "Customer"

    def logout(self):
        remove_session(self.session_token())
        self.send_json(HTTPStatus.OK, {"message": "Logged out"})

    def handle_request(self):
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
        self.handle_request()

    def do_POST(self):
        self.handle_request()

    def do_DELETE(self):
        self.handle_request()
