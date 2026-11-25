USE food_delivery_db;

-- Truy vấn 4: Khách có chi tiêu tích lũy cao hơn mức trung bình nền tảng.
-- Truy vấn con tính tổng chi tiêu COMPLETED của từng khách rồi lấy trung bình.
-- Chỉ khách có ít nhất một đơn COMPLETED mới xuất hiện trong kết quả.
SELECT c.customer_id, u.name,
       SUM(o.total_amount) AS lifetime_spending
FROM customer c
JOIN `user` u  ON u.user_id = c.user_id
JOIN `order` o ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
GROUP BY c.customer_id, u.name
HAVING SUM(o.total_amount) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(total_amount) AS customer_total
        FROM `order`
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ) AS customer_totals
)
ORDER BY lifetime_spending DESC;
