-- =========================================================
-- TẠO VÀ SỬ DỤNG CƠ SỞ DỮ LIỆU FOOD DELIVERY
-- =========================================================

CREATE DATABASE IF NOT EXISTS food_delivery_db; -- Tạo database nếu chưa tồn tại
USE food_delivery_db; -- Chọn database để thực hiện các thao tác tiếp theo


-- =========================================================
-- 1. NHÓM TÀI KHOẢN VÀ KẾ THỪA (SUPERCLASS / SUBCLASS)
-- =========================================================

-- Bảng user: Superclass (lớp cha), lưu thông tin chung của tất cả người dùng
CREATE TABLE user (
    user_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã người dùng tự động tăng
    name VARCHAR(100) NOT NULL, -- Họ tên người dùng, bắt buộc nhập
    phone VARCHAR(15) NOT NULL UNIQUE, -- Số điện thoại, bắt buộc và không được trùng lặp
    email VARCHAR(100) NULL UNIQUE, -- Email, có thể NULL nhưng nếu có thì không được trùng
    password VARCHAR(255) NOT NULL, -- Mật khẩu đã mã hóa (hash), bắt buộc nhập
    role ENUM('Customer', 'Restaurant', 'Driver', 'Admin') NOT NULL, -- Vai trò tài khoản, chỉ nhận 4 giá trị quy định
    address TEXT NULL, -- Địa chỉ tổng quát của người dùng, không bắt buộc
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP -- Thời điểm tạo tài khoản, mặc định là thời gian hiện tại
);

-- Bảng customer: Subclass (lớp con), lưu thông tin riêng của khách hàng
CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã khách hàng tự động tăng
    user_id INT NOT NULL UNIQUE, -- Khóa ngoại, mỗi tài khoản chỉ liên kết tối đa một khách hàng
    loyalty_points INT NULL DEFAULT 0, -- Điểm thưởng tích lũy, mặc định bằng 0
    total_orders INT NULL DEFAULT 0, -- Tổng số đơn hàng của khách, mặc định bằng 0
    preferred_payment VARCHAR(50) NULL, -- Phương thức thanh toán ưa thích, không bắt buộc
    FOREIGN KEY (user_id) REFERENCES user(user_id) -- Liên kết với tài khoản trong bảng user
);

-- Bảng restaurant: Subclass, lưu thông tin riêng của nhà hàng
CREATE TABLE restaurant (
    restaurant_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã nhà hàng tự động tăng
    user_id INT NOT NULL UNIQUE, -- Khóa ngoại, mỗi tài khoản chỉ đại diện tối đa một nhà hàng
    business_license VARCHAR(50) NULL, -- Mã giấy phép kinh doanh của nhà hàng
    cuisine_type VARCHAR(100) NULL, -- Loại hình ẩm thực, ví dụ: Việt Nam, Nhật Bản
    opening_hours VARCHAR(100) NULL, -- Thời gian hoạt động của nhà hàng
    commission_rate DECIMAL(5,2) NULL, -- Tỷ lệ hoa hồng nền tảng thu từ nhà hàng
    hub_id INT NULL, -- Mã trung tâm điều phối quản lý nhà hàng
    is_approved TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái phê duyệt: 0 chưa duyệt, 1 đã duyệt
    is_open TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái hoạt động: 0 đóng cửa, 1 đang mở
    min_order_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- Giá trị đơn hàng tối thiểu
    FOREIGN KEY (user_id) REFERENCES user(user_id), -- Liên kết với tài khoản chủ nhà hàng
    FOREIGN KEY (hub_id) REFERENCES hub(hub_id) -- Liên kết với trung tâm điều phối
);

-- Bảng driver: Subclass, lưu thông tin riêng của tài xế giao hàng
CREATE TABLE driver (
    driver_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã tài xế tự động tăng
    user_id INT NOT NULL UNIQUE, -- Khóa ngoại, mỗi tài khoản chỉ liên kết tối đa một tài xế
    driver_license VARCHAR(50) NULL, -- Số giấy phép lái xe
    vehicle_type VARCHAR(50) NULL, -- Loại phương tiện giao hàng
    plate_number VARCHAR(20) NULL, -- Biển số xe của tài xế
    current_location VARCHAR(255) NULL, -- Vị trí hiện tại của tài xế
    status ENUM('ONLINE', 'OFFLINE', 'BUSY') NULL DEFAULT 'OFFLINE', -- Trạng thái tài xế: trực tuyến, ngoại tuyến hoặc đang giao hàng
    hub_id INT NULL, -- Mã trung tâm điều phối mà tài xế trực thuộc
    FOREIGN KEY (user_id) REFERENCES user(user_id), -- Liên kết với tài khoản người dùng
    FOREIGN KEY (hub_id) REFERENCES hub(hub_id) -- Liên kết với trung tâm điều phối
);


-- =========================================================
-- 2. NHÓM VẬN HÀNH VÀ HỆ SINH THÁI (MANAGEMENT & ECOSYSTEM)
-- =========================================================

