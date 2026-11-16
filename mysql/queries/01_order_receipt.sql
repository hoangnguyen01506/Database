USE food_delivery_db;

-- Order receipt and line-item breakdown.
SELECT
    o.order_id, o.order_date, o.status, o.total_amount,
    cu.name AS customer_name, r.restaurant_name,
    oi.item_name, oi.quantity, oi.price,
    oi.quantity * oi.price AS line_total
FROM `order` AS o
JOIN customer AS c ON c.customer_id = o.customer_id
JOIN `user` AS cu ON cu.user_id = c.user_id
JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id
JOIN order_item AS oi ON oi.order_id = o.order_id
ORDER BY o.order_date DESC, o.order_id, oi.order_item_id;
