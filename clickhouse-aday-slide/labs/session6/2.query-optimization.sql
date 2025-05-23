-- =============================================
-- Query Execution Plan Analysis
-- =============================================

EXPLAIN SELECT * FROM chat_payments.attachments WHERE payment_status = 'paid';

-- More detailed explain with settings
EXPLAIN pipeline 
SELECT
    user_id,
    count() AS message_count,
    sum(if(message_type = 'invoice', 1, 0)) AS invoice_count
FROM chat_payments.messages
WHERE chat_id IN (100, 101, 102)
GROUP BY user_id;

EXPLAIN query tree
SELECT
    user_id,
    count() AS message_count,
    sum(if(message_type = 'invoice', 1, 0)) AS invoice_count
FROM chat_payments.messages
WHERE chat_id IN (100, 101, 102)
GROUP BY user_id;

-- =============================================
-- Optimizing WHERE Clauses
-- =============================================

-- Filter Optimization Principles

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

-- Partition Pruning
SELECT count(*) FROM messages
WHERE toYYYYMM(sent_timestamp) = 202304
  AND chat_id = 100;

SELECT count(*) FROM attachments
WHERE toYYYYMM(uploaded_at) = 202304
SETTINGS force_optimize_skip_unused_shards = 1;

-- IN Clause Optimization
-- Bad: Large inline list
SELECT count(*) FROM messages
WHERE chat_id IN (
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109
    /* hundreds more values */
);

-- Better: Use a temporary table
WITH [100, 101, 102, 103, 104, 105, 106, 107, 108, 109] as ids
SELECT count(*) FROM messages
WHERE chat_id IN ids;

-- =============================================
-- JOIN Optimization
-- =============================================

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

-- JOIN for time-based matching
SELECT m.user_id, m.sent_timestamp, a.payment_amount
FROM messages m
JOIN attachments a USING (message_id)
JOIN users u USING (user_id)
WHERE m.message_type = 'receipt'
  AND m.sent_timestamp >= a.uploaded_at;

SELECT * FROM messages LIMIT 10;
SELECT * FROM users LIMIT 10;
SELECT * FROM attachments LIMIT 10;

-- JOIN Algorithm Selection

-- Hash join (default, good for equality joins)
SELECT toDate(invoice_date) AS invoice_date, sum(payment_amount) AS total_amount, payment_currency
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
GROUP BY invoice_date, payment_currency
SETTINGS join_algorithm = 'hash', use_query_cache = true, query_cache_min_query_duration = 5000;

-- Grace hash join (for large tables)
SELECT toDate(invoice_date) AS invoice_date, sum(payment_amount) AS total_amount, payment_currency
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
GROUP BY invoice_date, payment_currency
SETTINGS join_algorithm = 'grace_hash';

-- Parallel hash join
SELECT toDate(invoice_date) AS invoice_date, sum(payment_amount) AS total_amount, payment_currency
FROM messages m
JOIN attachments p ON m.message_id = p.message_id
GROUP BY invoice_date, payment_currency
SETTINGS join_algorithm = 'parallel_hash';

-- Memory Management for JOINs
SET max_bytes_in_join = 1000000000; -- 1GB
SET join_overflow_mode = 'break';
SET max_joined_block_size_rows = 500000;

-- For distributed queries
SET distributed_product_mode = 'local';
SET optimize_skip_unused_shards = 1;
SET optimize_distributed_group_by_sharding_key = 1;

-- =============================================
-- Aggregation and GROUP BY Optimization
-- =============================================

-- Efficient Aggregation

-- Use specialized aggregate functions
SELECT uniq(user_id) FROM messages;
-- Instead of: SELECT count(DISTINCT user_id) FROM messages;

-- For quantiles
SELECT quantileTDigest(0.95)(toFloat64(payment_amount)) FROM attachments;

-- Combine multiple aggregations
SELECT
    payment_status,
    count() AS count,
    sum(payment_amount) AS total,
    round(avg(payment_amount), 2) AS average
FROM attachments
GROUP BY payment_status;

-- GROUP BY Optimization
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

-- Memory Settings for Aggregation
SET max_bytes_before_external_group_by = 2000000000;
SET group_by_overflow_mode = 'any';

-- =============================================
-- Other Query Optimization Techniques
-- =============================================

-- LIMIT Optimization

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

-- Optimizing String Operations

-- Bad
SELECT count(*) FROM messages WHERE content LIKE '%payment%';

-- Better - use a secondary index
ALTER TABLE messages
ADD INDEX content_idx content TYPE tokenbf_v1(512, 3, 0)
GRANULARITY 4;

DROP INDEX content_idx ON messages;

-- =============================================
-- Query Cache
-- =============================================

-- Enable query cache (if supported in your version)
SELECT some_expensive_calculation(column_1, column_2)
FROM table
SETTINGS use_query_cache = true, query_cache_min_query_duration = 5000;

-- =============================================
-- Kill Long-Running Query Example
-- =============================================

SELECT * FROM messages;

SELECT
    query_id,
    user,
    elapsed,
    query
FROM system.processes
ORDER BY elapsed DESC;

KILL QUERY WHERE query_id = '8bfe325d-617a-4f9f-ac94-c3f1e6a455ea' SYNC;