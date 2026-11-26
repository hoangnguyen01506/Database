USE food_delivery_db; -- Chọn database chứa các bảng gốc trước khi tạo view

-- =========================================================
-- VIEW 1: TÓM TẮT ĐƠN HÀNG (kèm tên khách & nhà hàng)
-- =========================================================
CREATE OR REPLACE VIEW vw_order_summary AS -- Tạo mới hoặc thay thế view nếu đã tồn tại
SELECT
    o.order_id,                 -- Mã đơn hàng (PK bảng order)
    o.order_date,               -- Thời điểm đặt đơn
    o.status,                   -- Trạng thái đơn: PENDING → COMPLETED / CANCELLED
    o.total_amount,             -- Tổng giá trị đơn hàng
    o.delivery_fee,             -- Phí giao hàng
    c.customer_id,              -- Mã khách hàng (PK bảng customer)
    cu.name AS customer_name,   -- Tên khách hàng lấy từ bảng user (kế thừa)
    r.restaurant_id,            -- Mã nhà hàng (PK bảng restaurant)
    r.restaurant_name,          -- Tên nhà hàng hiển thị
    o.driver_id                 -- Mã tài xế được phân công (NULL nếu chưa gán)
FROM `order` AS o                                   -- Bảng gốc: đơn hàng
JOIN customer AS c ON c.customer_id = o.customer_id -- INNER JOIN: order.customer_id NOT NULL + FK → luôn có khách
JOIN `user` AS cu ON cu.user_id = c.user_id         -- INNER JOIN: lấy tên khách từ bảng cha user
JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id; -- INNER JOIN: order.restaurant_id NOT NULL + FK → luôn có nhà hàng

-- =========================================================
-- VIEW 2: THỐNG KÊ DOANH THU THEO NHÀ HÀNG
-- =========================================================
CREATE OR REPLACE VIEW vw_restaurant_sales AS -- Tạo/thay thế view thống kê doanh thu
SELECT
    r.restaurant_id,            -- Mã nhà hàng
    r.restaurant_name,          -- Tên nhà hàng
    COUNT(o.order_id) AS total_orders, -- Tổng số đơn (mọi trạng thái, kể cả CANCELLED)
    SUM(CASE WHEN o.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders, -- Đếm có điều kiện: số đơn hoàn thành
    COALESCE(SUM(               -- Tổng GMV của đơn hoàn thành
        CASE WHEN o.status = 'COMPLETED' THEN o.total_amount ELSE 0 END
    ), 0.00) AS completed_gmv,  -- COALESCE tránh NULL khi chưa có đơn hoàn thành
    COALESCE(SUM(               -- Doanh thu gộp từ món ăn (đã trừ phí ship)
        CASE
            WHEN o.status = 'COMPLETED' THEN o.total_amount - o.delivery_fee -- Phí ship không thuộc về nhà hàng
            ELSE 0
        END
    ), 0.00) AS gross_food_revenue, -- Doanh thu gộp trước hoa hồng
    COALESCE(SUM(               -- Số tiền thực nhận sau khi trừ hoa hồng nền tảng
        CASE
            WHEN o.status = 'COMPLETED'
                THEN (o.total_amount - o.delivery_fee) * (1 - COALESCE(r.commission_rate, 0) / 100) -- commission_rate NULL → coi như 0%
            ELSE 0
        END
    ), 0.00) AS net_restaurant_payout -- Số tiền nhà hàng thực nhận
FROM restaurant AS r                          -- Bảng gốc: tất cả nhà hàng
LEFT JOIN `order` AS o ON o.restaurant_id = r.restaurant_id -- LEFT JOIN: giữ nhà hàng chưa có đơn nào (total_orders = 0)
GROUP BY r.restaurant_id, r.restaurant_name;  -- Nhóm theo từng nhà hàng (group cả tên cho tương thích rộng)

-- =========================================================
-- VIEW 3: HIỆU SUẤT TÀI XẾ (đơn, ca, đánh giá)
-- =========================================================
CREATE OR REPLACE VIEW vw_driver_performance AS -- Tạo/thay thế view hiệu suất tài xế
SELECT
    d.driver_id,                    -- Mã tài xế (PK bảng driver)
    u.name AS driver_name,          -- Tên tài xế lấy từ bảng user
    d.status AS current_status,     -- Trạng thái hiện tại: ONLINE / OFFLINE / BUSY
    h.name AS hub_name,             -- Tên trung tâm điều phối (NULL nếu chưa gán hub)
    COALESCE(orders.completed_orders, 0) AS completed_orders,     -- Tổng đơn hoàn thành (0 nếu chưa có)
    COALESCE(orders.cancelled_orders, 0) AS cancelled_orders,     -- Tổng đơn bị hủy (0 nếu chưa có)
    COALESCE(shifts.total_shifts, 0) AS total_shifts,             -- Tổng số ca đã làm (0 nếu chưa có)
    COALESCE(shifts.completed_shift_orders, 0) AS completed_shift_orders, -- Tổng đơn hoàn thành theo ca
    COALESCE(shifts.total_bonus, 0.00) AS total_bonus,            -- Tổng tiền thưởng (0.00 nếu chưa có)
    ratings.average_rating          -- Điểm đánh giá trung bình (NULL nếu chưa có review)
FROM driver AS d                                -- Bảng gốc: tất cả tài xế
JOIN `user` AS u ON u.user_id = d.user_id       -- INNER JOIN: driver.user_id NOT NULL + FK → luôn có user
LEFT JOIN hub AS h ON h.hub_id = d.hub_id       -- LEFT JOIN: giữ tài xế chưa thuộc hub nào (hub_name NULL)
LEFT JOIN (                                     -- Subquery 1: thống kê đơn theo tài xế
    SELECT
        driver_id,                              -- Nhóm theo tài xế
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders, -- Đếm đơn hoàn thành
        SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders  -- Đếm đơn bị hủy
    FROM `order`
    WHERE driver_id IS NOT NULL                 -- Bỏ đơn chưa phân công tài xế (tránh nhóm NULL vô nghĩa)
    GROUP BY driver_id
) AS orders ON orders.driver_id = d.driver_id   -- LEFT JOIN: giữ tài xế chưa có đơn nào
LEFT JOIN (                                     -- Subquery 2: thống kê ca làm việc
    SELECT
        driver_id,
        COUNT(*) AS total_shifts,               -- Đếm tổng số ca
        SUM(COALESCE(completed_orders, 0)) AS completed_shift_orders, -- Tổng đơn hoàn thành trong các ca (bỏ NULL)
        SUM(bonus_earned) AS total_bonus        -- Tổng thưởng (NULL nếu mọi ca đều NULL)
    FROM shift
    GROUP BY driver_id
) AS shifts ON shifts.driver_id = d.driver_id   -- LEFT JOIN: giữ tài xế chưa có ca nào
LEFT JOIN (                                     -- Subquery 3: đánh giá trung bình
    SELECT o.driver_id, AVG(rv.rating) AS average_rating -- Trung bình rating
    FROM review AS rv
    JOIN `order` AS o ON o.order_id = rv.order_id -- Nối review với order để biết tài xế nào
    WHERE rv.target_type = 'Driver' AND o.driver_id IS NOT NULL -- Chỉ lấy review về tài xế (loại review nhà hàng)
    GROUP BY o.driver_id
) AS ratings ON ratings.driver_id = d.driver_id; -- LEFT JOIN: giữ tài xế chưa được đánh giá (average_rating NULL)