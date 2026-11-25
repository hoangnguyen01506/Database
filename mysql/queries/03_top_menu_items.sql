USE food_delivery_db;

-- Truy vấn 3: Top 10 món bán chạy trong các đơn đã hoàn tất.
-- Cộng số lượng và doanh thu món từ order_item; chỉ tính đơn COMPLETED.
-- Nếu nhiều món đồng hạng, kết quả hiện chưa có tiêu chí phụ để phá hòa.
SELECT mi.menu_item_id, mi.name,
       SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.price) AS gross_sales
FROM menu_item mi
JOIN order_item oi ON oi.menu_item_id = mi.menu_item_id
JOIN `order` o     ON o.order_id = oi.order_id
WHERE o.status = 'COMPLETED'
GROUP BY mi.menu_item_id, mi.name
ORDER BY units_sold DESC
LIMIT 10;
