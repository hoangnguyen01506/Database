USE food_delivery_db;

START TRANSACTION;
SET @app_user_id = 2;

INSERT INTO `order` (
    customer_id, restaurant_id, total_amount, delivery_fee,
    payment_method, delivery_address_snapshot
) VALUES (
    1, 1, 0.00, 0.00, 'CASH', 'Temporary review test'
);
SET @test_order_id = LAST_INSERT_ID();

CALL assert_statement_rejected(
    CONCAT(
        'INSERT INTO review (order_id, reviewer_id, target_type, rating) VALUES (',
        @test_order_id, ', 2, ''Restaurant'', 5)'
    ),
    'review before completion'
);

CALL assert_statement_rejected(
    'INSERT INTO review (order_id, reviewer_id, target_type, rating) VALUES (1, 2, ''Driver'', 6)',
    'rating outside 1-5'
);

CALL assert_statement_rejected(
    'INSERT INTO review (order_id, reviewer_id, target_type, rating) VALUES (1, 2, ''Restaurant'', NULL)',
    'rating is required'
);

CALL assert_statement_rejected(
    'INSERT INTO payment (order_id, amount, payment_method) VALUES (1, 0, ''CASH'')',
    'payment amount must be positive'
);

CALL assert_statement_rejected(
    'INSERT INTO review (order_id, reviewer_id, target_type, rating) VALUES (1, 2, ''Restaurant'', 4)',
    'duplicate review target for an order'
);

CALL assert_statement_rejected(
    'INSERT INTO review (order_id, reviewer_id, target_type, rating) VALUES (1, 1, ''Restaurant'', 5)',
    'reviewer is not the ordering customer'
);

CALL assert_statement_rejected(
    CONCAT(
        'UPDATE audit_log SET new_status = ''CANCELLED'' WHERE order_id = ',
        @test_order_id
    ),
    'modify immutable audit log'
);

CALL assert_statement_rejected(
    CONCAT('DELETE FROM audit_log WHERE order_id = ', @test_order_id),
    'delete immutable audit log'
);

ROLLBACK;
