USE food_delivery_db;

START TRANSACTION;

CALL assert_statement_rejected(
    'INSERT INTO `user` (name, phone, password, role) VALUES (''Duplicate phone'', ''0900000002'', ''demo'', ''Customer'')',
    'duplicate phone'
);

CALL assert_statement_rejected(
    'INSERT INTO `user` (name, phone, email, password, role) VALUES (''Duplicate email'', ''0900000099'', ''customer@example.test'', ''demo'', ''Customer'')',
    'duplicate email'
);

CALL assert_statement_rejected(
    'INSERT INTO driver (user_id, driver_license) VALUES (2, ''duplicate-role'')',
    'specialized role mismatch'
);

CALL assert_statement_rejected(
    'UPDATE `user` SET role = ''Admin'' WHERE user_id = 2',
    'change role with an existing specialized account'
);

CALL assert_statement_rejected(
    'INSERT INTO address (user_id, recipient_name, recipient_phone, address_line) VALUES (999999, ''Unknown'', ''0900000000'', ''Unknown street'')',
    'missing user foreign key'
);

ROLLBACK;
