USE food_delivery_db;

-- Monthly completed-order value includes delivery fees.
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
    COUNT(*) AS completed_orders,
    SUM(total_amount) AS gross_order_value
FROM `order`
WHERE status = 'COMPLETED'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY sales_month;
