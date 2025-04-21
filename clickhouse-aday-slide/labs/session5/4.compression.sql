# ClickHouse Compression Overview

-- Check current compression settings
SELECT
    name,
    type,
    compression_codec,
    data_compressed_bytes,
    data_uncompressed_bytes,
    round(data_uncompressed_bytes / data_compressed_bytes, 2) as compression_ratio
FROM system.columns
WHERE table = 'attachments';

-- Check compression ratio for tables
SELECT
    table,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio
FROM system.columns
WHERE database = currentDatabase()
GROUP BY table
ORDER BY ratio DESC;



## Column-Specific Compression
-- Create table with column-specific compression

CREATE TABLE attachments_compressed
(
    attachment_id UUID CODEC(ZSTD(1)),
    message_id UUID CODEC(ZSTD(1)),
    payment_amount Decimal(18, 2) CODEC(Delta, ZSTD(1)),
    payment_currency LowCardinality(String) CODEC(ZSTD(1)),
    invoice_date Date CODEC(Delta, ZSTD(1)),
    payment_status Enum8('pending' = 1, 'paid' = 2, 'canceled' = 3) CODEC(ZSTD(1)),
    file_path String CODEC(ZSTD(3)),
    file_size UInt32 CODEC(Delta, ZSTD(1)),
    uploaded_at DateTime CODEC(Delta, ZSTD(1)),
    sign Int8 CODEC(Delta, ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (message_id, uploaded_at);

-- Fill with existing data
INSERT INTO attachments_compressed
SELECT * FROM attachments;


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
WHERE active AND database = 'chat_payments' AND table in ('attachments', 'attachments_compressed')
GROUP BY table
ORDER BY bytes_size DESC;