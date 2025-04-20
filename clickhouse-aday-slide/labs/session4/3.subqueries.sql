# Subquery Basics

-- Subquery in WHERE clause
SELECT *
FROM attachments
WHERE payment_amount > (
    SELECT avg(payment_amount) FROM attachments
) limit 100;

-- Subquery in FROM clause
SELECT currency, avg_amount
FROM (
    SELECT payment_currency AS currency, avg(payment_amount) AS avg_amount
    FROM attachments
    GROUP BY payment_currency
) AS currency_avgs;

-- Subquery in SELECT clause
SELECT 
    payment_currency,
    payment_amount,
    payment_amount / (SELECT avg(payment_amount) FROM attachments) AS relative_to_avg
FROM attachments limit 100;


## Correlated Subqueries
-- Find payments above average for their currency
SELECT 
    p1.payment_currency,
    p1.payment_amount
FROM attachments p1
JOIN (
    SELECT 
        payment_currency,
        avg(payment_amount) as avg_amount
    FROM attachments 
    GROUP BY payment_currency
) p2 ON p1.payment_currency = p2.payment_currency
WHERE p1.payment_amount > p2.avg_amount
ORDER BY p1.payment_currency, p1.payment_amount DESC
LIMIT 100;


## Subqueries with EXISTS
-- Find users who have made payments
SELECT DISTINCT
    u.user_id,
    u.username
FROM users u
JOIN messages m ON m.user_id = u.user_id
JOIN attachments p ON m.message_id = p.message_id
ORDER BY u.user_id;



-- Insert messages with proper UUIDs
INSERT INTO chat_payments.messages 
(message_id, chat_id, user_id, sent_timestamp, message_type, content, sign) 
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 201, 1001, now(), 'invoice', 'Large Invoice #1 - $1500',1),
    ('550e8400-e29b-41d4-a716-446655440002', 201, 1001, now(), 'invoice', 'Small Invoice #2 - $500',1),
    ('550e8400-e29b-41d4-a716-446655440003', 202, 1002, now(), 'invoice', 'Large Invoice #3 - $2000',1),
    ('550e8400-e29b-41d4-a716-446655440004', 202, 1002, now(), 'invoice', 'Large Invoice #4 - $3000',1),
    ('550e8400-e29b-41d4-a716-446655440005', 203, 1003, now(), 'invoice', 'Large Invoice #5 - $2500',1);

-- Then insert corresponding attachments with matching UUIDs
INSERT INTO chat_payments.attachments 
(attachment_id, message_id, payment_amount, payment_currency, payment_status, uploaded_at, sign) 
VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 1500.00, 'USD', 'paid', now(),1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 500.00, 'USD', 'paid', now(),1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440003', 2000.00, 'USD', 'paid', now(),1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440004', 3000.00, 'USD', 'pending', now(),1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440005', 2500.00, 'USD', 'paid', now(),1);

SELECT 
    message_id,
    content
FROM messages
WHERE message_id IN (
    SELECT message_id
    FROM attachments
    WHERE payment_status = 'paid'
    AND payment_amount > 1000
);


## Subqueries with ANY/ALL
-- Find payments greater than ANY USD payment
SELECT 
    payment_currency,
    payment_amount
FROM attachments
WHERE payment_amount > ANY (
    SELECT payment_amount
    FROM attachments
    WHERE payment_currency = 'USD'
) LIMIT 100;



## Top Paying Users by Currency
-- Find top 3 users by total payment for each currency
SELECT 
    currency_ranking.payment_currency,
    currency_ranking.user_id,
    currency_ranking.username,
    currency_ranking.total_amount
FROM (
    SELECT 
        p.payment_currency,
        u.user_id as user_id,
        u.username,
        sum(p.payment_amount) AS total_amount,
        row_number() OVER (
            PARTITION BY p.payment_currency 
            ORDER BY sum(p.payment_amount) DESC
        ) AS currency_rank
    FROM attachments p
    JOIN messages m ON p.message_id = m.message_id
    JOIN users u ON m.user_id = u.user_id
    WHERE p.payment_status = 'paid'
    GROUP BY p.payment_currency, u.user_id, u.username
) AS currency_ranking
WHERE currency_ranking.currency_rank <= 3
ORDER BY currency_ranking.payment_currency, currency_ranking.currency_rank;