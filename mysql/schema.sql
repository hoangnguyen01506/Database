CREATE DATABASE IF NOT EXISTS food_delivery_db; -- Tạo database nếu chưa tồn tại
USE food_delivery_db; -- Chọn database để thực hiện các thao tác tiếp theo

-- =========================================================
-- 1. NHÓM TÀI KHOẢN VÀ KẾ THỪA (SUPERCLASS / SUBCLASS)
-- =========================================================

CREATE TABLE user (
    user_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã người dùng tự động tăng
    name VARCHAR(100) NOT NULL, -- Họ tên người dùng, bắt buộc nhập
    phone VARCHAR(15) NOT NULL, -- Số điện thoại, bắt buộc và không được trùng lặp
    email VARCHAR(100) NULL, -- Email, có thể NULL nhưng nếu có thì không được trùng
    password VARCHAR(255) NOT NULL, -- dùng mật khẩu 6 ký tự demo
    role ENUM('Customer', 'Restaurant', 'Driver', 'Admin') NOT NULL, -- Vai trò tài khoản, chỉ nhận 4 giá trị quy định
    address TEXT NULL, -- Địa chỉ tổng quát của người dùng, không bắt buộc
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo tài khoản, mặc định là thời gian hiện tại
    CONSTRAINT uq_user_phone UNIQUE (phone), -- Ràng buộc duy nhất: số điện thoại không được trùng
    CONSTRAINT uq_user_email UNIQUE (email) -- Ràng buộc duy nhất: email không được trùng (cho phép nhiều NULL)
);

CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã khách hàng tự động tăng
    user_id INT NOT NULL, -- Khóa ngoại, mỗi tài khoản chỉ liên kết tối đa một khách hàng
    loyalty_points INT NULL DEFAULT 0, -- Điểm thưởng tích lũy, mặc định bằng 0
    total_orders INT NULL DEFAULT 0, -- Tổng số đơn hàng của khách, mặc định bằng 0
    preferred_payment VARCHAR(50) NULL, -- Phương thức thanh toán ưa thích, không bắt buộc
    CONSTRAINT uq_customer_user UNIQUE (user_id), -- Mỗi user chỉ tương ứng tối đa 1 bản ghi customer
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE -- Liên kết với tài khoản trong bảng user
);

CREATE TABLE hub (
    hub_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã trung tâm điều phối tự động tăng
    name VARCHAR(100) NOT NULL, -- Tên trung tâm điều phối, bắt buộc nhập
    location VARCHAR(255) NOT NULL, -- Vị trí/địa chỉ của trung tâm, bắt buộc nhập
    manager_id INT NULL, -- Mã người dùng quản lý trung tâm, có thể NULL nếu chưa phân công
    operating_area VARCHAR(255) NULL, -- Khu vực hoạt động/điều phối của trung tâm
    FOREIGN KEY (manager_id) REFERENCES user(user_id) -- Liên kết người quản lý với tài khoản user
);

CREATE TABLE restaurant (
    restaurant_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã nhà hàng tự động tăng
    user_id INT NOT NULL, -- Khóa ngoại, mỗi tài khoản chỉ đại diện tối đa một nhà hàng
    restaurant_name VARCHAR(150) NOT NULL, -- Tên cửa hàng hiển thị cho khách hàng, không phải tên chủ tài khoản
    business_license VARCHAR(50) NULL, -- Mã giấy phép kinh doanh của nhà hàng
    cuisine_type VARCHAR(100) NULL, -- Loại hình ẩm thực, ví dụ: Việt Nam, Nhật Bản
    opening_hours VARCHAR(100) NULL, -- Thời gian hoạt động của nhà hàng
    commission_rate DECIMAL(5,2) NULL, -- Tỷ lệ hoa hồng nền tảng thu từ nhà hàng
    hub_id INT NULL, -- Mã trung tâm điều phối quản lý nhà hàng
    is_approved TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái phê duyệt: 0 chưa duyệt, 1 đã duyệt
    is_open TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái hoạt động: 0 đóng cửa, 1 đang mở
    min_order_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- Giá trị đơn hàng tối thiểu
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE, -- Liên kết với tài khoản chủ nhà hàng
    CONSTRAINT uq_restaurant_user UNIQUE (user_id), -- Mỗi user chỉ đại diện tối đa 1 nhà hàng
    FOREIGN KEY (hub_id) REFERENCES hub(hub_id), -- Liên kết với trung tâm điều phối
    CONSTRAINT chk_restaurant_commission
    CHECK (commission_rate IS NULL OR commission_rate BETWEEN 0 AND 100), -- Hoa hồng phải trong khoảng 0–100%
    CONSTRAINT chk_restaurant_min_order CHECK (min_order_amount >= 0) -- Giá trị đơn tối thiểu không được âm
);

