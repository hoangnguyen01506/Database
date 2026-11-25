USE food_delivery_db;

-- Truy vấn 9: Các giao dịch thanh toán thất bại và thông tin chẩn đoán.
-- Hiển thị lý do lỗi cùng mã giao dịch của cổng thanh toán, mới nhất trước.
SELECT p.payment_id, p.order_id, p.amount, p.payment_method,
       p.provider, p.provider_transaction_id,
       p.failure_reason, p.transaction_date
FROM payment p
WHERE p.status = 'FAILED'
ORDER BY p.transaction_date DESC;
