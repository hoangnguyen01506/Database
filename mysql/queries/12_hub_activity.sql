USE food_delivery_db;

-- Truy vấn 12: Tổng quan nhà hàng, tài xế và đơn hàng theo trung tâm điều phối.
-- LEFT JOIN giữ cả hub chưa có hoạt động; đơn được tính qua nhà hàng thuộc hub.
-- COUNT(DISTINCT ...) tránh đếm lặp do đồng thời nối nhiều nhà hàng và tài xế.
SELECT h.hub_id, h.name AS hub_name,
       COUNT(DISTINCT r.restaurant_id) AS restaurant_count,
       COUNT(DISTINCT d.driver_id) AS driver_count,
       COUNT(DISTINCT o.order_id) AS total_orders,
       COUNT(DISTINCT CASE WHEN o.status = 'COMPLETED' THEN o.order_id END) AS completed_orders
FROM hub h
LEFT JOIN restaurant r ON r.hub_id = h.hub_id
LEFT JOIN driver d     ON d.hub_id = h.hub_id
LEFT JOIN `order` o    ON o.restaurant_id = r.restaurant_id
GROUP BY h.hub_id, h.name
ORDER BY total_orders DESC;
