USE food_delivery_db;

-- Truy vấn 2: Đếm đơn hoàn tất và tổng giá trị đơn theo từng nhà hàng.
-- Chỉ tính đơn COMPLETED; GROUP BY gom kết quả theo nhà hàng.
-- completed_revenue cộng total_amount, bao gồm cả phí giao hàng.
SELECT r.restaurant_id, u.name AS restaurant_name,
       COUNT(o.order_id) AS completed_orders,
       SUM(o.total_amount) AS completed_revenue
FROM restaurant r
JOIN `user` u  ON u.user_id = r.user_id
JOIN `order` o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'COMPLETED'
GROUP BY r.restaurant_id, u.name
ORDER BY completed_revenue DESC;
