USE food_delivery_db; -- Chọn database chứa trigger + dữ liệu mẫu cần kiểm thử

-- Chạy file này SAU triggers.sql và fixture sample_data.sql, bằng tài khoản DBA.
DROP PROCEDURE IF EXISTS assert_statement_rejected; -- Xóa procedure cũ nếu đã tồn tại (idempotent)

DELIMITER $$ -- Đổi delimiter để body procedure có thể chứa dấu ;

-- =========================================================
-- PROCEDURE HỖ TRỢ: Khẳng định một câu lệnh PHẢI bị từ chối
-- =========================================================
CREATE PROCEDURE assert_statement_rejected(
    IN p_statement TEXT,          -- Câu SQL cần kiểm tra (dynamic SQL)
    IN p_test_name VARCHAR(100)   -- Tên test case (dùng trong thông báo lỗi)
)
BEGIN
    DECLARE v_rejected BOOLEAN DEFAULT FALSE; -- Cờ đánh dấu câu lệnh có bị lỗi không
    DECLARE v_message VARCHAR(128);           -- Biến chứa thông báo lỗi tùy chỉnh

    BEGIN -- Block con để giới hạn phạm vi HANDLER
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE; -- Bắt MỌI lỗi SQL → đánh dấu bị từ chối, tiếp tục chạy
        SET @test_statement = p_statement;              -- Gán câu SQL vào biến session (PREPARE yêu cầu biến, không nhận tham số trực tiếp)
        PREPARE test_statement FROM @test_statement;    -- Chuẩn bị câu lệnh động
        EXECUTE test_statement;                         -- Thực thi — nếu lỗi → HANDLER bắt và set v_rejected = TRUE
        DEALLOCATE PREPARE test_statement;              -- Giải phóng câu lệnh đã chuẩn bị
    END;

    IF NOT v_rejected THEN -- Nếu câu lệnh KHÔNG bị lỗi → test thất bại
        SET v_message = CONCAT('Expected statement to fail: ', p_test_name); -- Tạo thông báo lỗi
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_message; -- Ném lỗi để dừng toàn bộ test
    END IF;
END$$

DELIMITER ; -- Khôi phục delimiter mặc định

-- Mọi test case kỳ vọng thất bại đều được kiểm tra; transaction sẽ rollback toàn bộ thay đổi test.
START TRANSACTION; -- Mở transaction: các thay đổi test (INSERT/UPDATE) sẽ bị hủy cuối file

-- =========================================================
-- TC-01: Số điện thoại trùng (kỳ vọng lỗi MySQL 1062 — duplicate entry)
-- =========================================================
CALL assert_statement_rejected(
    'INSERT INTO `user` (name, phone, password, role) VALUES (''Duplicate Phone Test'', ''0900000002'', ''demo'', ''Customer'')', -- 0900000002 đã tồn tại → vi phạm uq_user_phone
    'TC-01 duplicate phone' -- Tên test
);

-- =========================================================
-- TC-03: Customer không được đồng thời có subtype Driver
-- =========================================================
CALL assert_statement_rejected(
    'INSERT INTO driver (user_id, driver_license, vehicle_type, plate_number) VALUES (2, ''DL-999999'', ''Motorbike'', ''59-A1 999.99'')', -- user_id=2 là Customer → trigger trg_driver_role_insert chặn
    'TC-03 specialized role exclusivity' -- Kiểm tra tính độc quyền vai trò
);

-- =========================================================
-- TC-04: Address tham chiếu user không tồn tại (kỳ vọng lỗi 1452 — FK constraint)
-- =========================================================
CALL assert_statement_rejected(
    'INSERT INTO address (user_id, recipient_name, recipient_phone, address_line) VALUES (999999, ''Unknown User'', ''0900000001'', ''123 Non-Existent Street'')', -- user_id=999999 không tồn tại → vi phạm FK
    'TC-04 orphan address foreign key' -- Địa chỉ mồ côi
);

