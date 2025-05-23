-- =============================================
-- Attachments: Sorting and Limiting
-- =============================================

-- 1. Simple sorting: Top 10 paid attachments by amount
SELECT * FROM attachments
WHERE payment_status = 'paid'
ORDER BY payment_amount DESC
LIMIT 10;

-- 2. Order amounts by currency
SELECT * FROM attachments
ORDER BY payment_currency ASC, 
         payment_amount DESC
LIMIT 100;

-- 3. Sorting with expressions: Top 100 by payment amount
SELECT 
    attachment_id,
    payment_amount,
    payment_currency,
    payment_status
FROM attachments
ORDER BY payment_amount DESC
LIMIT 100;

-- 4. Find top 10 largest payments (duplicate query, kept for clarity)
SELECT * FROM attachments
ORDER BY payment_amount DESC
LIMIT 10;

-- 5. Get 10 random payments for review
SELECT *
FROM attachments
ORDER BY rand()
LIMIT 10;

-- 6. Largest payments by currency
SELECT 
    payment_currency,
    max(payment_amount) AS max_amount,
    sum(payment_amount) AS total
FROM attachments
GROUP BY payment_currency
ORDER BY total DESC;

-- =============================================
-- Messages: Sorting and Limiting
-- =============================================

-- 7. Multi-column sorting: Recent messages per chat
SELECT 
    message_id, user_id, sent_timestamp, message_type
FROM messages
ORDER BY chat_id ASC, 
         sent_timestamp DESC
LIMIT 20;

-- 8. Invoices: Most recent first
SELECT 
    message_id, 
    chat_id,
    sent_timestamp
FROM messages
WHERE message_type = 'invoice'
ORDER BY sent_timestamp DESC
LIMIT 100;