USE food_delivery_db;

-- Run the entire file for the indexed measurements.
-- Use benchmarks_without_indexes.sql for the comparison with these indexes ignored.
-- Each query below exercises one of the nine supplementary indexes. MySQL 8.0.18+ is required.
-- Filter values below target matching records near the upper end of the 5,000-data seed.

-- P-01: Customer order history (idx_order_customer_date)
EXPLAIN ANALYZE
SELECT order_id, order_date, status, total_amount
FROM `order`
WHERE customer_id = 4640
ORDER BY order_date DESC;

-- P-02: Restaurant order queue by status (idx_order_restaurant_status)
EXPLAIN ANALYZE
SELECT order_id, status, order_date
FROM `order`
WHERE restaurant_id = 200 AND status = 'COMPLETED'
ORDER BY order_date DESC;

-- P-03: Driver orders by status (idx_order_driver_status)
EXPLAIN ANALYZE
SELECT order_id, status, order_date
FROM `order`
WHERE driver_id = 150 AND status = 'DELIVERING';

-- P-04: Available menu items (idx_menu_restaurant_avail)
EXPLAIN ANALYZE
SELECT menu_item_id, name, price
FROM menu_item
WHERE restaurant_id = 200 AND is_available = 1;

-- P-05: Payment lookup by order and status (idx_payment_order_status)
EXPLAIN ANALYZE
SELECT payment_id, amount, status, transaction_date
FROM payment
WHERE order_id = 5000 AND status = 'FAILED';

-- P-06: Order audit history (idx_audit_order_date)
EXPLAIN ANALYZE
SELECT log_id, old_status, new_status, changed_at
FROM audit_log
WHERE order_id = 5000
ORDER BY changed_at DESC;

-- P-07: Review lookup by order and target (idx_review_order_target)
EXPLAIN ANALYZE
SELECT review_id, reviewer_id, rating, review_date
FROM review
WHERE order_id = 4999 AND target_type = 'Restaurant';

-- P-08: Driver shifts in reverse chronological order (idx_shift_driver_start)
EXPLAIN ANALYZE
SELECT shift_id, start_time, end_time, completed_orders, bonus_earned
FROM shift
WHERE driver_id = 150
ORDER BY start_time DESC;

-- P-09: Unread notifications by user, newest first (idx_notification_user_read)
EXPLAIN ANALYZE
SELECT notification_id, type, title, created_at
FROM notification
WHERE user_id = 3010 AND is_read = 0
ORDER BY created_at DESC;
