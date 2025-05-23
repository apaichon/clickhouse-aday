-- =============================================
-- Chat Application Schema with CollapsingMergeTree
-- =============================================

-- 1. Chat Rooms Table
CREATE TABLE chat_rooms (
    chat_id UInt64,
    room_name String,
    created_by UInt32,
    created_at DateTime,
    is_active UInt8,
    _sign Int8
) ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(created_at)
ORDER BY (chat_id, created_at);

-- 2. Messages Table
DROP TABLE IF EXISTS messages;
CREATE TABLE messages (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    message_type Enum8('text'=1, 'file'=2, 'payment'=3),
    content String,
    has_attachment UInt8,
    created_at DateTime,
    _sign Int8,
    INDEX message_type_idx message_type TYPE bloom_filter GRANULARITY 1
) ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(created_at)
ORDER BY (chat_id, created_at);

-- 3. Attachments Table
CREATE TABLE attachments (
    attachment_id UUID,
    message_id UUID,
    file_type Enum8('invoice'=1, 'receipt'=2, 'other'=3),
    file_path String,
    file_size UInt32,
    content_type String,
    upload_at DateTime,
    payment_amount Decimal64(2),
    payment_currency LowCardinality(String),
    payment_status Enum8('pending'=1, 'paid'=2, 'declined'=3),
    _sign Int8,
    INDEX file_type_idx file_type TYPE bloom_filter GRANULARITY 1
) ENGINE = CollapsingMergeTree(_sign)
PARTITION BY toYYYYMM(upload_at)
ORDER BY (message_id, upload_at);

-- =============================================
-- Sample Data
-- =============================================

-- Insert chat rooms
INSERT INTO chat_rooms VALUES
    (1001, 'Project Alpha Team', 101, '2024-01-15 09:00:00', 1, 1),
    (1002, 'Sales Department', 102, '2024-01-16 10:30:00', 1, 1),
    (1003, 'General Discussion', 101, '2024-01-17 11:00:00', 1, 1);

-- Insert messages
INSERT INTO messages (message_id, chat_id, user_id, message_type, content, has_attachment, created_at, _sign) VALUES
    (generateUUIDv4(), 1001, 101, 'text', 'Hello team!', 0, '2024-01-15 09:15:00', 1),
    (generateUUIDv4(), 1001, 102, 'payment', 'Please review the invoice for Project Alpha', 1, '2024-01-15 10:30:00', 1),
    (generateUUIDv4(), 1002, 103, 'payment', 'Here is the receipt for office supplies', 1, '2024-01-16 14:20:00', 1),
    (generateUUIDv4(), 1002, 101, 'text', 'Thanks for the update!', 0, '2024-01-16 14:25:00', 1),
    (generateUUIDv4(), 1003, 102, 'file', 'Check out our new product catalog', 1, '2024-01-17 15:00:00', 1);

-- Insert attachments
INSERT INTO attachments VALUES
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Please review the invoice for Project Alpha' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/inv_001.pdf', 256000, 'application/pdf', '2024-01-15 10:30:00', 1500.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Here is the receipt for office supplies' AND _sign = 1 LIMIT 1),
        'receipt', '/files/receipts/rec_001.pdf', 128000, 'application/pdf', '2024-01-16 14:20:00', 299.99, 'USD', 'paid', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Check out our new product catalog' AND _sign = 1 LIMIT 1),
        'other', '/files/documents/catalog_2024.pdf', 1024000, 'application/pdf', '2024-01-17 15:00:00', 0.00, 'USD', 'pending', 1);

-- =============================================
-- Example Updates (CollapsingMergeTree pattern)
-- =============================================

-- Update a message: mark old as deleted, insert new version
INSERT INTO messages VALUES
    (generateUUIDv4(), 1001, 101, 'text', 'Hello team!', 0, '2024-01-15 09:15:00', -1);
INSERT INTO messages VALUES
    (generateUUIDv4(), 1001, 101, 'text', 'Hello team! Updated message', 0, '2024-01-15 09:15:00', 1);

-- Update payment status for an invoice: mark old as deleted, insert new status
INSERT INTO attachments 
SELECT 
    attachment_id, message_id, file_type, file_path, file_size, 
    content_type, upload_at, payment_amount, payment_currency, 
    payment_status, -1 as _sign
FROM attachments 
WHERE payment_status = 'pending' AND file_type = 'invoice' AND _sign = 1;

INSERT INTO attachments 
SELECT 
    attachment_id, message_id, file_type, file_path, file_size, 
    content_type, upload_at, payment_amount, payment_currency, 
    'paid' as payment_status, 1 as _sign
FROM attachments 
WHERE payment_status = 'pending' AND file_type = 'invoice' AND _sign = -1;

-- =============================================
-- Query Examples
-- =============================================

-- Daily payment summary for invoices
SELECT 
    toDate(upload_at) AS day,
    sum(payment_amount) AS total_amount,
    countIf(payment_status = 'paid') AS paid_count
FROM attachments
WHERE 
    file_type = 'invoice' 
    AND toYYYYMM(upload_at) >= 202401
    AND toYYYYMM(upload_at) <= 202403
GROUP BY day
ORDER BY day;

-- View active chat rooms
SELECT * FROM chat_rooms WHERE _sign = 1;

-- View active messages with their attachments
SELECT 
    m.message_id,
    m.chat_id,
    m.content,
    a.file_type,
    a.payment_amount,
    a.payment_status
FROM messages m
LEFT JOIN attachments a ON m.message_id = a.message_id
WHERE m._sign = 1 AND (a._sign = 1 OR a._sign IS NULL);

