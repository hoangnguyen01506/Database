USE food_delivery_db;

START TRANSACTION;
SET @app_user_id = 2;

INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 0.00, 0.00, 'CASH', 'Temporary lifecycle test'
);
SET @test_order_id = LAST_INSERT_ID();

UPDATE driver SET status = 'OFFLINE' WHERE driver_id = 1;

CALL assert_statement_rejected(
    CONCAT('UPDATE `order` SET status = ''CONFIRMED'' WHERE order_id = ', @test_order_id),
    'confirm order without items'
);

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
VALUES (@test_order_id, 2, 1, 0.00, '');

CALL assert_decimal_query_equals(
    CONCAT('SELECT total_amount FROM `order` WHERE order_id = ', @test_order_id),
    10000.00,
    'order total calculated from its items'
);

UPDATE `order` SET total_amount = 1.00 WHERE order_id = @test_order_id;

CALL assert_decimal_query_equals(
    CONCAT('SELECT total_amount FROM `order` WHERE order_id = ', @test_order_id),
    10000.00,
    'client cannot override calculated order total'
);

CALL assert_statement_rejected(
    CONCAT('UPDATE `order` SET status = ''CONFIRMED'' WHERE order_id = ', @test_order_id),
    'order below restaurant minimum'
);

INSERT INTO order_item (order_id, menu_item_id, quantity, price, item_name)
VALUES (@test_order_id, 1, 1, 0.00, '');

CALL assert_statement_rejected(
    CONCAT('UPDATE `order` SET driver_id = 1 WHERE order_id = ', @test_order_id),
    'assign driver while offline'
);

UPDATE `order` SET status = 'CONFIRMED' WHERE order_id = @test_order_id;

CALL assert_statement_rejected(
    CONCAT('UPDATE `order` SET status = ''COMPLETED'' WHERE order_id = ', @test_order_id),
    'skip order lifecycle states'
);

CALL assert_statement_rejected(
    CONCAT('UPDATE order_item SET quantity = 2 WHERE order_id = ', @test_order_id),
    'change item after confirmation'
);

ROLLBACK;
