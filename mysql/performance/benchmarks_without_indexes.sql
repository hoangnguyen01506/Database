USE food_delivery_db;

-- Compare against benchmarks.sql on the same data.
-- IGNORE INDEX prevents each target index from being used by its query, while
-- leaving foreign-key constraints and all indexes in place. MySQL 8.0.18+ is required.
-- Filter values below target matching records near the upper end of the 5,000-data seed.

-- P-01: Customer order history without idx_order_customer_date
EXPLAIN ANALYZE
SELECT order_id, order_date, status, total_amount
FROM `order` IGNORE INDEX (idx_order_customer_date)
WHERE customer_id = 4640
ORDER BY order_date DESC;

-- P-02: Restaurant order queue without idx_order_restaurant_status
EXPLAIN ANALYZE
SELECT order_id, status, order_date
FROM `order` IGNORE INDEX (idx_order_restaurant_status)
WHERE restaurant_id = 200 AND status = 'COMPLETED'
ORDER BY order_date DESC;

-- P-03: Driver orders without idx_order_driver_status
EXPLAIN ANALYZE
SELECT order_id, status, order_date
FROM `order` IGNORE INDEX (idx_order_driver_status)
WHERE driver_id = 150 AND status = 'DELIVERING';

-- P-04: Available menu items without idx_menu_restaurant_avail
EXPLAIN ANALYZE
SELECT menu_item_id, name, price
FROM menu_item IGNORE INDEX (idx_menu_restaurant_avail)
WHERE restaurant_id = 200 AND is_available = 1;

-- P-05: Payment lookup without idx_payment_order_status
EXPLAIN ANALYZE
SELECT payment_id, amount, status, transaction_date
FROM payment IGNORE INDEX (idx_payment_order_status)
WHERE order_id = 5000 AND status = 'FAILED';

-- P-06: Order audit history without idx_audit_order_date
EXPLAIN ANALYZE
SELECT log_id, old_status, new_status, changed_at
FROM audit_log IGNORE INDEX (idx_audit_order_date)
WHERE order_id = 5000
ORDER BY changed_at DESC;

-- P-07: Review lookup without idx_review_order_target
EXPLAIN ANALYZE
SELECT review_id, reviewer_id, rating, review_date
FROM review IGNORE INDEX (idx_review_order_target)
WHERE order_id = 4999 AND target_type = 'Restaurant';

-- P-08: Driver shifts without idx_shift_driver_start
EXPLAIN ANALYZE
SELECT shift_id, start_time, end_time, completed_orders, bonus_earned
FROM shift IGNORE INDEX (idx_shift_driver_start)
WHERE driver_id = 150
ORDER BY start_time DESC;

-- P-09: Unread notifications without idx_notification_user_read
EXPLAIN ANALYZE
SELECT notification_id, type, title, created_at
FROM notification IGNORE INDEX (idx_notification_user_read)
WHERE user_id = 3010 AND is_read = 0
ORDER BY created_at DESC;
