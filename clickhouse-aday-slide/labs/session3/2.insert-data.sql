-- =============================================
-- Insert Sample Data into chat_payments Database
-- =============================================

-- 1. Insert multiple messages
INSERT INTO chat_payments.messages VALUES
    (generateUUIDv4(), 100, 1001, now(), 'invoice', 'April Invoice', 1, 1),
    (generateUUIDv4(), 100, 1002, now(), 'text', 'Got it, thanks!', 0, 1),
    (generateUUIDv4(), 101, 1003, now(), 'receipt', 'Payment receipt', 1, 1),
    (generateUUIDv4(), 101, 1001, now(), 'text', 'Payment confirmed', 0, 1);

-- 2. Insert a single payment attachment record (with explicit columns)
INSERT INTO chat_payments.attachments (
    attachment_id, message_id, payment_amount, payment_currency,
    invoice_date, payment_status, file_path, file_size, uploaded_at, sign
) VALUES (
    generateUUIDv4(), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    1250.00, 'USD', '2023-04-01', 'pending',
    '/storage/invoices/inv_12345.pdf', 
    128000, 
    parseDateTimeBestEffort('2023-04-02 14:30:00'),
    1
);

-- 3. Insert multiple payment attachment records
INSERT INTO chat_payments.attachments VALUES
    (generateUUIDv4(), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 1250.00, 'USD', 
     '2023-04-01', 'pending', '/storage/invoices/inv_12345.pdf', 128000, '2023-04-02 14:30:00', 1),
    (generateUUIDv4(), 'b1ffc999-7d1a-4ef8-bb6d-6bb9bd380a12', 750.50, 'EUR', 
     '2023-04-05', 'paid', '/storage/receipts/rec_75421.pdf', 98500, '2023-04-06 09:15:00', 1),
    (generateUUIDv4(), 'c2aac888-6e2b-4ef8-bb6d-6bb9bd380a13', 500.25, 'GBP', 
     '2023-04-10', 'canceled', '/storage/invoices/inv_33456.pdf', 115200, '2023-04-11 11:45:00', 1);

-- 4. Insert multiple users

INSERT INTO chat_payments.users VALUES
    (1001, 'John Doe', 'john.doe@example.com', 12345, '2023-01-01 00:00:00'),
    (1002, 'Jane Smith', 'jane.smith@example.com', 98765, '2023-01-01 00:00:00'),
    (1003, 'Alice Johnson', 'alice.johnson@example.com', 55555, '2023-01-01 00:00:00'),
    (1004, 'Bob Brown', 'bob.brown@example.com', 11111, '2023-01-01 00:00:00');

INSERT INTO chat_payments.messages VALUES
    ('11111111-1111-1111-1111-111111111111', 200, 1001, now(), 'invoice', 'Invoice for April services', 1, 1),
    ('22222222-2222-2222-2222-222222222222', 200, 1002, now(), 'text', 'Received the invoice, thank you!', 0, 1),
    ('33333333-3333-3333-3333-333333333333', 201, 1003, now(), 'receipt', 'Payment receipt for April', 1, 1),
    ('44444444-4444-4444-4444-444444444444', 201, 1004, now(), 'text', 'Payment has been processed.', 0, 1),
    ('55555555-5555-5555-5555-555555555555', 202, 1001, now(), 'text', 'Let me know if you have any questions.', 0, 1),
    ('66666666-6666-6666-6666-666666666666', 202, 1002, now(), 'invoice', 'May invoice attached.', 1, 1),
    ('77777777-7777-7777-7777-777777777777', 203, 1003, now(), 'text', 'Looking forward to our next meeting.', 0, 1),
    ('88888888-8888-8888-8888-888888888888', 203, 1004, now(), 'receipt', 'Receipt for May payment.', 1, 1);

-- Sample attachments for messages with has_attachment = 1
INSERT INTO chat_payments.attachments VALUES
    (generateUUIDv4(), '11111111-1111-1111-1111-111111111111', 1200.00, 'USD', '2023-04-01', 'pending', '/storage/invoices/inv_apr_2023.pdf', 128000, now(), 1),
    (generateUUIDv4(), '33333333-3333-3333-3333-333333333333', 1200.00, 'USD', '2023-04-02', 'paid', '/storage/receipts/rec_apr_2023.pdf', 64000, now(), 1),
    (generateUUIDv4(), '66666666-6666-6666-6666-666666666666', 1300.00, 'USD', '2023-05-01', 'pending', '/storage/invoices/inv_may_2023.pdf', 128000, now(), 1),
    (generateUUIDv4(), '88888888-8888-8888-8888-888888888888', 1300.00, 'USD', '2023-05-02', 'paid', '/storage/receipts/rec_may_2023.pdf', 64000, now(), 1);
-- =============================================
-- Bulk Data Import (CSV)
-- =============================================

-- 4. Generate the CSV file using Node.js
-- (Run this in your shell, not in SQL)
-- node generatecsv.js

-- 5. Copy the CSV file to the Docker container
-- (Run this in your shell, not in SQL)
-- docker cp output.csv clickhouse-server:/data/output.csv

-- 6. Check the current count of attachments
SELECT count(*) FROM chat_payments.attachments;

-- 7. Import the CSV data into ClickHouse
-- (Run this in your shell, not in SQL)
-- clickhouse-client -q "INSERT INTO chat_payments.attachments FORMAT CSVWithNames" < /data/output.csv

