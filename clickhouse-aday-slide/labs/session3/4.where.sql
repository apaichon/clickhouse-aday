SELECT * FROM attachments 
WHERE payment_status = 'paid'
  AND payment_amount > 500
  AND uploaded_at >= '2023-04-01'
  limit 100;
 

-- Using date functions in filters
SELECT 
    attachment_id,
    payment_amount,
    payment_currency,
    payment_status,
    uploaded_at
FROM attachments
WHERE toYYYYMM(uploaded_at) = 202304
  AND payment_currency = 'USD'
  limit 100;

SELECT * FROM messages
WHERE message_type IN ('invoice', 'receipt')
  AND sent_timestamp BETWEEN 
    '2025-04-01 00:00:00' AND '2025-04-30 23:59:59';

-- String pattern matching
SELECT * FROM messages
WHERE content LIKE '%invoice%'
  OR content LIKE '%payment%';

-- Using functions in filters
SELECT * FROM attachments
WHERE formatDateTime(uploaded_at, '%Y-%m-%d') = '2023-04-15'
  AND (payment_status = 'pending' 
       OR payment_status = 'paid')
       limit 100;

INSERT INTO chat_payments.messages VALUES
    (generateUUIDv4(), 100, 1001, now(), 'invoice', 'April 2024 Invoice', 1, 1),
    (generateUUIDv4(), 100, 1002, now(), 'text', 'Thank you for the invoice', 0, 1),
    (generateUUIDv4(), 101, 1003, now(), 'receipt', 'Payment Receipt #123', 1, 1),
    (generateUUIDv4(), 101, 1004, now(), 'text', 'Payment processed', 0, 1);


-- Finding large payments
SELECT * FROM attachments
WHERE payment_amount > 1000
  AND payment_status = 'pending'
ORDER BY payment_amount DESC limit 100;

-- Time-based filtering with chat context
SELECT m.*, p.payment_amount, p.payment_currency
FROM messages m
LEFT JOIN attachments p ON m.message_id = p.message_id
WHERE m.chat_id = 100
  AND toDate(m.sent_timestamp) = today()
   limit 100;

-- Finding specific file types
SELECT *
FROM attachments
WHERE file_path LIKE '%.pdf'
  AND file_size > 100000
  AND payment_status != 'canceled'
ORDER BY file_size DESC limit 100;