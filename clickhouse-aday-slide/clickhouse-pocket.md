# ClickHouse Pocket Book - One Day Course

## Session 1: Introduction

### What is ClickHouse?
- **ClickHouse** is an open-source, high-performance column-oriented DBMS developed by Yandex
- Designed for OLAP (Online Analytical Processing) workloads
- Handles petabytes of data with real-time query processing
- Key features:
  - **Columnar storage** - improves compression and query performance
  - **Data compression** - using algorithms such as LZ4 and ZSTD
  - **Parallel processing** - leveraging SIMD instructions and multi-threading
  - **Horizontal scalability** - via sharding and replication
- Ideal for log analytics, event tracking, and real-time dashboards

### Installation & Setup
- **Docker (recommended for labs/dev):**
  ```bash
  # Using docker-compose
  docker-compose --env-file .env up -d
  ```
  
- **docker-compose.yml example:**
  ```yaml
  version: '3.8'
  services:
    clickhouse:
      image: clickhouse/clickhouse-server:latest
      container_name: clickhouse-labs
      ports:
        - "${CLICKHOUSE_PORT:-8123}:8123"       # HTTP port
        - "${CLICKHOUSE_TCP_PORT:-9000}:9000"   # Native port
      volumes:
        - ./data:/var/lib/clickhouse
        - ./logs:/var/log/clickhouse-server
        - ./config/users.xml:/etc/clickhouse-server/users.d/users.xml:ro
      environment:
        - CLICKHOUSE_USER=${CLICKHOUSE_USER:-default}
        - CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD:-default}
        - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
      ulimits:
        nofile:
          soft: 262144
          hard: 262144
  ```

- **Ports:**
  - **8123** (HTTP interface) for REST queries and management
  - **9000** (native TCP) for high-performance native protocol queries

### Important Configuration Files

#### Server Configuration (`config.xml`)
```xml
<!-- Key server settings -->
<clickhouse>
    <!-- Network settings -->
    <listen_host>0.0.0.0</listen_host>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <mysql_port>9004</mysql_port>
    <postgresql_port>9005</postgresql_port>
    
    <!-- Memory settings -->
    <max_server_memory_usage_to_ram_ratio>0.9</max_server_memory_usage_to_ram_ratio>
    <max_memory_usage>10000000000</max_memory_usage> <!-- 10GB -->
    
    <!-- Storage paths -->
    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    
    <!-- Logging -->
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>
    
    <!-- Query processing -->
    <max_concurrent_queries>100</max_concurrent_queries>
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    
    <!-- Background processing -->
    <background_pool_size>16</background_pool_size>
    <background_merges_mutations_concurrency_ratio>2</background_merges_mutations_concurrency_ratio>
    
    <!-- Compression -->
    <compression>
        <case>
            <method>lz4</method>
        </case>
    </compression>
</clickhouse>
```

#### User Configuration (`users.xml`)
```xml
<clickhouse>
    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
        
        <!-- Production user example -->
        <analytics_user>
            <password_sha256_hex><!-- SHA256 hash of password --></password_sha256_hex>
            <networks>
                <ip>10.0.0.0/8</ip>
                <ip>192.168.0.0/16</ip>
            </networks>
            <profile>analytics</profile>
            <quota>analytics_quota</quota>
            <databases>
                <database>analytics_db</database>
            </databases>
        </analytics_user>
    </users>
    
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
        
        <analytics>
            <max_memory_usage>20000000000</max_memory_usage>
            <max_execution_time>3600</max_execution_time>
            <max_query_size>1000000000</max_query_size>
            <max_concurrent_queries_for_user>10</max_concurrent_queries_for_user>
        </analytics>
    </profiles>
    
    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
        
        <analytics_quota>
            <interval>
                <duration>3600</duration>
                <queries>1000</queries>
                <errors>100</errors>
                <result_rows>1000000000</result_rows>
                <read_rows>1000000000</read_rows>
                <execution_time>3600</execution_time>
            </interval>
        </analytics_quota>
    </quotas>
</clickhouse>
```

