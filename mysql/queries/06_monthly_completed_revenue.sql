USE food_delivery_db;

-- Truy vấn 6: Số đơn hoàn tất và doanh thu theo tháng dương lịch.
-- DATE_FORMAT gom ngày thành YYYY-MM; chỉ tổng hợp đơn COMPLETED.
SELECT DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
       COUNT(*) AS completed_orders,
       SUM(total_amount) AS revenue
FROM `order`
WHERE status = 'COMPLETED'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY sales_month;
