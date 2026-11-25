
USE food_delivery_db;

-- =========================================================
-- 1. TẠO CÁC ROLE
-- =========================================================

CREATE ROLE IF NOT EXISTS
    'role_customer',
    'role_restaurant',
    'role_driver',
    'role_admin';

-- Xóa quyền cũ trước khi cấp lại để tránh quyền thừa.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM
    'role_customer',
    'role_restaurant',
    'role_driver',
    'role_admin';


-- =========================================================
-- 2. ROLE CUSTOMER - KHÁCH HÀNG
-- =========================================================

-- Đọc thông tin tài khoản để xác thực đăng nhập.
GRANT SELECT (user_id, name, phone, email, password, role, address)
ON food_delivery_db.`user` TO 'role_customer';

-- Xem danh sách nhà hàng.
GRANT SELECT (
    restaurant_id, restaurant_name, cuisine_type,
    is_approved, is_open, min_order_amount
)
ON food_delivery_db.restaurant TO 'role_customer';

-- Xem thực đơn.
GRANT SELECT (
    menu_item_id, restaurant_id, name, description,
    price, category, is_available
)
ON food_delivery_db.menu_item TO 'role_customer';

-- Ánh xạ tài khoản sang khách hàng.
GRANT SELECT (customer_id, user_id)
ON food_delivery_db.customer TO 'role_customer';

-- Xem sổ địa chỉ.
GRANT SELECT (
    user_id, is_default, address_line, ward, district, city
)
ON food_delivery_db.address TO 'role_customer';

-- Xem lịch sử đơn hàng.
GRANT SELECT (
    order_id, customer_id, restaurant_id, driver_id,
    order_date, total_amount, status, delivery_fee,
    delivery_address_snapshot
)
ON food_delivery_db.`order` TO 'role_customer';

-- Tạo đơn hàng.
GRANT INSERT (
    customer_id, restaurant_id, total_amount, status,
    delivery_fee, payment_method, delivery_address_snapshot
)
ON food_delivery_db.`order` TO 'role_customer';

-- Xem chi tiết món trong đơn.
GRANT SELECT (
    order_item_id, order_id, menu_item_id,
    item_name, quantity, price
)
ON food_delivery_db.order_item TO 'role_customer';

-- Thêm món vào đơn hàng.
GRANT INSERT (
    order_id, menu_item_id, quantity, price, item_name
)
ON food_delivery_db.order_item TO 'role_customer';

-- Thêm thông tin thanh toán.
GRANT INSERT (
    order_id, amount, payment_method, status,
    transaction_date, provider,
    provider_transaction_id, paid_at
)
ON food_delivery_db.payment TO 'role_customer';

-- Xem lịch sử thanh toán.
GRANT SELECT (
    order_id, amount, payment_method,
    status, transaction_date, paid_at
)
ON food_delivery_db.payment TO 'role_customer';

-- Kiểm tra và tạo đánh giá.
GRANT SELECT (order_id, reviewer_id, target_type)
ON food_delivery_db.review TO 'role_customer';

GRANT INSERT (
    order_id, reviewer_id, target_type, rating, comment
)
ON food_delivery_db.review TO 'role_customer';

-- Xem thông báo và đánh dấu đã đọc.
GRANT SELECT (
    notification_id, order_id, user_id, type,
    title, message, is_read, created_at
),
UPDATE (is_read)
ON food_delivery_db.notification TO 'role_customer';


-- =========================================================
-- 3. ROLE RESTAURANT - NHÀ HÀNG
-- =========================================================

-- Xem tên khách hàng để hiển thị trên đơn.
GRANT SELECT (user_id, name, role)
ON food_delivery_db.`user` TO 'role_restaurant';

-- Ánh xạ tài khoản sang nhà hàng.
GRANT SELECT (restaurant_id, user_id)
ON food_delivery_db.restaurant TO 'role_restaurant';

-- Ánh xạ đơn hàng sang tài khoản khách để gửi thông báo trạng thái.
GRANT SELECT (customer_id, user_id)
ON food_delivery_db.customer TO 'role_restaurant';

-- Xem đơn hàng thuộc nhà hàng.
GRANT SELECT (
    order_id, restaurant_id, driver_id, order_date,
    status, total_amount, delivery_fee,
    customer_id, delivery_address_snapshot
)
ON food_delivery_db.`order` TO 'role_restaurant';

-- Chỉ cập nhật trạng thái đơn hàng.
GRANT UPDATE (status)
ON food_delivery_db.`order` TO 'role_restaurant';

-- Xem chi tiết món trong đơn.
GRANT SELECT (
    order_item_id, order_id, menu_item_id,
    item_name, quantity, price
)
ON food_delivery_db.order_item TO 'role_restaurant';

-- Xem thực đơn.
GRANT SELECT (
    menu_item_id, restaurant_id, name, description,
    price, category, is_available
)
ON food_delivery_db.menu_item TO 'role_restaurant';

