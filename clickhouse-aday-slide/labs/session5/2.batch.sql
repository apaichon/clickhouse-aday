-- =============================================
-- Batch Insert Best Practices
-- =============================================

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


-- =============================================
-- Monitoring Batch Operations
-- =============================================

-- Check recent insertion performance
SELECT
    query_start_time,
    event_time,
    query_duration_ms,
    read_rows,
    written_rows,
    memory_usage
FROM system.query_log
WHERE query LIKE '%INSERT INTO messages%'
  AND event_time > now() - INTERVAL 1 HOUR
  AND type = 'QueryFinish'
ORDER BY event_time DESC
LIMIT 20;

-- Check parts created by recent inserts
SELECT
    table,
    partition,
    name,
    rows,
    bytes_on_disk,
    modification_time
FROM system.parts
WHERE active = 1
  AND table = 'attachments'
ORDER BY modification_time DESC
LIMIT 20;

-- =============================================
-- Understanding Duplication Challenges
-- =============================================

-- Check for duplicate messages
SELECT
    message_id,
    COUNT(*) as count
FROM messages
GROUP BY message_id
HAVING count > 1
ORDER BY count DESC;

-- Check for duplicate payment attachments
SELECT
    attachment_id,
    COUNT(*) as count
FROM attachments
GROUP BY attachment_id
HAVING count > 1
ORDER BY count DESC;

-- =============================================
-- Basic Deduplication Implementation
-- =============================================

-- Using ReplacingMergeTree for payment attachments
DROP TABLE IF EXISTS attachments_dedup;

CREATE TABLE IF NOT EXISTS attachments_dedup
(
    attachment_id UUID,
    message_id UUID,
    payment_amount Decimal64(2),
    payment_currency LowCardinality(String),
    invoice_date Date,
    payment_status Enum8(
        'pending' = 1, 'paid' = 2, 'canceled' = 3
    ),
    file_path String,
    file_size UInt32,
    uploaded_at DateTime,
    sign Int8
) ENGINE = ReplacingMergeTree(uploaded_at)
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (message_id, attachment_id);

-- Fill the table with deduplicated data (example: first 10 rows)
INSERT INTO attachments_dedup
SELECT *
FROM attachments
LIMIT 10;

-- Check for duplicate messages in deduplicated table
SELECT
    message_id,
    COUNT(*) as count
FROM attachments_dedup FINAL
GROUP BY message_id
HAVING count > 1
ORDER BY count DESC;

-- =============================================
-- Force Merge for Deduplication
-- =============================================

-- Trigger merges to eliminate duplicates
OPTIMIZE TABLE attachments_dedup FINAL;

-- Verify deduplication
SELECT
    attachment_id,
    COUNT(*) as count
FROM attachments_dedup
GROUP BY attachment_id
HAVING count > 1;



