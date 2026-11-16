USE food_delivery_db;

CREATE INDEX idx_order_customer_date
    ON `order` (customer_id, order_date DESC);

CREATE INDEX idx_order_restaurant_status
    ON `order` (restaurant_id, status, order_date);

CREATE INDEX idx_order_driver_status
    ON `order` (driver_id, status);

CREATE INDEX idx_menu_restaurant_avail
    ON menu_item (restaurant_id, is_available);

CREATE INDEX idx_payment_order_status
    ON payment (order_id, status);

CREATE INDEX idx_audit_order_date
    ON audit_log (order_id, changed_at);

CREATE INDEX idx_review_order_target
    ON review (order_id, target_type);

CREATE INDEX idx_shift_driver_start
    ON shift (driver_id, start_time);

CREATE INDEX idx_notification_user_read
    ON notification (user_id, is_read, created_at);
