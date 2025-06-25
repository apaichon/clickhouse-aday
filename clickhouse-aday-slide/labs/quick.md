# ClickHouse Quick Reference Guide

## Table of Contents
- [Sparse Indexes](#sparse-indexes)
- [Skip Indexes](#skip-indexes)
- [Data Types](#data-types)
- [Granularity Settings](#granularity-settings)
- [Bloom Filters](#bloom-filters)
- [Common Functions](#common-functions)
- [Table Engines](#table-engines)
- [Performance Tips](#performance-tips)

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

## Quick Commands

```sql
-- Check table structure
DESCRIBE table_name;

-- Show table engines
SELECT name, engine FROM system.tables WHERE database = 'default';

-- Check indexes
SELECT * FROM system.data_skipping_indices WHERE database = 'default';

-- Monitor queries
SELECT query, elapsed, read_rows FROM system.query_log ORDER BY elapsed DESC LIMIT 10;

-- Check table sizes
SELECT table, sum(bytes_on_disk) as size FROM system.parts GROUP BY table;

-- Optimize table
OPTIMIZE TABLE table_name FINAL;

-- Check projections
SELECT * FROM system.projections WHERE database = 'default';
```

---

## Best Practices Summary

1. **Always use appropriate data types** - Choose smallest type that fits your data
2. **Design partition strategy first** - Time-based partitioning is usually best
3. **Order by most queried columns** - Primary key should match query patterns
4. **Add skip indexes for common filters** - Use minmax for ranges, bloom for equality
5. **Monitor query performance** - Use EXPLAIN and system.query_log
6. **Use materialized views for complex aggregations** - Pre-compute expensive queries
7. **Set appropriate TTL** - Automatically manage data retention
8. **Tune granularity settings** - Balance memory usage vs performance
