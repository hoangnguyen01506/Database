USE food_delivery_db;

-- Truy vấn 5: Khách đã đăng ký nhưng chưa từng có đơn hàng.
-- LEFT JOIN giữ lại mọi khách; order_id IS NULL là mẫu anti-join.
SELECT c.customer_id, u.name, u.phone, u.created_at
FROM customer c
JOIN `user` u       ON u.user_id = c.user_id
LEFT JOIN `order` o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