-- Xem đánh giá liên quan đến đơn hàng.
GRANT SELECT (
    order_id, reviewer_id, target_type, rating, comment
)
ON food_delivery_db.review TO 'role_restaurant';

-- Xem thông báo và đánh dấu đã đọc.
GRANT SELECT (
    notification_id, order_id, user_id, type,
    title, message, is_read, created_at
),
UPDATE (is_read)
ON food_delivery_db.notification TO 'role_restaurant';

-- Gửi thông báo trạng thái đơn hàng đến khách.
GRANT INSERT (
    order_id, user_id, type, title, message, is_read
)
ON food_delivery_db.notification TO 'role_restaurant';


-- =========================================================
-- 4. ROLE DRIVER - TÀI XẾ
-- =========================================================

-- Xem tên khách hàng và nhà hàng.
GRANT SELECT (user_id, name, role)
ON food_delivery_db.`user` TO 'role_driver';

-- Xem thông tin tài khoản tài xế.
GRANT SELECT (driver_id, user_id, status)
ON food_delivery_db.driver TO 'role_driver';

-- Cập nhật trạng thái hoạt động của tài xế.
GRANT UPDATE (status)
ON food_delivery_db.driver TO 'role_driver';

-- Xem thông tin ca làm việc.
GRANT SELECT (
    shift_id, driver_id, start_time, end_time
)
ON food_delivery_db.shift TO 'role_driver';

-- Tạo ca làm việc.
GRANT INSERT (
    driver_id, start_time, end_time,
    completed_orders, bonus_earned
)
ON food_delivery_db.shift TO 'role_driver';

-- Cập nhật thời gian kết thúc ca.
GRANT UPDATE (end_time)
ON food_delivery_db.shift TO 'role_driver';

-- Ánh xạ tài khoản khách hàng và nhà hàng
-- để gửi thông báo cho các bên liên quan.
GRANT SELECT (customer_id, user_id)
ON food_delivery_db.customer TO 'role_driver';

GRANT SELECT (restaurant_id, user_id)
ON food_delivery_db.restaurant TO 'role_driver';

-- Tạo thông báo liên quan đến đơn giao hàng.
GRANT INSERT (
    order_id, user_id, type, title, message, is_read
)
ON food_delivery_db.notification TO 'role_driver';

-- Xem thông báo và đánh dấu đã đọc.
GRANT SELECT (
    notification_id, order_id, user_id, type,
    title, message, is_read, created_at
),
UPDATE (is_read)
ON food_delivery_db.notification TO 'role_driver';

-- Xem đơn hàng được phân công.
GRANT SELECT (
    order_id, customer_id, restaurant_id, driver_id,
    order_date, status, total_amount, delivery_fee,
    delivery_address_snapshot
)
ON food_delivery_db.`order` TO 'role_driver';

-- Cập nhật trạng thái đơn và nhận đơn bằng driver_id.
GRANT UPDATE (status, driver_id)
ON food_delivery_db.`order` TO 'role_driver';

-- Xem chi tiết món cần giao.
GRANT SELECT (
    order_item_id, order_id, menu_item_id,
    item_name, quantity, price
)
ON food_delivery_db.order_item TO 'role_driver';


-- =========================================================
-- 5. ROLE ADMIN - QUẢN TRỊ VIÊN
-- =========================================================

-- Admin Dashboard chỉ đọc dữ liệu cần thiết.
-- Không cấp quyền INSERT, UPDATE hoặc DELETE.

-- Xem thông tin tài khoản.
GRANT SELECT (user_id, name, role)
ON food_delivery_db.`user` TO 'role_admin';

-- Xem toàn bộ đơn hàng.
GRANT SELECT (
    order_id, customer_id, restaurant_id, driver_id,
    order_date, status, total_amount, delivery_fee,
    delivery_address_snapshot
)
ON food_delivery_db.`order` TO 'role_admin';

-- Xem chi tiết món trong đơn.
GRANT SELECT (
    order_item_id, order_id, menu_item_id,
    item_name, quantity, price
)
ON food_delivery_db.order_item TO 'role_admin';

-- Đọc View tổng hợp đơn hàng.
GRANT SELECT
ON food_delivery_db.vw_order_summary
TO 'role_admin';

-- Đọc View doanh thu nhà hàng.
GRANT SELECT
ON food_delivery_db.vw_restaurant_sales
TO 'role_admin';

-- Đọc View hiệu suất tài xế.
GRANT SELECT
ON food_delivery_db.vw_driver_performance
TO 'role_admin';


-- =========================================================
-- 6. KIỂM TRA QUYỀN ĐÃ CẤP
-- =========================================================

SHOW GRANTS FOR 'role_customer';
SHOW GRANTS FOR 'role_restaurant';
SHOW GRANTS FOR 'role_driver';
SHOW GRANTS FOR 'role_admin';
