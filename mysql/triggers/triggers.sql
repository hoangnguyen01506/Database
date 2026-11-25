USE food_delivery_db; -- Chọn database chứa các bảng cần gắn trigger

DELIMITER $$ 
-- Đổi delimiter để MySQL không hiểu dấu ; bên trong trigger là kết thúc câu lệnh

-- =========================================================
-- NHÓM 1: ĐẢM BẢO KẾ THỪA ĐÚNG VAI TRÒ (ROLE INTEGRITY)
-- =========================================================

-- Trigger: Chặn INSERT customer nếu user không phải role Customer hoặc đã có vai trò khác
CREATE TRIGGER trg_customer_role_insert
BEFORE INSERT ON customer -- Chạy trước khi INSERT vào bảng customer
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user tương ứng

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE; -- Khóa dòng user để tránh race condition khi 2 transaction cùng lúc

    IF NOT (v_role <=> 'Customer') -- Dùng <=> để so sánh an toàn cả NULL (nếu user không tồn tại)
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id) -- Đã là nhà hàng?
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN -- Đã là tài xế?
        SIGNAL SQLSTATE '45000' -- Ném lỗi tùy chỉnh (45000 = unhandled user-defined exception)
            SET MESSAGE_TEXT = 'Customer must use a Customer account with no other specialized role';
    END IF;
END$$

-- Trigger: Tương tự cho UPDATE customer (chặn đổi user_id sang user sai role)
CREATE TRIGGER trg_customer_role_update
BEFORE UPDATE ON customer -- Chạy trước khi UPDATE bảng customer
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user mới

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id -- Dùng NEW vì có thể đổi user_id
    FOR UPDATE; -- Khóa dòng để đảm bảo nhất quán

    IF NOT (v_role <=> 'Customer')
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer must use a Customer account with no other specialized role';
    END IF;
END$$

-- Trigger: Chặn INSERT restaurant nếu user không phải role Restaurant hoặc đã có vai trò khác
CREATE TRIGGER trg_restaurant_role_insert
BEFORE INSERT ON restaurant -- Chạy trước khi INSERT vào bảng restaurant
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE; -- Khóa dòng user

    IF NOT (v_role <=> 'Restaurant') -- Role phải đúng là Restaurant
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id) -- Đã là khách?
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN -- Đã là tài xế?
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Restaurant must use a Restaurant account with no other specialized role';
    END IF;
END$$

-- Trigger: Tương tự cho UPDATE restaurant
CREATE TRIGGER trg_restaurant_role_update
BEFORE UPDATE ON restaurant -- Chạy trước khi UPDATE bảng restaurant
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user mới

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE; -- Khóa dòng user

    IF NOT (v_role <=> 'Restaurant')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Restaurant must use a Restaurant account with no other specialized role';
    END IF;
END$$

-- Trigger: Chặn INSERT driver nếu user không phải role Driver hoặc đã có vai trò khác
CREATE TRIGGER trg_driver_role_insert
BEFORE INSERT ON driver -- Chạy trước khi INSERT vào bảng driver
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE; -- Khóa dòng user

    IF NOT (v_role <=> 'Driver') -- Role phải đúng là Driver
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id) -- Đã là khách?
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id) THEN -- Đã là nhà hàng?
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver must use a Driver account with no other specialized role';
    END IF;
END$$

-- Trigger: Tương tự cho UPDATE driver
CREATE TRIGGER trg_driver_role_update
BEFORE UPDATE ON driver -- Chạy trước khi UPDATE bảng driver
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20); -- Biến lưu role của user mới

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE; -- Khóa dòng user

    IF NOT (v_role <=> 'Driver')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver must use a Driver account with no other specialized role';
    END IF;
END$$


