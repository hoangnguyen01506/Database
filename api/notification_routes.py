"""Đọc notification thuộc tài khoản đang đăng nhập và đánh dấu đã đọc."""

from http import HTTPStatus

from database import connect
from errors import APIError


class NotificationRoutes:
    """Cung cấp hộp thư notification cho khách hàng, nhà hàng và tài xế."""

    def list_notifications(self):
        """Trả các notification mới nhất chỉ thuộc user hiện tại."""
        session = self.current_session()
        if session["role"] not in ("Customer", "Restaurant", "Driver"):
            raise APIError(HTTPStatus.FORBIDDEN, "Notifications are not available for this account role")
        notifications = self.query_all(
            "SELECT notification_id, order_id, type, title, message, is_read, created_at "
            "FROM notification WHERE user_id = %s "
            "ORDER BY created_at DESC, notification_id DESC LIMIT 50",
            (session["user_id"],),
        )
        unread = self.query_one(
            "SELECT COUNT(*) AS unread_count FROM notification "
            "WHERE user_id = %s AND is_read = 0",
            (session["user_id"],),
        )
        self.send_json(HTTPStatus.OK, {
            "notifications": notifications,
            "unread_count": unread["unread_count"],
        })

    def mark_notification_read(self, notification_id):
        """Đánh dấu đã đọc một notification thuộc user hiện tại."""
        session = self.current_session()
        if session["role"] not in ("Customer", "Restaurant", "Driver"):
            raise APIError(HTTPStatus.FORBIDDEN, "Notifications are not available for this account role")
        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            cursor.execute(
                "UPDATE notification SET is_read = 1 "
                "WHERE notification_id = %s AND user_id = %s",
                (notification_id, session["user_id"]),
            )
            if cursor.rowcount == 0:
                cursor.execute(
                    "SELECT notification_id FROM notification "
                    "WHERE notification_id = %s AND user_id = %s",
                    (notification_id, session["user_id"]),
                )
                if cursor.fetchone() is None:
                    raise APIError(HTTPStatus.NOT_FOUND, "Notification not found")
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {
            "message": "Notification marked as read",
            "notification_id": notification_id,
        })