CREATE TABLE driver (
    driver_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã tài xế tự động tăng
    user_id INT NOT NULL, -- Khóa ngoại, mỗi tài khoản chỉ liên kết tối đa một tài xế
    driver_license VARCHAR(50) NULL, -- Số giấy phép lái xe
    vehicle_type VARCHAR(50) NULL, -- Loại phương tiện giao hàng
    plate_number VARCHAR(20) NULL, -- Biển số xe của tài xế
    current_location VARCHAR(255) NULL, -- Vị trí hiện tại của tài xế
    status ENUM('ONLINE', 'OFFLINE', 'BUSY') NOT NULL DEFAULT 'OFFLINE', -- Trạng thái tài xế
    hub_id INT NULL, -- Mã trung tâm điều phối mà tài xế trực thuộc
    CONSTRAINT uq_driver_user UNIQUE (user_id), -- Mỗi user chỉ tương ứng tối đa 1 tài xế
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE, -- Liên kết với tài khoản người dùng
    FOREIGN KEY (hub_id) REFERENCES hub(hub_id) -- Liên kết với trung tâm điều phối
);

-- =========================================================
-- 2. NHÓM VẬN HÀNH VÀ HỆ SINH THÁI (MANAGEMENT & ECOSYSTEM)
-- =========================================================

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

CREATE TABLE menu_item (
    menu_item_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã món ăn tự động tăng
    restaurant_id INT NOT NULL, -- Mã nhà hàng sở hữu món ăn
    name VARCHAR(100) NOT NULL, -- Tên món ăn, bắt buộc nhập
    description TEXT NULL, -- Mô tả chi tiết món ăn
    price DECIMAL(10,2) NOT NULL, -- Giá bán món ăn, bắt buộc nhập
    category VARCHAR(50) NULL, -- Danh mục món ăn, ví dụ: Món chính, Đồ uống
    is_available TINYINT(1) NOT NULL DEFAULT 1, -- Trạng thái kinh doanh: 1 còn bán, 0 tạm ngừng
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id), -- Liên kết món ăn với nhà hàng sở hữu
    CONSTRAINT chk_menu_price CHECK (price >= 0) -- Giá món ăn không được âm
);

CREATE TABLE shift (
    shift_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã ca làm việc tự động tăng
    driver_id INT NOT NULL, -- Mã tài xế thực hiện ca làm việc
    start_time DATETIME NOT NULL, -- Thời gian bắt đầu ca làm việc
    end_time DATETIME NULL, -- Thời gian kết thúc ca, NULL nếu ca chưa kết thúc
    completed_orders INT NULL DEFAULT 0, -- Số đơn hàng hoàn thành trong ca, mặc định bằng 0
    bonus_earned DECIMAL(10,2) NULL DEFAULT 0.00, -- Tiền thưởng tài xế nhận được trong ca
    FOREIGN KEY (driver_id) REFERENCES driver(driver_id), -- Liên kết ca làm việc với tài xế
    CONSTRAINT chk_shift_time CHECK (end_time IS NULL OR end_time >= start_time), -- Thời gian kết thúc phải sau hoặc bằng bắt đầu
    CONSTRAINT chk_shift_completed_orders CHECK (completed_orders IS NULL OR completed_orders >= 0), -- Số đơn hoàn thành không âm
    CONSTRAINT chk_shift_bonus CHECK (bonus_earned IS NULL OR bonus_earned >= 0) -- Tiền thưởng không âm
);

-- =========================================================
-- 3. NHÓM GIAO DỊCH CỐT LÕI (CORE TRANSACTIONS)
-- =========================================================

CREATE TABLE `order` (
    order_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã đơn hàng tự động tăng
    customer_id INT NOT NULL, -- Mã khách hàng thực hiện đặt hàng
    restaurant_id INT NOT NULL, -- Mã nhà hàng tiếp nhận đơn hàng
    driver_id INT NULL, -- Mã tài xế được phân công, NULL nếu chưa có tài xế
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo đơn hàng, mặc định là hiện tại
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- Tổng giá trị đơn hàng
    status ENUM('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'PICKED_UP', 'DELIVERING', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PENDING', -- Trạng thái đơn hàng trong quy trình xử lý
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- Phí giao hàng
    payment_method VARCHAR(50) NULL, -- Phương thức thanh toán được lựa chọn
    delivery_address_snapshot TEXT NULL, -- Lưu bản sao địa chỉ giao hàng tại thời điểm đặt đơn để bảo toàn lịch sử
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id), -- Liên kết đơn hàng với khách hàng đặt đơn
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id), -- Liên kết đơn hàng với nhà hàng
    FOREIGN KEY (driver_id) REFERENCES driver(driver_id), -- Liên kết đơn hàng với tài xế được phân công
    CONSTRAINT chk_order_amounts CHECK (total_amount >= 0 AND delivery_fee >= 0) -- Tổng tiền và phí giao hàng không âm
);

