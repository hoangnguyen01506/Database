USE food_delivery_db;

-- Truy vấn 8: Nhà hàng có giá trị đơn trung bình cao hơn mức trung bình nền tảng.
-- So sánh AVG(total_amount) của từng nhà hàng với AVG toàn bộ đơn COMPLETED.
-- Chỉ nhà hàng có ít nhất một đơn COMPLETED mới được xét.
SELECT r.restaurant_id, u.name AS restaurant_name,
       ROUND(AVG(o.total_amount), 2) AS average_order_value
FROM restaurant r
JOIN `user` u  ON u.user_id = r.user_id
JOIN `order` o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'COMPLETED'
GROUP BY r.restaurant_id, u.name
HAVING AVG(o.total_amount) > (
    SELECT AVG(total_amount)
    FROM `order`
    WHERE status = 'COMPLETED'
);
