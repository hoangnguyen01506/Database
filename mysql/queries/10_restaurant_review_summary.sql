USE food_delivery_db;

-- Truy vấn 10: Số lượng và điểm đánh giá trung bình của từng nhà hàng.
-- LEFT JOIN giữ cả nhà hàng chưa có đánh giá.
-- COUNT(review_id) không đếm dòng NULL do LEFT JOIN tạo ra.
SELECT r.restaurant_id, u.name AS restaurant_name,
       COUNT(rv.review_id) AS review_count,
       ROUND(AVG(rv.rating), 2) AS average_rating
FROM restaurant r
JOIN `user` u       ON u.user_id = r.user_id
LEFT JOIN `order` o ON o.restaurant_id = r.restaurant_id
LEFT JOIN review rv ON rv.order_id = o.order_id AND rv.target_type = 'Restaurant'
GROUP BY r.restaurant_id, u.name
ORDER BY average_rating DESC;
