"""Route đơn hàng: checkout, lọc quyền xem và xử lý giao hàng."""

from http import HTTPStatus
import secrets

from database import connect
from errors import APIError
from notification_service import record_driver_status_change, record_order_status_change


class OrderRoutes:
    """Quản lý vòng đời đơn hàng theo role khách, nhà hàng và tài xế."""

    def place_order(self):
        """Tạo đơn cùng các dòng món trong một giao dịch MySQL."""
        session = self.current_session("Customer")
        if not session["cart"]:
            raise APIError(HTTPStatus.CONFLICT, "Add at least one available menu item before checkout")
        payload = self.read_json()
        payment_method = payload.get("payment_method", "CASH")
        if payment_method not in ("CASH", "MOMO"):
            raise APIError(HTTPStatus.BAD_REQUEST, "Choose CASH or MOMO demo payment")
        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        payment = None
        try:
            connection.start_transaction()
            cursor.execute("SET @app_user_id = %s", (session["user_id"],))
            cursor.execute(
                "SELECT customer_id FROM customer WHERE user_id = %s FOR SHARE",
                (session["user_id"],),
            )
            customer = cursor.fetchone()
            if customer is None:
                raise APIError(HTTPStatus.FORBIDDEN, "This account has no customer profile")
            cursor.execute(
                "SELECT address_line, ward, district, city FROM address "
                "WHERE user_id = %s AND is_default = 1 "
                "ORDER BY address_line, ward, district, city LIMIT 1",
                (session["user_id"],),
            )
            address = cursor.fetchone()
            if address:
                address_snapshot = ", ".join(
                    part for part in (
                        address["address_line"], address["ward"], address["district"], address["city"]
                    ) if part
                )
            else:
                cursor.execute("SELECT address FROM `user` WHERE user_id = %s", (session["user_id"],))
                address_snapshot = cursor.fetchone()["address"] or "No delivery address provided"

            restaurant_id = session["cart_restaurant_id"]
            cursor.execute(
                "SELECT restaurant_id FROM restaurant "
                "WHERE restaurant_id = %s AND is_approved = 1 AND is_open = 1 FOR SHARE",
                (restaurant_id,),
            )
            if cursor.fetchone() is None:
                raise APIError(HTTPStatus.CONFLICT, "Restaurant stopped accepting orders")

            cart_items = []
            for menu_item_id, quantity in session["cart"].items():
                cursor.execute(
                    "SELECT mi.menu_item_id, mi.is_available, mi.restaurant_id "
                    "FROM menu_item AS mi WHERE mi.menu_item_id = %s FOR SHARE",
                    (menu_item_id,),
                )
                item = cursor.fetchone()
                if item is None or item["restaurant_id"] != restaurant_id or not item["is_available"]:
                    raise APIError(HTTPStatus.CONFLICT, "A cart item is no longer available")
                cart_items.append({
                    "menu_item_id": item["menu_item_id"],
                    "quantity": quantity,
                })

            cursor.execute(
                "INSERT INTO `order` "
                "(customer_id, restaurant_id, total_amount, status, delivery_fee, payment_method, delivery_address_snapshot) "
                "VALUES (%s, %s, 0, 'PENDING', 0, %s, %s)",
                (customer["customer_id"], restaurant_id, payment_method, address_snapshot),
            )
            order_id = cursor.lastrowid
            for item in cart_items:
                # The BEFORE INSERT trigger replaces these placeholders with the menu snapshot.
                cursor.execute(
                    "INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) "
                    "VALUES (%s, %s, %s, 0, '')",
                    (
                        order_id,
                        item["menu_item_id"],
                        item["quantity"],
                    ),
                )
            cursor.execute(
                "SELECT order_id, status, total_amount, delivery_fee "
                "FROM `order` WHERE order_id = %s",
                (order_id,),
            )
            created_order = cursor.fetchone()
            if payment_method == "MOMO":
                if created_order["total_amount"] <= 0:
                    raise APIError(HTTPStatus.CONFLICT, "Demo virtual payment requires an order total greater than zero")
                transaction_id = "DEMO-" + secrets.token_hex(16)
                cursor.execute(
                    "INSERT INTO payment "
                    "(order_id, amount, payment_method, status, provider, "
                    "provider_transaction_id, transaction_date, paid_at) "
                    "VALUES (%s, %s, %s, 'SUCCESS', 'FoodieGo Demo Gateway', %s, "
                    "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                    (order_id, created_order["total_amount"], payment_method, transaction_id),
                )
                payment = {
                    "status": "SUCCESS",
                    "payment_method": payment_method,
                    "provider_transaction_id": transaction_id,
                }
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        session["cart"].clear()
        session["cart_restaurant_id"] = None
        self.send_json(HTTPStatus.CREATED, {
            "message": "Order created",
            "order": created_order,
            "payment": payment,
        })

    def list_orders(self):
        """Liệt kê các đơn mà role hiện tại được phép xem."""
        session = self.current_session()
        if session["role"] == "Customer":
            sql = (
                "SELECT o.order_id, o.order_date, o.status, o.total_amount, o.delivery_fee, "
                "o.restaurant_id, o.driver_id, "
                "EXISTS (SELECT 1 FROM review AS rv WHERE rv.order_id = o.order_id "
                "AND rv.reviewer_id = %s AND rv.target_type = 'Restaurant') AS restaurant_reviewed, "
                "EXISTS (SELECT 1 FROM review AS rv WHERE rv.order_id = o.order_id "
                "AND rv.reviewer_id = %s AND rv.target_type = 'Driver') AS driver_reviewed "
                "FROM `order` AS o "
                "JOIN customer AS c ON c.customer_id = o.customer_id "
                "WHERE c.user_id = %s ORDER BY o.order_date DESC LIMIT 100"
            )
            params = (session["user_id"], session["user_id"], session["user_id"])
        elif session["role"] == "Restaurant":
            sql = (
                "SELECT o.order_id, o.order_date, o.status, o.total_amount, o.delivery_fee, "
                "o.restaurant_id, o.driver_id FROM `order` AS o "
                "JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id "
                "WHERE r.user_id = %s ORDER BY o.order_date DESC LIMIT 100"
            )
            params = (session["user_id"],)
        elif session["role"] == "Driver":
            sql = (
                "SELECT o.order_id, o.order_date, o.status, o.total_amount, o.delivery_fee, "
                "o.restaurant_id, o.driver_id FROM `order` AS o "
                "JOIN driver AS d ON d.user_id = %s "
                "WHERE o.driver_id = d.driver_id "
                "OR (d.status = 'ONLINE' AND o.driver_id IS NULL "
                "AND o.status IN ('PREPARING', 'READY')) "
                "ORDER BY o.order_date DESC LIMIT 100"
            )
            params = (session["user_id"],)
        elif session["role"] == "Admin":
            sql = (
                "SELECT order_id, order_date, status, total_amount, delivery_fee, restaurant_id, driver_id "
                "FROM `order` ORDER BY order_date DESC LIMIT 100"
            )
            params = ()
        else:
            raise APIError(HTTPStatus.FORBIDDEN, "This account role cannot view orders")
        rows = self.query_all(sql, params)
        self.send_json(HTTPStatus.OK, {"orders": rows})

    def restaurant_stats(self):
        """Tổng hợp toàn bộ đơn của nhà hàng, không phụ thuộc giới hạn danh sách."""
        session = self.current_session("Restaurant")
        statistics = self.query_one(
            "SELECT "
            "COUNT(CASE WHEN o.status = 'PENDING' THEN 1 END) AS pending, "
            "COUNT(CASE WHEN o.status IN ('CONFIRMED', 'PREPARING') THEN 1 END) AS preparation, "
            "COUNT(CASE WHEN o.status = 'READY' THEN 1 END) AS ready, "
            "COALESCE(SUM(CASE WHEN o.status = 'COMPLETED' "
            "THEN o.total_amount - o.delivery_fee ELSE 0 END), 0) AS revenue "
            "FROM restaurant AS r "
            "LEFT JOIN `order` AS o ON o.restaurant_id = r.restaurant_id "
            "WHERE r.user_id = %s "
            "GROUP BY r.restaurant_id",
            (session["user_id"],),
        )
        if statistics is None:
            raise APIError(HTTPStatus.FORBIDDEN, "This account has no restaurant profile")
        self.send_json(HTTPStatus.OK, {"statistics": statistics})

    def add_review(self, order_id):
        """Lưu đánh giá nhà hàng hoặc tài xế cho đơn đã hoàn tất của khách."""
        session = self.current_session("Customer")
        payload = self.read_json()
        target_type = payload.get("target_type")
        rating = payload.get("rating")
        comment = payload.get("comment", "")
        if target_type not in ("Restaurant", "Driver"):
            raise APIError(HTTPStatus.BAD_REQUEST, "Review target must be Restaurant or Driver")
        if isinstance(rating, bool) or not isinstance(rating, int) or not 1 <= rating <= 5:
            raise APIError(HTTPStatus.BAD_REQUEST, "Rating must be an integer from 1 to 5")
        if not isinstance(comment, str) or len(comment) > 2000:
            raise APIError(HTTPStatus.BAD_REQUEST, "Review comment must be text of at most 2,000 characters")

        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute(
                "SELECT o.status, o.driver_id FROM `order` AS o "
                "JOIN customer AS c ON c.customer_id = o.customer_id "
                "WHERE o.order_id = %s AND c.user_id = %s FOR UPDATE",
                (order_id, session["user_id"]),
            )
            order = cursor.fetchone()
            if order is None:
                raise APIError(HTTPStatus.NOT_FOUND, "Completed order not found for this customer")
            if order["status"] != "COMPLETED":
                raise APIError(HTTPStatus.CONFLICT, "Reviews are available after order completion")
            if target_type == "Driver" and order["driver_id"] is None:
                raise APIError(HTTPStatus.CONFLICT, "This order has no assigned driver to review")
            cursor.execute(
                "INSERT INTO review (order_id, reviewer_id, target_type, rating, comment) "
                "VALUES (%s, %s, %s, %s, %s)",
                (order_id, session["user_id"], target_type, rating, comment.strip() or None),
            )
            review_id = cursor.lastrowid
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.CREATED, {
            "message": "Review saved",
            "review": {
                "review_id": review_id,
                "order_id": order_id,
                "target_type": target_type,
                "rating": rating,
                "comment": comment.strip(),
            },
        })

    def get_order(self, order_id):
        """Lấy chi tiết đơn sau khi kiểm tra quyền sở hữu."""
        session = self.current_session()
        order = self.query_one(
            "SELECT o.order_id, o.order_date, o.status, o.total_amount, o.delivery_fee, "
            "o.restaurant_id, o.driver_id, o.customer_id, o.delivery_address_snapshot "
            "FROM `order` AS o WHERE o.order_id = %s",
            (order_id,),
        )
        if order is None:
            raise APIError(HTTPStatus.NOT_FOUND, "Order not found")
        if not self.can_view_order(session, order):
            raise APIError(HTTPStatus.FORBIDDEN, "You cannot view this order")
        order["items"] = self.query_all(
            "SELECT order_item_id, menu_item_id, item_name, quantity, price, "
            "(quantity * price) AS line_total FROM order_item "
            "WHERE order_id = %s ORDER BY order_item_id",
            (order_id,),
        )
        self.send_json(HTTPStatus.OK, {"order": order})

    def can_view_order(self, session, order):
        """Kiểm tra user có quyền xem đơn theo role và quan hệ sở hữu."""
        if session["role"] == "Admin":
            return True
        if session["role"] == "Customer":
            row = self.query_one(
                "SELECT customer_id FROM customer WHERE user_id = %s AND customer_id = %s",
                (session["user_id"], order["customer_id"]),
            )
            return row is not None
        if session["role"] == "Restaurant":
            row = self.query_one(
                "SELECT restaurant_id FROM restaurant WHERE user_id = %s AND restaurant_id = %s",
                (session["user_id"], order["restaurant_id"]),
            )
            return row is not None
        if session["role"] == "Driver":
            row = self.query_one(
                "SELECT driver_id FROM driver WHERE user_id = %s AND driver_id = %s",
                (session["user_id"], order["driver_id"]),
            ) if order["driver_id"] is not None else None
            return row is not None
        return False

    def change_order(self, order_id, action):
        """Chuyển thao tác trạng thái đến route nhà hàng hoặc tài xế."""
        session = self.current_session()
        if action in ("confirm", "prepare", "ready"):
            self.restaurant_order_action(session, order_id, action)
        elif action == "accept":
            self.driver_accept_order(session, order_id)
        elif action in ("pickup", "start-delivery", "complete"):
            self.driver_order_action(session, order_id, action)

    def restaurant_order_action(self, session, order_id, action):
        """Xác nhận và cập nhật các bước chuẩn bị của nhà hàng."""
        if session["role"] != "Restaurant":
            raise APIError(HTTPStatus.FORBIDDEN, "Only restaurant accounts can change preparation status")
        transitions = {
            "confirm": ("PENDING", "CONFIRMED"),
            "prepare": ("CONFIRMED", "PREPARING"),
            "ready": ("PREPARING", "READY"),
        }
        old_status, new_status = transitions[action]
        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute("SET @app_user_id = %s", (session["user_id"],))
            cursor.execute(
                "SELECT status, restaurant_id, customer_id FROM `order` "
                "WHERE order_id = %s FOR UPDATE",
                (order_id,),
            )
            row = cursor.fetchone()
            if row is None:
                raise APIError(HTTPStatus.NOT_FOUND, "Order not found for this restaurant")
            restaurant = self.query_one(
                "SELECT restaurant_id FROM restaurant WHERE restaurant_id = %s AND user_id = %s",
                (row["restaurant_id"], session["user_id"]),
            )
            if restaurant is None:
                raise APIError(HTTPStatus.NOT_FOUND, "Order not found for this restaurant")
            if row["status"] != old_status:
                raise APIError(HTTPStatus.CONFLICT, "Order must be " + old_status + " before this action")
            cursor.execute(
                "UPDATE `order` SET status = %s WHERE order_id = %s",
                (new_status, order_id),
            )
            record_order_status_change(cursor, order_id, row["customer_id"], new_status)
            cursor.execute(
                "SELECT order_id, status, total_amount FROM `order` WHERE order_id = %s",
                (order_id,),
            )
            order = cursor.fetchone()
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {"message": "Order status updated", "order": order})

    def driver_accept_order(self, session, order_id):
        """Tài xế trực tuyến tự nhận một đơn đang chờ giao."""
        if session["role"] != "Driver":
            raise APIError(HTTPStatus.FORBIDDEN, "Only driver accounts can accept orders")
        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute("SET @app_user_id = %s", (session["user_id"],))
            cursor.execute(
                "SELECT driver_id, status FROM driver WHERE user_id = %s FOR UPDATE",
                (session["user_id"],),
            )
            driver = cursor.fetchone()
            if driver is None:
                raise APIError(HTTPStatus.FORBIDDEN, "This account has no driver profile")
            if driver["status"] != "ONLINE":
                raise APIError(HTTPStatus.CONFLICT, "Driver must be ONLINE to accept an order")
            cursor.execute(
                "SELECT order_id FROM `order` "
                "WHERE driver_id = %s AND status NOT IN ('COMPLETED', 'CANCELLED') "
                "LIMIT 1 FOR UPDATE",
                (driver["driver_id"],),
            )
            if cursor.fetchone() is not None:
                raise APIError(HTTPStatus.CONFLICT, "Driver already has an active order")
            cursor.execute(
                "SELECT order_id, status, driver_id FROM `order` WHERE order_id = %s FOR UPDATE",
                (order_id,),
            )
            order = cursor.fetchone()
            if order is None:
                raise APIError(HTTPStatus.NOT_FOUND, "Order not found")
            if order["status"] not in ("PREPARING", "READY") or order["driver_id"] is not None:
                raise APIError(HTTPStatus.CONFLICT, "Only an unassigned PREPARING or READY order can be accepted")
            cursor.execute(
                "UPDATE `order` SET driver_id = %s WHERE order_id = %s",
                (driver["driver_id"], order_id),
            )
            record_driver_status_change(
                cursor,
                driver["driver_id"],
                session["user_id"],
                "BUSY",
                order_id,
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {
            "message": "Driver assigned to order",
            "order_id": order_id,
            "driver_id": driver["driver_id"],
        })

    def driver_order_action(self, session, order_id, action):
        """Tài xế chuyển một đơn đúng một bước trong quy trình giao hàng."""
        if session["role"] != "Driver":
            raise APIError(HTTPStatus.FORBIDDEN, "Only driver accounts can update delivery progress")
        transitions = {
            "pickup": ("READY", "PICKED_UP", "Driver picked up the order"),
            "start-delivery": ("PICKED_UP", "DELIVERING", "Delivery started"),
            "complete": ("DELIVERING", "COMPLETED", "Delivery completed"),
        }
        old_status, new_status, message = transitions[action]
        connection = connect(session["role"])
        cursor = connection.cursor(dictionary=True)
        try:
            connection.start_transaction()
            cursor.execute("SET @app_user_id = %s", (session["user_id"],))
            cursor.execute(
                "SELECT d.driver_id, d.status FROM driver AS d WHERE d.user_id = %s FOR UPDATE",
                (session["user_id"],),
            )
            driver = cursor.fetchone()
            if driver is None:
                raise APIError(HTTPStatus.FORBIDDEN, "This account has no driver profile")
            cursor.execute(
                "SELECT order_id, status, driver_id FROM `order` WHERE order_id = %s FOR UPDATE",
                (order_id,),
            )
            order = cursor.fetchone()
            if order is None or order["driver_id"] != driver["driver_id"]:
                raise APIError(HTTPStatus.NOT_FOUND, "Order not found for this driver")
            if order["status"] != old_status:
                raise APIError(
                    HTTPStatus.CONFLICT,
                    "Order must be %s before this action" % old_status,
                )
            cursor.execute(
                "UPDATE `order` SET status = %s WHERE order_id = %s",
                (new_status, order_id),
            )
            cursor.execute(
                "SELECT status FROM driver WHERE driver_id = %s",
                (driver["driver_id"],),
            )
            updated_driver = cursor.fetchone()
            if updated_driver["status"] != driver["status"]:
                record_driver_status_change(
                    cursor,
                    driver["driver_id"],
                    session["user_id"],
                    updated_driver["status"],
                    order_id,
                )
            order["status"] = new_status
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()
        self.send_json(HTTPStatus.OK, {
            "message": message,
            "order": {"order_id": order_id, "status": order["status"]},
        })
