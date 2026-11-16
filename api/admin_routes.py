from http import HTTPStatus


class AdminRoutes:
    def admin_stats(self):
        self.current_session("Admin")
        row = self.query_one(
            "SELECT COUNT(*) AS total_orders, "
            "SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders, "
            "SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders, "
            "COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount ELSE 0 END), 0) AS completed_gmv, "
            "COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount - delivery_fee ELSE 0 END), 0) AS food_revenue "
            "FROM `order`"
        )
        self.send_json(HTTPStatus.OK, {"statistics": row})
