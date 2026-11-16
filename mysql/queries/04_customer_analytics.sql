USE food_delivery_db;

-- Customers whose completed-order value (including delivery fees) exceeds the average.
SELECT
    c.customer_id,
    u.name,
    SUM(o.total_amount) AS lifetime_gross_order_value
FROM customer AS c
JOIN `user` AS u ON u.user_id = c.user_id
JOIN `order` AS o ON o.customer_id = c.customer_id
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
ORDER BY lifetime_gross_order_value DESC;

-- Registered customers without any orders.
SELECT c.customer_id, u.name, u.phone, u.created_at
FROM customer AS c
JOIN `user` AS u ON u.user_id = c.user_id
LEFT JOIN `order` AS o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Customers with at least two completed orders.
SELECT
    c.customer_id,
    u.name,
    COUNT(o.order_id) AS completed_order_count
FROM customer AS c
JOIN `user` AS u ON u.user_id = c.user_id
JOIN `order` AS o ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
GROUP BY c.customer_id, u.name
HAVING COUNT(o.order_id) >= 2
ORDER BY completed_order_count DESC;
