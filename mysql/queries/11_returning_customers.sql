USE food_delivery_db;

-- Truy vấn 11: Khách hàng quay lại, có ít nhất hai đơn hoàn tất.
-- COUNT đếm đơn COMPLETED theo từng khách; HAVING lọc sau khi gom nhóm.
SELECT c.customer_id, u.name,
       COUNT(o.order_id) AS completed_order_count
FROM customer c
JOIN `user` u  ON u.user_id = c.user_id
JOIN `order` o ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
GROUP BY c.customer_id, u.name
HAVING COUNT(o.order_id) >= 2
ORDER BY completed_order_count DESC;
