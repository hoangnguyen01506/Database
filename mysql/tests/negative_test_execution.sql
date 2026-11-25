USE food_delivery_db;

-- Dùng sau khi đã nạp seed 5.000 và triggers.sql, bằng tài khoản DBA.
-- Chạy từng test riêng bằng Ctrl+Enter; câu chuẩn bị có thể chạy thành công.
-- Câu test chính phải bị từ chối. Cuối cùng chạy ROLLBACK để hủy mọi thay đổi.
START TRANSACTION;

-- TC-01: Số điện thoại này đã có trong seed 5.000.
INSERT INTO `user` (name, phone, password, role)
VALUES ('Duplicate Phone Test', '0978046115', 'demo', 'Customer');

-- TC-02: Email đã tồn tại; số điện thoại mới để chỉ vi phạm uq_user_email.
INSERT INTO `user` (name, phone, email, password, role)
VALUES (
    'Duplicate Email Test',
    '0999999999',
    'lieugiaphung00001@gmail.com',
    'demo',
    'Customer'
);

-- TC-03: User 2 đã là Customer, không thể tạo thêm subtype Driver.
INSERT INTO driver (user_id, driver_license, vehicle_type, plate_number)
VALUES (2, 'NEGATIVE-TEST-LICENSE', 'Motorbike', 'NEG-TEST');

-- TC-04: User ID này không tồn tại, khóa ngoại phải từ chối.
INSERT INTO address (user_id, recipient_name, recipient_phone, address_line)
VALUES (99999999, 'Unknown User', '0900000001', 'Non-existent test address');

-- TC-05: Giá món không được âm.
INSERT INTO menu_item (restaurant_id, name, price)
VALUES (1, 'Invalid Negative Item', -5000.00);

-- TC-06: Đơn 2 đang PENDING và có món 471; số lượng 0 không hợp lệ.
INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
VALUES (2, 471, 0, 45000.00, 'Invalid quantity test');

-- TC-07: Order 2 thuộc nhà hàng 95, còn món 1 thuộc nhà hàng 1.
INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
VALUES (2, 1, 1, 50000.00, 'Wrong restaurant test');

-- TC-08: Tạm tăng mức tối thiểu; xác nhận order 2 phải bị từ chối.
UPDATE restaurant
SET min_order_amount = 999999.00
WHERE restaurant_id = 95;
SET @app_user_id = 4735;
UPDATE `order`
SET status = 'CONFIRMED'
WHERE order_id = 2;

-- TC-09: Tài xế 1 bị chuyển OFFLINE; gán vào đơn PENDING 2 phải bị từ chối.
UPDATE driver
SET status = 'OFFLINE'
WHERE driver_id = 1;
SET @app_user_id = (SELECT user_id FROM driver WHERE driver_id = 1);
UPDATE `order`
SET driver_id = 1
WHERE order_id = 2;

-- TC-10: Tài xế 2 được đặt BUSY; gán vào order 2 phải bị từ chối.
UPDATE driver
SET status = 'BUSY'
WHERE driver_id = 2;
SET @app_user_id = (SELECT user_id FROM driver WHERE driver_id = 2);
UPDATE `order`
SET driver_id = 2
WHERE order_id = 2;

-- TC-11: Audit log không được cập nhật hoặc xóa.
UPDATE audit_log
SET new_status = 'CANCELLED'
WHERE log_id = 1;

DELETE FROM audit_log
WHERE log_id = 1;

-- TC-12: Đơn 8 đã hoàn tất, khách 489 chưa đánh giá tài xế.
INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
VALUES (8, 489, 'Driver', 6, 'Invalid rating score');

-- TC-13: Đơn 8 đã có đánh giá Restaurant của khách 489; đánh giá lần hai bị từ chối.
INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
VALUES (8, 489, 'Restaurant', 5, 'Duplicate review test');

ROLLBACK;
