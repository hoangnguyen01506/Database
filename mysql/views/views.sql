USE food_delivery_db;

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.order_date,
    o.status,
    o.total_amount,
    o.delivery_fee,
    c.customer_id,
    cu.name AS customer_name,
    r.restaurant_id,
    ru.name AS restaurant_name,
    o.driver_id
FROM `order` AS o
JOIN customer AS c ON c.customer_id = o.customer_id
JOIN `user` AS cu ON cu.user_id = c.user_id
JOIN restaurant AS r ON r.restaurant_id = o.restaurant_id
JOIN `user` AS ru ON ru.user_id = r.user_id;

CREATE OR REPLACE VIEW vw_restaurant_sales AS
SELECT
    r.restaurant_id,
    ru.name AS restaurant_name,
    COUNT(o.order_id) AS total_orders,
    SUM(CASE WHEN o.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
    COALESCE(SUM(
        CASE WHEN o.status = 'COMPLETED' THEN o.total_amount ELSE 0 END
    ), 0.00) AS completed_gmv,
    COALESCE(SUM(
        CASE
            WHEN o.status = 'COMPLETED' THEN o.total_amount - o.delivery_fee
            ELSE 0
        END
    ), 0.00) AS gross_food_revenue,
    COALESCE(SUM(
        CASE
            WHEN o.status = 'COMPLETED'
                THEN (o.total_amount - o.delivery_fee) * (1 - COALESCE(r.commission_rate, 0) / 100)
            ELSE 0
        END
    ), 0.00) AS net_restaurant_payout
FROM restaurant AS r
JOIN `user` AS ru ON ru.user_id = r.user_id
LEFT JOIN `order` AS o ON o.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, ru.name;

CREATE OR REPLACE VIEW vw_driver_performance AS
SELECT
    d.driver_id,
    u.name AS driver_name,
    d.status AS current_status,
    h.name AS hub_name,
    COALESCE(orders.completed_orders, 0) AS completed_orders,
    COALESCE(orders.cancelled_orders, 0) AS cancelled_orders,
    COALESCE(shifts.total_shifts, 0) AS total_shifts,
    COALESCE(shifts.completed_shift_orders, 0) AS completed_shift_orders,
    COALESCE(shifts.total_bonus, 0.00) AS total_bonus,
    ratings.average_rating
FROM driver AS d
JOIN `user` AS u ON u.user_id = d.user_id
LEFT JOIN hub AS h ON h.hub_id = d.hub_id
LEFT JOIN (
    SELECT
        driver_id,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders
    FROM `order`
    WHERE driver_id IS NOT NULL
    GROUP BY driver_id
) AS orders ON orders.driver_id = d.driver_id
LEFT JOIN (
    SELECT
        driver_id,
        COUNT(*) AS total_shifts,
        SUM(COALESCE(completed_orders, 0)) AS completed_shift_orders,
        SUM(bonus_earned) AS total_bonus
    FROM shift
    GROUP BY driver_id
) AS shifts ON shifts.driver_id = d.driver_id
LEFT JOIN (
    SELECT o.driver_id, AVG(rv.rating) AS average_rating
    FROM review AS rv
    JOIN `order` AS o ON o.order_id = rv.order_id
    WHERE rv.target_type = 'Driver' AND o.driver_id IS NOT NULL
    GROUP BY o.driver_id
) AS ratings ON ratings.driver_id = d.driver_id;
