USE food_delivery_db;

START TRANSACTION;

-- Tạo tài khoản mẫu cho khách hàng, nhà hàng và tài xế.
INSERT INTO `user` (name, phone, email, password, role, address) VALUES
('Demo Customer', '0990000000001', 'demo.customer@example.test', 'demo123', 'Customer', '12 Demo Street, Binh Thanh, HCMC'),
('Demo Restaurant', '0990000000002', 'demo.restaurant@example.test', 'demo123', 'Restaurant', '12 Demo Street, Binh Thanh, HCMC'),
('Demo Driver', '0990000000003', 'demo.driver@example.test', 'demo123', 'Driver', '12 Demo Street, Binh Thanh, HCMC');

-- Tạo hồ sơ cho ba tài khoản mẫu dựa trên số điện thoại.
INSERT INTO customer (user_id, loyalty_points, total_orders, preferred_payment)
SELECT user_id, 0, 0, 'MOMO'
FROM `user`
WHERE phone = '0990000000001';

INSERT INTO restaurant (
    user_id, restaurant_name, business_license, cuisine_type, opening_hours,
    commission_rate, hub_id, is_approved, is_open, min_order_amount
)
SELECT user_id, 'Bếp Nhà Demo', 'DEMO-LICENSE', 'Vietnamese', '06:00 - 21:00',
       15.00, (SELECT MIN(hub_id) FROM hub), 1, 1, 30000.00
FROM `user`
WHERE phone = '0990000000002';

INSERT INTO driver (
    user_id, driver_license, vehicle_type, plate_number,
    current_location, status, hub_id
)
SELECT user_id, 'DEMO-DRIVER', 'Motorbike', 'DEMO-0001',
       '10.8012, 106.7114', 'ONLINE', (SELECT MIN(hub_id) FROM hub)
FROM `user`
WHERE phone = '0990000000003';

-- Thêm địa chỉ mặc định cho khách và mở ca làm cho tài xế.
INSERT INTO address (
    user_id, label, recipient_name, recipient_phone, address_line,
    ward, district, city, latitude, longitude, is_default
)
SELECT user_id, 'Home', 'Demo Customer', '0990000000001',
       '12 Demo Street, Binh Thanh, HCMC', 'Ward 1', 'Binh Thanh',
       'HCMC', 10.8012000, 106.7114000, 1
FROM `user`
WHERE phone = '0990000000001';

INSERT INTO shift (driver_id, start_time, end_time, completed_orders, bonus_earned)
SELECT driver_id, CURRENT_TIMESTAMP - INTERVAL 4 HOUR, NULL, 0, 0.00
FROM driver
JOIN `user` ON `user`.user_id = driver.user_id
WHERE `user`.phone = '0990000000003';

-- Tạo hai món demo cho nhà hàng mẫu.
INSERT INTO menu_item (restaurant_id, name, description, price, category, is_available)
SELECT restaurant_id, 'Grilled Pork Rice', 'Demo menu item', 45000.00, 'Main Dish', 1
FROM restaurant
JOIN `user` ON `user`.user_id = restaurant.user_id
WHERE `user`.phone = '0990000000002';

INSERT INTO menu_item (restaurant_id, name, description, price, category, is_available)
SELECT restaurant_id, 'Iced Jasmine Tea', 'Demo beverage', 10000.00, 'Beverage', 1
FROM restaurant
JOIN `user` ON `user`.user_id = restaurant.user_id
WHERE `user`.phone = '0990000000002';

-- Trigger cần @app_user_id để xác thực người tạo đơn và ghi audit_log.
SET @app_user_id = (SELECT user_id FROM `user` WHERE phone = '0990000000001');

-- Đơn mới phải bắt đầu ở PENDING và chưa được gán tài xế.
INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
)
SELECT customer.customer_id, restaurant.restaurant_id, 0.00, 15000.00,
       'MOMO', '12 Demo Street, Binh Thanh, HCMC'
FROM customer
JOIN `user` ON `user`.user_id = customer.user_id
JOIN restaurant ON restaurant.user_id = (
    SELECT user_id FROM `user` WHERE phone = '0990000000002'
)
WHERE `user`.phone = '0990000000001';

-- Lưu ID tự tăng để các lệnh INSERT/UPDATE tiếp theo dùng đúng đơn.
SET @demo_order_id = LAST_INSERT_ID();

