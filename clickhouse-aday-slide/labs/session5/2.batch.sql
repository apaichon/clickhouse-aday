# Batch Insert Best Practices

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
FROM numbers(1_000_000);  -- Generate 1 million rows

-- Optimal batch size in production
SET max_insert_block_size = 1000000;  -- Default is 1048576
SET min_insert_block_size_rows = 10000;
SET min_insert_block_size_bytes = 10000000;

-- Backup

-- Transform

## Monitoring Batch Operations
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



