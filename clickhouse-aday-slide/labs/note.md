# Materialized View
Tips
1. Create Materilized View
```sql
CREATE MATERIALIZED VIEW daily_policy_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(policy_date)
ORDER BY (policy_date, policy_type, agent_id)
AS
SELECT 
    toDate(effective_date) as policy_date,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE status = 'Active'
GROUP BY policy_date, policy_type, agent_id;
```

2. Refresh Materalized view
```sql
Insert into daily_policy_summary
SELECT 
    toDate(effective_date) as policy_date,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE status = 'Active'
GROUP BY policy_date, policy_type, agent_id;
```
3. Check data.
```sql
select * from daily_policy_summary final
```

4. Insert new data.
```sql
INSERT INTO policies
(policy_id, customer_id, agent_id, policy_number, policy_type, coverage_amount, premium_amount, deductible_amount, effective_date, end_date, status, created_at, updated_at, version)
SELECT
    generateUUIDv4() as policy_id,
    toUInt64(rand() % 100000) as customer_id,
    604 as agent_id,
    'LIFE-' || toString(toYear(now())) || '-' || toString(number) as policy_number,
    'Endowment'  as policy_type,
    round(rand() * 1000000 + 100000, 2) as coverage_amount,
    round(rand() * 5000 + 500, 2) as premium_amount,
    round(rand() * 1000, 2) as deductible_amount,
    '2024-06-25'::Date as effective_date,
    (now() + toIntervalYear(20 + rand() % 20))::Date as end_date,
    CAST(
        multiIf(
            rand() % 10 = 0, 'Pending',
            rand() % 20 = 0, 'Lapsed',
            rand() % 50 = 0, 'Terminated',
            rand() % 100 = 0, 'Matured',
            'Active'
        ) AS Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5)
    ) as status,
    now() as created_at,
    now() as updated_at,
    1 as version
FROM numbers(2);
```




# ClickHouse Table Primary Key: Pros and Cons

## **Tables WITH Primary Key**

### **Pros:**

1. **Query Performance**
   - Faster lookups for specific key values
   - Efficient range queries on primary key columns
   - Better index utilization

2. **Data Organization**
   - Logical data ordering and clustering
   - Predictable data layout on disk
   - Better compression ratios

3. **Optimization Features**
   - Automatic skip index creation
   - Better partition pruning
   - More efficient merges

4. **Query Optimization**
   - Query planner can make better decisions
   - Automatic use of primary key for ORDER BY
   - Better join performance

### **Cons:**

1. **Storage Overhead**
   - Additional index storage
   - Slightly larger table size

2. **Insert Performance**
   - Slight overhead for maintaining order
   - May need to sort data during inserts

3. **Flexibility Limitations**
   - Fixed ordering may not suit all query patterns
   - Harder to change once set

## **Tables WITHOUT Primary Key**

### **Pros:**

1. **Insert Performance**
   - Faster inserts (no ordering required)
   - Lower CPU overhead during writes
   - Better for high-frequency inserts

2. **Storage Efficiency**
   - No index storage overhead
   - Smaller table size
   - Lower memory usage

3. **Flexibility**
   - No fixed ordering constraints
   - Easier to modify table structure
   - Better for append-only workloads

### **Cons:**

1. **Query Performance**
   - Slower lookups and range queries
   - Full table scans for many operations
   - Poor performance for analytical queries

2. **Limited Optimization**
   - No automatic skip indexes
   - Poor partition pruning
   - Inefficient merges

3. **Query Limitations**
   - No automatic ORDER BY optimization
   - Poor join performance
   - Limited query planner optimization

## **When to Use Each Approach**

### **Use Primary Key When:**

```sql
-- Good for analytical queries with specific patterns
CREATE TABLE policies_with_pk
(
    policy_id UUID,
    customer_id UInt64,
    effective_date Date,
    policy_type String,
    coverage_amount Decimal64(2)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(effective_date)
ORDER BY (customer_id, effective_date, policy_type)  -- Primary key
PRIMARY KEY (customer_id, effective_date);  -- Explicit primary key
```

**Use Cases:**
- Analytical workloads with predictable query patterns
- Tables with frequent range queries
- Data that benefits from logical ordering
- Complex joins and aggregations

### **Use No Primary Key When:**

```sql
-- Good for high-frequency inserts and simple queries
CREATE TABLE events_no_pk
(
    event_id UUID,
    event_type String,
    event_data String,
    timestamp DateTime
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY tuple();  -- No primary key
```

**Use Cases:**
- High-frequency event logging
- Append-only workloads
- Simple data collection
- When query patterns are unpredictable

## **Performance Comparison Examples**

### **With Primary Key:**
```sql
-- Fast query due to primary key optimization
SELECT * FROM policies_with_pk
WHERE customer_id = 1001
  AND effective_date >= '2024-01-01'
ORDER BY effective_date;  -- Uses primary key automatically
```

### **Without Primary Key:**
```sql
-- Slower query due to full scan
SELECT * FROM events_no_pk
WHERE event_type = 'policy_created'
  AND timestamp >= '2024-01-01'
ORDER BY timestamp;  -- Requires explicit sorting
```

## **Recommendations**

1. **For Life Insurance Data:**
   - **Use Primary Key** for `policies`, `customers`, `claims` tables
   - Order by frequently queried columns (customer_id, effective_date)

2. **For Event Logging:**
   - **No Primary Key** for audit logs, system events
   - Focus on partition strategy instead

3. **Hybrid Approach:**
   - Use primary keys for main business tables
   - Use no primary key for temporary or staging tables

## **Best Practices**

```sql
-- Recommended for business tables
CREATE TABLE policies
(
    policy_id UUID,
    customer_id UInt64,
    effective_date Date,
    policy_type String,
    coverage_amount Decimal64(2)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(effective_date)
ORDER BY (customer_id, effective_date, policy_type)  -- Logical ordering
PRIMARY KEY (customer_id, effective_date);  -- Most common query pattern
```

**Rule of Thumb:** Use primary keys for tables that support business analytics and reporting, skip them for pure data collection and logging tables.




- quick command
- access control
- generate data
- index