-- Bảng hub: Quản lý các trung tâm điều phối giao hàng theo khu vực
CREATE TABLE hub (
    hub_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã trung tâm điều phối tự động tăng
    name VARCHAR(100) NOT NULL, -- Tên trung tâm điều phối, bắt buộc nhập
    location VARCHAR(255) NOT NULL, -- Địa chỉ trung tâm điều phối, bắt buộc nhập
    manager_id INT NULL, -- Mã tài khoản người quản lý trung tâm
    operating_area VARCHAR(255) NULL, -- Khu vực địa lý mà trung tâm phụ trách
    FOREIGN KEY (manager_id) REFERENCES user(user_id) -- Liên kết người quản lý với tài khoản trong bảng user
);

-- Bảng address: Quản lý sổ địa chỉ giao hàng của người dùng
CREATE TABLE address (
    address_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã địa chỉ tự động tăng
    user_id INT NOT NULL, -- Mã người dùng sở hữu địa chỉ
    label VARCHAR(50) NULL, -- Tên gợi nhớ địa chỉ, ví dụ: Nhà riêng, Công ty
    recipient_name VARCHAR(100) NOT NULL, -- Tên người nhận hàng
    recipient_phone VARCHAR(20) NOT NULL, -- Số điện thoại người nhận hàng
    address_line TEXT NOT NULL, -- Địa chỉ chi tiết, bắt buộc nhập
    ward VARCHAR(100) NULL, -- Phường hoặc xã
    district VARCHAR(100) NULL, -- Quận hoặc huyện
    city VARCHAR(100) NULL, -- Tỉnh hoặc thành phố
    latitude DECIMAL(10,7) NULL, -- Vĩ độ địa lý của địa chỉ
    longitude DECIMAL(10,7) NULL, -- Kinh độ địa lý của địa chỉ
    is_default TINYINT(1) NOT NULL DEFAULT 0, -- Đánh dấu địa chỉ mặc định: 0 không, 1 có
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE -- Liên kết với user, tự động xóa địa chỉ khi tài khoản bị xóa
);

-- Bảng menu_item: Quản lý danh sách món ăn trong thực đơn nhà hàng
CREATE TABLE menu_item (
    menu_item_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã món ăn tự động tăng
    restaurant_id INT NOT NULL, -- Mã nhà hàng sở hữu món ăn
    name VARCHAR(100) NOT NULL, -- Tên món ăn, bắt buộc nhập
    description TEXT NULL, -- Mô tả chi tiết món ăn
    price DECIMAL(10,2) NOT NULL, -- Giá bán món ăn, bắt buộc nhập
    category VARCHAR(50) NULL, -- Danh mục món ăn, ví dụ: Món chính, Đồ uống
    is_available TINYINT(1) NULL DEFAULT 1, -- Trạng thái kinh doanh: 1 còn bán, 0 tạm ngừng
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id) -- Liên kết món ăn với nhà hàng sở hữu
);

-- Bảng shift: Quản lý ca làm việc và hiệu suất của tài xế
CREATE TABLE shift (
    shift_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã ca làm việc tự động tăng
    driver_id INT NOT NULL, -- Mã tài xế thực hiện ca làm việc
    start_time DATETIME NOT NULL, -- Thời gian bắt đầu ca làm việc
    end_time DATETIME NULL, -- Thời gian kết thúc ca, NULL nếu ca chưa kết thúc
    completed_orders INT NULL DEFAULT 0, -- Số đơn hàng hoàn thành trong ca, mặc định bằng 0
    bonus_earned DECIMAL(10,2) NULL DEFAULT 0.00, -- Tiền thưởng tài xế nhận được trong ca
    FOREIGN KEY (driver_id) REFERENCES driver(driver_id) -- Liên kết ca làm việc với tài xế
);


-- =========================================================
-- 3. NHÓM GIAO DỊCH CỐT LÕI (CORE TRANSACTIONS)
-- =========================================================

-- Bảng order: Quản lý đơn hàng, kết nối khách hàng, nhà hàng và tài xế
CREATE TABLE `order` (
    order_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã đơn hàng tự động tăng
    customer_id INT NOT NULL, -- Mã khách hàng thực hiện đặt hàng
    restaurant_id INT NOT NULL, -- Mã nhà hàng tiếp nhận đơn hàng
    driver_id INT NULL, -- Mã tài xế được phân công, NULL nếu chưa có tài xế
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo đơn hàng, mặc định là hiện tại
    total_amount DECIMAL(10,2) NOT NULL, -- Tổng giá trị đơn hàng
    status ENUM('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'PICKED UP', 'DELIVERING', 'COMPLETED', 'CANCELLED') NULL DEFAULT 'PENDING', -- Trạng thái đơn hàng trong quy trình xử lý
    delivery_fee DECIMAL(10,2) NULL, -- Phí giao hàng
    payment_method VARCHAR(50) NULL, -- Phương thức thanh toán được lựa chọn
    delivery_address_snapshot TEXT NULL, -- Lưu bản sao địa chỉ giao hàng tại thời điểm đặt đơn để bảo toàn lịch sử
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id), -- Liên kết đơn hàng với khách hàng đặt đơn
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id), -- Liên kết đơn hàng với nhà hàng
    FOREIGN KEY (driver_id) REFERENCES driver(driver_id) -- Liên kết đơn hàng với tài xế được phân công
);

