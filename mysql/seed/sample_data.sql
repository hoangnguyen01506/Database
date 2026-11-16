USE food_delivery_db;

-- Replace this placeholder with a valid bcrypt hash before testing authentication.
SET @demo_password_hash = '$2b$12$REPLACE_WITH_A_VALID_BCRYPT_HASH';

START TRANSACTION;

INSERT INTO `user` (user_id, name, phone, email, password, role, address) VALUES
(1, 'Demo Admin', '0900000001', 'admin@example.test', @demo_password_hash, 'Admin', 'District 1, HCMC'),
(2, 'Demo Customer', '0900000002', 'customer@example.test', @demo_password_hash, 'Customer', 'Binh Thanh, HCMC'),
(3, 'Demo Restaurant', '0900000003', 'restaurant@example.test', @demo_password_hash, 'Restaurant', 'Binh Thanh, HCMC'),
(4, 'Demo Driver', '0900000004', 'driver@example.test', @demo_password_hash, 'Driver', 'Binh Thanh, HCMC'),
(5, 'Demo Restaurant B', '0900000005', 'restaurant-b@example.test', @demo_password_hash, 'Restaurant', 'District 1, HCMC');

INSERT INTO hub (hub_id, name, location, manager_id, operating_area)
VALUES (1, 'Binh Thanh Demo Hub', 'Binh Thanh, HCMC', 1, 'Binh Thanh');

INSERT INTO customer (customer_id, user_id, loyalty_points, total_orders, preferred_payment)
VALUES (1, 2, 0, 0, 'MOMO');

INSERT INTO restaurant (
    restaurant_id, user_id, business_license, cuisine_type, opening_hours,
    commission_rate, hub_id, is_approved, is_open, min_order_amount
) VALUES (
    1, 3, 'DEMO-LICENSE-1', 'Vietnamese', '06:00 - 21:00',
    15.00, 1, 1, 1, 30000.00
);

INSERT INTO restaurant (
    restaurant_id, user_id, business_license, cuisine_type, opening_hours,
    commission_rate, hub_id, is_approved, is_open, min_order_amount
) VALUES (
    2, 5, 'DEMO-LICENSE-2', 'Japanese', '10:00 - 22:00',
    12.50, 1, 1, 1, 0.00
);

INSERT INTO driver (
    driver_id, user_id, driver_license, vehicle_type, plate_number,
    current_location, status, hub_id
) VALUES (
    1, 4, 'DEMO-DRIVER-1', 'Motorbike', 'DEMO-01',
    '10.8012, 106.7114', 'ONLINE', 1
);

INSERT INTO menu_item (menu_item_id, restaurant_id, name, description, price, category, is_available) VALUES
(1, 1, 'Grilled Pork Rice', 'Demo menu item', 45000.00, 'Main Dish', 1),
(2, 1, 'Iced Jasmine Tea', 'Demo beverage', 10000.00, 'Beverage', 1),
(3, 2, 'Demo Ramen', 'Restaurant B test item', 55000.00, 'Main Dish', 1);

SET @app_user_id = 2;

INSERT INTO `order` (
    order_id, customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 1, 0.00, 15000.00, 'MOMO',
    'Demo delivery address, Binh Thanh, HCMC'
);

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) VALUES
(1, 1, 2, 0.00, ''),
(1, 2, 1, 0.00, '');

SET @app_user_id = 3;

UPDATE `order`
SET status = 'CONFIRMED', driver_id = 1
WHERE order_id = 1;

UPDATE `order` SET status = 'PREPARING' WHERE order_id = 1;
UPDATE `order` SET status = 'READY' WHERE order_id = 1;

SET @app_user_id = 4;
UPDATE `order` SET status = 'PICKED_UP' WHERE order_id = 1;
UPDATE `order` SET status = 'DELIVERING' WHERE order_id = 1;
UPDATE `order` SET status = 'COMPLETED' WHERE order_id = 1;

SET @app_user_id = 2;

INSERT INTO payment (
    order_id, amount, payment_method, status, provider,
    provider_transaction_id, paid_at
) VALUES (
    1, 115000.00, 'MOMO', 'SUCCESS', 'DemoGateway',
    'DEMO-TXN-0001', CURRENT_TIMESTAMP
);

INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
VALUES (1, 2, 'Restaurant', 5, 'Demo review');

COMMIT;
