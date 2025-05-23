-- =============================================
-- Attachments: Basic Filtering
-- =============================================

-- 1. Paid attachments with amount > 500 after 2023-04-01
SELECT * FROM attachments 
WHERE payment_status = 'paid'
  AND payment_amount > 500
  AND uploaded_at >= '2023-04-01'
LIMIT 100;

-- 2. Attachments in April 2023, USD only
SELECT 
    attachment_id,
    payment_amount,
    payment_currency,
    payment_status,
    uploaded_at
FROM attachments
WHERE toYYYYMM(uploaded_at) = 202304
  AND payment_currency = 'USD'
LIMIT 100;

-- 3. Attachments on a specific day, pending or paid
SELECT * FROM attachments
WHERE formatDateTime(uploaded_at, '%Y-%m-%d') = '2023-04-15'
  AND (payment_status = 'pending' OR payment_status = 'paid')
LIMIT 100;

-- 4. Finding large pending payments
SELECT * FROM attachments
WHERE payment_amount > 1000
  AND payment_status = 'pending'
ORDER BY payment_amount DESC
LIMIT 100;

-- 5. Finding specific file types (large PDFs, not canceled)
SELECT *
FROM attachments
WHERE file_path LIKE '%.pdf'
  AND file_size > 100000
  AND payment_status != 'canceled'
ORDER BY file_size DESC
LIMIT 100;

-- =============================================
-- Messages: Filtering and Pattern Matching
-- =============================================

-- 6. Messages of type invoice or receipt in April 2025
SELECT * FROM messages
WHERE message_type IN ('invoice', 'receipt')
  AND sent_timestamp BETWEEN '2025-04-01 00:00:00' AND '2025-04-30 23:59:59';

-- 7. Messages with content containing 'invoice' or 'payment'
SELECT * FROM messages
WHERE content LIKE '%invoice%'
   OR content LIKE '%payment%';

-- =============================================
-- Messages and Attachments: Joins and Context
-- =============================================

-- 8. Time-based filtering with chat context (today's messages in chat 100)
SELECT m.*, p.payment_amount, p.payment_currency
FROM messages m
LEFT JOIN attachments p ON m.message_id = p.message_id
WHERE m.chat_id = 100
  AND toDate(m.sent_timestamp) = today()
LIMIT 100;
