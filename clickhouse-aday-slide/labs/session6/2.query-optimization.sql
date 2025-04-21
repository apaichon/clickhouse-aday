-- View the query execution plan
EXPLAIN SELECT * FROM chat_payments.attachments WHERE payment_status = 'paid';
-- More detailed explain with settings
EXPLAIN pipeline 
SELECT
    user_id,
    count() AS message_count,
    sum(if(message_type = 'invoice', 1, 0)) AS invoice_count
FROM chat_payments.messages
WHERE chat_id IN (100, 101, 102)
GROUP BY user_id

EXPLAIN query tree
SELECT
    user_id,
    count() AS message_count,
    sum(if(message_type = 'invoice', 1, 0)) AS invoice_count
FROM chat_payments.messages
WHERE chat_id IN (100, 101, 102)
GROUP BY user_id



# Optimizing WHERE Clauses

<div class="grid grid-cols-2 gap-4" style="height:400px;overflow-y:auto;">
<div>

## Filter Optimization Principles

-- Bad: Non-indexed filter first
SELECT count(*) FROM messages
WHERE message_type = 'invoice'
  AND chat_id = 100
  AND sent_timestamp >= '2023-04-01';

-- Good: Primary key columns first
SELECT count(*) FROM messages
WHERE chat_id = 100
  AND sent_timestamp >= '2023-04-01'
  AND message_type = 'invoice';

-- Avoid transformations on indexed columns
-- Bad:
SELECT count(*) FROM messages
WHERE toDate(sent_timestamp) = '2023-04-01';
-- Good:
SELECT count(*) FROM messages
WHERE sent_timestamp >= '2023-04-01 00:00:00'
  AND sent_timestamp < '2023-04-02 00:00:00';


## Partition Pruning
-- Efficient: Scans only specific partitions
SELECT * FROM messages
WHERE toYYYYMM(sent_timestamp) = 202304
  AND chat_id = 100;

/*SELECT * FROM messages
WHERE  chat_id = 100
AND sent_timestamp >= '2023-04-01 00:00:00'
  AND sent_timestamp < '2023-04-30 00:00:00';*/

-- Force partition pruning
SELECT count(*) FROM attachments
WHERE toYYYYMM(uploaded_at) = 202304
SETTINGS force_optimize_skip_unused_shards = 1;


## IN Clause Optimization

-- Optimize large IN lists
-- Bad: Large inline list
SELECT count(*) FROM messages
WHERE chat_id IN (
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
    /* hundreds more values */
);

-- Better: Use a temporary table
WITH [100, 101, 102, 103, 104, 105, 106, 107, 108, 109] as ids
SELECT count(*) FROM messages
WHERE chat_id IN ids;


# JOIN Optimization


## JOIN Strategies

-- Filter before joining
SELECT m.chat_id, p.payment_amount
FROM (
    SELECT * FROM messages 
    WHERE chat_id = 100 
) AS m
JOIN attachments p ON m.message_id = p.message_id;


-- Use JOIN hints
SELECT m.chat_id, p.payment_amount
FROM messages m
JOIN /* LOCAL */ attachments p
ON m.message_id = p.message_id
WHERE m.chat_id = 100;


-- ASOF JOIN for time-based matching
SELECT m.user_id, m.sent_timestamp, p.payment_amount
FROM messages m
ASOF JOIN attachments p
ON m.user_id = p.user_id
AND m.sent_timestamp >= p.uploaded_at
WHERE m.message_type = 'receipt';



## JOIN Algorithm Selection

-- Hash join (default, good for equality joins)
SELECT   toDate(invoice_date) invoice_date ,sum(payment_amount) total_amount, payment_currency FROM messages m
JOIN attachments p ON m.message_id = p.message_id
group by invoice_date, payment_currency
SETTINGS join_algorithm = 'hash';

-- Grace hash join (for large tables)
SELECT   toDate(invoice_date) invoice_date ,sum(payment_amount) total_amount, payment_currency FROM messages m
JOIN attachments p ON m.message_id = p.message_id
group by invoice_date, payment_currency
SETTINGS join_algorithm = 'grace_hash';

SELECT   toDate(invoice_date) invoice_date ,sum(payment_amount) total_amount, payment_currency FROM messages m
JOIN attachments p ON m.message_id = p.message_id
group by invoice_date, payment_currency
SETTINGS join_algorithm = 'parallel_hash';


## Memory Management for JOINs

-- Limit memory for large joins
SET max_bytes_in_join = 1000000000; -- 1GB
SET join_overflow_mode = 'break';
SET max_joined_block_size_rows = 500000;

-- For distributed queries
SET distributed_product_mode = 'local';
SET optimize_skip_unused_shards = 1;
SET optimize_distributed_group_by_sharding_key = 1;


# Aggregation and GROUP BY Optimization
## Efficient Aggregation
-- Use specialized aggregate functions
-- For approximate distinct counts
SELECT uniq(user_id) FROM messages;
-- Instead of: SELECT count(DISTINCT user_id) FROM messages;

-- For quantiles
SELECT quantileTDigest(0.95)(toFloat64(payment_amount)) FROM attachments;

-- Instead of sorting and manual calculation

-- Combine multiple aggregations
SELECT
    payment_status,
    count() AS count,
    sum(payment_amount) AS total,
    round(avg(payment_amount), 2) AS average
FROM attachments
GROUP BY payment_status;



## GROUP BY Optimization
-- Leverage ORDER BY for grouped data
SELECT
    chat_id,
    toDate(sent_timestamp) AS date,
    count() AS message_count
FROM messages
WHERE chat_id IN (100, 101, 102)
GROUP BY chat_id, date
ORDER BY chat_id, date;

-- Use WITH TOTALS for summary rows
SELECT
    payment_currency,
    payment_status,
    sum(payment_amount) AS total
FROM attachments
GROUP BY payment_currency, payment_status
WITH TOTALS
ORDER BY payment_currency, payment_status;


## Memory Settings for Aggregation
-- Control memory usage for aggregations
SET max_bytes_before_external_group_by = 2000000000;
SET group_by_overflow_mode = 'any';
```



# Other Query Optimization Techniques

## LIMIT Optimization
```sql{all|1-5|7-12|all}
-- Use LIMIT with ORDER BY
SELECT * FROM messages
WHERE chat_id = 100
ORDER BY sent_timestamp DESC
LIMIT 100;

-- Using LIMIT BY for top-N per group
SELECT
    user_id,
    sent_timestamp,
    content
FROM messages
ORDER BY user_id, sent_timestamp DESC
LIMIT 5 BY user_id;


## Optimizing String Operations
-- Avoid expensive string operations
-- Bad
SELECT count(*) FROM messages WHERE content LIKE '%payment%';

-- Better - use a secondary index
-- tokenbf_v1(size_of_bloom_filter_in_bytes, number_of_hash_functions, random_seed)

ALTER TABLE messages
ADD INDEX content_idx content TYPE tokenbf_v1(512, 3, 0)
GRANULARITY 4;

DROP INDEX content_idx ON messages;



## Query Cache
-- Enable query cache (if supported in your version)
SET use_query_cache = 1;
SET query_cache_min_query_duration = 10;
SET query_cache_min_result_size = 1048576;
SET query_cache_max_entries = 1000000;

-- Check query cache status
SELECT 
    metric, 
    value 
FROM system.metrics 
WHERE metric LIKE '%Cache%';
```



