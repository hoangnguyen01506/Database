USE food_delivery_db; -- Chọn database để tạo các chỉ mục

-- =========================================================
-- CHỈ MỤC BỔ SUNG CHO CÁC TRUY VẤN PHỔ BIẾN
-- =========================================================

-- 1. Đơn hàng theo khách + thời gian: phục vụ lịch sử đơn hàng, phân trang "đơn gần nhất"
CREATE INDEX idx_order_customer_date
    ON `order` (customer_id, order_date DESC); -- Composite index: lọc theo customer_id, sắp xếp order_date giảm dần

-- 2. Đơn hàng theo nhà hàng + trạng thái: phục vụ dashboard nhà hàng (đơn chờ xử lý, đang giao...)
CREATE INDEX idx_order_restaurant_status
    ON `order` (restaurant_id, status, order_date); -- Composite index: lọc theo nhà hàng + trạng thái, sắp theo ngày

-- 3. Đơn hàng theo tài xế + trạng thái: phục vụ tài xế xem đơn được phân công / đang giao
CREATE INDEX idx_order_driver_status
    ON `order` (driver_id, status); -- Composite index: lọc đơn theo tài xế và trạng thái xử lý

-- 4. Món ăn theo nhà hàng + trạng thái bán: phục vụ hiển thị thực đơn còn hàng
CREATE INDEX idx_menu_restaurant_avail
    ON menu_item (restaurant_id, is_available); -- Composite index: lọc món theo nhà hàng và trạng thái còn bán

-- 5. Thanh toán theo đơn + trạng thái: phục vụ tra cứu giao dịch thành công/thất bại của đơn
CREATE INDEX idx_payment_order_status
    ON payment (order_id, status); -- Composite index: lọc payment theo đơn hàng và trạng thái

-- 6. Nhật ký kiểm toán theo đơn + thời gian: phục vụ tra cứu lịch sử thay đổi trạng thái đơn (BR-08)
CREATE INDEX idx_audit_order_date
    ON audit_log (order_id, changed_at); -- Composite index: lấy log theo đơn, sắp theo thời điểm thay đổi

-- 7. Đánh giá theo đơn + đối tượng: phục vụ kiểm tra đã đánh giá nhà hàng/tài xế chưa
CREATE INDEX idx_review_order_target
    ON review (order_id, target_type); -- Composite index: lọc review theo đơn và loại đối tượng (Restaurant/Driver)

-- 8. Ca làm việc theo tài xế + thời gian bắt đầu: phục vụ thống kê ca, hiệu suất tài xế
CREATE INDEX idx_shift_driver_start
    ON shift (driver_id, start_time); -- Composite index: lấy ca theo tài xế, sắp theo thời gian bắt đầu

-- 9. Thông báo theo người dùng + trạng thái đọc + thời gian: phục vụ hộp thư / đếm thông báo chưa đọc
CREATE INDEX idx_notification_user_read
    ON notification (user_id, is_read, created_at); -- Composite index: lọc thông báo theo user, trạng thái đọc, sắp theo thời gian