-- =========================================================
-- TC-05: Giá món ăn không được âm (kỳ vọng lỗi CHECK 3819)
-- =========================================================
CALL assert_statement_rejected(
    'INSERT INTO menu_item (restaurant_id, name, price) VALUES (1, ''Invalid Negative Item'', -5000.00)', -- price = -5000 → vi phạm chk_menu_price
    'TC-05 negative menu price' -- Giá âm
);

-- =========================================================
-- TẠO ĐƠN TẠM ĐỂ TEST CÁC CASE LIÊN QUAN ĐẾN ORDER
-- =========================================================
SET @app_user_id = 2; -- Actor = khách hàng (user_id=2) — trigger yêu cầu đúng chủ đơn
INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 0.00, 0.00, 'CASH', 'Temporary negative test order' -- Đơn tạm, sẽ bị rollback cuối file
);
SET @negative_test_order_id = LAST_INSERT_ID(); -- Lưu order_id vừa tạo để dùng cho TC-06, TC-09, TC-11

-- =========================================================
-- TC-06: Số lượng món phải > 0 (kỳ vọng lỗi CHECK 3819)
-- =========================================================
CALL assert_statement_rejected(
    CONCAT( -- Nối chuỗi để chèn order_id động
        'INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) VALUES (',
        @negative_test_order_id, ', 1, 0, 45000.00, ''Broken Rice'')' -- quantity = 0 → vi phạm chk_order_item_qty
    ),
    'TC-06 zero order-item quantity' -- Số lượng = 0
);

-- =========================================================
-- TC-09: Tài xế OFFLINE không được gán vào đơn
-- =========================================================
UPDATE driver
SET status = 'OFFLINE' -- Chuyển tài xế 1 sang OFFLINE để test
WHERE driver_id = 1;
SET @app_user_id = 4; -- Actor = tài xế (user_id=4) — trigger kiểm tra driver phải ONLINE
CALL assert_statement_rejected(
    CONCAT(
        'UPDATE `order` SET driver_id = 1 WHERE order_id = ', -- Gán tài xế OFFLINE → trigger trg_order_before_update chặn
        @negative_test_order_id
    ),
    'TC-09 assign an OFFLINE driver' -- Gán tài xế OFFLINE
);

-- =========================================================
-- TC-11: Audit log là bất biến — không cho UPDATE/DELETE
-- =========================================================
SET @negative_test_log_id := ( -- Lấy log_id của dòng audit đầu tiên (tạo đơn) của đơn test
    SELECT log_id
    FROM audit_log
    WHERE order_id = @negative_test_order_id
      AND old_status IS NULL -- old_status NULL = log INSERT đơn mới
    ORDER BY log_id
    LIMIT 1
);
CALL assert_statement_rejected(
    CONCAT(
        'UPDATE audit_log SET new_status = ''CANCELLED'' WHERE log_id = ', -- UPDATE audit → trigger trg_audit_log_before_update chặn
        @negative_test_log_id
    ),
    'TC-11 modify an audit row' -- Sửa audit
);
CALL assert_statement_rejected(
    CONCAT(
        'DELETE FROM audit_log WHERE log_id = ', -- DELETE audit → trigger trg_audit_log_before_delete chặn
        @negative_test_log_id
    ),
    'TC-11 delete an audit row' -- Xóa audit
);

-- =========================================================
-- TC-12: Rating chỉ được từ 1 đến 5 (kỳ vọng lỗi CHECK 3819)
-- =========================================================
CALL assert_statement_rejected(
    'INSERT INTO review (order_id, reviewer_id, target_type, rating, comment) VALUES (1, 2, ''Driver'', 6, ''Invalid rating score'')', -- rating = 6 → vi phạm chk_review_rating
    'TC-12 rating above five' -- Rating > 5
);

ROLLBACK; -- Hủy toàn bộ thay đổi test (đơn tạm, driver OFFLINE, ...) — DB về trạng thái ban đầu

DROP PROCEDURE assert_statement_rejected; -- Dọn dẹp procedure sau khi test xong