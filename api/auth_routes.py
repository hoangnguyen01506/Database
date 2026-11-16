"""Route đăng nhập: xác thực tài khoản và tạo phiên ứng dụng."""

import secrets
from http import HTTPStatus

from errors import APIError
from sessions import create as create_session


class AuthRoutes:
    """Xử lý các thao tác xác thực người dùng."""

    def login(self):
        """Kiểm tra email/mật khẩu rồi trả token cùng thông tin role."""
        payload = self.read_json()
        email = payload.get("email", "")
        password = payload.get("password", "")
        if not isinstance(email, str) or not isinstance(password, str) or not email or not password:
            raise APIError(HTTPStatus.BAD_REQUEST, "Email and password are required")

        # Coursework demo accounts intentionally store plaintext passwords.
        user = self.query_one(
            "SELECT user_id, name, role FROM `user` WHERE email = %s AND password = %s LIMIT 1",
            (email, password),
        )
        if user is None:
            raise APIError(HTTPStatus.UNAUTHORIZED, "Email or password is incorrect")
        token = secrets.token_urlsafe(32)
        create_session(token, {
            "user_id": user["user_id"],
            "name": user["name"],
            "role": user["role"],
            "cart": {},
            "cart_restaurant_id": None,
        })
        self.send_json(HTTPStatus.OK, {"token": token, "user": {
            "user_id": user["user_id"],
            "name": user["name"],
            "role": user["role"],
        }})
