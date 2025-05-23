-- =============================================
-- 1. Payment Trends by Currency
-- =============================================

-- Monthly payment trends by currency
SELECT 
    toStartOfMonth(uploaded_at) AS month,
    payment_currency,
    count() AS payment_count,
    sum(payment_amount) AS monthly_total,
    round(avg(payment_amount), 2) AS average_payment
FROM attachments
GROUP BY month, payment_currency
ORDER BY month DESC, payment_currency;

-- =============================================
-- 2. User Payment Statistics
-- =============================================

-- Insert messages with known UUIDs for user payment statistics
INSERT INTO chat_payments.messages VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 100, 1001, now(), 'invoice', 'March Invoice', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440001', 100, 1002, now(), 'receipt', 'Payment Receipt', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440002', 101, 1003, now(), 'invoice', 'April Invoice', 1, 1);

-- Insert attachments with matching message_ids
INSERT INTO chat_payments.attachments VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440000', 1250.00, 'USD', '2023-04-01', 'paid', '/storage/invoices/inv_12345.pdf', 128000, now(), 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 750.50, 'EUR', '2023-04-05', 'paid', '/storage/receipts/rec_75421.pdf', 98500, now(), 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 500.25, 'GBP', '2023-04-10', 'pending', '/storage/invoices/inv_33456.pdf', 115200, now(), 1);

-- User payment statistics query
SELECT 
    m.user_id,
    uniq(m.chat_id) AS active_chats,
    count(p.attachment_id) AS payment_count,
    sum(p.payment_amount) AS total_amount,
    max(p.payment_amount) AS largest_payment,
    min(p.uploaded_at) AS first_payment,
    max(p.uploaded_at) AS last_payment
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
GROUP BY m.user_id
HAVING payment_count > 0
ORDER BY total_amount DESC;

-- =============================================
-- 3. Status Distribution by Month
-- =============================================

SELECT 
    toStartOfMonth(uploaded_at) AS month,
    payment_status,
    count() AS count,
    round(count() / sum(count()) OVER (PARTITION BY month) * 100, 2) AS percentage
FROM attachments
GROUP BY month, payment_status
ORDER BY month DESC, payment_status;

-- =============================================
-- 4. Find Large Payments for Review
-- =============================================

-- Insert messages for large payment review
INSERT INTO chat_payments.messages VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 201, 3001, now(), 'invoice', 'Large Invoice #1', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440001', 202, 3002, now(), 'invoice', 'Large Invoice #2', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440002', 203, 3003, now(), 'invoice', 'Large Invoice #3', 1, 1);

-- Insert matching attachments with payment_amount > 5000 and status = 'pending'
INSERT INTO chat_payments.attachments VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440000', 15000.00, 'USD', '2024-03-01', 'pending', '/storage/invoices/large_inv_001.pdf', 256000, now(), 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 8500.50, 'EUR', '2024-03-05', 'pending', '/storage/invoices/large_inv_002.pdf', 198500, now(), 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 7250.75, 'USD', '2024-03-10', 'pending', '/storage/invoices/large_inv_003.pdf', 215200, now(), 1);

-- Query: Find large payments for review
SELECT 
    p.attachment_id,
    m.chat_id,
    m.user_id,
    p.payment_amount,
    p.payment_currency,
    p.payment_status,
    p.uploaded_at,
    p.file_path
FROM attachments p
JOIN messages m ON p.message_id = m.message_id
WHERE p.payment_amount > 5000
  AND p.payment_status = 'pending'
ORDER BY p.payment_amount DESC;

-- =============================================
-- 5. Query Log Analysis (System Table)
-- =============================================

SELECT 
    query_id,
    query,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%attachments%'
  AND event_time > now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC
LIMIT 10;

-- =============================================
-- 6. Find Payments > 1000 Pending
-- =============================================

SELECT 
    p.attachment_id,
    m.chat_id,
    m.user_id,
    p.payment_amount,
    p.payment_currency,
    p.payment_status,
    p.uploaded_at,
    p.file_path
FROM attachments p
JOIN messages m ON p.message_id = m.message_id
WHERE p.payment_amount > 1000
  AND p.payment_status = 'pending'
ORDER BY p.payment_amount DESC 



