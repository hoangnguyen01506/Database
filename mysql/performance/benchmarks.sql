USE food_delivery_db;

-- Run after indexes/indexes.sql with representative data.
EXPLAIN ANALYZE
SELECT order_id, order_date, status, total_amount
FROM `order`
WHERE customer_id = 1
ORDER BY order_date DESC;

EXPLAIN ANALYZE
SELECT order_id, status, order_date
FROM `order`
WHERE restaurant_id = 1 AND status = 'COMPLETED'
ORDER BY order_date DESC;

EXPLAIN ANALYZE
SELECT menu_item_id, name, price
FROM menu_item
WHERE restaurant_id = 1 AND is_available = 1;

EXPLAIN ANALYZE
SELECT payment_id, amount, status, transaction_date
FROM payment
WHERE order_id = 1 AND status = 'FAILED';

EXPLAIN ANALYZE
SELECT log_id, old_status, new_status, changed_at
FROM audit_log
WHERE order_id = 1
ORDER BY changed_at DESC;
