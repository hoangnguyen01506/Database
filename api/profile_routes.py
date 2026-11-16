"""Route hồ sơ người dùng và trạng thái trực tuyến của tài xế."""

from http import HTTPStatus

from database import connect
from errors import APIError


class ProfileRoutes:
    """Trả hồ sơ theo role và quản lý trạng thái sẵn sàng nhận đơn."""

    def profile(self):
        """Đọc thông tin hồ sơ phù hợp với role trong phiên đăng nhập."""
        session = self.current_session()
        if session["role"] == "Restaurant":
            sql = (
                "SELECT u.user_id, u.name, u.role, r.restaurant_id "
                "FROM `user` AS u JOIN restaurant AS r ON r.user_id = u.user_id "
                "WHERE u.user_id = %s"
            )
        elif session["role"] == "Driver":
            sql = (
                "SELECT u.user_id, u.name, u.role, d.driver_id, d.status AS driver_status "
                "FROM `user` AS u JOIN driver AS d ON d.user_id = u.user_id "
                "WHERE u.user_id = %s"
            )
        else:
            sql = "SELECT user_id, name, role FROM `user` WHERE user_id = %s"
        profile = self.query_one(sql, (session["user_id"],))
        if profile is None:
            raise APIError(HTTPStatus.NOT_FOUND, "User profile not found")
        self.send_json(HTTPStatus.OK, {"user": profile})

    def update_driver_status(self):
        """Đổi trạng thái tài xế, không cho ngoại tuyến khi còn đơn hoạt động."""
        session = self.current_session("Driver")
        payload = self.read_json()
        status = payload.get("status")
        if status not in ("ONLINE", "OFFLINE"):
            raise APIError(HTTPStatus.BAD_REQUEST, "Driver status must be ONLINE or OFFLINE")

        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute(
                "SELECT driver_id FROM driver WHERE user_id = %s FOR UPDATE",
                (session["user_id"],),
            )
            driver = cursor.fetchone()
            if driver is None:
                raise APIError(HTTPStatus.FORBIDDEN, "This account has no driver profile")
            if status == "OFFLINE":
                cursor.execute(
                    "SELECT order_id FROM `order` "
                    "WHERE driver_id = %s AND status NOT IN ('COMPLETED', 'CANCELLED') LIMIT 1",
                    (driver["driver_id"],),
                )
                if cursor.fetchone() is not None:
                    raise APIError(HTTPStatus.CONFLICT, "Complete the active delivery before going offline")
            cursor.execute(
                "UPDATE driver SET status = %s WHERE driver_id = %s",
                (status, driver["driver_id"]),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {"message": "Driver status updated", "status": status})
