CREATE USER 'food_delivery_customer'@'127.0.0.1' IDENTIFIED BY 'your-password';
GRANT 'role_customer' TO 'food_delivery_customer'@'127.0.0.1';
SET DEFAULT ROLE NONE TO 'food_delivery_customer'@'127.0.0.1';

CREATE USER 'food_delivery_restaurant'@'127.0.0.1' IDENTIFIED BY 'your-password';
GRANT 'role_restaurant' TO 'food_delivery_restaurant'@'127.0.0.1';
SET DEFAULT ROLE NONE TO 'food_delivery_restaurant'@'127.0.0.1';

CREATE USER 'food_delivery_driver'@'127.0.0.1' IDENTIFIED BY 'your-password';
GRANT 'role_driver' TO 'food_delivery_driver'@'127.0.0.1';
SET DEFAULT ROLE NONE TO 'food_delivery_driver'@'127.0.0.1';

CREATE USER 'food_delivery_admin'@'127.0.0.1' IDENTIFIED BY 'your-password';
GRANT 'role_admin' TO 'food_delivery_admin'@'127.0.0.1';
SET DEFAULT ROLE NONE TO 'food_delivery_admin'@'127.0.0.1';
