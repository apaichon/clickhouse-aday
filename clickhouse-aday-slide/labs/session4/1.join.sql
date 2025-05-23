-- =============================================
-- Basic JOIN Examples
-- =============================================

-- INNER JOIN: Get messages with payment attachments
SELECT m.message_id, m.chat_id, m.user_id, 
       p.payment_amount, p.payment_currency
FROM messages m
INNER JOIN attachments p 
ON m.message_id = p.message_id;

-- LEFT JOIN: Get all messages and any payment attachments
SELECT m.message_id, m.content, 
       p.payment_amount, p.payment_status
FROM messages m
LEFT JOIN attachments p 
ON m.message_id = p.message_id
LIMIT 100;

-- FULL JOIN: Get all messages and all payments
SELECT m.message_id, m.content, 
       p.attachment_id, p.payment_amount
FROM messages m
FULL JOIN attachments p 
ON m.message_id = p.message_id
LIMIT 100;

-- =============================================
-- Data Preparation for JOIN Examples
-- =============================================

-- Insert users
INSERT INTO chat_payments.users 
    (user_id, username, email, company_id, created_at) 
VALUES
    (5001, 'john.doe', 'john.doe@company.com', 101, now()),
    (5002, 'jane.smith', 'jane.smith@company.com', 102, now()),
    (5003, 'bob.wilson', 'bob.wilson@company.com', 101, now());

-- Insert messages with matching user_ids
INSERT INTO chat_payments.messages VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 301, 5001, '2024-04-10 10:00:00', 'invoice', 'April Invoice #1', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440001', 302, 5002, '2024-04-15 14:30:00', 'invoice', 'April Invoice #2', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440002', 303, 5003, '2024-04-20 09:15:00', 'invoice', 'April Invoice #3', 1, 1);

-- Insert attachments with matching message_ids and 'paid' status
INSERT INTO chat_payments.attachments VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440000', 2500.00, 'USD', '2024-04-10', 'paid', '/storage/invoices/apr_inv_001.pdf', 156000, '2024-04-10 10:00:00', 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 3750.50, 'EUR', '2024-04-15', 'paid', '/storage/invoices/apr_inv_002.pdf', 178500, '2024-04-15 14:30:00', 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 1850.75, 'USD', '2024-04-20', 'paid', '/storage/invoices/apr_inv_003.pdf', 145200, '2024-04-20 09:15:00', 1);

-- =============================================
-- Multi-table JOIN Example: User, Message, Payment
-- =============================================

SELECT 
    u.user_id,
    u.username,
    u.company_id,
    m.chat_id,
    m.message_type,
    m.sent_timestamp,
    p.payment_amount,
    p.payment_currency,
    p.payment_status
FROM messages m
JOIN attachments p 
    ON m.message_id = p.message_id
JOIN users u 
    ON m.user_id = u.user_id
WHERE p.payment_status = 'paid'
  AND m.sent_timestamp >= '2024-04-01 00:00:00'
  AND m.sent_timestamp < '2024-05-01 00:00:00'
ORDER BY p.payment_amount DESC
LIMIT 100;

-- =============================================
-- Advanced JOIN Techniques
-- =============================================

-- CROSS JOIN: All user/currency combinations
SELECT u.user_id, u.username, c.currency_code
FROM 
    (SELECT DISTINCT payment_currency AS currency_code FROM attachments) AS c
CROSS JOIN 
(SELECT user_id, username FROM users LIMIT 10) AS u;

-- JOIN with USING: Simplified join syntax when column names match
SELECT m.chat_id, m.user_id, p.payment_amount
FROM messages m
JOIN attachments p
USING (message_id);

-- JOIN with Complex Conditions: Matching payments within a time window
SELECT m.message_id, m.sent_timestamp, m.content, p.payment_amount, p.uploaded_at
FROM messages m
JOIN attachments p
ON p.message_id = m.message_id
   AND p.uploaded_at > m.sent_timestamp
   AND p.uploaded_at < m.sent_timestamp + INTERVAL 1 DAY;

-- =============================================
-- ARRAY JOIN Example
-- =============================================
 
-- Add tags column to users table
ALTER TABLE chat_payments.users
ADD COLUMN tags String;

-- Update users with some sample tags
INSERT INTO chat_payments.users 
(user_id, username, email, company_id, created_at, tags) 
VALUES
    (5001, 'john.doe', 'john.doe@company.com', 101, now(), 'premium,vip,business'),
    (5002, 'jane.smith', 'jane.smith@company.com', 102, now(), 'premium,standard'),
    (5003, 'bob.wilson', 'bob.wilson@company.com', 101, now(), 'business,trial');

-- Split tags into rows
SELECT user_id, tag
FROM users
ARRAY JOIN splitByChar(',', tags) AS tag
WHERE length(tag) > 0;

-- =============================================
-- Monthly Payment Analysis
-- =============================================

SELECT 
    toStartOfMonth(p.uploaded_at) AS month,
    u.company_id,
    count() AS payment_count,
    sum(p.payment_amount) AS total_amount
FROM attachments p
JOIN messages m 
    ON p.message_id = m.message_id
JOIN users u 
    ON m.user_id = u.user_id
WHERE p.payment_status = 'paid'
GROUP BY month, u.company_id
ORDER BY month DESC, total_amount DESC;

-- =============================================
-- Payment History for a Specific User
-- =============================================

-- Insert users
INSERT INTO chat_payments.users 
(user_id, username, email, company_id, created_at) 
VALUES
    (1001, 'alice.wong', 'alice.wong@company.com', 101, now()),
    (1002, 'bob.smith', 'bob.smith@company.com', 102, now()),
    (1003, 'carol.lee', 'carol.lee@company.com', 101, now());

-- Insert messages linked to these users
INSERT INTO chat_payments.messages 
(message_id, chat_id, user_id, sent_timestamp, message_type, content, has_attachment, sign) 
VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 201, 1001, '2024-03-15 10:00:00', 'invoice', 'March Invoice #1', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440001', 201, 1001, '2024-03-20 14:30:00', 'invoice', 'March Invoice #2', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440002', 202, 1002, '2024-03-18 09:15:00', 'invoice', 'Project Payment', 1, 1),
    ('550e8400-e29b-41d4-a716-446655440003', 203, 1003, '2024-03-22 11:45:00', 'invoice', 'Service Invoice', 1, 1);

-- Insert attachments with matching message_ids
INSERT INTO chat_payments.attachments 
(attachment_id, message_id, payment_amount, payment_currency, payment_status, uploaded_at, file_path, sign) 
VALUES
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440000', 1500.00, 'USD', 'paid', '2024-03-15 10:30:00', '/invoices/inv_001.pdf', 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440001', 2500.00, 'USD', 'pending', '2024-03-20 15:00:00', '/invoices/inv_002.pdf', 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440002', 3000.00, 'EUR', 'paid', '2024-03-18 10:00:00', '/invoices/inv_003.pdf', 1),
    (generateUUIDv4(), '550e8400-e29b-41d4-a716-446655440003', 1750.00, 'USD', 'pending', '2024-03-22 12:00:00', '/invoices/inv_004.pdf', 1);

-- Query: Payment history for a specific user
SELECT 
    u.username,
    m.chat_id,
    p.payment_amount,
    p.payment_currency,
    p.payment_status,
    p.uploaded_at,
    m.content AS message_content
FROM users u
JOIN messages m 
    ON u.user_id = m.user_id
JOIN attachments p 
    ON m.message_id = p.message_id
WHERE u.user_id = 1001
ORDER BY p.uploaded_at DESC;

