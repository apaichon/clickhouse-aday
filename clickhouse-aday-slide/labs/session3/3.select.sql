SELECT *
FROM messages
LIMIT 5;

-- Select specific columns
SELECT 
    message_id,
    chat_id,
    user_id,
    message_type,
    sent_timestamp
FROM messages
LIMIT 10


SELECT 
    message_id,
    chat_id,
    user_id,
    message_type,
    sent_timestamp
FROM messages
LIMIT 2,1;

# Working with Chat Payments Data

-- Get all invoice messages
SELECT 
    message_id, chat_id, sent_timestamp, content
FROM messages
WHERE message_type = 'invoice';

-- Find messages with attachments
SELECT 
    message_id, chat_id, user_id, 
    message_type, sent_timestamp
FROM messages
WHERE has_attachment = 1;

-- Get payment data
SELECT 
    attachment_id,
    message_id,
    payment_amount,
    payment_currency,
    payment_status
FROM attachments limit 10;