### Critical Runtime Settings
```sql
-- Memory management
SET max_memory_usage = 10000000000;  -- 10GB per query
SET max_bytes_before_external_group_by = 20000000000;  -- 20GB before spilling to disk
SET max_bytes_before_external_sort = 20000000000;

-- Query optimization
SET max_threads = 8;  -- Number of threads for query processing
SET max_execution_time = 3600;  -- 1 hour timeout
SET send_timeout = 300;
SET receive_timeout = 300;

-- Insert optimization
SET max_insert_block_size = 1048576;  -- Rows per insert block
SET min_insert_block_size_rows = 1048576;
SET min_insert_block_size_bytes = 268435456;  -- 256MB

-- Join settings
SET join_algorithm = 'hash';  -- or 'partial_merge', 'full_sorting_merge'
SET max_bytes_in_join = 1000000000;  -- 1GB for join hash table
SET join_use_nulls = 1;  -- Use NULL for non-matching rows in JOIN

-- Distributed query settings
SET distributed_product_mode = 'global';  -- For distributed JOINs
SET insert_distributed_sync = 1;  -- Synchronous distributed inserts
```

### Why ClickHouse is Fast
- **Column-oriented storage** - only reads columns needed for queries
- **Granule-based architecture** - data organized in granules (~8192 rows)
- **Sparse indexing** - efficient data skipping
- **Vectorized execution** - SIMD instructions for parallel processing
- **Compression** - reduces I/O and memory usage

---

## Session 2: Data Types and Schema Design

### Numeric Types
- **Integers (Signed):**
  - `Int8`, `Int16`, `Int32`, `Int64`, `Int128`, `Int256`
  - Use the smallest type that fits your data for better performance
- **Integers (Unsigned):**
  - `UInt8`, `UInt16`, `UInt32`, `UInt64`, `UInt128`, `UInt256`
  - Example: `UInt8` for flags, `UInt32` for user IDs
- **Floating Point:**
  - `Float32` (single precision), `Float64` (double precision)
  - Be aware of precision issues when comparing floating-point values
- **Decimal:**
  - `Decimal32`, `Decimal64`, `Decimal128`, `Decimal256` (with scale parameter)
  - Ideal for financial data to avoid floating-point inaccuracies
  - Example: `Decimal64(2)` for currency values like $123.45

### String & UUID Types
- **String:** Variable-length UTF-8 encoded string
- **FixedString(N):** Fixed-length string (N bytes), more efficient for constant-length data
- **UUID:** 128-bit unique identifier (use `generateUUIDv4()` to generate)
- **LowCardinality(String):** Optimized for columns with limited distinct values
  - Reduces storage and speeds up queries using dictionary encoding
  - Perfect for statuses, categories, country codes

### Date & Time Types
- **Date:** Calendar date (e.g., `2023-01-01`)
- **Date32:** Extended range date (supports dates beyond 2100)
- **DateTime:** Timestamp (seconds since Unix epoch)
  - Optionally specify timezone: `DateTime('Europe/London')`
- **DateTime64(precision):** High-precision timestamp (microsecond/nanosecond)

### Special Types
- **Enum8/Enum16:** Enumerated types for fixed sets of values
  - Example: `Enum8('pending'=1, 'paid'=2, 'canceled'=3)`
- **IPv4, IPv6:** Native types for IP addresses
- **Nullable(T):** Allows NULL values (use sparingly due to overhead)
- **Array(T):** Ordered list of elements of type T
- **Tuple(T1, T2, ...):** Groups multiple values of different types
- **Map(K,V):** Key-value pairs for flexible, semi-structured data
- **Nested(...):** Nested table structure within a row

### Schema Design Best Practices
- **Denormalization:** Prefer denormalized schemas over normalized ones for analytics
- **Data Type Selection:** Always choose the smallest appropriate data type
- **Partitioning:** Partition large tables by date/time columns
  - Example: `PARTITION BY toYYYYMM(date_column)`
- **ORDER BY:** Choose columns frequently used in WHERE clauses (high to low cardinality)
- **Secondary Indexes:** Use sparingly on non-ORDER BY columns for filtering

---

## Session 3: Basic Operations

### Creating Databases & Tables
```sql
-- Database Creation
CREATE DATABASE chat_payments;
USE chat_payments;

-- Table Creation Example (Messages)
CREATE TABLE messages (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    sent_timestamp DateTime,
    message_type Enum8('text'=1, 'image'=2, 'invoice'=3, 'receipt'=4),
    content String,
    has_attachment UInt8,
    sign Int8,
    INDEX message_type_idx message_type TYPE bloom_filter GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(sent_timestamp)
ORDER BY (message_id, chat_id, sent_timestamp);

-- Payment Attachments Table
CREATE TABLE attachments (
    attachment_id UUID,
    message_id UUID,
    payment_amount Decimal64(2),
    payment_currency LowCardinality(String),
    invoice_date Date,
    payment_status Enum8('pending'=1, 'paid'=2, 'canceled'=3),
    file_path String,
    file_size UInt32,
    uploaded_at DateTime,
    sign Int8,
    INDEX payment_status_idx payment_status TYPE set(0) GRANULARITY 1,
    INDEX currency_idx payment_currency TYPE set(0) GRANULARITY 1
) ENGINE = CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(uploaded_at)
ORDER BY (attachment_id, message_id, uploaded_at);
```

### Table Engines
- **MergeTree:** Base engine for analytical tables with primary key and partitioning
- **ReplacingMergeTree:** Deduplicates rows based on primary key and version column
- **CollapsingMergeTree:** Uses sign column to mark inserted/deleted rows
- **SummingMergeTree:** Pre-aggregates numeric columns during merges
- **AggregatingMergeTree:** Stores intermediate aggregate states

### Table Engine Configuration
```sql
-- MergeTree with custom settings
CREATE TABLE events (
    event_id UUID,
    timestamp DateTime,
    user_id UInt32,
    event_type String,
    properties Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (user_id, timestamp)
SETTINGS 
    index_granularity = 8192,           -- Rows per granule
    index_granularity_bytes = 10485760, -- 10MB per granule
    merge_max_block_size = 8192,
    storage_policy = 'default';

-- ReplacingMergeTree for deduplication
CREATE TABLE user_profiles (
    user_id UInt32,
    username String,
    email String,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY user_id
SETTINGS 
    clean_deleted_rows = 'Always';

-- SummingMergeTree for pre-aggregation
CREATE TABLE daily_stats (
    date Date,
    user_id UInt32,
    page_views UInt64,
    session_duration UInt32
) ENGINE = SummingMergeTree((page_views, session_duration))
PARTITION BY toYYYYMM(date)
ORDER BY (date, user_id);
```

### Inserting Data
```sql
-- Single-row insert (for testing)
INSERT INTO messages VALUES 
(generateUUIDv4(), 100, 1001, now(), 'text', 'Hello', 0, 1);

-- Batch insert (recommended for production)
INSERT INTO messages VALUES
    (generateUUIDv4(), 100, 1001, now(), 'invoice', 'April Invoice', 1, 1),
    (generateUUIDv4(), 100, 1002, now(), 'text', 'Got it, thanks!', 0, 1),
    (generateUUIDv4(), 101, 1003, now(), 'receipt', 'Payment receipt', 1, 1);

-- Insert from SELECT
INSERT INTO messages_backup 
SELECT * FROM messages 
WHERE sent_timestamp >= '2024-01-01';
```

### Basic Querying
```sql
-- Exploratory queries (always use LIMIT)
SELECT * FROM messages LIMIT 5;

-- Filtered queries
SELECT message_id, chat_id, content 
FROM messages 
WHERE message_type = 'invoice' 
  AND sent_timestamp >= '2024-01-01'
LIMIT 100;

-- Aggregation
SELECT 
    message_type, 
    count() as message_count,
    count(DISTINCT chat_id) as unique_chats
FROM messages 
GROUP BY message_type 
ORDER BY message_count DESC;
```

### Performance Tips for Basic Operations
- **Always use LIMIT** when exploring data
- **Avoid SELECT *** in production; specify needed columns
- **Filter on ORDER BY columns** for best performance
- **Use batch inserts** instead of single-row inserts
- **Leverage partition pruning** by filtering on partition columns

---

## Session 4: Advanced Querying - Mastering Complex Analytics

### JOIN Operations
```sql
-- INNER JOIN - Match messages with payment attachments
SELECT m.message_id, m.chat_id, m.user_id, 
       p.payment_amount, p.payment_currency
FROM messages m
INNER JOIN attachments p ON m.message_id = p.message_id;

-- LEFT JOIN - All messages and any payment attachments
SELECT m.message_id, m.content, 
       p.payment_amount, p.payment_status
FROM messages m
LEFT JOIN attachments p ON m.message_id = p.message_id;

-- Multi-table JOIN with filtering
SELECT 
    u.username,
    m.chat_id,
    m.message_type,
    p.payment_amount,
    p.payment_currency
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
JOIN users u ON m.user_id = u.user_id
WHERE p.payment_status = 'paid'
  AND m.sent_timestamp >= '2024-04-01'
ORDER BY p.payment_amount DESC
LIMIT 100;
```

### JOIN Configuration Settings
```sql
-- Optimize JOIN performance
SET join_algorithm = 'hash';                    -- Default, good for most cases
SET join_algorithm = 'partial_merge';           -- For sorted data
SET join_algorithm = 'full_sorting_merge';      -- For large datasets

SET max_bytes_in_join = 1000000000;            -- 1GB limit for hash table
SET join_use_nulls = 1;                        -- Use NULL for non-matching rows
SET max_memory_usage_for_user = 20000000000;   -- 20GB per user

-- Distributed JOIN settings
SET distributed_product_mode = 'global';        -- Broadcast right table
SET prefer_localhost_replica = 1;               -- Use local replica when possible
```

### Window Functions
```sql
-- Running totals by chat
SELECT 
    chat_id,
    sent_timestamp,
    payment_amount,
    sum(payment_amount) OVER (
        PARTITION BY chat_id 
        ORDER BY sent_timestamp 
        ROWS UNBOUNDED PRECEDING
    ) as running_total
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
ORDER BY chat_id, sent_timestamp;

-- Ranking payments by amount
SELECT 
    payment_amount,
    payment_currency,
    row_number() OVER (ORDER BY payment_amount DESC) as rank,
    dense_rank() OVER (PARTITION BY payment_currency ORDER BY payment_amount DESC) as currency_rank
FROM attachments
WHERE payment_status = 'paid';
```

### Common Table Expressions (CTEs)
```sql
WITH payment_summary AS (
    SELECT 
        chat_id,
        count() as payment_count,
        sum(payment_amount) as total_amount,
        avg(payment_amount) as avg_amount
    FROM messages m
    JOIN attachments p ON m.message_id = p.message_id
    WHERE p.payment_status = 'paid'
    GROUP BY chat_id
),
high_value_chats AS (
    SELECT chat_id
    FROM payment_summary
    WHERE total_amount > 10000
)
SELECT 
    ps.chat_id,
    ps.payment_count,
    ps.total_amount,
    ps.avg_amount
FROM payment_summary ps
JOIN high_value_chats hvc ON ps.chat_id = hvc.chat_id
ORDER BY ps.total_amount DESC;
```

### Advanced Analytics Functions
```sql
-- Time-based aggregations
SELECT
    toStartOfMonth(uploaded_at) AS month,
    payment_currency,
    sum(payment_amount) AS total,
    uniq(message_id) AS unique_payments,
    quantile(0.5)(payment_amount) AS median_amount
FROM attachments
WHERE payment_status = 'paid'
GROUP BY month, payment_currency
ORDER BY month DESC, payment_currency;

-- Cohort analysis
SELECT
    toStartOfMonth(first_payment) AS cohort_month,
    dateDiff('month', first_payment, payment_month) AS month_number,
    count(DISTINCT user_id) AS active_users
FROM (
    SELECT 
        user_id,
        min(uploaded_at) OVER (PARTITION BY user_id) AS first_payment,
        toStartOfMonth(uploaded_at) AS payment_month
    FROM messages m
    JOIN attachments p ON m.message_id = p.message_id
    WHERE p.payment_status = 'paid'
) 
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;
```

---

## Session 5: Data Management - Optimizing Operations

### Data Insertion Configuration
```sql
-- Optimal batch settings for high-throughput inserts
SET max_insert_block_size = 1048576;           -- 1M rows per block
SET min_insert_block_size_rows = 1048576;      -- Minimum rows before flush
SET min_insert_block_size_bytes = 268435456;   -- 256MB minimum block size
SET max_insert_threads = 4;                    -- Parallel insert threads

-- Async insert settings (ClickHouse 21.11+)
SET async_insert = 1;
SET wait_for_async_insert = 1;
SET async_insert_timeout_ms = 200;
SET async_insert_max_data_size = 10485760;     -- 10MB buffer

-- Insert deduplication
SET insert_deduplicate = 1;
SET deduplicate_blocks_in_dependent_materialized_views = 1;
```

### Data Insertion Methods
```sql
-- Batch processing with generated data
INSERT INTO messages
SELECT
    generateUUIDv4() as message_id,
    toUInt64(rand() % 1000) as chat_id,
    toUInt32(rand() % 10000) as user_id,
    now() - toIntervalDay(rand() % 30) as sent_timestamp,
    CAST(multiIf(
        rand() % 4 = 0, 'text',
        rand() % 4 = 1, 'image',
        rand() % 4 = 2, 'invoice',
        'receipt'
    ) AS Enum8('text'=1, 'image'=2, 'invoice'=3, 'receipt'=4)) as message_type,
    'Batch generated message ' || toString(number) as content,
    rand() % 2 as has_attachment,
    1 as sign
FROM numbers(1000000);  -- Generate 1 million rows
```

### Data Deduplication
```sql
-- Check for duplicates
SELECT message_id, COUNT(*) as count
FROM messages
GROUP BY message_id
HAVING count > 1
ORDER BY count DESC;

-- Remove duplicates using ReplacingMergeTree
CREATE TABLE messages_deduplicated AS messages
ENGINE = ReplacingMergeTree(sent_timestamp)
ORDER BY (message_id, chat_id);

-- Force merge to apply deduplication
OPTIMIZE TABLE messages_deduplicated FINAL;
```

### Data Compression & Storage
```sql
-- Check compression ratios
SELECT 
    table,
    sum(bytes_on_disk) as compressed_size,
    sum(data_uncompressed_bytes) as uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) as compression_ratio
FROM system.parts
WHERE active = 1
GROUP BY table;

-- Compression codecs
CREATE TABLE compressed_messages (
    message_id UUID CODEC(LZ4),
    content String CODEC(ZSTD(3)),
    sent_timestamp DateTime CODEC(Delta, LZ4)
) ENGINE = MergeTree()
ORDER BY message_id;
```

### Storage Policies Configuration
```xml
<!-- In config.xml -->
<storage_configuration>
    <disks>
        <fast_ssd>
            <path>/fast_ssd/clickhouse/</path>
        </fast_ssd>
        <slow_hdd>
            <path>/slow_hdd/clickhouse/</path>
        </slow_hdd>
    </disks>
    
    <policies>
        <tiered_storage>
            <volumes>
                <hot>
                    <disk>fast_ssd</disk>
                    <max_data_part_size_bytes>1073741824</max_data_part_size_bytes> <!-- 1GB -->
                </hot>
                <cold>
                    <disk>slow_hdd</disk>
                </cold>
            </volumes>
            <move_factor>0.1</move_factor>
        </tiered_storage>
    </policies>
</storage_configuration>
```

### Backup and Restore
```sql
-- Create backup
BACKUP TABLE messages TO Disk('backups', 'messages_backup_2024.zip');

-- Restore from backup
RESTORE TABLE messages FROM Disk('backups', 'messages_backup_2024.zip');

-- Export to file
SELECT * FROM messages 
INTO OUTFILE '/tmp/messages_export.csv'
FORMAT CSV;
```

### Monitoring Data Operations
```sql
-- Monitor recent insertions
SELECT
    query_start_time,
    query_duration_ms,
    read_rows,
    written_rows,
    memory_usage
FROM system.query_log
WHERE query LIKE '%INSERT INTO messages%'
  AND event_time > now() - INTERVAL 1 HOUR
  AND type = 'QueryFinish'
ORDER BY event_time DESC;

-- Check table parts
SELECT
    table,
    partition,
    name,
    rows,
    bytes_on_disk,
    modification_time
FROM system.parts
WHERE active = 1 AND table = 'messages'
ORDER BY modification_time DESC;
```

---

## Session 6: Performance Optimization

### Index Types and Usage

#### Primary Key (Sparse Index)
```sql
-- Primary key defined by ORDER BY
CREATE TABLE optimized_messages (
    message_id UUID,
    chat_id UInt64,
    user_id UInt32,
    sent_timestamp DateTime,
    message_type Enum8('text'=1, 'image'=2, 'invoice'=3, 'receipt'=4),
    content String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(sent_timestamp)
ORDER BY (chat_id, sent_timestamp, message_id)  -- High to low cardinality
SETTINGS 
    index_granularity = 8192,
    index_granularity_bytes = 10485760;
```

#### Secondary Indexes (Skip Indexes)
```sql
-- Bloom filter index for enum values
ALTER TABLE messages 
ADD INDEX message_type_bloom message_type TYPE bloom_filter GRANULARITY 1;

-- Set index for low-cardinality values
ALTER TABLE attachments 
ADD INDEX payment_status_set payment_status TYPE set(0) GRANULARITY 3;

-- MinMax index for numeric ranges
ALTER TABLE attachments 
ADD INDEX amount_minmax payment_amount TYPE minmax GRANULARITY 1;

-- N-gram index for text search
ALTER TABLE messages 
ADD INDEX content_ngram content TYPE ngrambf_v1(3, 256, 2, 0) GRANULARITY 1;
```