-- Trigger: Chặn đổi role của user nếu đang có tài khoản chuyên biệt (customer/restaurant/driver)
CREATE TRIGGER trg_user_role_update
BEFORE UPDATE ON `user` -- Chạy trước khi UPDATE bảng user
FOR EACH ROW
BEGIN
    IF NEW.role <> OLD.role AND ( -- Chỉ kiểm tra khi role thực sự thay đổi
        (EXISTS (SELECT 1 FROM customer WHERE user_id = OLD.user_id) -- Đang là customer?
            AND NEW.role <> 'Customer') -- Mà đổi sang role khác?
        OR (EXISTS (SELECT 1 FROM restaurant WHERE user_id = OLD.user_id) -- Đang là restaurant?
            AND NEW.role <> 'Restaurant')
        OR (EXISTS (SELECT 1 FROM driver WHERE user_id = OLD.user_id) -- Đang là driver?
            AND NEW.role <> 'Driver')
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot change a user role while its specialized account exists';
    END IF;
END$$

-- =========================================================
-- NHÓM 2: RÀNG BUỘC ĐƠN HÀNG (ORDER LIFECYCLE)
-- =========================================================

-- Trigger: Kiểm tra trước khi tạo đơn hàng mới
CREATE TRIGGER trg_order_before_insert
BEFORE INSERT ON `order` -- Chạy trước khi INSERT vào bảng order
FOR EACH ROW
BEGIN
    DECLARE v_actor_exists INT DEFAULT 0; -- Cờ kiểm tra user thực hiện có tồn tại
    DECLARE v_customer_owns_order INT DEFAULT 0; -- Cờ kiểm tra khách hàng sở hữu đơn

    IF NEW.status <> 'PENDING' OR NEW.driver_id IS NOT NULL THEN -- Đơn mới phải PENDING và chưa gán tài xế
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'New orders must start PENDING and unassigned';
    END IF;

    IF @app_user_id IS NULL OR @app_user_id <= 0 THEN -- Biến session phải được set trước
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Set @app_user_id to the authenticated user before creating an order';
    END IF;

    SELECT COUNT(*) INTO v_actor_exists
    FROM `user`
    WHERE user_id = @app_user_id; -- Kiểm tra user thực hiện có tồn tại

    IF v_actor_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The authenticated order actor does not exist';
    END IF;

    SELECT COUNT(*) INTO v_customer_owns_order
    FROM customer
    WHERE customer_id = NEW.customer_id
      AND user_id = @app_user_id; -- Chỉ khách hàng sở hữu mới được tạo đơn

    IF v_customer_owns_order <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only the customer placing the order can create it';
    END IF;

    SET NEW.total_amount = NEW.delivery_fee; -- Khởi tạo total_amount = phí ship (chưa có món)
END$$

-- Trigger: Kiểm tra trước khi UPDATE đơn hàng (chuyển trạng thái, gán tài xế, đổi phí)
CREATE TRIGGER trg_order_before_update
BEFORE UPDATE ON `order` -- Chạy trước khi UPDATE bảng order
FOR EACH ROW
BEGIN
    DECLARE v_actor_exists INT DEFAULT 0; -- Cờ kiểm tra user thực hiện
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00; -- Tổng tiền món (chưa gồm ship)
    DECLARE v_minimum DECIMAL(12,2) DEFAULT 0.00; -- Giá trị đơn tối thiểu của nhà hàng
    DECLARE v_driver_status VARCHAR(10); -- Trạng thái tài xế được gán

    IF NOT (NEW.customer_id <=> OLD.customer_id) -- Không cho đổi khách hàng
       OR NOT (NEW.restaurant_id <=> OLD.restaurant_id) THEN -- Không cho đổi nhà hàng
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An order customer and restaurant cannot be changed';
    END IF;

    IF NOT (NEW.status <=> OLD.status) THEN -- Chỉ xử lý khi trạng thái thay đổi
        IF @app_user_id IS NULL OR @app_user_id <= 0 THEN -- Bắt buộc set biến session
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Set @app_user_id to the authenticated user before changing order status';
        END IF;

        SELECT COUNT(*) INTO v_actor_exists
        FROM `user`
        WHERE user_id = @app_user_id; -- Kiểm tra user tồn tại

        IF v_actor_exists <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The authenticated order actor does not exist';
        END IF;

        -- Kiểm tra transition hợp lệ theo state machine
        IF (OLD.status = 'PENDING' AND NEW.status NOT IN ('CONFIRMED', 'CANCELLED')) -- PENDING → CONFIRMED/CANCELLED
           OR (OLD.status = 'CONFIRMED' AND NEW.status NOT IN ('PREPARING', 'CANCELLED')) -- CONFIRMED → PREPARING/CANCELLED
           OR (OLD.status = 'PREPARING' AND NEW.status NOT IN ('READY', 'CANCELLED')) -- PREPARING → READY/CANCELLED
           OR (OLD.status = 'READY' AND NEW.status NOT IN ('PICKED_UP', 'CANCELLED')) -- READY → PICKED_UP/CANCELLED
           OR (OLD.status = 'PICKED_UP' AND NEW.status NOT IN ('DELIVERING', 'CANCELLED')) -- PICKED_UP → DELIVERING/CANCELLED
           OR (OLD.status = 'DELIVERING' AND NEW.status NOT IN ('COMPLETED', 'CANCELLED')) -- DELIVERING → COMPLETED/CANCELLED
           OR OLD.status IN ('COMPLETED', 'CANCELLED') THEN -- Đơn kết thúc không được đổi nữa
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invalid order status transition';
        END IF;

        IF NEW.status = 'CONFIRMED' THEN -- Khi xác nhận đơn, kiểm tra món + giá tối thiểu
            SELECT COALESCE(SUM(quantity * price), 0.00) -- Tính subtotal từ order_item
            INTO v_subtotal
            FROM order_item
            WHERE order_id = OLD.order_id;

            SELECT min_order_amount INTO v_minimum -- Lấy giá trị đơn tối thiểu của nhà hàng
            FROM restaurant
            WHERE restaurant_id = NEW.restaurant_id;

            IF NOT EXISTS ( -- Đơn phải có ít nhất 1 món
                SELECT 1 FROM order_item WHERE order_id = NEW.order_id
            ) OR v_subtotal < v_minimum THEN -- Và subtotal phải ≥ min_order_amount
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Order must contain items and meet the restaurant minimum';
            END IF;
        END IF;
    END IF;

    IF NOT (NEW.driver_id <=> OLD.driver_id) THEN -- Khi gán/đổi/hủy tài xế
        IF @app_user_id IS NULL OR @app_user_id <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Set @app_user_id before assigning or releasing a driver';
        END IF;

        IF NEW.status IN ('COMPLETED', 'CANCELLED') AND NEW.driver_id IS NOT NULL THEN -- Đơn kết thúc không gán tài xế
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A driver cannot be assigned to a terminal order';
        END IF;

        IF NEW.driver_id IS NOT NULL THEN -- Nếu gán tài xế mới
            SELECT status INTO v_driver_status
            FROM driver
            WHERE driver_id = NEW.driver_id
            FOR UPDATE; -- Khóa dòng driver tránh race condition

            IF v_driver_status <> 'ONLINE' THEN -- Chỉ tài xế ONLINE mới được gán
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Only an ONLINE driver can be assigned';
            END IF;
        END IF;
    END IF;

    IF NOT (NEW.delivery_fee <=> OLD.delivery_fee) AND OLD.status <> 'PENDING' THEN -- Phí ship chỉ đổi được khi PENDING
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Delivery fee cannot change after an order is confirmed';
    END IF;

    SELECT COALESCE(SUM(quantity * price), 0.00) -- Tính lại subtotal từ order_item
    INTO v_subtotal
    FROM order_item
    WHERE order_id = OLD.order_id;

    SET NEW.total_amount = v_subtotal + NEW.delivery_fee; -- total_amount = subtotal + phí ship
END$$

-- Trigger: Sau khi INSERT đơn — tăng total_orders của khách + ghi audit
CREATE TRIGGER trg_order_audit_after_insert
AFTER INSERT ON `order` -- Chạy sau khi INSERT thành công
FOR EACH ROW
BEGIN
    UPDATE customer
    SET total_orders = COALESCE(total_orders, 0) + 1 -- Tăng tổng đơn của khách
    WHERE customer_id = NEW.customer_id;

    INSERT INTO audit_log (order_id, old_status, new_status, changed_by, changed_at) -- Ghi log tạo đơn
    VALUES (NEW.order_id, NULL, NEW.status, @app_user_id, CURRENT_TIMESTAMP); -- old_status = NULL vì là đơn mới
END$$

-- Trigger: Sau khi UPDATE đơn — audit + cập nhật trạng thái tài xế + điểm khách + ca làm việc
CREATE TRIGGER trg_order_audit_and_driver_after_update
AFTER UPDATE ON `order` -- Chạy sau khi UPDATE thành công
FOR EACH ROW
BEGIN
    IF NOT (NEW.status <=> OLD.status) THEN -- Nếu trạng thái thay đổi → ghi audit
        INSERT INTO audit_log (order_id, old_status, new_status, changed_by, changed_at)
        VALUES (NEW.order_id, OLD.status, NEW.status, @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    IF NOT (NEW.driver_id <=> OLD.driver_id) THEN -- Nếu tài xế thay đổi
        IF NEW.driver_id IS NOT NULL THEN -- Gán tài xế mới → chuyển sang BUSY
            UPDATE driver
            SET status = 'BUSY'
            WHERE driver_id = NEW.driver_id AND status = 'ONLINE'; -- Chỉ đổi nếu đang ONLINE

            IF ROW_COUNT() <> 1 THEN -- Nếu không đổi được dòng nào → tài xế không còn ONLINE
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Driver assignment lost its ONLINE status';
            END IF;
        END IF;

        IF OLD.driver_id IS NOT NULL THEN -- Giải phóng tài xế cũ → về ONLINE nếu không còn đơn active
            UPDATE driver AS d
            SET status = 'ONLINE'
            WHERE d.driver_id = OLD.driver_id
              AND NOT EXISTS ( -- Không còn đơn active nào khác của tài xế này
                  SELECT 1
                  FROM `order` AS active_order
                  WHERE active_order.driver_id = OLD.driver_id
                    AND active_order.order_id <> NEW.order_id -- Bỏ qua đơn hiện tại
                    AND active_order.status NOT IN ('COMPLETED', 'CANCELLED') -- Đơn chưa kết thúc
              );
        END IF;
    END IF;

    IF NEW.status IN ('COMPLETED', 'CANCELLED') -- Đơn vừa kết thúc
       AND OLD.status NOT IN ('COMPLETED', 'CANCELLED') -- Trước đó chưa kết thúc
       AND NEW.driver_id IS NOT NULL THEN -- Có tài xế được gán
        UPDATE driver AS d
        SET status = 'ONLINE' -- Giải phóng tài xế về ONLINE
        WHERE d.driver_id = NEW.driver_id
          AND NOT EXISTS ( -- Nếu không còn đơn active nào khác
              SELECT 1
              FROM `order` AS active_order
              WHERE active_order.driver_id = NEW.driver_id
                AND active_order.order_id <> NEW.order_id
                AND active_order.status NOT IN ('COMPLETED', 'CANCELLED')
          );
    END IF;

    IF NEW.status = 'COMPLETED' AND OLD.status <> 'COMPLETED' THEN -- Đơn vừa hoàn thành
        UPDATE customer
        SET loyalty_points = COALESCE(loyalty_points, 0) + 10 -- Cộng 10 điểm thưởng
        WHERE customer_id = NEW.customer_id;

        IF NEW.driver_id IS NOT NULL THEN -- Cập nhật ca làm việc hiện tại của tài xế
            UPDATE shift
            SET completed_orders = COALESCE(completed_orders, 0) + 1, -- Tăng đơn hoàn thành trong ca
                bonus_earned = COALESCE(bonus_earned, 0.00) + 10.00 -- Cộng 10.00 thưởng
            WHERE driver_id = NEW.driver_id
              AND start_time <= CURRENT_TIMESTAMP -- Ca đã bắt đầu
              AND (end_time IS NULL OR end_time >= CURRENT_TIMESTAMP) -- Ca chưa kết thúc
            ORDER BY start_time DESC -- Lấy ca gần nhất
            LIMIT 1;
        END IF;
    END IF;
END$$

-- =========================================================
-- NHÓM 3: RÀNG BUỘC CHI TIẾT ĐƠN HÀNG (ORDER ITEM)
-- =========================================================

-- Trigger: Kiểm tra trước khi thêm món vào đơn
CREATE TRIGGER trg_order_item_before_insert
BEFORE INSERT ON order_item -- Chạy trước khi INSERT order_item
FOR EACH ROW
BEGIN
    DECLARE v_available TINYINT; -- Trạng thái còn bán của món
    DECLARE v_menu_restaurant INT; -- Nhà hàng sở hữu món
    DECLARE v_order_restaurant INT; -- Nhà hàng của đơn
    DECLARE v_order_status VARCHAR(20); -- Trạng thái đơn
    DECLARE v_name VARCHAR(100); -- Tên món (snapshot)
    DECLARE v_price DECIMAL(10,2); -- Giá món (snapshot)
    DECLARE v_found TINYINT DEFAULT 1; -- Cờ tìm thấy bản ghi
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0; -- Bắt lỗi NOT FOUND

    SELECT mi.is_available, mi.restaurant_id, mi.name, mi.price, -- Lấy thông tin món + đơn
           o.restaurant_id, o.status
    INTO v_available, v_menu_restaurant, v_name, v_price,
         v_order_restaurant, v_order_status
    FROM menu_item AS mi
    JOIN `order` AS o ON o.order_id = NEW.order_id
    WHERE mi.menu_item_id = NEW.menu_item_id;

    IF v_found = 0 THEN -- Nếu không tìm thấy đơn hoặc món
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order or menu item does not exist';
    END IF;

    IF v_order_status <> 'PENDING' THEN -- Chỉ thêm món vào đơn PENDING
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items can only be added to a PENDING order';
    END IF;

    IF v_available <> 1 THEN -- Món phải còn bán
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Menu item is unavailable';
    END IF;

    IF v_menu_restaurant <> v_order_restaurant THEN -- Món phải thuộc đúng nhà hàng của đơn
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Menu item belongs to a different restaurant';
    END IF;

    SET NEW.item_name = v_name; -- Ghi đè tên món bằng snapshot từ menu_item
    SET NEW.price = v_price; -- Ghi đè giá bằng snapshot từ menu_item
END$$

-- Trigger: Kiểm tra trước khi UPDATE order_item
CREATE TRIGGER trg_order_item_before_update
BEFORE UPDATE ON order_item -- Chạy trước khi UPDATE order_item
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20); -- Trạng thái đơn chứa món

    SELECT status INTO v_order_status
    FROM `order`
    WHERE order_id = OLD.order_id; -- Lấy trạng thái đơn gốc

    IF v_order_status <> 'PENDING' THEN -- Chỉ sửa món khi đơn PENDING
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items cannot be changed after order confirmation';
    END IF;

    IF NEW.order_id <> OLD.order_id OR NEW.menu_item_id <> OLD.menu_item_id THEN -- Không cho đổi đơn/món
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An order item cannot be moved or replaced';
    END IF;

    SET NEW.item_name = OLD.item_name; -- Giữ nguyên tên món (snapshot)
    SET NEW.price = OLD.price; -- Giữ nguyên giá (snapshot)
END$$

-- Trigger: Kiểm tra trước khi DELETE order_item
CREATE TRIGGER trg_order_item_before_delete
BEFORE DELETE ON order_item -- Chạy trước khi DELETE order_item
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20); -- Trạng thái đơn chứa món

    SELECT status INTO v_order_status
    FROM `order`
    WHERE order_id = OLD.order_id;

    IF v_order_status <> 'PENDING' THEN -- Chỉ xóa món khi đơn PENDING
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items cannot be deleted after order confirmation';
    END IF;
