USE food_delivery_db;

CREATE ROLE IF NOT EXISTS
    'role_customer',
    'role_restaurant',
    'role_driver',
    'role_reporting',
    'role_admin';

GRANT SELECT ON food_delivery_db.restaurant TO 'role_customer';
GRANT SELECT ON food_delivery_db.menu_item TO 'role_customer';
GRANT SELECT ON food_delivery_db.`order` TO 'role_customer';
GRANT SELECT ON food_delivery_db.order_item TO 'role_customer';
GRANT SELECT ON food_delivery_db.payment TO 'role_customer';
GRANT SELECT ON food_delivery_db.notification TO 'role_customer';
GRANT INSERT ON food_delivery_db.`order` TO 'role_customer';
GRANT INSERT ON food_delivery_db.order_item TO 'role_customer';
GRANT INSERT ON food_delivery_db.payment TO 'role_customer';
GRANT SELECT, INSERT ON food_delivery_db.review TO 'role_customer';
GRANT SELECT ON food_delivery_db.address TO 'role_customer';
GRANT SELECT (user_id, name, email, password, role, address)
    ON food_delivery_db.`user` TO 'role_customer';
GRANT SELECT (customer_id, user_id)
    ON food_delivery_db.customer TO 'role_customer';

GRANT SELECT, INSERT, UPDATE, DELETE
    ON food_delivery_db.menu_item TO 'role_restaurant';
GRANT SELECT ON food_delivery_db.restaurant TO 'role_restaurant';
GRANT SELECT ON food_delivery_db.`order` TO 'role_restaurant';
GRANT SELECT ON food_delivery_db.order_item TO 'role_restaurant';
GRANT SELECT ON food_delivery_db.review TO 'role_restaurant';
GRANT UPDATE (status, driver_id) ON food_delivery_db.`order` TO 'role_restaurant';
GRANT SELECT (user_id, name, email, password, role)
    ON food_delivery_db.`user` TO 'role_restaurant';

GRANT SELECT ON food_delivery_db.`order` TO 'role_driver';
GRANT SELECT ON food_delivery_db.order_item TO 'role_driver';
GRANT SELECT ON food_delivery_db.address TO 'role_driver';
GRANT SELECT ON food_delivery_db.shift TO 'role_driver';
GRANT SELECT (driver_id, user_id, status)
    ON food_delivery_db.driver TO 'role_driver';
GRANT UPDATE (status) ON food_delivery_db.driver TO 'role_driver';
GRANT SELECT (user_id, name, email, password, role)
    ON food_delivery_db.`user` TO 'role_driver';
GRANT UPDATE (status, driver_id) ON food_delivery_db.`order` TO 'role_driver';

GRANT SELECT ON food_delivery_db.vw_order_summary TO 'role_reporting';
GRANT SELECT ON food_delivery_db.vw_restaurant_sales TO 'role_reporting';
GRANT SELECT ON food_delivery_db.vw_driver_performance TO 'role_reporting';

GRANT ALL PRIVILEGES ON food_delivery_db.* TO 'role_admin';
