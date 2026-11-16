USE food_delivery_db;

-- Completed GMV includes delivery fees; food revenue and payout exclude them.
SELECT
    restaurant_id,
    restaurant_name,
    total_orders,
    completed_orders,
    completed_gmv,
    gross_food_revenue,
    net_restaurant_payout
FROM vw_restaurant_sales
ORDER BY completed_gmv DESC;

-- Restaurants with average completed-order value above the platform average.
SELECT
    r.restaurant_id,
    r.restaurant_name,
    ROUND(AVG(o.total_amount), 2) AS average_order_value
FROM restaurant AS r
JOIN `order` AS o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'COMPLETED'
GROUP BY r.restaurant_id, r.restaurant_name
HAVING AVG(o.total_amount) > (
    SELECT AVG(total_amount)
    FROM `order`
    WHERE status = 'COMPLETED'
);

-- Restaurant review summary.
SELECT
    r.restaurant_id,
    r.restaurant_name,
    COUNT(rv.review_id) AS review_count,
    ROUND(AVG(rv.rating), 2) AS average_rating
FROM restaurant AS r
LEFT JOIN `order` AS o ON o.restaurant_id = r.restaurant_id
LEFT JOIN review AS rv
    ON rv.order_id = o.order_id AND rv.target_type = 'Restaurant'
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY average_rating DESC;
