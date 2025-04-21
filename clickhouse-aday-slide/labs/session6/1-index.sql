
## Primary Key Optimization


CREATE TABLE chat_payments.messages_optimized (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    sent_timestamp DateTime,
    message_type Enum8(
        'text' = 1, 'image' = 2, 
        'invoice' = 3, 'receipt' = 4
    ),
    content String,
    has_attachment UInt8,
    sign Int8
) ENGINE = CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(sent_timestamp)
ORDER BY (chat_id, toStartOfDay(sent_timestamp), message_type, user_id);

insert into messages_optimized
select * from messages


SELECT 
    toDate(sent_timestamp) AS date,
    count() AS message_count
FROM messages_optimized
WHERE chat_id = 100
  AND sent_timestamp >= '2023-04-01'
  AND sent_timestamp < '2023-04-30'
  AND message_type = 'invoice' 
GROUP BY date
ORDER BY date;


SELECT 
    toDate(sent_timestamp) AS date,
    count() AS message_count
FROM messages
WHERE chat_id = 100
  AND sent_timestamp >= '2023-04-01'
  AND sent_timestamp < '2023-04-30'
  AND message_type = 'invoice' 
GROUP BY date
ORDER BY date;


## Skip Index Recommendations

CREATE TABLE chat_payments.attachments_optimized (
    attachment_id UUID CODEC(ZSTD(1)),
    message_id UUID CODEC(ZSTD(1)),
    payment_amount Decimal64(2) CODEC(Delta, ZSTD(1)),
    payment_currency LowCardinality(String) CODEC(ZSTD(1)),
    invoice_date Date CODEC(Delta, ZSTD(1)),
    payment_status Enum8(
        'pending' = 1, 'paid' = 2, 'canceled' = 3
    ) CODEC(ZSTD(1)),
    file_path String CODEC(ZSTD(3)),
    file_size UInt32 CODEC(Delta, ZSTD(1)),
    uploaded_at DateTime CODEC(Delta, ZSTD(1)),
    sign Int8 CODEC(Delta, ZSTD(1)),
    
    -- Improved indexes
    INDEX payment_status_idx payment_status TYPE minmax GRANULARITY 1,
    INDEX currency_idx payment_currency TYPE set(8) GRANULARITY 1,
    INDEX file_size_idx file_size TYPE minmax GRANULARITY 1,
    INDEX payment_amount_idx payment_amount TYPE minmax GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (message_id, uploaded_at, attachment_id)
SETTINGS 
    index_granularity = 8192,
    min_bytes_for_wide_part = 10485760,
    enable_mixed_granularity_parts = 1;


insert into attachments_optimized
select * from attachments


SELECT 
    toDate(uploaded_at) AS date,
    count() AS attachment_count
FROM attachments
WHERE uploaded_at >= '2023-04-01'
  AND uploaded_at < '2023-04-30'
GROUP BY date

SELECT 
    toDate(uploaded_at) AS date,
    count() AS attachment_count
FROM attachments_optimized
WHERE uploaded_at >= '2023-04-01'
  AND uploaded_at < '2023-04-30'
GROUP BY date


SELECT 
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows,
    min(min_date) as min_date,
    max(max_date) as max_date,
    sum(bytes) as bytes_size,
    sum(data_compressed_bytes) as compressed_size,
    sum(data_uncompressed_bytes) as uncompressed_size,
    round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes), 3) as compression_ratio
FROM system.parts
WHERE active AND database = 'chat_payments' AND table in ('attachments', 'attachments_optimized')
GROUP BY table
ORDER BY bytes_size DESC;



## Diagnosing Index Usage

-- Check if a query uses the index
EXPLAIN indexes = 1
SELECT * FROM attachments_optimized WHERE payment_status = 'paid';

select * from system.parts
where table = 'attachments_optimized'

SELECT 
    database,
    table,
    sum(marks) as total_granules,
    formatReadableSize(sum(data_compressed_bytes)) as compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size
FROM system.parts
WHERE active = 1
GROUP BY database, table
ORDER BY total_granules DESC;

-- Analyze missed index opportunities
SELECT * FROM payment_attachments WHERE payment_status = 'paid';

-- Analyze missed index opportunities
  SELECT
    query_id,
    query,
    read_rows,
    read_bytes,
    query_duration_ms
FROM system.query_log
WHERE query LIKE '%attachments%'
    AND read_rows > 1000000
    AND event_time > now() - INTERVAL 1 DAY
    AND type = 'QueryFinish'  -- Only show completed queries
ORDER BY query_duration_ms DESC;