### Query Optimization Settings
```sql
-- Memory and performance settings
SET max_memory_usage = 10000000000;            -- 10GB per query
SET max_threads = 8;                           -- Parallel threads
SET max_execution_time = 3600;                 -- Query timeout

-- Query optimization
SET optimize_read_in_order = 1;                -- Read in ORDER BY order
SET optimize_aggregation_in_order = 1;         -- Optimize GROUP BY
SET use_uncompressed_cache = 0;                -- Disable for analytics
SET compile_expressions = 1;                   -- JIT compilation
SET min_count_to_compile_expression = 3;       -- Compile after 3 uses

-- Join optimization
SET join_algorithm = 'hash';
SET max_bytes_in_join = 1000000000;
SET join_use_nulls = 1;

-- GROUP BY optimization
SET group_by_two_level_threshold = 100000;     -- Use two-level aggregation
SET group_by_two_level_threshold_bytes = 50000000;
SET max_bytes_before_external_group_by = 20000000000;  -- Spill to disk
```

### Query Optimization Techniques
```sql
-- Use PREWHERE for early filtering (more efficient than WHERE)
SELECT message_id, content
FROM messages
PREWHERE message_type = 'invoice'
WHERE sent_timestamp >= '2024-01-01'
LIMIT 1000;

-- Optimize GROUP BY with low cardinality first
SELECT 
    payment_currency,  -- Low cardinality first
    toYYYYMM(uploaded_at),
    sum(payment_amount)
FROM attachments
GROUP BY payment_currency, toYYYYMM(uploaded_at);

-- Use SAMPLE for large dataset analysis
SELECT 
    message_type,
    count() * 10 as estimated_total  -- Multiply by sample rate
FROM messages SAMPLE 0.1  -- 10% sample
GROUP BY message_type;
```

### Materialized Views
```sql
-- Create materialized view for daily payment summaries
CREATE MATERIALIZED VIEW daily_payment_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(day)
ORDER BY (day, payment_currency)
AS SELECT
    toDate(uploaded_at) AS day,
    payment_currency,
    sum(payment_amount) AS total_amount,
    count() AS payment_count
FROM attachments
WHERE payment_status = 'paid'
GROUP BY day, payment_currency;

-- Query the materialized view (much faster)
SELECT 
    day,
    payment_currency,
    total_amount
FROM daily_payment_summary
WHERE day >= '2024-01-01'
ORDER BY day DESC, total_amount DESC;
```

### Projections
```sql
-- Create projection for different sort order
ALTER TABLE messages 
ADD PROJECTION user_time_projection (
    SELECT *
    ORDER BY user_id, sent_timestamp
);

-- Materialize the projection
ALTER TABLE messages MATERIALIZE PROJECTION user_time_projection;

-- Queries will automatically use the projection when beneficial
SELECT * FROM messages 
WHERE user_id = 1001 
ORDER BY sent_timestamp 
LIMIT 100;
```

### Performance Monitoring
```sql
-- Analyze query performance
SELECT
    query,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage,
    ProfileEvents['SelectedRows'] as selected_rows,
    ProfileEvents['SelectedBytes'] as selected_bytes
FROM system.query_log
WHERE event_time > now() - INTERVAL 1 HOUR
  AND type = 'QueryFinish'
  AND query_duration_ms > 1000  -- Queries taking more than 1 second
ORDER BY query_duration_ms DESC
LIMIT 10;

-- Check index usage
SELECT
    table,
    name,
    type,
    granularity,
    data_compressed_bytes,
    data_uncompressed_bytes
FROM system.data_skipping_indices
WHERE table IN ('messages', 'attachments');
```

---

## Session 7: Monitoring Scripts