CREATE TABLE order_item (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã chi tiết đơn hàng tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng chứa món ăn
    menu_item_id INT NOT NULL, -- Mã món ăn được đặt
    quantity INT NOT NULL, -- Số lượng món ăn khách hàng đặt
    price DECIMAL(10,2) NOT NULL, -- Giá món ăn tại thời điểm đặt hàng, tránh thay đổi khi giá thực đơn cập nhật
    item_name VARCHAR(100) NOT NULL, -- Tên món ăn tại thời điểm đặt hàng, bảo toàn lịch sử giao dịch
    INDEX idx_order_item_order (order_id), -- Chỉ mục tăng tốc truy vấn chi tiết theo đơn hàng
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết chi tiết món ăn với đơn hàng
    FOREIGN KEY (menu_item_id) REFERENCES menu_item(menu_item_id), -- Liên kết chi tiết món ăn với thực đơn
    CONSTRAINT chk_order_item_qty CHECK (quantity > 0), -- Số lượng đặt phải lớn hơn 0
    CONSTRAINT chk_order_item_price CHECK (price >= 0) -- Giá tại thời điểm đặt không âm
);

-- =========================================================
-- 4. NHÓM PHÁT SINH VÀ KIỂM TOÁN (AUDIT & FEEDBACK)
-- =========================================================

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

CREATE TABLE notification (
    notification_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã thông báo tự động tăng
    order_id INT NULL, -- Đơn hàng liên quan; NULL với thông báo không thuộc loại ORDER
    user_id INT NOT NULL, -- Mã người dùng nhận thông báo
    type ENUM('ORDER', 'SYSTEM') NOT NULL, -- Loại thông báo: đơn hàng hoặc hệ thống
    title VARCHAR(255) NOT NULL, -- Tiêu đề thông báo
    message TEXT NOT NULL, -- Nội dung chi tiết thông báo
    is_read TINYINT(1) NOT NULL DEFAULT 0, -- Trạng thái đọc: 0 chưa đọc, 1 đã đọc
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo thông báo
    FOREIGN KEY (order_id) REFERENCES `order`(order_id) ON DELETE CASCADE, -- Xóa đơn thì xóa thông báo liên quan
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE, -- Liên kết với user, xóa thông báo khi tài khoản bị xóa
    CONSTRAINT chk_notification_order_ref CHECK (type <> 'ORDER' OR order_id IS NOT NULL) -- Thông báo loại ORDER phải có order_id
);

CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã giao dịch thanh toán tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng được thanh toán
    amount DECIMAL(10,2) NOT NULL, -- Số tiền của giao dịch
    payment_method VARCHAR(50) NOT NULL, -- Phương thức thanh toán
    status ENUM('PENDING', 'SUCCESS', 'FAILED') NOT NULL DEFAULT 'PENDING', -- Trạng thái: đang xử lý, thành công hoặc thất bại
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm tạo giao dịch
    provider VARCHAR(50) NULL, -- Đơn vị cung cấp dịch vụ thanh toán, ví dụ: MoMo, VNPay
    provider_transaction_id VARCHAR(150) NULL, -- Mã giao dịch từ nhà cung cấp, không được trùng lặp
    paid_at DATETIME NULL, -- Thời điểm thanh toán thành công
    failure_reason VARCHAR(255) NULL, -- Lý do thanh toán thất bại nếu có
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết giao dịch thanh toán với đơn hàng
    CONSTRAINT uq_payment_provider_transaction UNIQUE (provider_transaction_id), -- Mã giao dịch provider không được trùng
    CONSTRAINT chk_payment_amount CHECK (amount > 0) -- Số tiền thanh toán phải lớn hơn 0
);

CREATE TABLE review (
    review_id INT AUTO_INCREMENT PRIMARY KEY, -- Khóa chính, mã đánh giá tự động tăng
    order_id INT NOT NULL, -- Mã đơn hàng làm căn cứ đánh giá
    reviewer_id INT NOT NULL, -- Mã tài khoản người thực hiện đánh giá
    target_type ENUM('Restaurant', 'Driver') NOT NULL, -- Đối tượng được đánh giá: nhà hàng hoặc tài xế
    rating INT NOT NULL, -- Điểm đánh giá, bắt buộc trong khoảng từ 1 đến 5
    comment TEXT NULL, -- Nội dung nhận xét của khách hàng
    review_date DATETIME DEFAULT CURRENT_TIMESTAMP, -- Thời điểm thực hiện đánh giá
    CONSTRAINT uq_review_order_target UNIQUE (order_id, reviewer_id, target_type), -- Mỗi đơn/người/đối tượng chỉ đánh giá 1 lần
    FOREIGN KEY (order_id) REFERENCES `order`(order_id), -- Liên kết đánh giá với đơn hàng
    FOREIGN KEY (reviewer_id) REFERENCES user(user_id), -- Liên kết người đánh giá với tài khoản user
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5) -- Điểm đánh giá chỉ từ 1 đến 5
);