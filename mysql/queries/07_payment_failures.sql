USE food_delivery_db;

-- Failed payment transactions.
SELECT
    p.payment_id, p.order_id, p.amount, p.payment_method,
    p.provider, p.provider_transaction_id, p.failure_reason, p.transaction_date
FROM payment AS p
WHERE p.status = 'FAILED'
ORDER BY p.transaction_date DESC;