### System Monitoring Queries
```sql
-- Database and table sizes
SELECT
    database,
    table,
    sum(bytes_on_disk) as size_bytes,
    formatReadableSize(sum(bytes_on_disk)) as size_readable,
    sum(rows) as total_rows
FROM system.parts
WHERE active = 1
GROUP BY database, table
ORDER BY size_bytes DESC;

-- Query performance monitoring
SELECT
    toStartOfHour(event_time) as hour,
    count() as query_count,
    avg(query_duration_ms) as avg_duration_ms,
    quantile(0.95)(query_duration_ms) as p95_duration_ms,
    sum(read_bytes) as total_read_bytes
FROM system.query_log
WHERE event_time > now() - INTERVAL 24 HOUR
  AND type = 'QueryFinish'
GROUP BY hour
ORDER BY hour DESC;

-- Memory usage monitoring
SELECT
    event_time,
    CurrentMetric_MemoryTracking as current_memory,
    CurrentMetric_MemoryTrackingForMerges as merge_memory,
    CurrentMetric_BackgroundPoolTask as background_tasks
FROM system.metric_log
WHERE event_time > now() - INTERVAL 1 HOUR
ORDER BY event_time DESC
LIMIT 100;

-- Replication lag (for replicated tables)
SELECT
    database,
    table,
    replica_name,
    log_max_index,
    log_pointer,
    log_max_index - log_pointer as replication_lag
FROM system.replicas
WHERE is_leader = 0;
```

### Grafana Integration Configuration
```yaml
# Grafana datasource configuration
apiVersion: 1
datasources:
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    url: http://clickhouse:8123
    access: proxy
    database: default
    basicAuth: false
    isDefault: true
    jsonData:
      defaultDatabase: chat_payments
      dialTimeout: 10
      queryTimeout: 60
      idleTimeout: 60
    secureJsonData:
      username: default
      password: ""
```

### Grafana Monitoring Queries
```sql
-- Metrics for Grafana dashboards

-- Query rate over time
SELECT
    toStartOfMinute(event_time) as time,
    count() as queries_per_minute
FROM system.query_log
WHERE event_time > now() - INTERVAL 1 HOUR
  AND type = 'QueryFinish'
GROUP BY time
ORDER BY time;

-- Error rate monitoring
SELECT
    toStartOfMinute(event_time) as time,
    countIf(exception != '') as error_count,
    count() as total_queries,
    (error_count / total_queries) * 100 as error_rate_percent
FROM system.query_log
WHERE event_time > now() - INTERVAL 1 HOUR
GROUP BY time
ORDER BY time;

-- Disk usage by table
SELECT
    table,
    sum(bytes_on_disk) as bytes_on_disk,
    sum(rows) as rows
FROM system.parts
WHERE active = 1
  AND database = 'chat_payments'
GROUP BY table;

-- Connection monitoring
SELECT
    toStartOfMinute(event_time) as time,
    uniq(initial_user) as unique_users,
    count() as total_connections
FROM system.session_log
WHERE event_time > now() - INTERVAL 1 HOUR
GROUP BY time
ORDER BY time;
```

### Health Check Scripts
```sql
-- Overall cluster health
SELECT
    'ClickHouse Version' as metric,
    version() as value
UNION ALL
SELECT
    'Uptime (seconds)',
    toString(uptime())
UNION ALL
SELECT
    'Total Databases',
    toString(count())
FROM system.databases
UNION ALL
SELECT
    'Active Parts',
    toString(count())
FROM system.parts
WHERE active = 1;

-- Check for failed parts
SELECT
    database,
    table,
    name,
    reason
FROM system.part_log
WHERE event_type = 'RemovePart'
  AND event_time > now() - INTERVAL 1 DAY
  AND reason LIKE '%Exception%';

-- Check merge performance
SELECT
    database,
    table,
    count() as merge_count,
    avg(duration_ms) as avg_merge_duration,
    sum(bytes_read_uncompressed) as total_bytes_merged
FROM system.part_log
WHERE event_type = 'MergeParts'
  AND event_time > now() - INTERVAL 1 DAY
GROUP BY database, table
ORDER BY avg_merge_duration DESC;
```

### Alert Configuration Examples
```sql
-- Slow query alert (queries > 30 seconds)
SELECT
    count() as slow_query_count
FROM system.query_log
WHERE event_time > now() - INTERVAL 5 MINUTE
  AND type = 'QueryFinish'
  AND query_duration_ms > 30000;

-- High memory usage alert
SELECT
    max(CurrentMetric_MemoryTracking) as max_memory_usage
FROM system.metric_log
WHERE event_time > now() - INTERVAL 5 MINUTE;

-- Replication lag alert
SELECT
    max(log_max_index - log_pointer) as max_replication_lag
FROM system.replicas
WHERE is_leader = 0;

-- Disk space alert
SELECT
    name,
    free_space,
    total_space,
    (free_space / total_space) * 100 as free_space_percent
FROM system.disks
WHERE free_space_percent < 10;  -- Alert when < 10% free space
```