-- Bảng order_item: Bảng trung gian giải quyết quan hệ nhiều-nhiều (M:N) giữa order và menu_item
CREATE TABLE order_item (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã chi tiết đơn hàng tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng chứa món ăn
    menu_item_id INT NOT NULL, -- Mã món ăn được đặt
    quantity INT NOT NULL, -- Số lượng món ăn khách hàng đặt
    price DECIMAL(10,2) NOT NULL, -- Giá món ăn tại thời điểm đặt hàng, tránh thay đổi khi giá thực đơn cập nhật
    item_name VARCHAR(100) NOT NULL, -- Tên món ăn tại thời điểm đặt hàng, bảo toàn lịch sử giao dịch
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết chi tiết món ăn với đơn hàng
    FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id) -- Liên kết chi tiết món ăn với thực đơn
);


-- =========================================================
-- 4. NHÓM PHÁT SINH VÀ KIỂM TOÁN (AUDIT & FEEDBACK)
-- =========================================================

-- Bảng audit_log: Lưu lại lịch sử thay đổi trạng thái đơn hàng để phục vụ kiểm toán (BR-08)
CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã nhật ký tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng có thay đổi trạng thái
    old_status VARCHAR(50) NULL, -- Trạng thái cũ trước khi thay đổi
    new_status VARCHAR(50) NOT NULL, -- Trạng thái mới sau khi thay đổi
    changed_by INT NOT NULL, -- Mã người dùng thực hiện thay đổi
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm ghi nhận thay đổi
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết nhật ký với đơn hàng
    FOREIGN KEY (changed_by) REFERENCES user(user_id) -- Liên kết người thực hiện với tài khoản user
);

-- Bảng notification: Quản lý thông báo gửi đến người dùng
CREATE TABLE notification (
    notification_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã thông báo tự động tăng
    user_id INT NOT NULL, -- Mã người dùng nhận thông báo
    type ENUM('ORDER', 'PROMOTION', 'SYSTEM') NOT NULL, -- Loại thông báo: đơn hàng, khuyến mãi hoặc hệ thống
    title VARCHAR(255) NOT NULL, -- Tiêu đề thông báo
    message TEXT NOT NULL, -- Nội dung chi tiết thông báo
    is_read TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái đọc: 0 chưa đọc, 1 đã đọc
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo thông báo
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE -- Liên kết với user, xóa thông báo khi tài khoản bị xóa
);

-- Bảng payment: Quản lý giao dịch thanh toán của đơn hàng
CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã giao dịch thanh toán tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng được thanh toán
    amount DECIMAL(10,2) NOT NULL, -- Số tiền của giao dịch
    payment_method VARCHAR(50) NOT NULL, -- Phương thức thanh toán
    status ENUM('PENDING', 'SUCCESS', 'FAILED') NULL DEFAULT 'PENDING', -- Trạng thái: đang xử lý, thành công hoặc thất bại
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo giao dịch
    provider VARCHAR(50) NULL, -- Đơn vị cung cấp dịch vụ thanh toán, ví dụ: MoMo, VNPay
    provider_transaction_id VARCHAR(150) NULL UNIQUE, -- Mã giao dịch từ nhà cung cấp, không được trùng lặp
    paid_at DATETIME NULL, -- Thời điểm thanh toán thành công
    failure_reason VARCHAR(255) NULL, -- Lý do thanh toán thất bại nếu có
    FOREIGN KEY (order_id) REFERENCES `order`(order_id) -- Liên kết giao dịch thanh toán với đơn hàng
);

-- Bảng review: Quản lý đánh giá của khách hàng đối với nhà hàng hoặc tài xế (BR-09)
CREATE TABLE review (
    review_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã đánh giá tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng làm căn cứ đánh giá
    reviewer_id INT NOT NULL, -- Mã tài khoản người thực hiện đánh giá
    target_type ENUM('Restaurant', 'Driver') NOT NULL, -- Đối tượng được đánh giá: nhà hàng hoặc tài xế
    rating INT NULL, -- Điểm đánh giá, nên giới hạn trong khoảng từ 1 đến 5
    comment TEXT NULL, -- Nội dung nhận xét của khách hàng
    review_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm thực hiện đánh giá
    UNIQUE (order_id, reviewer_id, target_type), -- Mỗi người chỉ được đánh giá một lần cho mỗi đối tượng trong cùng đơn hàng
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết đánh giá với đơn hàng
    FOREIGN KEY (reviewer_id) REFERENCES user(user_id) -- Liên kết người đánh giá với tài khoản user
);