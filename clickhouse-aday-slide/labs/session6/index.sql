-- =============================================
-- ClickHouse Session 6: Performance Optimization - Index Overview
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- Index Overview and Management
-- =============================================

-- Show all indexes in the life insurance database
SELECT 
    database,
    table,
    name as index_name,
    type,
    granularity,
    query
FROM system.data_skipping_indices
WHERE database = 'life_insurance'
ORDER BY table, name;

-- Check index effectiveness
SELECT 
    table,
    name as index_name,
    type,
    granularity
FROM system.data_skipping_indices
WHERE database = 'life_insurance'
ORDER BY table, name;

-- Monitor index usage and performance
SELECT 
    table,
    count() as total_parts,
    sum(rows) as total_rows,
    formatReadableSize(sum(bytes_on_disk)) as total_size
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
GROUP BY table
ORDER BY total_size DESC;

-- Show table structures with primary keys
SHOW CREATE TABLE policies;
SHOW CREATE TABLE claims;
SHOW CREATE TABLE customers;
SHOW CREATE TABLE agents;

SELECT
    table,
    formatReadableSize(sum(primary_key_bytes_in_memory)) AS primary_index_size,
    formatReadableSize(sum(bytes_on_disk)) AS table_size,
    round((sum(primary_key_bytes_in_memory) / sum(bytes_on_disk)) * 100, 2) AS index_percentage
FROM system.parts
WHERE active = 1
GROUP BY table
ORDER BY sum(primary_key_bytes_in_memory) DESC;




ALTER TABLE attachments
ADD INDEX payment_status_idx
payment_status TYPE set(0)
GRANULARITY 3;

-- Create a table with a secondary index
CREATE TABLE invoices (
    invoice_id UUID,
    customer_id UInt32,
    amount Decimal64(2),
    status Enum8('draft'=1, 'sent'=2, 'paid'=3, 'overdue'=4),
    created_at DateTime,
    /* other fields */
    
    INDEX status_idx status TYPE set(100) GRANULARITY 4,
    INDEX amount_idx amount TYPE minmax GRANULARITY 4
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(created_at)
ORDER BY (customer_id, created_at);

-- Forcing the use of a secondary index
SELECT count(*) FROM attachments
WHERE payment_status = 'paid'
SETTINGS use_secondary_index = 1,
         force_index_by_date = 0;