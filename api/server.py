"""Định tuyến HTTP và phục vụ giao diện tĩnh cho ứng dụng giao món."""

import os
import re
from http import HTTPStatus
from http.server import ThreadingHTTPServer
from urllib.parse import urlparse

import mysql.connector

from admin_routes import AdminRoutes
from auth_routes import AuthRoutes
from base_handler import BaseHandler
from catalog_routes import CatalogRoutes
from config import API_DIR
from errors import APIError
from order_routes import OrderRoutes
from profile_routes import ProfileRoutes


class Handler(
    AuthRoutes,
    CatalogRoutes,
    OrderRoutes,
    AdminRoutes,
    ProfileRoutes,
    BaseHandler,
):
    """Ghép các nhóm route API và ánh xạ URL đến hàm xử lý tương ứng."""

    def dispatch(self):
        """Phân loại yêu cầu theo phương thức HTTP và đường dẫn."""
        path = urlparse(self.path).path.rstrip("/") or "/"
        if self.command == "GET" and path == "/":
            return self.serve_home()
        if self.command == "GET" and path == "/api/health":
            return self.health()
        asset_types = {
            "app.css": "text/css; charset=utf-8",
            "app.js": "text/javascript; charset=utf-8",
            "shared.js": "text/javascript; charset=utf-8",
            "orders.js": "text/javascript; charset=utf-8",
            "customer.js": "text/javascript; charset=utf-8",
            "restaurant.js": "text/javascript; charset=utf-8",
            "driver.js": "text/javascript; charset=utf-8",
            "admin.js": "text/javascript; charset=utf-8",
        }
        asset_match = re.fullmatch(r"/assets/([a-z]+\.js|app\.css)", path)
        if self.command == "GET" and asset_match and asset_match.group(1) in asset_types:
            return self.serve_asset(asset_match.group(1), asset_types[asset_match.group(1)])
        if self.command == "POST" and path == "/api/login":
            return self.login()
        if self.command == "POST" and path == "/api/logout":
            return self.logout()
        if self.command == "GET" and path == "/api/profile":
            return self.profile()
        if self.command == "POST" and path == "/api/driver/status":
            return self.update_driver_status()
        if self.command == "GET" and path == "/api/restaurants":
            return self.list_restaurants()
        match = re.fullmatch(r"/api/restaurants/(\d+)/menu", path)
        if self.command == "GET" and match:
            return self.list_menu(int(match.group(1)))
        if self.command == "GET" and path == "/api/cart":
            return self.get_cart()
        if self.command == "POST" and path == "/api/cart/items":
            return self.add_cart_item()
        if self.command == "DELETE" and path == "/api/cart/items":
            return self.clear_cart()
        if self.command == "POST" and path == "/api/orders":
            return self.place_order()
        if self.command == "GET" and path == "/api/orders":
            return self.list_orders()
        match = re.fullmatch(r"/api/orders/(\d+)", path)
        if self.command == "GET" and match:
            return self.get_order(int(match.group(1)))
        match = re.fullmatch(r"/api/orders/(\d+)/(confirm|prepare|ready|accept|complete)", path)
        if self.command == "POST" and match:
            return self.change_order(int(match.group(1)), match.group(2))
        if self.command == "GET" and path == "/api/admin/stats":
            return self.admin_stats()
        raise APIError(HTTPStatus.NOT_FOUND, "API route not found")

    def serve_home(self):
        """Gửi trang HTML chính của bản demo."""
        body = (API_DIR / "index.html").read_bytes()
        self.send_page(body, "text/html; charset=utf-8")

    def serve_asset(self, filename, content_type):
        """Gửi một tệp JavaScript hoặc CSS được phép truy cập."""
        body = (API_DIR / "static" / filename).read_bytes()
        self.send_page(body, content_type)

    def send_page(self, body, content_type):
        """Gửi nội dung tĩnh kèm các header cơ bản."""
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def health(self):
        """Kiểm tra kết nối MySQL và trả trạng thái cho trang sức khỏe."""
        try:
            row = self.query_one("SELECT 1 AS database_connected")
        except mysql.connector.Error:
            self.send_json(HTTPStatus.SERVICE_UNAVAILABLE, {
                "status": "database_unavailable",
                "database": os.getenv("MYSQL_DATABASE", "food_delivery_db"),
                "message": "Check MySQL is running and api/.env has the correct connection settings.",
            })
            return
        self.send_json(HTTPStatus.OK, {"status": "ok", "database": row["database_connected"] == 1})


def create_server(host, port):
    """Tạo máy chủ HTTP đa luồng tại địa chỉ cấu hình."""
    return ThreadingHTTPServer((host, port), Handler)
