"""Route đăng nhập: xác thực tài khoản và tạo phiên ứng dụng."""

from http import HTTPStatus
import secrets

from database import connect
from errors import APIError
from notification_service import record_driver_status_change
from sessions import create as create_session


class AuthRoutes:
    """Xử lý các thao tác xác thực người dùng."""

    def login(self):
        """Kiểm tra số điện thoại/mật khẩu rồi trả token cùng thông tin role."""
        payload = self.read_json()
        phone = payload.get("phone", "")
        password = payload.get("password", "")
        if not isinstance(phone, str) or not isinstance(password, str) or not phone.strip() or not password:
            raise APIError(HTTPStatus.BAD_REQUEST, "Phone number and password are required")
        phone = phone.strip()

        # Coursework demo accounts intentionally store plaintext passwords.
        user = self.query_one(
            "SELECT user_id, name, role FROM `user` WHERE phone = %s AND password = %s LIMIT 1",
            (phone, password),
        )
        if user is None:
            raise APIError(HTTPStatus.UNAUTHORIZED, "Phone number or password is incorrect")
        if user["role"] == "Driver":
            self.start_driver_shift(user["user_id"])
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

    def start_driver_shift(self, user_id):
        """Đưa tài xế vào trạng thái phù hợp và mở ca nếu chưa có ca hiện tại."""
        connection = connect("Driver")
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute(
                "SELECT driver_id, status FROM driver WHERE user_id = %s FOR UPDATE",
                (user_id,),
            )
            driver = cursor.fetchone()
            if driver is None:
                raise APIError(HTTPStatus.FORBIDDEN, "This account has no driver profile")

            cursor.execute(
                "SELECT order_id FROM `order` "
                "WHERE driver_id = %s AND status NOT IN ('COMPLETED', 'CANCELLED') "
                "LIMIT 1 FOR UPDATE",
                (driver["driver_id"],),
            )
            active_order = cursor.fetchone()
            desired_status = "BUSY" if active_order else "ONLINE"
            if driver["status"] != desired_status:
                cursor.execute(
                    "UPDATE driver SET status = %s WHERE driver_id = %s",
                    (desired_status, driver["driver_id"]),
                )
                record_driver_status_change(
                    cursor,
                    driver["driver_id"],
                    user_id,
                    desired_status,
                    active_order["order_id"] if active_order else None,
                )

            cursor.execute(
                "SELECT shift_id FROM shift "
                "WHERE driver_id = %s AND start_time <= CURRENT_TIMESTAMP AND end_time IS NULL "
                "ORDER BY start_time DESC LIMIT 1 FOR UPDATE",
                (driver["driver_id"],),
            )
            if cursor.fetchone() is None:
                cursor.execute(
                    "INSERT INTO shift (driver_id, start_time, end_time, completed_orders, bonus_earned) "
                    "VALUES (%s, CURRENT_TIMESTAMP, NULL, 0, 0.00)",
                    (driver["driver_id"],),
                )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
