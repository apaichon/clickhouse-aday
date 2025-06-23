-- =============================================
-- ClickHouse Session 5: Data Operations and Management - Compression
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Analyzing Current Compression
-- =============================================

-- Check table sizes and compression ratios
SELECT 
    table,
    formatReadableSize(sum(bytes_on_disk)) as compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) as compression_ratio,
    sum(rows) as total_rows
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
GROUP BY table
ORDER BY sum(bytes_on_disk) DESC;

-- Detailed compression analysis by partition
SELECT 
    table,
    partition,
    formatReadableSize(sum(bytes_on_disk)) as compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) as compression_ratio,
    sum(rows) as rows_count
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
  AND table IN ('policies', 'claims', 'customers')
GROUP BY table, partition
ORDER BY table, partition;

-- Column-level compression analysis
SELECT 
    table,
    column,
    formatReadableSize(sum(column_bytes_on_disk)) as compressed_size,
    formatReadableSize(sum(column_data_uncompressed_bytes)) as uncompressed_size,
    round(sum(column_data_uncompressed_bytes) / sum(column_bytes_on_disk), 2) as compression_ratio
FROM system.parts_columns
WHERE database = 'life_insurance'
  AND active = 1
  AND table IN ('policies', 'claims', 'customers')
GROUP BY table, column
ORDER BY table, sum(column_bytes_on_disk) DESC;

-- =============================================
-- 2. Creating Tables with Different Compression Codecs
-- =============================================

-- Create a test table with LZ4 compression (default)
CREATE TABLE policies_lz4
(
    policy_id UUID,
    customer_id UInt64,
    agent_id UInt32,
    policy_type LowCardinality(String),
    policy_number String CODEC(LZ4),
    coverage_amount Decimal64(2) CODEC(LZ4),
    premium_amount Decimal64(2) CODEC(LZ4),
    effective_date Date CODEC(LZ4),
    status LowCardinality(String),
    description String CODEC(LZ4)
)
ENGINE = MergeTree()
ORDER BY (policy_id, customer_id)
SETTINGS index_granularity = 8192;

-- Create a test table with ZSTD compression
CREATE TABLE policies_zstd
(
    policy_id UUID,
    customer_id UInt64,
    agent_id UInt32,
    policy_type LowCardinality(String),
    policy_number String CODEC(ZSTD),
    coverage_amount Decimal64(2) CODEC(ZSTD),
    premium_amount Decimal64(2) CODEC(ZSTD),
    effective_date Date CODEC(ZSTD),
    status LowCardinality(String),
    description String CODEC(ZSTD)
)
ENGINE = MergeTree()
ORDER BY (policy_id, customer_id)
SETTINGS index_granularity = 8192;

-- Create a test table with Delta + LZ4 for numeric columns
CREATE TABLE policies_delta
(
    policy_id UUID,
    customer_id UInt64 CODEC(Delta, LZ4),
    agent_id UInt32 CODEC(Delta, LZ4),
    policy_type LowCardinality(String),
    policy_number String CODEC(LZ4),
    coverage_amount Decimal64(2) CODEC(Delta, LZ4),
    premium_amount Decimal64(2) CODEC(Delta, LZ4),
    effective_date Date CODEC(Delta, LZ4),
    status LowCardinality(String),
    description String CODEC(LZ4)
)
ENGINE = MergeTree()
ORDER BY (policy_id, customer_id)
SETTINGS index_granularity = 8192;

-- =============================================
-- 3. Inserting Test Data for Compression Comparison
-- =============================================

-- Insert same data into all test tables
INSERT INTO policies_lz4 
SELECT 
    generateUUIDv4(),
    7000 + number,
    700 + (number % 50),
    multiIf(
        number % 5 = 0, 'Term Life',
        number % 5 = 1, 'Whole Life',
        number % 5 = 2, 'Universal Life',
        number % 5 = 3, 'Variable Life',
        'Endowment'
    ),
    concat('POL-LZ4-', toString(number)),
    250000.00 + (number % 100) * 10000.00,
    600.00 + (number % 100) * 10.00,
    today() - INTERVAL (number % 1000) DAY,
    multiIf(
        number % 10 = 0, 'Pending',
        number % 20 = 0, 'Lapsed',
        'Active'
    ),
    concat('Policy description for customer ', toString(7000 + number), ' with detailed terms and conditions.')
FROM numbers(10000);

INSERT INTO policies_zstd 
SELECT 
    generateUUIDv4(),
    7000 + number,
    700 + (number % 50),
    multiIf(
        number % 5 = 0, 'Term Life',
        number % 5 = 1, 'Whole Life',
        number % 5 = 2, 'Universal Life',
        number % 5 = 3, 'Variable Life',
        'Endowment'
    ),
    concat('POL-ZSTD-', toString(number)),
    250000.00 + (number % 100) * 10000.00,
    600.00 + (number % 100) * 10.00,
    today() - INTERVAL (number % 1000) DAY,
    multiIf(
        number % 10 = 0, 'Pending',
        number % 20 = 0, 'Lapsed',
        'Active'
    ),
    concat('Policy description for customer ', toString(7000 + number), ' with detailed terms and conditions.')
FROM numbers(10000);

INSERT INTO policies_delta 
SELECT 
    generateUUIDv4(),
    7000 + number,
    700 + (number % 50),
    multiIf(
        number % 5 = 0, 'Term Life',
        number % 5 = 1, 'Whole Life',
        number % 5 = 2, 'Universal Life',
        number % 5 = 3, 'Variable Life',
        'Endowment'
    ),
    concat('POL-DELTA-', toString(number)),
    250000.00 + (number % 100) * 10000.00,
    600.00 + (number % 100) * 10.00,
    today() - INTERVAL (number % 1000) DAY,
    multiIf(
        number % 10 = 0, 'Pending',
        number % 20 = 0, 'Lapsed',
        'Active'
    ),
    concat('Policy description for customer ', toString(7000 + number), ' with detailed terms and conditions.')
FROM numbers(10000);

-- =============================================
-- 4. Comparing Compression Results
-- =============================================

-- Compare compression ratios between different codecs
SELECT 
    table,
    formatReadableSize(sum(bytes_on_disk)) as compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) as compression_ratio,
    sum(rows) as total_rows
FROM system.parts
WHERE database = 'life_insurance'
  AND active = 1
  AND table LIKE 'policies_%'
GROUP BY table
ORDER BY compression_ratio DESC;

-- Detailed column compression comparison
SELECT 
    table,
    column,
    formatReadableSize(sum(column_bytes_on_disk)) as compressed_size,
    round(sum(column_data_uncompressed_bytes) / sum(column_bytes_on_disk), 2) as compression_ratio
FROM system.parts_columns
WHERE database = 'life_insurance'
  AND active = 1
  AND table LIKE 'policies_%'
  AND column IN ('coverage_amount', 'premium_amount', 'description')
GROUP BY table, column
ORDER BY table, column;

-- =============================================
-- 5. Cleanup Test Tables
-- =============================================

-- Drop test tables after analysis
-- DROP TABLE IF EXISTS policies_lz4;
-- DROP TABLE IF EXISTS policies_zstd;  
-- DROP TABLE IF EXISTS policies_delta;