---

## Summary Cheatsheet - Important Functions and Features

### Essential Configuration Settings
```sql
-- Performance settings
SET max_memory_usage = 10000000000;            -- 10GB per query
SET max_threads = 8;                           -- Parallel processing
SET max_execution_time = 3600;                 -- Query timeout
SET join_algorithm = 'hash';                   -- JOIN method
SET optimize_read_in_order = 1;                -- Read optimization

-- Insert settings
SET max_insert_block_size = 1048576;           -- Batch size
SET async_insert = 1;                          -- Async inserts
SET insert_deduplicate = 1;                    -- Deduplication

-- Memory management
SET max_bytes_before_external_group_by = 20000000000;  -- Spill threshold
SET max_bytes_in_join = 1000000000;            -- JOIN memory limit
```

### Essential Functions
```sql
-- Date/Time Functions
now()                           -- Current timestamp
today()                         -- Current date
toYYYYMM(date)                 -- Extract year-month for partitioning
toStartOfMonth(date)           -- First day of month
dateDiff('day', date1, date2)  -- Difference between dates

-- String Functions
length(string)                  -- String length
substring(string, start, len)   -- Extract substring
concat(str1, str2, ...)        -- Concatenate strings
lower(string), upper(string)   -- Case conversion

-- Aggregate Functions
count()                        -- Count rows
sum(column)                    -- Sum values
avg(column)                    -- Average
min(column), max(column)       -- Min/max values
uniq(column)                   -- Count unique values
quantile(0.5)(column)          -- Median (50th percentile)

-- Array Functions
arrayJoin(array)               -- Expand array to rows
arrayMap(func, array)          -- Apply function to array elements
arrayFilter(func, array)       -- Filter array elements
arrayReduce(func, array)       -- Reduce array to single value

-- UUID Functions
generateUUIDv4()               -- Generate random UUID
toUUID(string)                 -- Convert string to UUID

-- Type Conversion
toString(value)                -- Convert to string
toInt32(value)                 -- Convert to integer
toDecimal64(value, scale)      -- Convert to decimal
```

### Performance Best Practices
1. **Data Types:** Use smallest appropriate types
2. **Partitioning:** Partition by date/time columns
3. **ORDER BY:** High to low cardinality columns
4. **Indexes:** Use secondary indexes sparingly
5. **Batch Inserts:** Prefer large batches over single rows
6. **LIMIT:** Always use LIMIT for exploratory queries
7. **Materialized Views:** Pre-aggregate frequently queried data
8. **Compression:** Use appropriate codecs for different data types
9. **Memory Settings:** Configure appropriate memory limits
10. **Monitoring:** Set up proper monitoring and alerting

### Common Configuration Patterns
```sql
-- High-performance analytics workload
SET max_memory_usage = 20000000000;
SET max_threads = 16;
SET optimize_read_in_order = 1;
SET optimize_aggregation_in_order = 1;
SET compile_expressions = 1;

-- High-throughput insert workload
SET max_insert_block_size = 1048576;
SET async_insert = 1;
SET async_insert_timeout_ms = 100;
SET max_insert_threads = 8;

-- Memory-constrained environment
SET max_memory_usage = 2000000000;  -- 2GB
SET max_bytes_before_external_group_by = 1000000000;
SET max_bytes_in_join = 500000000;
SET join_algorithm = 'partial_merge';
```

### Troubleshooting Queries
```sql
-- Find slow queries
SELECT query, query_duration_ms, read_rows, memory_usage
FROM system.query_log
WHERE query_duration_ms > 5000
ORDER BY query_duration_ms DESC
LIMIT 10;

-- Check table statistics
SELECT 
    table,
    sum(rows) as total_rows,
    sum(bytes_on_disk) as size_bytes,
    count() as parts_count
FROM system.parts
WHERE active = 1
GROUP BY table;

-- Monitor current processes
SELECT 
    query_id,
    user,
    query,
    elapsed,
    read_rows,
    memory_usage
FROM system.processes
WHERE query != '';

-- Check configuration
SELECT name, value, changed, description
FROM system.settings
WHERE name LIKE '%memory%' OR name LIKE '%thread%'
ORDER BY name;
```

---
*This pocket book covers the essential ClickHouse concepts, configurations, and operations for the one-day course. For deeper technical details, refer to the full [ClickHouse documentation](https://clickhouse.com/docs).*