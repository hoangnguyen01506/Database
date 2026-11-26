"""Route danh mục: nhà hàng, thực đơn và giỏ hàng theo phiên khách."""

from http import HTTPStatus

from errors import APIError


class CatalogRoutes:
    """Phục vụ nội dung cửa hàng và các thao tác giỏ hàng của khách."""

    def list_restaurants(self):
        """Liệt kê nhà hàng đã được duyệt."""
        rows = self.query_all(
            "SELECT r.restaurant_id, r.restaurant_name, r.cuisine_type, "
            "r.is_approved, r.is_open, r.min_order_amount "
            "FROM restaurant AS r "
            "WHERE r.is_approved = 1 "
            "ORDER BY r.is_open DESC, r.restaurant_name, r.restaurant_id"
        )
        self.send_json(HTTPStatus.OK, {"restaurants": rows})

    def list_menu(self, restaurant_id):
        """Lấy thực đơn và trạng thái còn bán của một nhà hàng."""
        rows = self.query_all(
            "SELECT menu_item_id, restaurant_id, name, description, price, category, is_available "
            "FROM menu_item WHERE restaurant_id = %s ORDER BY category, name, menu_item_id",
            (restaurant_id,),
        )
        self.send_json(HTTPStatus.OK, {"menu": rows})

    def get_cart(self):
        """Đọc giỏ hàng tạm đang lưu trong phiên khách."""
        session = self.current_session("Customer")
        items = []
        if session["cart"]:
            placeholders = ", ".join(["%s"] * len(session["cart"]))
            items = self.query_all(
                "SELECT menu_item_id, name, price FROM menu_item "
                "WHERE menu_item_id IN (" + placeholders + ") ORDER BY menu_item_id",
                tuple(session["cart"].keys()),
            )
            for item in items:
                item["quantity"] = session["cart"][item["menu_item_id"]]
                item["line_total"] = item["price"] * item["quantity"]
        self.send_json(HTTPStatus.OK, {
            "restaurant_id": session["cart_restaurant_id"],
            "items": items,
        })

    def add_cart_item(self):
        """Kiểm tra rồi thêm món còn bán vào giỏ của một nhà hàng."""
        session = self.current_session("Customer")
        payload = self.read_json()
        try:
            menu_item_id = int(payload.get("menu_item_id"))
            quantity = int(payload.get("quantity", 1))
        except (TypeError, ValueError) as exc:
            raise APIError(HTTPStatus.BAD_REQUEST, "menu_item_id and quantity must be integers") from exc
        if menu_item_id < 1 or quantity < 1 or quantity > 50:
            raise APIError(HTTPStatus.BAD_REQUEST, "Use a positive menu item ID and quantity from 1 to 50")

        item = self.query_one(
            "SELECT mi.menu_item_id, mi.restaurant_id, mi.name, mi.price, "
            "mi.is_available, r.is_approved, r.is_open "
            "FROM menu_item AS mi JOIN restaurant AS r ON r.restaurant_id = mi.restaurant_id "
            "WHERE mi.menu_item_id = %s",
            (menu_item_id,),
        )
        if item is None:
            raise APIError(HTTPStatus.NOT_FOUND, "Menu item not found")
        if not item["is_available"]:
            raise APIError(HTTPStatus.CONFLICT, "This menu item is currently unavailable")
        if not item["is_approved"] or not item["is_open"]:
            raise APIError(HTTPStatus.CONFLICT, "This restaurant is not accepting orders")
        current_restaurant_id = session["cart_restaurant_id"]
        if current_restaurant_id not in (None, item["restaurant_id"]):
            raise APIError(HTTPStatus.CONFLICT, "A cart can contain items from only one restaurant")
        session["cart_restaurant_id"] = item["restaurant_id"]
        session["cart"][menu_item_id] = session["cart"].get(menu_item_id, 0) + quantity
        self.send_json(HTTPStatus.CREATED, {
            "message": "Item added to cart",
            "cart_item": {
                "menu_item_id": item["menu_item_id"],
                "name": item["name"],
                "quantity": session["cart"][menu_item_id],
                "price": item["price"],
            },
        })

    def clear_cart(self):
        """Xóa các món và nhà hàng hiện chọn khỏi giỏ phiên."""
        session = self.current_session("Customer")
        session["cart"].clear()
        session["cart_restaurant_id"] = None
        self.send_json(HTTPStatus.OK, {"message": "Cart cleared"})
