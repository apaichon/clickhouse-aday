-- =============================================
-- 1. Data Insertion Methods
-- =============================================

-- INSERT FROM SELECT: Copy data from one table to another
CREATE TABLE attachments_backup AS attachments;

INSERT INTO attachments_backup
SELECT *
FROM attachments
WHERE toYear(uploaded_at) = 2023
  AND payment_status = 'paid'
  AND payment_amount > 1000;

-- =============================================
-- 2. Batch Processing
-- =============================================

-- Batch Insert Best Practices

TRUNCATE TABLE messages;

-- Prepare a large batch of messages
INSERT INTO messages
SELECT
    generateUUIDv4() as message_id,
    toUInt64(rand() % 1000) as chat_id,
    toUInt32(rand() % 10000) as user_id,
    now() - toIntervalDay(rand() % 30) as sent_timestamp,
    CAST(
        multiIf(
            rand() % 4 = 0, 'text',
            rand() % 4 = 1, 'image',
            rand() % 4 = 2, 'invoice',
            'receipt'
        ) AS Enum8('text' = 1, 'image' = 2, 'invoice' = 3, 'receipt' = 4)
    ) as message_type,
    'Batch generated message ' || toString(number) as content,
    rand() % 2 as has_attachment,
    1 as sign
FROM numbers(5_000_000)  
SETTINGS 
    max_insert_block_size = 10_000_000,
    min_insert_block_size_rows = 100_000,
    min_insert_block_size_bytes = 100_000_000;



SELECT name, value, default
FROM system.settings 
WHERE name IN ('max_insert_block_size', 'min_insert_block_size_rows', 'min_insert_block_size_bytes');


SET max_insert_block_size = DEFAULT;
SET min_insert_block_size_rows = DEFAULT;
SET min_insert_block_size_bytes = DEFAULT;

xml
<!-- In users.xml or settings profiles -->
<profiles>
    <default_profile>
        <max_insert_block_size>1048576</max_insert_block_size>
        <min_insert_block_size_rows>0</min_insert_block_size_rows>
        <min_insert_block_size_bytes>0</min_insert_block_size_bytes>
    </default_profile>
</profiles>
Then apply the profile:




