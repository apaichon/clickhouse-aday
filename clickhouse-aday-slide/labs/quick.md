# ClickHouse Quick Reference Guide

## Table of Contents
- [Basic Data Types](#basic-data-types)
- [Essential SQL Commands](#essential-sql-commands)
- [JOIN Operations](#join-operations)
- [Window Functions](#window-functions)
- [Common Table Expressions (CTEs)](#common-table-expressions-ctes)
- [Sparse Indexes](#sparse-indexes)
- [Skip Indexes](#skip-indexes)
- [Data Types](#data-types)
- [Granularity Settings](#granularity-settings)
- [Bloom Filters](#bloom-filters)
- [Common Functions](#common-functions)
- [Table Engines](#table-engines)
- [Performance Tips](#performance-tips)
- [EXPLAIN Commands](#explain-commands)
- [System Tables & Monitoring](#system-tables--monitoring)
- [Security & User Management](#security--user-management)
- [Query Optimization Tips](#query-optimization-tips)
- [Backup & Recovery](#backup--recovery)

---

## Basic Data Types

| Category | Type | Size | Range/Description | Use Case |
|----------|------|------|-------------------|----------|
| **Integers** | `UInt8` | 1 byte | 0 to 255 | Status codes, small counters |
| | `UInt16` | 2 bytes | 0 to 65,535 | Port numbers, small IDs |
| | `UInt32` | 4 bytes | 0 to 4.3 billion | User IDs, large counters |
| | `UInt64` | 8 bytes | 0 to 18 quintillion | Primary keys, timestamps |
| | `Int8` | 1 byte | -128 to 127 | Small signed values |
| | `Int16` | 2 bytes | -32,768 to 32,767 | Temperature, small ranges |
| | `Int32` | 4 bytes | ±2.1 billion | Signed IDs, coordinates |
| | `Int64` | 8 bytes | ±9.2 quintillion | Large signed values |
| **Decimals** | `Decimal32(s)` | 4 bytes | 7 digits precision | Prices, rates |
| | `Decimal64(s)` | 8 bytes | 18 digits precision | Financial amounts |
| | `Decimal128(s)` | 16 bytes | 38 digits precision | High precision finance |
| **Strings** | `String` | Variable | UTF-8 text | Names, descriptions |
| | `FixedString(n)` | n bytes | Fixed length text | Codes, hashes |
| **Dates** | `Date` | 2 bytes | 1970-2106 | Birth dates, events |
| | `DateTime` | 4 bytes | 1970-2106 with time | Timestamps |
| | `DateTime64(3)` | 8 bytes | Microsecond precision | High precision time |
| **Special** | `UUID` | 16 bytes | Universally unique ID | Primary keys |
| | `Enum8` | 1 byte | Up to 127 values | Status, categories |
| | `Array(T)` | Variable | Array of type T | Lists, collections |
| | `Nullable(T)` | T + 1 bit | Allows NULL values | Optional fields |

### Data Type Examples

```sql
-- Numeric types
CREATE TABLE example_types (
    id UInt64,                          -- Primary key
    age UInt8,                          -- 0-255, perfect for age
    salary Decimal64(2),                -- Money with 2 decimal places
    score Float32,                      -- Floating point number
    
    -- String types
    name String,                        -- Variable length text
    country_code FixedString(2),        -- Always 2 characters (US, UK, etc.)
    
    -- Date/Time types
    birth_date Date,                    -- Just the date
    created_at DateTime,                -- Date and time
    updated_at DateTime64(3),           -- Millisecond precision
    
    -- Special types
    user_id UUID,                       -- Unique identifier
    status Enum8('Active'=1, 'Inactive'=2, 'Pending'=3),
    tags Array(String),                 -- Array of strings
    middle_name Nullable(String)        -- Optional field
) ENGINE = MergeTree()
ORDER BY id;
```

---

## Essential SQL Commands

| Command | Purpose | Syntax | Example |
|---------|---------|--------|---------|
| **CREATE DATABASE** | Create database | `CREATE DATABASE name` | `CREATE DATABASE life_insurance` |
| **USE** | Select database | `USE database_name` | `USE life_insurance` |
| **CREATE TABLE** | Create table | `CREATE TABLE name (columns) ENGINE = engine` | See examples below |
| **INSERT** | Add data | `INSERT INTO table VALUES (...)` | `INSERT INTO users VALUES (1, 'John')` |
| **SELECT** | Query data | `SELECT columns FROM table WHERE condition` | `SELECT * FROM users WHERE age > 18` |
| **UPDATE** | Modify data | `UPDATE table SET column = value WHERE condition` | Limited in ClickHouse |
| **DELETE** | Remove data | `DELETE FROM table WHERE condition` | Limited in ClickHouse |
| **ALTER** | Modify structure | `ALTER TABLE table ADD/DROP/MODIFY column` | `ALTER TABLE users ADD email String` |
| **DROP** | Remove objects | `DROP TABLE/DATABASE name` | `DROP TABLE old_table` |
| **SHOW** | Display info | `SHOW TABLES/DATABASES/CREATE TABLE` | `SHOW TABLES` |

### SQL Command Examples

```sql
-- Database operations
CREATE DATABASE analytics;
USE analytics;
SHOW DATABASES;

-- Table creation
CREATE TABLE users (
    id UInt64,
    name String,
    email String,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY id;

-- Data insertion
INSERT INTO users VALUES 
    (1, 'John Doe', 'john@example.com', now()),
    (2, 'Jane Smith', 'jane@example.com', now());

-- Batch insert from another table
INSERT INTO users_backup SELECT * FROM users WHERE created_at > '2024-01-01';

-- Basic queries
SELECT * FROM users;
SELECT name, email FROM users WHERE id > 1;
SELECT count() FROM users;

-- Table modifications
ALTER TABLE users ADD COLUMN age UInt8;
ALTER TABLE users DROP COLUMN age;
ALTER TABLE users MODIFY COLUMN name Nullable(String);

-- Table information
SHOW CREATE TABLE users;
DESCRIBE users;
```

---

## JOIN Operations

| JOIN Type | Description | When to Use | Performance |
|-----------|-------------|-------------|-------------|
| **INNER JOIN** | Returns matching rows only | Most common, when you need matching data | Fast |
| **LEFT JOIN** | All rows from left + matching from right | Keep all left records | Medium |
| **RIGHT JOIN** | All rows from right + matching from left | Keep all right records | Medium |
| **FULL JOIN** | All rows from both tables | Complete data set | Slow |
| **CROSS JOIN** | Cartesian product | Rare, be careful with size | Very slow |
| **ASOF JOIN** | Time-series joins | Time-based data matching | Fast for time series |

### JOIN Examples

```sql
-- Sample tables for examples
CREATE TABLE customers (
    customer_id UInt64,
    name String,
    email String
) ENGINE = MergeTree() ORDER BY customer_id;

CREATE TABLE orders (
    order_id UInt64,
    customer_id UInt64,
    amount Decimal64(2),
    order_date Date
) ENGINE = MergeTree() ORDER BY order_id;

-- INNER JOIN - customers who have orders
SELECT c.name, o.amount, o.order_date
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id;

-- LEFT JOIN - all customers, with or without orders
SELECT c.name, c.email, o.amount
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id;

-- RIGHT JOIN - all orders, even if customer data is missing
SELECT c.name, o.amount, o.order_date
FROM customers c
RIGHT JOIN orders o ON c.customer_id = o.customer_id;

-- Multi-table JOIN
SELECT c.name, o.amount, p.product_name
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id;

-- ASOF JOIN for time-series data
SELECT * FROM 
    (SELECT timestamp, price FROM stock_prices) sp
ASOF LEFT JOIN
    (SELECT timestamp, volume FROM trading_volume) tv
ON sp.timestamp >= tv.timestamp;

-- JOIN with aggregation
SELECT 
    c.name,
    count(o.order_id) as total_orders,
    sum(o.amount) as total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name;
```

### JOIN Performance Tips

```sql
-- Pre-filter before joining (better performance)
SELECT c.name, o.amount
FROM (SELECT * FROM customers WHERE country = 'US') c
JOIN (SELECT * FROM orders WHERE amount > 100) o
ON c.customer_id = o.customer_id;

-- Use USING when column names match
SELECT c.name, o.amount
FROM customers c
JOIN orders o USING (customer_id);

-- Join hints for large tables
SELECT c.name, o.amount
FROM customers c
GLOBAL JOIN orders o ON c.customer_id = o.customer_id;
```

---

## Window Functions

| Function Category | Functions | Description | Use Case |
|-------------------|-----------|-------------|----------|
| **Ranking** | `row_number()`, `rank()`, `dense_rank()` | Assign ranks to rows | Top N analysis |
| **Offset** | `lag()`, `lead()`, `first_value()`, `last_value()` | Access other rows | Comparison analysis |
| **Aggregate** | `sum()`, `avg()`, `count()`, `max()`, `min()` | Running calculations | Running totals |
| **Statistical** | `ntile()`, `percent_rank()`, `cume_dist()` | Statistical analysis | Percentiles |

### Window Function Syntax

```sql
function_name([arguments]) OVER (
    [PARTITION BY column1, column2, ...]
    [ORDER BY column1 [ASC|DESC], column2 [ASC|DESC], ...]
    [ROWS|RANGE BETWEEN frame_start AND frame_end]
)
```

### Window Function Examples

```sql
-- Sample data for examples
CREATE TABLE sales (
    id UInt64,
    salesperson String,
    region String,
    amount Decimal64(2),
    sale_date Date
) ENGINE = MergeTree() ORDER BY id;

-- Row numbering and ranking
SELECT 
    salesperson,
    amount,
    row_number() OVER (ORDER BY amount DESC) as row_num,
    rank() OVER (ORDER BY amount DESC) as rank_pos,
    dense_rank() OVER (ORDER BY amount DESC) as dense_rank_pos
FROM sales;

-- Partition by region
SELECT 
    salesperson,
    region,
    amount,
    rank() OVER (PARTITION BY region ORDER BY amount DESC) as region_rank,
    row_number() OVER (PARTITION BY region ORDER BY amount DESC) as region_row
FROM sales;

-- Running totals and averages
SELECT 
    sale_date,
    amount,
    sum(amount) OVER (ORDER BY sale_date ROWS UNBOUNDED PRECEDING) as running_total,
    avg(amount) OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as moving_avg_3day
FROM sales
ORDER BY sale_date;

-- Lag and Lead for comparisons
SELECT 
    sale_date,
    amount,
    lag(amount, 1) OVER (ORDER BY sale_date) as previous_amount,
    lead(amount, 1) OVER (ORDER BY sale_date) as next_amount,
    amount - lag(amount, 1) OVER (ORDER BY sale_date) as change_from_previous
FROM sales
ORDER BY sale_date;

-- Top N per group
SELECT *
FROM (
    SELECT 
        salesperson,
        region,
        amount,
        row_number() OVER (PARTITION BY region ORDER BY amount DESC) as rn
    FROM sales
) ranked
WHERE rn <= 3;  -- Top 3 salespeople per region

-- Percentiles and statistical functions
SELECT 
    salesperson,
    amount,
    ntile(4) OVER (ORDER BY amount) as quartile,
    percent_rank() OVER (ORDER BY amount) as percent_rank,
    cume_dist() OVER (ORDER BY amount) as cumulative_distribution
FROM sales;

-- Window frames
SELECT 
    sale_date,
    amount,
    -- Last 7 days average
    avg(amount) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as avg_7_days,
    -- Month-to-date sum
    sum(amount) OVER (
        PARTITION BY toYYYYMM(sale_date)
        ORDER BY sale_date
        ROWS UNBOUNDED PRECEDING
    ) as mtd_sum
FROM sales;
```

---

## Common Table Expressions (CTEs)

| CTE Type | Syntax | Description | Use Case |
|----------|--------|-------------|----------|
| **Simple CTE** | `WITH cte_name AS (SELECT ...)` | Single temporary result set | Simplify complex queries |
| **Multiple CTEs** | `WITH cte1 AS (...), cte2 AS (...)` | Multiple temporary result sets | Break down complex logic |
| **Recursive CTE** | `WITH RECURSIVE cte AS (...)` | Self-referencing queries | Hierarchical data |
| **CTE in Subquery** | `SELECT * FROM (WITH cte AS ...)` | Nested CTEs | Complex transformations |

### CTE Examples

```sql
-- Simple CTE
WITH high_value_customers AS (
    SELECT customer_id, sum(amount) as total_spent
    FROM orders
    GROUP BY customer_id
    HAVING total_spent > 1000
)
SELECT c.name, hvc.total_spent
FROM customers c
JOIN high_value_customers hvc ON c.customer_id = hvc.customer_id;

-- Multiple CTEs
WITH 
monthly_sales AS (
    SELECT 
        toYYYYMM(order_date) as month,
        sum(amount) as monthly_total
    FROM orders
    GROUP BY month
),
avg_monthly AS (
    SELECT avg(monthly_total) as avg_monthly_sales
    FROM monthly_sales
)
SELECT 
    ms.month,
    ms.monthly_total,
    am.avg_monthly_sales,
    ms.monthly_total - am.avg_monthly_sales as variance
FROM monthly_sales ms
CROSS JOIN avg_monthly am;

-- CTE with window functions
WITH ranked_sales AS (
    SELECT 
        salesperson,
        amount,
        sale_date,
        rank() OVER (PARTITION BY salesperson ORDER BY amount DESC) as rank_in_person
    FROM sales
)
SELECT 
    salesperson,
    amount,
    sale_date
FROM ranked_sales
WHERE rank_in_person <= 3;  -- Top 3 sales per person

-- Complex data transformation with CTE
WITH 
customer_segments AS (
    SELECT 
        customer_id,
        sum(amount) as total_spent,
        count(*) as order_count,
        CASE 
            WHEN sum(amount) > 5000 THEN 'Premium'
            WHEN sum(amount) > 1000 THEN 'Standard'
            ELSE 'Basic'
        END as segment
    FROM orders
    GROUP BY customer_id
),
segment_stats AS (
    SELECT 
        segment,
        count(*) as customer_count,
        avg(total_spent) as avg_spent,
        avg(order_count) as avg_orders
    FROM customer_segments
    GROUP BY segment
)
SELECT 
    segment,
    customer_count,
    round(avg_spent, 2) as avg_spent,
    round(avg_orders, 2) as avg_orders
FROM segment_stats
ORDER BY avg_spent DESC;

-- Recursive CTE for hierarchical data
WITH RECURSIVE employee_hierarchy AS (
    -- Base case: top-level managers
    SELECT 
        employee_id,
        name,
        manager_id,
        1 as level,
        CAST(name AS String) as path
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: employees with managers
    SELECT 
        e.employee_id,
        e.name,
        e.manager_id,
        eh.level + 1,
        eh.path || ' -> ' || e.name
    FROM employees e
    JOIN employee_hierarchy eh ON e.manager_id = eh.employee_id
    WHERE eh.level < 10  -- Prevent infinite recursion
)
SELECT * FROM employee_hierarchy
ORDER BY level, name;

-- CTE for data quality checks
WITH data_quality AS (
    SELECT 
        'customers' as table_name,
        count(*) as total_rows,
        count(DISTINCT customer_id) as unique_ids,
        sum(CASE WHEN email LIKE '%@%' THEN 1 ELSE 0 END) as valid_emails
    FROM customers
    
    UNION ALL
    
    SELECT 
        'orders' as table_name,
        count(*) as total_rows,
        count(DISTINCT order_id) as unique_ids,
        sum(CASE WHEN amount > 0 THEN 1 ELSE 0 END) as valid_amounts
    FROM orders
)
SELECT 
    table_name,
    total_rows,
    unique_ids,
    round((unique_ids / total_rows) * 100, 2) as uniqueness_pct,
    CASE table_name
        WHEN 'customers' THEN round((valid_emails / total_rows) * 100, 2)
        WHEN 'orders' THEN round((valid_amounts / total_rows) * 100, 2)
    END as data_quality_pct
FROM data_quality;
```

---

## Sparse Indexes

| Feature | Description | Example | Use Case |
|---------|-------------|---------|----------|
| **Primary Key** | Main sparse index for table ordering | `ORDER BY (customer_id, date)` | Range queries, lookups |
| **Partition Key** | Divides data into logical partitions | `PARTITION BY toYYYYMM(date)` | Time-based queries |
| **Sparse Storage** | Stores every N-th row (default: 8192) | `SETTINGS index_granularity = 8192` | Memory efficiency |
| **Automatic Creation** | Created automatically with ORDER BY | Built-in with MergeTree | Always available |
| **Query Optimization** | Enables fast range scans | `WHERE customer_id = 1001` | Analytical queries |

---

## Skip Indexes

| Index Type | Description | Syntax | Best For | Granularity |
|------------|-------------|--------|----------|-------------|
| **minmax** | Stores min/max values per granule | `TYPE minmax` | Range queries | 1-8192 |
| **set** | Stores unique values per granule | `TYPE set(max_rows)` | IN queries | 1-8192 |
| **bloom_filter** | Probabilistic membership test | `TYPE bloom_filter` | Equality checks | 1-8192 |
| **tokenbf_v1** | N-gram bloom filter for text | `TYPE tokenbf_v1(size, hashes, seed)` | Text search | 1-8192 |
| **ngrambf_v1** | N-gram bloom filter | `TYPE ngrambf_v1(n, size, hashes, seed)` | Substring search | 1-8192 |

### Skip Index Examples

```sql
-- MinMax index for range queries
ALTER TABLE policies ADD INDEX idx_coverage coverage_amount TYPE minmax GRANULARITY 4;

-- Set index for IN queries
ALTER TABLE policies ADD INDEX idx_status status TYPE set(10) GRANULARITY 1;

-- Bloom filter for equality
ALTER TABLE policies ADD INDEX idx_policy_number policy_number TYPE bloom_filter GRANULARITY 1;

-- Text search index
ALTER TABLE documents ADD INDEX idx_content content TYPE tokenbf_v1(512, 3, 0) GRANULARITY 4;
```

---

## Data Types

| Category | Type | Size | Description | Example |
|----------|------|------|-------------|---------|
| **Integers** | `UInt8` | 1 byte | 0 to 255 | `UInt8(255)` |
| | `UInt16` | 2 bytes | 0 to 65,535 | `UInt16(1000)` |
| | `UInt32` | 4 bytes | 0 to 4,294,967,295 | `UInt32(1000000)` |
| | `UInt64` | 8 bytes | 0 to 18,446,744,073,709,551,615 | `UInt64(1000000000)` |
| | `Int8` | 1 byte | -128 to 127 | `Int8(-100)` |
| | `Int16` | 2 bytes | -32,768 to 32,767 | `Int16(-1000)` |
| | `Int32` | 4 bytes | -2,147,483,648 to 2,147,483,647 | `Int32(-1000000)` |
| | `Int64` | 8 bytes | -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807 | `Int64(-1000000000)` |
| **Floating Point** | `Float32` | 4 bytes | Single precision | `Float32(3.14)` |
| | `Float64` | 8 bytes | Double precision | `Float64(3.14159)` |
| **Decimal** | `Decimal32(s)` | 4 bytes | Fixed-point decimal | `Decimal32(2)` |
| | `Decimal64(s)` | 8 bytes | Fixed-point decimal | `Decimal64(2)` |
| | `Decimal128(s)` | 16 bytes | Fixed-point decimal | `Decimal128(2)` |
| **Strings** | `String` | Variable | UTF-8 string | `String('Hello')` |
| | `FixedString(n)` | Fixed n bytes | Fixed-length string | `FixedString(10)` |
| **Date/Time** | `Date` | 2 bytes | Date (1970-2106) | `Date('2024-01-01')` |
| | `DateTime` | 4 bytes | DateTime (1970-2106) | `DateTime('2024-01-01 12:00:00')` |
| | `DateTime64` | 8 bytes | DateTime with precision | `DateTime64(3, 'UTC')` |
| **Special** | `UUID` | 16 bytes | UUID | `UUID('550e8400-e29b-41d4-a716-446655440000')` |
| | `Enum8` | 1 byte | Enumeration | `Enum8('Active' = 1, 'Inactive' = 2)` |
| | `Enum16` | 2 bytes | Enumeration | `Enum16('Small' = 1, 'Medium' = 2, 'Large' = 3)` |
| | `Array(T)` | Variable | Array of type T | `Array(String)` |
| | `Nullable(T)` | T + 1 byte | Nullable type | `Nullable(String)` |

---

## Granularity Settings

| Setting | Default | Description | Impact | Use Case |
|---------|---------|-------------|--------|----------|
| **index_granularity** | 8192 | Rows per sparse index entry | Memory vs Performance | General purpose |
| **min_bytes_for_wide_part** | 10MB | Minimum size for wide format | Storage format | Large tables |
| **min_rows_for_wide_part** | 8192 | Minimum rows for wide format | Storage format | Large tables |
| **max_bytes_before_external_group_by** | 2GB | External group by threshold | Memory usage | Large aggregations |
| **max_bytes_before_external_sort** | 2GB | External sort threshold | Memory usage | Large sorts |
| **max_memory_usage** | 10GB | Maximum memory per query | Query limits | Resource control |

### Granularity Examples

```sql
-- High performance, more memory
CREATE TABLE fast_table
(
    id UInt64,
    data String
)
ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 1024;  -- Smaller granules

-- Memory efficient, slower queries
CREATE TABLE memory_efficient_table
(
    id UInt64,
    data String
)
ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 16384;  -- Larger granules
```

---

## Bloom Filters

| Feature | Description | Syntax | Use Case | Performance |
|---------|-------------|--------|----------|-------------|
| **Standard Bloom Filter** | Probabilistic membership test | `TYPE bloom_filter` | Equality checks | Very fast |
| **Token Bloom Filter** | N-gram based text search | `TYPE tokenbf_v1(size, hashes, seed)` | Text search | Fast |
| **N-gram Bloom Filter** | Substring search | `TYPE ngrambf_v1(n, size, hashes, seed)` | Substring search | Fast |
| **False Positive Rate** | ~1% with default settings | Configurable | Accuracy vs Speed | Tunable |
| **Memory Usage** | ~10 bits per element | Size parameter | Storage efficiency | Configurable |

### Bloom Filter Examples

```sql
-- Standard bloom filter for equality
ALTER TABLE policies ADD INDEX idx_policy_number 
    policy_number TYPE bloom_filter GRANULARITY 1;

-- Token bloom filter for text search
ALTER TABLE documents ADD INDEX idx_content 
    content TYPE tokenbf_v1(512, 3, 0) GRANULARITY 4;

-- N-gram bloom filter for substring search
ALTER TABLE documents ADD INDEX idx_content_ngram 
    content TYPE ngrambf_v1(3, 256, 2, 0) GRANULARITY 4;

-- High precision bloom filter
ALTER TABLE users ADD INDEX idx_email 
    email TYPE bloom_filter(0.01) GRANULARITY 1;  -- 1% false positive rate
```

---

## Common Functions

| Category | Function | Description | Example |
|----------|----------|-------------|---------|
| **Aggregation** | `count()` | Count rows | `count()` |
| | `sum()` | Sum values | `sum(amount)` |
| | `avg()` | Average | `avg(price)` |
| | `uniq()` | Approximate unique count | `uniq(user_id)` |
| | `quantile()` | Quantile | `quantile(0.95)(amount)` |
| **Date/Time** | `now()` | Current timestamp | `now()` |
| | `today()` | Current date | `today()` |
| | `toYYYYMM()` | Year-Month | `toYYYYMM(date)` |
| | `toStartOfMonth()` | Start of month | `toStartOfMonth(date)` |
| | `dateDiff()` | Date difference | `dateDiff('day', start, end)` |
| **String** | `length()` | String length | `length(name)` |
| | `substring()` | Substring | `substring(text, 1, 10)` |
| | `like()` | Pattern matching | `name LIKE '%John%'` |
| | `position()` | Find substring | `position('abc', text)` |
| **Type Conversion** | `toString()` | To string | `toString(number)` |
| | `toInt32()` | To integer | `toInt32(string)` |
| | `toDate()` | To date | `toDate(timestamp)` |
| | `toDateTime()` | To datetime | `toDateTime(date)` |

---

## Table Engines

| Engine | Description | Use Case | Pros | Cons |
|--------|-------------|----------|------|------|
| **MergeTree** | Default analytical engine | General purpose | Fast queries, good compression | Complex configuration |
| **ReplacingMergeTree** | Deduplicates by version | Versioned data | Automatic deduplication | Version column required |
| **SummingMergeTree** | Aggregates numeric columns | Aggregated data | Automatic aggregation | Limited to numeric columns |
| **AggregatingMergeTree** | Flexible aggregation | Complex aggregations | Flexible aggregation | Complex query syntax |
| **CollapsingMergeTree** | Handles sign columns | Change data capture | Efficient for CDC | Requires sign column |
| **VersionedCollapsingMergeTree** | Versioned collapsing | Complex CDC | Version support | Complex setup |

---

## Performance Tips

| Tip | Description | Impact | Example |
|-----|-------------|--------|---------|
| **Partition Strategy** | Use time-based partitioning | High | `PARTITION BY toYYYYMM(date)` |
| **Order Key** | Order by most queried columns | High | `ORDER BY (customer_id, date)` |
| **Skip Indexes** | Add indexes for common filters | Medium | `ADD INDEX idx_status status TYPE set(10)` |
| **Granularity** | Tune index granularity | Medium | `SETTINGS index_granularity = 4096` |
| **Data Types** | Use smallest appropriate type | Medium | `UInt8` instead of `UInt64` |
| **Compression** | Use appropriate compression | Low | `CODEC(ZSTD(3))` |
| **TTL** | Set data retention | Low | `TTL date + INTERVAL 1 YEAR` |

---

## EXPLAIN Commands

| Command | Description | Use Case | Example |
|---------|-------------|----------|---------|
| **EXPLAIN** | Basic query execution plan | Understanding query flow | `EXPLAIN SELECT * FROM table WHERE id = 1` |
| **EXPLAIN indexes = 1** | Detailed index usage information | Index optimization | `EXPLAIN indexes = 1 SELECT * FROM claims WHERE status = 'Approved'` |
| **EXPLAIN pipeline** | Shows execution pipeline | Performance analysis | `EXPLAIN pipeline SELECT customer_id, count() FROM policies GROUP BY customer_id` |
| **EXPLAIN query tree** | Query structure analysis | Complex query debugging | `EXPLAIN query tree SELECT ... FROM ... JOIN ...` |
| **EXPLAIN SYNTAX** | Shows optimized query | Query rewrite analysis | `EXPLAIN SYNTAX SELECT * FROM table WHERE condition` |

### EXPLAIN Examples

```sql
-- Check if indexes are being used
EXPLAIN indexes = 1
SELECT * FROM policies WHERE customer_id = 1001 AND status = 'Active';

-- Analyze JOIN performance
EXPLAIN pipeline
SELECT p.policy_id, c.claim_amount
FROM policies p
JOIN claims c ON p.policy_id = c.policy_id;

-- Check query optimization
EXPLAIN SYNTAX
SELECT customer_id, sum(premium_amount)
FROM policies 
WHERE effective_date >= '2024-01-01'
GROUP BY customer_id;
```

---

## System Tables & Monitoring

| System Table | Description | Key Columns | Use Case |
|--------------|-------------|-------------|-----------|
| **system.query_log** | Query execution history | `query`, `query_duration_ms`, `read_rows`, `memory_usage` | Performance monitoring |
| **system.parts** | Table parts information | `table`, `rows`, `bytes_on_disk`, `modification_time` | Storage analysis |
| **system.data_skipping_indices** | Skip index information | `table`, `name`, `type`, `granularity` | Index management |
| **system.tables** | Table metadata | `database`, `table`, `engine`, `total_rows` | Schema analysis |
| **system.columns** | Column information | `table`, `name`, `type`, `default_expression` | Schema exploration |
| **system.quota_usage** | Resource usage by user | `user`, `quota_name`, `queries`, `errors` | Resource monitoring |
| **system.processes** | Active queries | `query_id`, `user`, `elapsed`, `query` | Live monitoring |

### Monitoring Examples

```sql
-- Monitor slow queries
SELECT 
    query_id,
    user,
    query_duration_ms,
    read_rows,
    memory_usage,
    query
FROM system.query_log
WHERE query_duration_ms > 10000
  AND event_time > now() - INTERVAL 1 HOUR
  AND type = 'QueryFinish'
ORDER BY query_duration_ms DESC
LIMIT 10;

-- Check table sizes and compression
SELECT 
    table,
    sum(rows) as total_rows,
    formatReadableSize(sum(bytes_on_disk)) as size_on_disk,
    formatReadableSize(sum(data_compressed_bytes)) as compressed_size,
    round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes) * 100, 2) as compression_ratio
FROM system.parts
WHERE active = 1
GROUP BY table
ORDER BY sum(bytes_on_disk) DESC;

-- Monitor index effectiveness
SELECT 
    database,
    table,
    name as index_name,
    type,
    granularity
FROM system.data_skipping_indices
WHERE database = 'life_insurance'
ORDER BY table, name;

-- Check active queries
SELECT 
    query_id,
    user,
    elapsed,
    formatReadableSize(memory_usage) as memory,
    query
FROM system.processes
WHERE query != ''
ORDER BY elapsed DESC;
```

---

## Security & User Management

| Command Type | Description | Syntax | Example |
|--------------|-------------|--------|---------|
| **CREATE USER** | Create new user | `CREATE USER name IDENTIFIED BY 'password'` | `CREATE USER analyst IDENTIFIED BY 'SecurePass123'` |
| **CREATE ROLE** | Create role | `CREATE ROLE role_name` | `CREATE ROLE insurance_agent` |
| **GRANT** | Grant permissions | `GRANT privilege ON database.table TO user` | `GRANT SELECT ON life_insurance.* TO analyst` |
| **REVOKE** | Revoke permissions | `REVOKE privilege ON database.table FROM user` | `REVOKE INSERT ON policies FROM temp_user` |
| **CREATE QUOTA** | Resource limits | `CREATE QUOTA name FOR INTERVAL time MAX queries = n` | See examples below |
| **ROW POLICY** | Row-level security | `CREATE ROW POLICY name ON table FOR SELECT USING condition` | See examples below |

### Security Examples

```sql
-- Create users with different access levels
CREATE USER insurance_agent 
IDENTIFIED WITH sha256_password BY 'StrongPassword123!'
HOST IP '10.0.0.0/8'
SETTINGS readonly = 1, max_memory_usage = 2000000000;

-- Create hierarchical roles
CREATE ROLE base_user_role 
SETTINGS readonly = 1, max_execution_time = 300;

CREATE ROLE agent_role 
SETTINGS max_memory_usage = 1000000000;

GRANT base_user_role TO agent_role;

-- Grant specific permissions
GRANT SELECT ON life_insurance.policies TO agent_role;
GRANT SELECT, INSERT ON life_insurance.claims TO agent_role;
GRANT ALL ON life_insurance.* TO admin_role;

-- Create resource quotas
CREATE QUOTA agent_quota 
FOR INTERVAL 1 HOUR MAX queries = 1000, errors = 100, result_rows = 10000000
FOR INTERVAL 1 DAY MAX queries = 5000, errors = 200, result_rows = 50000000
TO agent_role;

-- Row-level security - Agent access to their own policies
CREATE ROW POLICY agent_data_isolation ON life_insurance.policies
FOR SELECT USING agent_id IN (
    SELECT agent_id FROM life_insurance.agents 
    WHERE email = currentUser() AND is_active = 1
)
TO agent_role;

-- Customer data access restriction for agents
CREATE ROW POLICY agent_customer_access ON life_insurance.customers
FOR SELECT USING customer_id IN (
    SELECT DISTINCT customer_id FROM life_insurance.policies 
    WHERE agent_id IN (
        SELECT agent_id FROM life_insurance.agents 
        WHERE email = currentUser() AND is_active = 1
    )
)
TO agent_role;

-- Claims access based on policy ownership
CREATE ROW POLICY agent_claims_access ON life_insurance.claims
FOR SELECT USING policy_id IN (
    SELECT policy_id FROM life_insurance.policies 
    WHERE agent_id IN (
        SELECT agent_id FROM life_insurance.agents 
        WHERE email = currentUser() AND is_active = 1
    )
)
TO agent_role;

-- Territory-based access for OIC (Officers in Charge)
CREATE ROW POLICY oic_territory_access ON life_insurance.policies
FOR SELECT USING agent_id IN (
    SELECT a.agent_id 
    FROM life_insurance.agents a
    JOIN life_insurance.oic o ON a.territory = o.region
    WHERE o.email = currentUser() AND o.is_active = 1
)
TO oic_role;

-- Simple territory-based access using agent's territory directly
CREATE ROW POLICY agent_territory_simple ON life_insurance.policies
FOR SELECT USING agent_id IN (
    SELECT agent_id FROM life_insurance.agents 
    WHERE territory = (
        SELECT territory FROM life_insurance.agents 
        WHERE email = currentUser() AND is_active = 1
        LIMIT 1
    )
    AND is_active = 1
)
TO territory_manager_role;

-- Time-based access for recent data only
CREATE ROW POLICY recent_data_policy ON life_insurance.claims
FOR SELECT USING 
    reported_date >= now() - INTERVAL 90 DAY
    AND claim_status IN ('Reported', 'Under Review', 'Approved')
TO junior_adjuster_role;

-- Monitor user activities
SELECT 
    user,
    query_start_time,
    query_duration_ms,
    read_rows,
    query
FROM system.query_log 
WHERE user = 'insurance_agent'
  AND event_time > now() - INTERVAL 1 DAY
ORDER BY query_start_time DESC;
```

---

## Query Optimization Tips

| Tip Category | Description | Bad Example | Good Example |
|--------------|-------------|-------------|--------------|
| **Filter Order** | Put indexed filters first | `WHERE type = 'A' AND id = 1` | `WHERE id = 1 AND type = 'A'` |
| **Function Usage** | Avoid functions on indexed columns | `WHERE toDate(timestamp) = '2024-01-01'` | `WHERE timestamp >= '2024-01-01' AND timestamp < '2024-01-02'` |
| **IN Clauses** | Use arrays for large IN lists | `WHERE id IN (1,2,3...1000)` | `WITH [1,2,3...1000] AS ids SELECT * WHERE id IN ids` |
| **JOINs** | Filter before joining | `SELECT * FROM a JOIN b ON ... WHERE a.x = 1` | `SELECT * FROM (SELECT * FROM a WHERE x = 1) JOIN b ON ...` |
| **SELECT** | Avoid SELECT * | `SELECT * FROM table` | `SELECT id, name FROM table` |
| **Partitioning** | Use partition functions | `WHERE date = '2024-01-01'` | `WHERE toYYYYMM(date) = 202401` |

### Optimization Examples

```sql
-- Efficient filtering with primary key first
SELECT count(*) FROM policies
WHERE customer_id = 1001          -- Primary key first
  AND effective_date >= '2024-01-01'  -- Primary key second
  AND policy_type = 'Term Life';      -- Secondary filter last

-- Partition pruning for better performance
SELECT count(*) FROM claims
WHERE toYYYYMM(reported_date) = 202401  -- Partition pruning
  AND claim_status = 'Approved'
SETTINGS force_optimize_skip_unused_shards = 1;

-- Optimize large IN clauses
WITH [1001, 1002, 1003, 1004, 1005] as customer_ids
SELECT * FROM policies
WHERE customer_id IN customer_ids;

-- Pre-filter before JOINs
SELECT p.policy_number, c.claim_amount
FROM (
    SELECT policy_id, policy_number 
    FROM policies 
    WHERE customer_id = 1001
) p
JOIN (
    SELECT policy_id, claim_amount 
    FROM claims 
    WHERE claim_status = 'Approved'
) c ON p.policy_id = c.policy_id;
```

---

## Backup & Recovery

| Command | Description | Use Case | Example |
|---------|-------------|----------|---------|
| **BACKUP** | Create backup | Database backup | `BACKUP DATABASE life_insurance TO Disk('backups', 'backup_20240125.zip')` |
| **RESTORE** | Restore from backup | Database restore | `RESTORE DATABASE life_insurance FROM Disk('backups', 'backup_20240125.zip')` |
| **FREEZE** | Create partition snapshot | Table-level backup | `ALTER TABLE policies FREEZE PARTITION '202401'` |
| **ATTACH/DETACH** | Manage table parts | Maintenance operations | `ALTER TABLE policies DETACH PARTITION '202401'` |

### Backup Examples

```sql
-- Full database backup
BACKUP DATABASE life_insurance TO Disk('backups', 'full_backup_20240125.zip');

-- Table-specific backup
BACKUP TABLE life_insurance.policies TO Disk('backups', 'policies_backup.zip');

-- Incremental backup with specific partitions
BACKUP TABLE life_insurance.claims PARTITIONS '202401', '202402' 
TO Disk('backups', 'claims_q1_2024.zip');

-- Restore operations
RESTORE DATABASE life_insurance FROM Disk('backups', 'full_backup_20240125.zip');

-- Freeze partition for manual backup
ALTER TABLE policies FREEZE PARTITION '202401';

-- Check backup status
SELECT * FROM system.backups;
```

---

## Quick Commands

```sql
-- Check table structure
DESCRIBE table_name;
SHOW CREATE TABLE table_name;

-- Show table engines and basic info
SELECT name, engine, total_rows, total_bytes FROM system.tables WHERE database = 'life_insurance';

-- Check indexes
SELECT database, table, name, type, granularity FROM system.data_skipping_indices WHERE database = 'life_insurance';

-- Monitor recent queries
SELECT query_start_time, query_duration_ms, read_rows, query FROM system.query_log 
WHERE event_time > now() - INTERVAL 1 HOUR AND type = 'QueryFinish'
ORDER BY query_duration_ms DESC LIMIT 10;

-- Check table sizes and compression
SELECT table, formatReadableSize(sum(bytes_on_disk)) as size, 
       round(sum(data_compressed_bytes)/sum(data_uncompressed_bytes)*100,2) as compression_ratio
FROM system.parts WHERE active = 1 GROUP BY table ORDER BY sum(bytes_on_disk) DESC;

-- Optimize table (force merge)
OPTIMIZE TABLE table_name FINAL;

-- Check active processes
SELECT query_id, user, elapsed, formatReadableSize(memory_usage) as memory, query 
FROM system.processes WHERE query != '';

-- Show users and roles
SHOW USERS;
SHOW ROLES;
SHOW GRANTS FOR current_user;

-- Database and schema info
SHOW DATABASES;
SHOW TABLES FROM database_name;
SELECT database, table, engine FROM system.tables WHERE database != 'system';

-- Resource monitoring
SELECT user, quota_name, queries, errors, result_rows FROM system.quota_usage;

-- Kill long-running query
KILL QUERY WHERE query_id = 'query-id-here';

-- Check cluster status (for distributed setups)
SELECT * FROM system.clusters;
SELECT * FROM system.replicas;
```

---

## Best Practices Summary

1. **Always use appropriate data types** - Choose smallest type that fits your data
2. **Design partition strategy first** - Time-based partitioning is usually best  
3. **Order by most queried columns** - Primary key should match query patterns
4. **Add skip indexes for common filters** - Use minmax for ranges, bloom for equality
5. **Monitor query performance regularly** - Use EXPLAIN and system.query_log
6. **Use materialized views for complex aggregations** - Pre-compute expensive queries
7. **Set appropriate TTL** - Automatically manage data retention
8. **Tune granularity settings** - Balance memory usage vs performance
9. **Implement proper security** - Use roles, quotas, and row-level security
10. **Regular backup strategy** - Implement automated backup and recovery procedures
11. **Monitor resource usage** - Set appropriate memory and execution time limits
12. **Optimize queries before indexes** - Good query structure beats complex indexing
