USE food_delivery_db;

-- Top 10 best-selling menu items.
SELECT
    mi.menu_item_id,
    mi.name,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.price) AS gross_item_sales
FROM menu_item AS mi
JOIN order_item AS oi ON oi.menu_item_id = mi.menu_item_id
JOIN `order` AS o ON o.order_id = oi.order_id
WHERE o.status = 'COMPLETED'
GROUP BY mi.menu_item_id, mi.name
ORDER BY units_sold DESC
LIMIT 10;
