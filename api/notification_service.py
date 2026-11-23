"""Ghi nhận thay đổi trạng thái tài xế cho các bên liên quan."""


def record_driver_status_change(cursor, driver_id, driver_user_id, status, order_id=None):
    """Ghi notification cho tài xế và, nếu có đơn, khách cùng nhà hàng của đơn."""
    recipients = [driver_user_id]
    notification_type = "SYSTEM"
    notification_order_id = None
    message = "Trạng thái tài xế đã chuyển sang %s." % status

    if order_id is not None:
        cursor.execute(
            "SELECT c.user_id AS customer_user_id, r.user_id AS restaurant_user_id "
            "FROM `order` AS o "
            "JOIN customer AS c ON c.customer_id = o.customer_id "
            "JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id "
            "WHERE o.order_id = %s AND o.driver_id = %s",
            (order_id, driver_id),
        )
        order_parties = cursor.fetchone()
        if order_parties is None:
            raise RuntimeError("Cannot resolve notification recipients for the driver order")
        recipients.extend((
            order_parties["customer_user_id"],
            order_parties["restaurant_user_id"],
        ))
        notification_type = "ORDER"
        notification_order_id = order_id
        message = "Trạng thái tài xế của đơn #%s đã chuyển sang %s." % (order_id, status)

    for recipient_user_id in dict.fromkeys(recipients):
        cursor.execute(
            "INSERT INTO notification (order_id, user_id, type, title, message, is_read) "
            "VALUES (%s, %s, %s, %s, %s, 0)",
            (
                notification_order_id,
                recipient_user_id,
                notification_type,
                "Trạng thái tài xế thay đổi",
                message,
            ),
        )