END$$

-- Trigger: Sau khi INSERT order_item — tính lại total_amount của đơn
CREATE TRIGGER trg_order_item_recalculate_after_insert
AFTER INSERT ON order_item -- Chạy sau khi INSERT order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = ( -- total_amount = tổng món + phí ship
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = NEW.order_id
    ) + o.delivery_fee
    WHERE o.order_id = NEW.order_id;
END$$

-- Trigger: Sau khi UPDATE order_item — tính lại total_amount
CREATE TRIGGER trg_order_item_recalculate_after_update
AFTER UPDATE ON order_item -- Chạy sau khi UPDATE order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = ( -- Tính lại từ đầu để tránh sai lệch
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = NEW.order_id
    ) + o.delivery_fee
    WHERE o.order_id = NEW.order_id;
END$$

-- Trigger: Sau khi DELETE order_item — tính lại total_amount
CREATE TRIGGER trg_order_item_recalculate_after_delete
AFTER DELETE ON order_item -- Chạy sau khi DELETE order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = ( -- Tính lại từ đầu sau khi xóa
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = OLD.order_id -- Dùng OLD vì bản ghi đã bị xóa
    ) + o.delivery_fee
    WHERE o.order_id = OLD.order_id;
END$$

-- =========================================================
-- NHÓM 4: RÀNG BUỘC ĐÁNH GIÁ (REVIEW)
-- =========================================================

