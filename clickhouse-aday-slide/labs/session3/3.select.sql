-- =============================================
-- Basic Selects
-- =============================================

-- 1. Select all columns, limit 5
SELECT *
FROM messages
LIMIT 5;

-- 2. Select specific columns, limit 10
SELECT 
    message_id,
    chat_id,
    user_id,
    message_type,
    sent_timestamp
FROM messages
LIMIT 10;

-- 3. Select specific columns, offset 2, limit 1 (LIMIT offset, count is MySQL syntax; in ClickHouse use LIMIT count OFFSET offset)
SELECT 
    message_id,
    chat_id,
    user_id,
    message_type,
    sent_timestamp
FROM messages
LIMIT 1 OFFSET 2;

-- =============================================
-- Chat Payments Data Queries
-- =============================================

-- 4. Get all invoice messages
SELECT 
    message_id, 
    chat_id, 
    sent_timestamp, 
    content
FROM messages
WHERE message_type = 'invoice';

-- 5. Find messages with attachments
SELECT 
    message_id, 
    chat_id, 
    user_id, 
    message_type, 
    sent_timestamp
FROM messages
WHERE has_attachment = 1;

-- 6. Get payment data from attachments
SELECT 
    attachment_id,
    message_id,
    payment_amount,
    payment_currency,
    payment_status
FROM attachments
LIMIT 10;