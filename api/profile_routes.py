"""Route hồ sơ người dùng và trạng thái trực tuyến của tài xế."""

from http import HTTPStatus

from database import connect
from errors import APIError
from notification_service import record_driver_status_change


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

    def driver_shift(self):
        """Trả ca làm gần nhất của tài xế đang đăng nhập."""
        session = self.current_session("Driver")
        shift = self.query_one(
            "SELECT s.shift_id, s.start_time, s.end_time "
            "FROM driver AS d "
            "JOIN shift AS s ON s.driver_id = d.driver_id "
            "WHERE d.user_id = %s "
            "ORDER BY s.start_time DESC, s.shift_id DESC LIMIT 1",
            (session["user_id"],),
        )
        self.send_json(HTTPStatus.OK, {"shift": shift})

    def update_driver_status(self):
        """Đổi trạng thái và đồng bộ ca làm việc, từ chối khi còn đơn hoạt động."""
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
                "SELECT driver_id, status FROM driver WHERE user_id = %s FOR UPDATE",
                (session["user_id"],),
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
            has_active_order = cursor.fetchone() is not None
            if has_active_order and status != driver["status"]:
                raise APIError(
                    HTTPStatus.CONFLICT,
                    "Complete the active delivery before changing driver status",
                )
            if driver["status"] != status:
                cursor.execute(
                    "UPDATE driver SET status = %s WHERE driver_id = %s",
                    (status, driver["driver_id"]),
                )
            if status == "ONLINE":
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
            else:
                cursor.execute(
                    "UPDATE shift SET end_time = CURRENT_TIMESTAMP "
                    "WHERE driver_id = %s AND start_time <= CURRENT_TIMESTAMP AND end_time IS NULL",
                    (driver["driver_id"],),
                )
            if driver["status"] != status:
                record_driver_status_change(
                    cursor,
                    driver["driver_id"],
                    session["user_id"],
                    status,
                )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {"message": "Driver status updated", "status": status})