-- Trigger lấy tên và giá từ menu_item, sau đó tính lại tổng tiền của đơn.
INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
SELECT @demo_order_id, menu_item_id, 2, 0.00, ''
FROM menu_item
WHERE name = 'Grilled Pork Rice'
  AND restaurant_id = (
      SELECT restaurant_id
      FROM restaurant
      JOIN `user` ON `user`.user_id = restaurant.user_id
      WHERE `user`.phone = '0990000000002'
  );

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
SELECT @demo_order_id, menu_item_id, 1, 0.00, ''
FROM menu_item
WHERE name = 'Iced Jasmine Tea'
  AND restaurant_id = (
      SELECT restaurant_id
      FROM restaurant
      JOIN `user` ON `user`.user_id = restaurant.user_id
      WHERE `user`.phone = '0990000000002'
  );

-- Ghi lần thanh toán demo thất bại trước lần thử thành công, trước khi nhà hàng xử lý đơn.
INSERT INTO payment (
    order_id, amount, payment_method, status, provider,
    provider_transaction_id, transaction_date, paid_at, failure_reason
) VALUES
(
    @demo_order_id, 115000.00, 'MOMO', 'FAILED', 'DemoGateway',
    'DEMO-FAILED-0001', CURRENT_TIMESTAMP, NULL,
    'Demo declined transaction; customer retried successfully'
),
(
    @demo_order_id, 115000.00, 'MOMO', 'SUCCESS', 'DemoGateway',
    'DEMO-SUCCESS-0001', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL
);

-- Nhà hàng chuyển đơn qua từng trạng thái hợp lệ.
SET @app_user_id = (SELECT user_id FROM `user` WHERE phone = '0990000000002');
UPDATE `order` SET status = 'CONFIRMED' WHERE order_id = @demo_order_id;
INSERT INTO notification (order_id, user_id, type, title, message, is_read)
SELECT @demo_order_id, c.user_id, 'ORDER', 'Cập nhật trạng thái đơn hàng',
       CONCAT('Đơn hàng #', @demo_order_id, ' đã được nhà hàng xác nhận.'), 0
FROM `order` AS o
JOIN customer AS c ON c.customer_id = o.customer_id
WHERE o.order_id = @demo_order_id;

UPDATE `order` SET status = 'PREPARING' WHERE order_id = @demo_order_id;
INSERT INTO notification (order_id, user_id, type, title, message, is_read)
SELECT @demo_order_id, c.user_id, 'ORDER', 'Cập nhật trạng thái đơn hàng',
       CONCAT('Đơn hàng #', @demo_order_id, ' đang được nhà hàng chuẩn bị.'), 0
FROM `order` AS o
JOIN customer AS c ON c.customer_id = o.customer_id
WHERE o.order_id = @demo_order_id;

UPDATE `order` SET status = 'READY' WHERE order_id = @demo_order_id;
INSERT INTO notification (order_id, user_id, type, title, message, is_read)
SELECT @demo_order_id, c.user_id, 'ORDER', 'Cập nhật trạng thái đơn hàng',
       CONCAT('Đơn hàng #', @demo_order_id, ' đã sẵn sàng để tài xế đến lấy.'), 0
FROM `order` AS o
JOIN customer AS c ON c.customer_id = o.customer_id
WHERE o.order_id = @demo_order_id;

-- Tài xế nhận đơn và cập nhật tiến trình giao từng bước.
SET @app_user_id = (SELECT user_id FROM `user` WHERE phone = '0990000000003');
UPDATE `order`
SET driver_id = (
    SELECT driver_id
    FROM driver
    JOIN `user` ON `user`.user_id = driver.user_id
    WHERE `user`.phone = '0990000000003'
)
WHERE order_id = @demo_order_id;
-- API báo tài xế, khách và nhà hàng khi trạng thái tài xế chuyển sang BUSY.
INSERT INTO notification (order_id, user_id, type, title, message, is_read)
SELECT @demo_order_id, recipients.user_id, 'ORDER', 'Trạng thái tài xế thay đổi',
       CONCAT('Trạng thái tài xế của đơn #', @demo_order_id, ' đã chuyển sang BUSY.'), 0
FROM (
    SELECT c.user_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = @demo_order_id
    UNION
    SELECT r.user_id
    FROM `order` AS o
    JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id
    WHERE o.order_id = @demo_order_id
    UNION
    SELECT d.user_id
    FROM `order` AS o
    JOIN driver AS d ON d.driver_id = o.driver_id
    WHERE o.order_id = @demo_order_id
) AS recipients;

UPDATE `order` SET status = 'PICKED_UP' WHERE order_id = @demo_order_id;
UPDATE `order` SET status = 'DELIVERING' WHERE order_id = @demo_order_id;
UPDATE `order` SET status = 'COMPLETED' WHERE order_id = @demo_order_id;
-- API báo các bên liên quan khi trigger đưa tài xế về ONLINE sau khi giao xong.
INSERT INTO notification (order_id, user_id, type, title, message, is_read)
SELECT @demo_order_id, recipients.user_id, 'ORDER', 'Trạng thái tài xế thay đổi',
       CONCAT('Trạng thái tài xế của đơn #', @demo_order_id, ' đã chuyển sang ONLINE.'), 0
