"""Route thống kê tổng quan dành riêng cho role Admin."""

from http import HTTPStatus


class AdminRoutes:
    """Cung cấp số liệu chỉ đọc cho bảng điều khiển quản trị."""

    def admin_stats(self):
        """Tổng hợp số đơn, GMV và doanh thu món ăn bằng SQL."""
        self.current_session("Admin")
        row = self.query_one(
            "SELECT COUNT(*) AS total_orders, "
            "SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders, "
            "COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount ELSE 0 END), 0) AS completed_gmv, "
            "COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount - delivery_fee ELSE 0 END), 0) AS food_revenue "
            "FROM `order`"
        )
        self.send_json(HTTPStatus.OK, {"statistics": row})
