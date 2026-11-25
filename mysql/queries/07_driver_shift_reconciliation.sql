USE food_delivery_db;

-- Truy vấn 7: Đối soát đơn hoàn tất, số ca và tiền thưởng theo tài xế.
-- Tổng hợp order và shift riêng trước khi JOIN để tránh nhân bản dòng và tiền thưởng.
-- LEFT JOIN cùng COALESCE vẫn hiển thị tài xế chưa có đơn hoặc chưa có ca.
SELECT d.driver_id, u.name AS driver_name,
       COALESCE(os.completed_orders, 0) AS completed_orders,
       COALESCE(ss.total_shifts, 0) AS total_shifts,
       COALESCE(ss.total_bonus, 0.00) AS total_bonus
FROM driver d
JOIN `user` u ON u.user_id = d.user_id
LEFT JOIN (
    SELECT driver_id, COUNT(*) AS completed_orders
    FROM `order`
    WHERE status = 'COMPLETED' AND driver_id IS NOT NULL
    GROUP BY driver_id
) os ON os.driver_id = d.driver_id
LEFT JOIN (
    SELECT driver_id, COUNT(*) AS total_shifts, SUM(bonus_earned) AS total_bonus
    FROM shift
    GROUP BY driver_id
) ss ON ss.driver_id = d.driver_id
ORDER BY completed_orders DESC;