-- Trigger: Kiểm tra trước khi INSERT review
CREATE TRIGGER trg_review_before_insert
BEFORE INSERT ON review -- Chạy trước khi INSERT review
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20); -- Trạng thái đơn
    DECLARE v_customer_user_id INT; -- User ID của khách đặt đơn
    DECLARE v_driver_id INT; -- Tài xế được gán cho đơn
    DECLARE v_found TINYINT DEFAULT 1; -- Cờ tìm thấy
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0; -- Bắt lỗi NOT FOUND

    SELECT o.status, c.user_id, o.driver_id -- Lấy thông tin đơn + khách + tài xế
    INTO v_order_status, v_customer_user_id, v_driver_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = NEW.order_id;

    IF v_found = 0 OR v_order_status <> 'COMPLETED' THEN -- Chỉ đánh giá đơn đã COMPLETED
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviews require a completed order';
    END IF;

    IF v_customer_user_id <> NEW.reviewer_id THEN -- Người đánh giá phải là khách đặt đơn
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviewer must be the customer who placed the order';
    END IF;

    IF NEW.target_type = 'Driver' AND v_driver_id IS NULL THEN -- Không đánh giá tài xế nếu đơn không có tài xế
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot review a driver when none was assigned';
    END IF;
END$$

-- Trigger: Kiểm tra trước khi UPDATE review (tương tự INSERT)
CREATE TRIGGER trg_review_before_update
BEFORE UPDATE ON review -- Chạy trước khi UPDATE review
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20); -- Trạng thái đơn
    DECLARE v_customer_user_id INT; -- User ID của khách đặt đơn
    DECLARE v_driver_id INT; -- Tài xế được gán
    DECLARE v_found TINYINT DEFAULT 1; -- Cờ tìm thấy
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0; -- Bắt lỗi NOT FOUND

    SELECT o.status, c.user_id, o.driver_id
    INTO v_order_status, v_customer_user_id, v_driver_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = NEW.order_id;

    IF v_found = 0 OR v_order_status <> 'COMPLETED' THEN -- Vẫn phải là đơn COMPLETED
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviews require a completed order';
    END IF;

    IF v_customer_user_id <> NEW.reviewer_id THEN -- Người đánh giá không được đổi
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviewer must be the customer who placed the order';
    END IF;

    IF NEW.target_type = 'Driver' AND v_driver_id IS NULL THEN -- Vẫn phải có tài xế nếu đánh giá tài xế
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot review a driver when none was assigned';
    END IF;
END$$

-- =========================================================
-- NHÓM 5: BẢO VỆ AUDIT LOG (IMMUTABILITY)
-- =========================================================

-- Trigger: Chặn mọi UPDATE trên audit_log
CREATE TRIGGER trg_audit_log_before_update
BEFORE UPDATE ON audit_log -- Chạy trước khi UPDATE audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' -- Luôn ném lỗi → không cho UPDATE
        SET MESSAGE_TEXT = 'Audit log records are immutable';
END$$

-- Trigger: Chặn mọi DELETE trên audit_log
CREATE TRIGGER trg_audit_log_before_delete
BEFORE DELETE ON audit_log -- Chạy trước khi DELETE audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' -- Luôn ném lỗi → không cho DELETE
        SET MESSAGE_TEXT = 'Audit log records cannot be deleted';
END$$

DELIMITER ; -- Khôi phục delimiter mặc định là ;
