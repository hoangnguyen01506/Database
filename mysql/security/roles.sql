USE food_delivery_db; -- Chọn database đích để cấp quyền

-- =========================================================
-- 1. TẠO CÁC ROLE (idempotent — chạy lại không lỗi)
-- =========================================================
CREATE ROLE IF NOT EXISTS
    'role_customer',    -- Role cho khách hàng (kiêm login chưa xác thực + đọc nhà hàng/menu)
    'role_restaurant',  -- Role cho nhà hàng (xem đơn, cập nhật trạng thái đơn)
    'role_driver',      -- Role cho tài xế (nhận đơn, cập nhật trạng thái giao)
    'role_reporting',   -- Role cho báo cáo (chỉ đọc view tổng hợp)
    'role_admin';       -- Role cho admin dashboard (chỉ đọc, không ghi)

-- Xây dựng lại quyền: chạy lại script sẽ xóa quyền cũ trước khi cấp mới.
-- Đảm bảo không còn quyền lỗi thời nếu script được sửa và chạy lại.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM
    'role_customer',
    'role_restaurant',
    'role_driver',
    'role_reporting',
    'role_admin';

-- =========================================================
-- 2. ROLE CUSTOMER — khách hàng + login chưa xác thực + đọc menu
-- =========================================================

-- Đọc thông tin user để xác thực đăng nhập (không lấy phone, created_at)
GRANT SELECT (user_id, name, email, password, role, address)
    ON food_delivery_db.`user` TO 'role_customer';

-- Đọc danh sách nhà hàng đã duyệt/đang mở để hiển thị cho khách
GRANT SELECT (restaurant_id, restaurant_name, cuisine_type, is_approved, is_open, min_order_amount)
    ON food_delivery_db.restaurant TO 'role_customer';

-- Đọc thực đơn của nhà hàng
GRANT SELECT (menu_item_id, restaurant_id, name, description, price, category, is_available)
    ON food_delivery_db.menu_item TO 'role_customer';

-- Đọc customer_id ánh xạ từ user_id (để biết khách hàng nào đang đăng nhập)
GRANT SELECT (customer_id, user_id)
    ON food_delivery_db.customer TO 'role_customer';

-- Đọc sổ địa chỉ của chính khách (không lấy recipient_phone, latitude, longitude)
GRANT SELECT (user_id, is_default, address_line, ward, district, city)
    ON food_delivery_db.address TO 'role_customer';

-- Đọc đơn hàng (chỉ các cột cần hiển thị lịch sử)
GRANT SELECT (order_id, customer_id, restaurant_id, driver_id, order_date,
              total_amount, status, delivery_fee, delivery_address_snapshot)
    ON food_delivery_db.`order` TO 'role_customer';

-- Tạo đơn mới (không cho set order_id, order_date — để DB tự sinh)
GRANT INSERT (customer_id, restaurant_id, total_amount, status, delivery_fee,
              payment_method, delivery_address_snapshot)
    ON food_delivery_db.`order` TO 'role_customer';

-- Đọc chi tiết món trong đơn
GRANT SELECT (order_item_id, order_id, menu_item_id, item_name, quantity, price)
    ON food_delivery_db.order_item TO 'role_customer';

-- Thêm món vào đơn (không cho set order_item_id — tự sinh)
GRANT INSERT (order_id, menu_item_id, quantity, price, item_name)
    ON food_delivery_db.order_item TO 'role_customer';

-- =========================================================
-- 3. ROLE RESTAURANT — nhà hàng xem đơn + chuyển trạng thái
-- =========================================================

-- Đọc tên user (để hiển thị tên khách đặt đơn)
GRANT SELECT (user_id, name, role)
    ON food_delivery_db.`user` TO 'role_restaurant';

-- Đọc restaurant_id ánh xạ từ user_id (biết nhà hàng nào đang đăng nhập)
GRANT SELECT (restaurant_id, user_id)
    ON food_delivery_db.restaurant TO 'role_restaurant';

-- Đọc đơn hàng thuộc nhà hàng mình
GRANT SELECT (order_id, restaurant_id, driver_id, order_date, status,
              total_amount, delivery_fee, customer_id, delivery_address_snapshot)
    ON food_delivery_db.`order` TO 'role_restaurant';

-- Chỉ được cập nhật cột status (không đổi total_amount, delivery_fee...)
GRANT UPDATE (status) ON food_delivery_db.`order` TO 'role_restaurant';

-- Đọc chi tiết món trong đơn
GRANT SELECT (order_item_id, order_id, menu_item_id, item_name, quantity, price)
    ON food_delivery_db.order_item TO 'role_restaurant';

-- Đọc thực đơn của mình
GRANT SELECT (menu_item_id, restaurant_id, name, description, price, category, is_available)
    ON food_delivery_db.menu_item TO 'role_restaurant';

-- =========================================================
-- 4. ROLE DRIVER — tài xế nhận đơn + cập nhật trạng thái giao
-- =========================================================

-- Đọc tên user (hiển thị tên khách/nhà hàng)
GRANT SELECT (user_id, name, role)
    ON food_delivery_db.`user` TO 'role_driver';

-- Đọc thông tin tài xế của chính mình
GRANT SELECT (driver_id, user_id, status)
    ON food_delivery_db.driver TO 'role_driver';

-- Cập nhật trạng thái tài xế (ONLINE/OFFLINE/BUSY)
GRANT UPDATE (status) ON food_delivery_db.driver TO 'role_driver';

-- Đọc đơn hàng được phân công / đang giao
GRANT SELECT (order_id, customer_id, restaurant_id, driver_id, order_date,
              status, total_amount, delivery_fee, delivery_address_snapshot)
    ON food_delivery_db.`order` TO 'role_driver';

-- Cập nhật trạng thái đơn + gán driver_id (nhận đơn)
GRANT UPDATE (status, driver_id) ON food_delivery_db.`order` TO 'role_driver';

-- Đọc chi tiết món trong đơn (để biết giao gì)
GRANT SELECT (order_item_id, order_id, menu_item_id, item_name, quantity, price)
    ON food_delivery_db.order_item TO 'role_driver';

-- =========================================================
-- 5. ROLE REPORTING — chỉ đọc view tổng hợp
-- =========================================================

-- Đọc view tóm tắt đơn hàng
GRANT SELECT ON food_delivery_db.vw_order_summary TO 'role_reporting';

-- Đọc view doanh thu nhà hàng
GRANT SELECT ON food_delivery_db.vw_restaurant_sales TO 'role_reporting';

-- Đọc view hiệu suất tài xế
GRANT SELECT ON food_delivery_db.vw_driver_performance TO 'role_reporting';

-- =========================================================
-- 6. ROLE ADMIN — dashboard chỉ đọc (không ghi)
-- =========================================================

-- API admin dashboard chỉ đọc; quản trị DB dùng tài khoản DBA riêng.
GRANT SELECT (user_id, name, role)
    ON food_delivery_db.`user` TO 'role_admin';

-- Đọc đơn hàng (toàn bộ, không lọc theo nhà hàng/khách)
GRANT SELECT (order_id, customer_id, restaurant_id, driver_id, order_date,
              status, total_amount, delivery_fee, delivery_address_snapshot)
    ON food_delivery_db.`order` TO 'role_admin';

-- Đọc chi tiết món trong đơn
GRANT SELECT (order_item_id, order_id, menu_item_id, item_name, quantity, price)
    ON food_delivery_db.order_item TO 'role_admin';