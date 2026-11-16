USE food_delivery_db;

-- Driver delivery and shift performance.
SELECT
    driver_id,
    driver_name,
    current_status,
    hub_name,
    completed_orders,
    cancelled_orders,
    total_shifts,
    completed_shift_orders,
    total_bonus,
    average_rating
FROM vw_driver_performance
ORDER BY completed_orders DESC;

-- Hub-level capacity and order throughput.
SELECT
    h.hub_id,
    h.name AS hub_name,
    COUNT(DISTINCT r.restaurant_id) AS restaurant_count,
    COUNT(DISTINCT d.driver_id) AS driver_count,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'COMPLETED' THEN o.order_id END) AS completed_orders
FROM hub AS h
LEFT JOIN restaurant AS r ON r.hub_id = h.hub_id
LEFT JOIN driver AS d ON d.hub_id = h.hub_id
LEFT JOIN `order` AS o ON o.restaurant_id = r.restaurant_id
GROUP BY h.hub_id, h.name
ORDER BY total_orders DESC;
