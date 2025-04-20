
-- Insert multiple rows
INSERT INTO chat_payments.messages VALUES
    (generateUUIDv4(), 100, 1001, now(), 'invoice', 'April Invoice', 1, 1),
    (generateUUIDv4(), 100, 1002, now(), 'text', 'Got it, thanks!', 0, 1),
    (generateUUIDv4(), 101, 1003, now(), 'receipt', 'Payment receipt', 1, 1),
    (generateUUIDv4(), 101, 1001, now(), 'text', 'Payment confirmed', 0, 1);


-- Insert payment attachment records
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

-- Insert multiple payment records
INSERT INTO chat_payments.attachments VALUES
(generateUUIDv4(), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 1250.00, 'USD', 
 '2023-04-01', 'pending', '/storage/invoices/inv_12345.pdf', 128000, '2023-04-02 14:30:00' ,1),
(generateUUIDv4(), 'b1ffc999-7d1a-4ef8-bb6d-6bb9bd380a12', 750.50, 'EUR', 
 '2023-04-05', 'paid', '/storage/receipts/rec_75421.pdf', 98500, '2023-04-06 09:15:00', 1),
(generateUUIDv4(), 'c2aac888-6e2b-4ef8-bb6d-6bb9bd380a13', 500.25, 'GBP', 
 '2023-04-10', 'canceled', '/storage/invoices/inv_33456.pdf', 115200, '2023-04-11 11:45:00', 1);


 # First generate the CSV file
node generatecsv.js

# Then copy it to the Docker container
docker cp output.csv clickhouse-server:/data/output.csv

select count(*) from chat_payments.attachments;


clickhouse-client -q "INSERT INTO chat_payments.attachments FORMAT CSVWithNames" < /data/output.csv