-- View payment statistics
SELECT 
    payment_status,
    count() as count,
    sum(payment_amount) as total_amount
FROM attachments
WHERE _sign = 1
GROUP BY payment_status;

-- =============================================
-- Materialized View for Payment Summary
-- =============================================

CREATE MATERIALIZED VIEW payment_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(day)
ORDER BY (payment_currency, day)
AS
SELECT 
    toDate(upload_at) AS day,
    payment_currency,
    payment_status,
    count() AS payment_count,
    sum(payment_amount) AS total_amount
FROM attachments
WHERE file_type IN ('invoice', 'receipt')
GROUP BY day, payment_currency, payment_status;

-- Optionally, insert summary data manually
INSERT INTO payment_summary 
SELECT 
    upload_at,
    payment_currency,
    payment_status,
    count() AS payment_count,
    sum(payment_amount) AS total_amount
FROM attachments
WHERE _sign = 1
GROUP BY upload_at, payment_currency, payment_status;

-- =============================================
-- More Sample Messages and Attachments
-- =============================================

-- Insert more messages
INSERT INTO messages VALUES
    (generateUUIDv4(), 1001, 101, 'text', 'Weekly project update meeting tomorrow at 10 AM', 0, '2024-01-18 15:00:00', 1),
    (generateUUIDv4(), 1001, 102, 'payment', 'Q1 consulting invoice attached', 1, '2024-01-18 16:30:00', 1),
    (generateUUIDv4(), 1001, 103, 'file', 'Project timeline updated', 1, '2024-01-19 09:15:00', 1),
    (generateUUIDv4(), 1001, 101, 'payment', 'Software license renewal invoice', 1, '2024-01-19 11:20:00', 1),
    (generateUUIDv4(), 1001, 102, 'text', 'Invoice approved, processing payment', 0, '2024-01-19 14:30:00', 1),
    (generateUUIDv4(), 1002, 104, 'payment', 'Client meeting expenses receipt', 1, '2024-01-18 10:00:00', 1),
    (generateUUIDv4(), 1002, 105, 'file', 'Updated sales presentation', 1, '2024-01-18 13:45:00', 1),
    (generateUUIDv4(), 1002, 106, 'payment', 'Marketing campaign invoice', 1, '2024-01-19 10:00:00', 1),
    (generateUUIDv4(), 1002, 104, 'text', 'Great results this quarter!', 0, '2024-01-19 15:30:00', 1),
    (generateUUIDv4(), 1002, 105, 'payment', 'Trade show booth payment receipt', 1, '2024-01-19 16:45:00', 1),
    (generateUUIDv4(), 1003, 107, 'text', 'Office maintenance scheduled for weekend', 0, '2024-01-18 11:00:00', 1),
    (generateUUIDv4(), 1003, 108, 'payment', 'Office supplies invoice', 1, '2024-01-18 14:20:00', 1),
    (generateUUIDv4(), 1003, 109, 'file', 'Company handbook updated', 1, '2024-01-19 09:30:00', 1),
    (generateUUIDv4(), 1003, 107, 'payment', 'Catering service invoice for team lunch', 1, '2024-01-19 13:15:00', 1),
    (generateUUIDv4(), 1003, 108, 'text', 'Remember to submit expenses by Friday', 0, '2024-01-19 16:00:00', 1);

-- Insert corresponding attachments
INSERT INTO attachments VALUES
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Q1 consulting invoice attached' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/consulting_q1.pdf', 345000, 'application/pdf', '2024-01-18 16:30:00', 5000.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Project timeline updated' AND _sign = 1 LIMIT 1),
        'other', '/files/documents/timeline_v2.xlsx', 250000, 'application/xlsx', '2024-01-19 09:15:00', 0.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Software license renewal invoice' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/license_2024.pdf', 280000, 'application/pdf', '2024-01-19 11:20:00', 2499.99, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Client meeting expenses receipt' AND _sign = 1 LIMIT 1),
        'receipt', '/files/receipts/client_meeting.pdf', 156000, 'application/pdf', '2024-01-18 10:00:00', 245.50, 'USD', 'paid', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Updated sales presentation' AND _sign = 1 LIMIT 1),
        'other', '/files/presentations/sales_q1.pptx', 1500000, 'application/pptx', '2024-01-18 13:45:00', 0.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Marketing campaign invoice' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/marketing_jan24.pdf', 425000, 'application/pdf', '2024-01-19 10:00:00', 7500.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Trade show booth payment receipt' AND _sign = 1 LIMIT 1),
        'receipt', '/files/receipts/tradeshow_booth.pdf', 198000, 'application/pdf', '2024-01-19 16:45:00', 3500.00, 'USD', 'paid', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Office supplies invoice' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/office_supplies_jan.pdf', 175000, 'application/pdf', '2024-01-18 14:20:00', 458.75, 'EUR', 'paid', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Company handbook updated' AND _sign = 1 LIMIT 1),
        'other', '/files/documents/handbook_2024.pdf', 2500000, 'application/pdf', '2024-01-19 09:30:00', 0.00, 'USD', 'pending', 1),
    (generateUUIDv4(), (SELECT message_id FROM messages WHERE content = 'Catering service invoice for team lunch' AND _sign = 1 LIMIT 1),
        'invoice', '/files/invoices/catering_jan24.pdf', 165000, 'application/pdf', '2024-01-19 13:15:00', 850.00, 'EUR', 'pending', 1);

-- =============================================
-- End of Chat App Example
-- =============================================