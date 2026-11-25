USE food_delivery_db;

-- Truy vấn 1: Chi tiết hóa đơn và từng dòng món.
-- JOIN lấy thông tin khách, nhà hàng và món; line_total = số lượng x đơn giá.
-- Dùng INNER JOIN nên chỉ hiện đơn có ít nhất một dòng món.
SELECT o.order_id, o.order_date, o.status, o.total_amount,
       cu.name AS customer_name, ru.name AS restaurant_name,
       oi.item_name, oi.quantity, oi.price,
       (oi.quantity * oi.price) AS line_total
FROM `order` o
JOIN customer c    ON c.customer_id = o.customer_id
JOIN `user` cu     ON cu.user_id = c.user_id
JOIN restaurant r  ON r.restaurant_id = o.restaurant_id
JOIN `user` ru     ON ru.user_id = r.user_id
JOIN order_item oi ON oi.order_id = o.order_id
ORDER BY o.order_date DESC, o.order_id, oi.order_item_id;
