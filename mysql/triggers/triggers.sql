USE food_delivery_db;

DELIMITER $$

CREATE TRIGGER trg_customer_role_insert
BEFORE INSERT ON customer
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Customer')
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer must use a Customer account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_customer_role_update
BEFORE UPDATE ON customer
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Customer')
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer must use a Customer account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_restaurant_role_insert
BEFORE INSERT ON restaurant
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Restaurant')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Restaurant must use a Restaurant account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_restaurant_role_update
BEFORE UPDATE ON restaurant
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Restaurant')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM driver WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Restaurant must use a Restaurant account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_driver_role_insert
BEFORE INSERT ON driver
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Driver')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver must use a Driver account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_driver_role_update
BEFORE UPDATE ON driver
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);

    SELECT role INTO v_role
    FROM `user`
    WHERE user_id = NEW.user_id
    FOR UPDATE;

    IF NOT (v_role <=> 'Driver')
       OR EXISTS (SELECT 1 FROM customer WHERE user_id = NEW.user_id)
       OR EXISTS (SELECT 1 FROM restaurant WHERE user_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver must use a Driver account with no other specialized role';
    END IF;
END$$

CREATE TRIGGER trg_user_role_update
BEFORE UPDATE ON `user`
FOR EACH ROW
BEGIN
    IF NEW.role <> OLD.role AND (
        (EXISTS (SELECT 1 FROM customer WHERE user_id = OLD.user_id)
            AND NEW.role <> 'Customer')
        OR (EXISTS (SELECT 1 FROM restaurant WHERE user_id = OLD.user_id)
            AND NEW.role <> 'Restaurant')
        OR (EXISTS (SELECT 1 FROM driver WHERE user_id = OLD.user_id)
            AND NEW.role <> 'Driver')
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot change a user role while its specialized account exists';
    END IF;
END$$

CREATE TRIGGER trg_order_before_insert
BEFORE INSERT ON `order`
FOR EACH ROW
BEGIN
    DECLARE v_actor_exists INT DEFAULT 0;
    DECLARE v_customer_owns_order INT DEFAULT 0;

    IF NEW.status <> 'PENDING' OR NEW.driver_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'New orders must start PENDING and unassigned';
    END IF;

    IF @app_user_id IS NULL OR @app_user_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Set @app_user_id to the authenticated user before creating an order';
    END IF;

    SELECT COUNT(*) INTO v_actor_exists
    FROM `user`
    WHERE user_id = @app_user_id;

    IF v_actor_exists <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The authenticated order actor does not exist';
    END IF;

    SELECT COUNT(*) INTO v_customer_owns_order
    FROM customer
    WHERE customer_id = NEW.customer_id
      AND user_id = @app_user_id;

    IF v_customer_owns_order <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only the customer placing the order can create it';
    END IF;

    SET NEW.total_amount = NEW.delivery_fee;
END$$

CREATE TRIGGER trg_order_before_update
BEFORE UPDATE ON `order`
FOR EACH ROW
BEGIN
    DECLARE v_actor_exists INT DEFAULT 0;
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_minimum DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_driver_status VARCHAR(10);

    IF NOT (NEW.customer_id <=> OLD.customer_id)
       OR NOT (NEW.restaurant_id <=> OLD.restaurant_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An order customer and restaurant cannot be changed';
    END IF;

    IF NOT (NEW.status <=> OLD.status) THEN
        IF @app_user_id IS NULL OR @app_user_id <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Set @app_user_id to the authenticated user before changing order status';
        END IF;

        SELECT COUNT(*) INTO v_actor_exists
        FROM `user`
        WHERE user_id = @app_user_id;

        IF v_actor_exists <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The authenticated order actor does not exist';
        END IF;

        IF (OLD.status = 'PENDING' AND NEW.status NOT IN ('CONFIRMED', 'CANCELLED'))
           OR (OLD.status = 'CONFIRMED' AND NEW.status NOT IN ('PREPARING', 'CANCELLED'))
           OR (OLD.status = 'PREPARING' AND NEW.status NOT IN ('READY', 'CANCELLED'))
           OR (OLD.status = 'READY' AND NEW.status NOT IN ('PICKED_UP', 'CANCELLED'))
           OR (OLD.status = 'PICKED_UP' AND NEW.status NOT IN ('DELIVERING', 'CANCELLED'))
           OR (OLD.status = 'DELIVERING' AND NEW.status NOT IN ('COMPLETED', 'CANCELLED'))
           OR OLD.status IN ('COMPLETED', 'CANCELLED') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invalid order status transition';
        END IF;

        IF NEW.status = 'CONFIRMED' THEN
            SELECT COALESCE(SUM(quantity * price), 0.00)
            INTO v_subtotal
            FROM order_item
            WHERE order_id = OLD.order_id;

            SELECT min_order_amount INTO v_minimum
            FROM restaurant
            WHERE restaurant_id = NEW.restaurant_id;

            IF NOT EXISTS (
                SELECT 1 FROM order_item WHERE order_id = NEW.order_id
            ) OR v_subtotal < v_minimum THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Order must contain items and meet the restaurant minimum';
            END IF;
        END IF;
    END IF;

    IF NOT (NEW.driver_id <=> OLD.driver_id) THEN
        IF @app_user_id IS NULL OR @app_user_id <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Set @app_user_id before assigning or releasing a driver';
        END IF;

        IF NEW.status IN ('COMPLETED', 'CANCELLED') AND NEW.driver_id IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A driver cannot be assigned to a terminal order';
        END IF;

        IF NEW.driver_id IS NOT NULL THEN
            SELECT status INTO v_driver_status
            FROM driver
            WHERE driver_id = NEW.driver_id
            FOR UPDATE;

            IF v_driver_status <> 'ONLINE' THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Only an ONLINE driver can be assigned';
            END IF;
        END IF;
    END IF;

    IF NOT (NEW.delivery_fee <=> OLD.delivery_fee) AND OLD.status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Delivery fee cannot change after an order is confirmed';
    END IF;

    SELECT COALESCE(SUM(quantity * price), 0.00)
    INTO v_subtotal
    FROM order_item
    WHERE order_id = OLD.order_id;

    SET NEW.total_amount = v_subtotal + NEW.delivery_fee;
END$$

CREATE TRIGGER trg_order_audit_after_insert
AFTER INSERT ON `order`
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (order_id, old_status, new_status, changed_by, changed_at)
    VALUES (NEW.order_id, NULL, NEW.status, @app_user_id, CURRENT_TIMESTAMP);
END$$

CREATE TRIGGER trg_order_audit_and_driver_after_update
AFTER UPDATE ON `order`
FOR EACH ROW
BEGIN
    IF NOT (NEW.status <=> OLD.status) THEN
        INSERT INTO audit_log (order_id, old_status, new_status, changed_by, changed_at)
        VALUES (NEW.order_id, OLD.status, NEW.status, @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    IF NOT (NEW.driver_id <=> OLD.driver_id) THEN
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE driver
            SET status = 'BUSY'
            WHERE driver_id = NEW.driver_id AND status = 'ONLINE';

            IF ROW_COUNT() <> 1 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Driver assignment lost its ONLINE status';
            END IF;
        END IF;

        IF OLD.driver_id IS NOT NULL THEN
            UPDATE driver AS d
            SET status = 'ONLINE'
            WHERE d.driver_id = OLD.driver_id
              AND NOT EXISTS (
                  SELECT 1
                  FROM `order` AS active_order
                  WHERE active_order.driver_id = OLD.driver_id
                    AND active_order.order_id <> NEW.order_id
                    AND active_order.status NOT IN ('COMPLETED', 'CANCELLED')
              );
        END IF;
    END IF;

    IF NEW.status IN ('COMPLETED', 'CANCELLED')
       AND OLD.status NOT IN ('COMPLETED', 'CANCELLED')
       AND NEW.driver_id IS NOT NULL THEN
        UPDATE driver AS d
        SET status = 'ONLINE'
        WHERE d.driver_id = NEW.driver_id
          AND NOT EXISTS (
              SELECT 1
              FROM `order` AS active_order
              WHERE active_order.driver_id = NEW.driver_id
                AND active_order.order_id <> NEW.order_id
                AND active_order.status NOT IN ('COMPLETED', 'CANCELLED')
          );
    END IF;
END$$

CREATE TRIGGER trg_order_item_before_insert
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_available TINYINT;
    DECLARE v_menu_restaurant INT;
    DECLARE v_order_restaurant INT;
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_name VARCHAR(100);
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_found TINYINT DEFAULT 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    SELECT mi.is_available, mi.restaurant_id, mi.name, mi.price,
           o.restaurant_id, o.status
    INTO v_available, v_menu_restaurant, v_name, v_price,
         v_order_restaurant, v_order_status
    FROM menu_item AS mi
    JOIN `order` AS o ON o.order_id = NEW.order_id
    WHERE mi.menu_item_id = NEW.menu_item_id;

    IF v_found = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order or menu item does not exist';
    END IF;

    IF v_order_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items can only be added to a PENDING order';
    END IF;

    IF v_available <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Menu item is unavailable';
    END IF;

    IF v_menu_restaurant <> v_order_restaurant THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Menu item belongs to a different restaurant';
    END IF;

    SET NEW.item_name = v_name;
    SET NEW.price = v_price;
END$$

CREATE TRIGGER trg_order_item_before_update
BEFORE UPDATE ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20);

    SELECT status INTO v_order_status
    FROM `order`
    WHERE order_id = OLD.order_id;

    IF v_order_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items cannot be changed after order confirmation';
    END IF;

    IF NEW.order_id <> OLD.order_id OR NEW.menu_item_id <> OLD.menu_item_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An order item cannot be moved or replaced';
    END IF;

    SET NEW.item_name = OLD.item_name;
    SET NEW.price = OLD.price;
END$$

CREATE TRIGGER trg_order_item_before_delete
BEFORE DELETE ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20);

    SELECT status INTO v_order_status
    FROM `order`
    WHERE order_id = OLD.order_id;

    IF v_order_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Items cannot be deleted after order confirmation';
    END IF;
END$$

CREATE TRIGGER trg_order_item_recalculate_after_insert
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = (
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = NEW.order_id
    ) + o.delivery_fee
    WHERE o.order_id = NEW.order_id;
END$$

CREATE TRIGGER trg_order_item_recalculate_after_update
AFTER UPDATE ON order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = (
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = NEW.order_id
    ) + o.delivery_fee
    WHERE o.order_id = NEW.order_id;
END$$

CREATE TRIGGER trg_order_item_recalculate_after_delete
AFTER DELETE ON order_item
FOR EACH ROW
BEGIN
    UPDATE `order` AS o
    SET total_amount = (
        SELECT COALESCE(SUM(oi.quantity * oi.price), 0.00)
        FROM order_item AS oi
        WHERE oi.order_id = OLD.order_id
    ) + o.delivery_fee
    WHERE o.order_id = OLD.order_id;
END$$

CREATE TRIGGER trg_review_before_insert
BEFORE INSERT ON review
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_customer_user_id INT;
    DECLARE v_driver_id INT;
    DECLARE v_found TINYINT DEFAULT 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    SELECT o.status, c.user_id, o.driver_id
    INTO v_order_status, v_customer_user_id, v_driver_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = NEW.order_id;

    IF v_found = 0 OR v_order_status <> 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviews require a completed order';
    END IF;

    IF v_customer_user_id <> NEW.reviewer_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviewer must be the customer who placed the order';
    END IF;

    IF NEW.target_type = 'Driver' AND v_driver_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot review a driver when none was assigned';
    END IF;
END$$

CREATE TRIGGER trg_review_before_update
BEFORE UPDATE ON review
FOR EACH ROW
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_customer_user_id INT;
    DECLARE v_driver_id INT;
    DECLARE v_found TINYINT DEFAULT 1;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = 0;

    SELECT o.status, c.user_id, o.driver_id
    INTO v_order_status, v_customer_user_id, v_driver_id
    FROM `order` AS o
    JOIN customer AS c ON c.customer_id = o.customer_id
    WHERE o.order_id = NEW.order_id;

    IF v_found = 0 OR v_order_status <> 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviews require a completed order';
    END IF;

    IF v_customer_user_id <> NEW.reviewer_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reviewer must be the customer who placed the order';
    END IF;

    IF NEW.target_type = 'Driver' AND v_driver_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot review a driver when none was assigned';
    END IF;
END$$

CREATE TRIGGER trg_audit_log_before_update
BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log records are immutable';
END$$

CREATE TRIGGER trg_audit_log_before_delete
BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log records cannot be deleted';
END$$

DELIMITER ;