FROM (
    SELECT c.user_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = @demo_order_id
    UNION
    SELECT r.user_id
    FROM `order` AS o
    JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id
    WHERE o.order_id = @demo_order_id
    UNION
    SELECT d.user_id
    FROM `order` AS o
    JOIN driver AS d ON d.driver_id = o.driver_id
    WHERE o.order_id = @demo_order_id
) AS recipients;

-- Khách chỉ được đánh giá sau khi đơn đã hoàn tất.
INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
SELECT @demo_order_id, user_id, 'Restaurant', 5, 'Demo restaurant review'
FROM `user`
WHERE phone = '0990000000001';

INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
SELECT @demo_order_id, user_id, 'Driver', 5, 'Demo driver review'
FROM `user`
WHERE phone = '0990000000001';

-- Hoàn tất transaction và hiển thị kết quả đơn mẫu.
COMMIT;

-- Hiển thị ba tài khoản mẫu và hồ sơ tương ứng.
SELECT u.user_id, u.name, u.phone, u.role,
       c.customer_id, r.restaurant_id, d.driver_id, d.status AS driver_status
FROM `user` AS u
LEFT JOIN customer AS c ON c.user_id = u.user_id
LEFT JOIN restaurant AS r ON r.user_id = u.user_id
LEFT JOIN driver AS d ON d.user_id = u.user_id
WHERE u.phone IN ('0990000000001', '0990000000002', '0990000000003')
ORDER BY u.role;

-- Hiển thị địa chỉ giao hàng, ca làm và các món của nhà hàng demo.
SELECT a.address_id, a.recipient_name, a.address_line, a.ward, a.district, a.city
FROM address AS a
JOIN `user` AS u ON u.user_id = a.user_id
WHERE u.phone = '0990000000001';

SELECT s.shift_id, s.start_time, s.end_time, s.completed_orders, s.bonus_earned
FROM shift AS s
JOIN driver AS d ON d.driver_id = s.driver_id
JOIN `user` AS u ON u.user_id = d.user_id
WHERE u.phone = '0990000000003'
ORDER BY s.start_time DESC;

SELECT mi.menu_item_id, mi.name, mi.price, mi.category, mi.is_available
FROM menu_item AS mi
JOIN restaurant AS r ON r.restaurant_id = mi.restaurant_id
JOIN `user` AS u ON u.user_id = r.user_id
WHERE u.phone = '0990000000002'
ORDER BY mi.menu_item_id;

-- Hiển thị đơn và các món đã được trigger ghi giá/tên.
SELECT order_id, order_date, status, total_amount, delivery_fee, payment_method
FROM `order`
WHERE order_id = @demo_order_id;

SELECT order_item_id, menu_item_id, item_name, quantity, price,
       quantity * price AS line_total
FROM order_item
WHERE order_id = @demo_order_id
ORDER BY order_item_id;

-- Hiển thị thanh toán, đánh giá, thông báo và lịch sử trạng thái của đơn mẫu.
SELECT payment_id, amount, payment_method, status, provider,
       provider_transaction_id, transaction_date, paid_at, failure_reason
FROM payment
WHERE order_id = @demo_order_id
ORDER BY payment_id;

SELECT review_id, reviewer_id, target_type, rating, comment, review_date
FROM review
WHERE order_id = @demo_order_id
ORDER BY review_id;

SELECT notification_id, user_id, type, title, message, is_read, created_at
FROM notification
WHERE order_id = @demo_order_id
ORDER BY notification_id;

SELECT log_id, old_status, new_status, changed_by, changed_at
FROM audit_log
WHERE order_id = @demo_order_id
ORDER BY log_id;

-- Chạy ba view hiện có, lọc riêng nhà hàng, tài xế và đơn demo vừa tạo.
SELECT *
FROM vw_order_summary
WHERE order_id = @demo_order_id;

SELECT *
FROM vw_restaurant_sales
WHERE restaurant_id = (
    SELECT restaurant_id
    FROM restaurant
    JOIN `user` ON `user`.user_id = restaurant.user_id
    WHERE `user`.phone = '0990000000002'
);

SELECT *
FROM vw_driver_performance
WHERE driver_id = (
    SELECT driver_id
    FROM driver
    JOIN `user` ON `user`.user_id = driver.user_id
    WHERE `user`.phone = '0990000000003'
);
