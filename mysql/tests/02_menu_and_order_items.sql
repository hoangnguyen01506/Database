USE food_delivery_db;

START TRANSACTION;
SET @app_user_id = 2;

CALL assert_statement_rejected(
    'INSERT INTO menu_item (restaurant_id, name, price) VALUES (1, ''Negative price'', -1)',
    'negative menu price'
);

INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 0.00, 0.00, 'CASH', 'Temporary item test'
);
SET @test_order_id = LAST_INSERT_ID();

CALL assert_statement_rejected(
    CONCAT(
        'INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) VALUES (',
        @test_order_id, ', 1, 0, 0, '''')'
    ),
    'zero item quantity'
);

CALL assert_statement_rejected(
    CONCAT(
        'INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name) VALUES (',
        @test_order_id, ', 3, 1, 0, '''')'
    ),
    'menu item belongs to a different restaurant'
);

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
VALUES (@test_order_id, 1, 1, 0.00, '');

CALL assert_decimal_query_equals(
    CONCAT('SELECT total_amount FROM `order` WHERE order_id = ', @test_order_id),
    45000.00,
    'order total calculated from item snapshot and delivery fee'
);

ROLLBACK;
