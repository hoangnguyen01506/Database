USE food_delivery_db;

-- Run this fixture with a database administrator account, not an API role account.
-- Local coursework fixture only; the API currently compares this plaintext demo password.
SET @demo_password = '123456';

START TRANSACTION;

INSERT INTO `user` (user_id, name, phone, email, password, role, address) VALUES
(1, 'Demo Admin', '0900000001', 'admin@example.test', @demo_password, 'Admin', 'District 1, HCMC'),
(2, 'Demo Customer', '0900000002', 'customer@example.test', @demo_password, 'Customer', 'Binh Thanh, HCMC'),
(3, 'Demo Restaurant', '0900000003', 'restaurant@example.test', @demo_password, 'Restaurant', 'Binh Thanh, HCMC'),
(4, 'Demo Driver', '0900000004', 'driver@example.test', @demo_password, 'Driver', 'Binh Thanh, HCMC'),
(5, 'Demo Restaurant B', '0900000005', 'restaurant-b@example.test', @demo_password, 'Restaurant', 'District 1, HCMC');

INSERT INTO hub (hub_id, name, location, manager_id, operating_area)
VALUES (1, 'Binh Thanh Demo Hub', 'Binh Thanh, HCMC', 1, 'Binh Thanh');

INSERT INTO customer (customer_id, user_id, loyalty_points, total_orders, preferred_payment)
VALUES (1, 2, 0, 0, 'MOMO');

INSERT INTO restaurant (
    restaurant_id, user_id, restaurant_name, business_license, cuisine_type, opening_hours,
    commission_rate, hub_id, is_approved, is_open, min_order_amount
) VALUES (
    1, 3, 'Bếp Nhà Demo', 'DEMO-LICENSE-1', 'Vietnamese', '06:00 - 21:00',
    15.00, 1, 1, 1, 30000.00
);

INSERT INTO restaurant (
    restaurant_id, user_id, restaurant_name, business_license, cuisine_type, opening_hours,
    commission_rate, hub_id, is_approved, is_open, min_order_amount
) VALUES (
    2, 5, 'Sushi Demo', 'DEMO-LICENSE-2', 'Japanese', '10:00 - 22:00',
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

-- @app_user_id records the application actor for trigger validation and audit.
-- The API separately activates that actor's MySQL role on each request.
SET @app_user_id = 2;

INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 0.00, 15000.00, 'MOMO',
    'Demo delivery address, Binh Thanh, HCMC'
);
SET @sample_order_id = LAST_INSERT_ID();

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) VALUES
(@sample_order_id, 1, 2, 0.00, ''),
(@sample_order_id, 2, 1, 0.00, '');

SET @app_user_id = 3;

UPDATE `order`
SET status = 'CONFIRMED'
WHERE order_id = @sample_order_id;

UPDATE `order` SET status = 'PREPARING' WHERE order_id = @sample_order_id;
UPDATE `order` SET status = 'READY' WHERE order_id = @sample_order_id;

SET @app_user_id = 4;
UPDATE `order`
SET driver_id = 1
WHERE order_id = @sample_order_id;

UPDATE `order` SET status = 'PICKED_UP' WHERE order_id = @sample_order_id;
UPDATE `order` SET status = 'DELIVERING' WHERE order_id = @sample_order_id;
UPDATE `order` SET status = 'COMPLETED' WHERE order_id = @sample_order_id;

SET @app_user_id = 2;

INSERT INTO payment (
    order_id, amount, payment_method, status, provider,
    provider_transaction_id, paid_at
) VALUES (
    @sample_order_id, 115000.00, 'MOMO', 'SUCCESS', 'DemoGateway',
    'DEMO-TXN-0001', CURRENT_TIMESTAMP
);

INSERT INTO review (order_id, reviewer_id, target_type, rating, comment)
VALUES (@sample_order_id, 2, 'Restaurant', 5, 'Demo review');

COMMIT;
