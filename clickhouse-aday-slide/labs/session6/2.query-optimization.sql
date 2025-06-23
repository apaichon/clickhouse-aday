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

-- =============================================
-- ClickHouse Session 6: Performance Optimization - Query Optimization
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Query Structure Optimization
-- =============================================

-- BAD: Inefficient query with unnecessary JOINs
-- SELECT 
--     c.first_name,
--     c.last_name,
--     p.policy_number,
--     p.coverage_amount,
--     cl.claim_amount
-- FROM customers c
-- JOIN policies p ON c.customer_id = p.customer_id
-- JOIN claims cl ON p.policy_id = cl.policy_id
-- WHERE c.customer_id = 1001;

-- GOOD: Optimized query with proper filtering
SELECT 
    c.first_name,
    c.last_name,
    p.policy_number,
    p.coverage_amount,
    cl.claim_amount
FROM customers c
JOIN policies p ON c.customer_id = p.customer_id
LEFT JOIN claims cl ON p.policy_id = cl.policy_id AND cl._sign > 0
WHERE c.customer_id = 1001
  AND c._sign > 0
  AND p.status = 'Active';

-- =============================================
-- 2. WHERE Clause Optimization
-- =============================================

-- BAD: Function on indexed column
-- SELECT * FROM policies WHERE toYear(effective_date) = 2024;

-- GOOD: Range condition on indexed column
SELECT 
    policy_id,
    policy_number,
    customer_id,
    coverage_amount,
    effective_date
FROM policies
WHERE effective_date >= '2024-01-01'
  AND effective_date < '2025-01-01'
  AND status = 'Active';

-- BAD: OR conditions that prevent index usage
-- SELECT * FROM claims WHERE claim_status = 'Approved' OR claim_status = 'Paid';

-- GOOD: Use IN clause for multiple values
SELECT 
    claim_id,
    policy_id,
    claim_number,
    claim_amount,
    claim_status
FROM claims
WHERE claim_status IN ('Approved', 'Paid')
  AND _sign > 0;

-- =============================================
-- 3. JOIN Optimization
-- =============================================

-- Optimize JOIN order - put smallest table first
-- Policy and claims analysis with proper JOIN order
SELECT 
    p.policy_type,
    count(p.policy_id) as policy_count,
    count(c.claim_id) as claim_count,
    avg(p.coverage_amount) as avg_coverage,
    sum(c.claim_amount) as total_claims
FROM (
    SELECT policy_id, policy_type, coverage_amount
    FROM policies 
    WHERE status = 'Active'
    AND effective_date >= '2024-01-01'
) p
LEFT JOIN (
    SELECT policy_id, claim_id, claim_amount
    FROM claims
    WHERE _sign > 0
    AND claim_status IN ('Approved', 'Paid')
) c ON p.policy_id = c.policy_id
GROUP BY p.policy_type;

-- Use GLOBAL JOIN for distributed queries
SELECT 
    a.territory,
    count(p.policy_id) as policies_sold,
    sum(p.premium_amount) as total_premiums
FROM agents a
GLOBAL JOIN policies p ON a.agent_id = p.agent_id
WHERE a.is_active = 1
  AND a._sign > 0
  AND p.status = 'Active'
GROUP BY a.territory;

-- =============================================
-- 4. Aggregation Optimization
-- =============================================

-- Use appropriate aggregation functions
SELECT 
    policy_type,
    count() as policy_count,
    uniq(customer_id) as unique_customers,
    sum(coverage_amount) as total_coverage,
    avg(premium_amount) as avg_premium,
    quantile(0.5)(coverage_amount) as median_coverage,
    quantile(0.95)(coverage_amount) as p95_coverage
FROM policies
WHERE status = 'Active'
GROUP BY policy_type
ORDER BY total_coverage DESC;

-- Optimize GROUP BY with proper column order
SELECT 
    toStartOfMonth(effective_date) as month,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(premium_amount) as monthly_premiums
FROM policies
WHERE effective_date >= '2024-01-01'
  AND status = 'Active'
GROUP BY month, policy_type, agent_id
ORDER BY month DESC, monthly_premiums DESC;

-- =============================================
-- 5. Subquery Optimization
-- =============================================

-- BAD: Correlated subquery
-- SELECT * FROM policies p1
-- WHERE coverage_amount > (
--     SELECT avg(coverage_amount) 
--     FROM policies p2 
--     WHERE p2.policy_type = p1.policy_type
-- );

-- GOOD: Convert to JOIN with CTE
WITH policy_type_averages AS (
    SELECT 
        policy_type,
        avg(coverage_amount) as avg_coverage
    FROM policies
    WHERE status = 'Active'
    GROUP BY policy_type
)
SELECT 
    p.policy_id,
    p.policy_number,
    p.policy_type,
    p.coverage_amount,
    pta.avg_coverage,
    p.coverage_amount - pta.avg_coverage as diff_from_avg
FROM policies p
JOIN policy_type_averages pta ON p.policy_type = pta.policy_type
WHERE p.coverage_amount > pta.avg_coverage
  AND p.status = 'Active';

-- =============================================
-- 6. LIMIT and ORDER BY Optimization
-- =============================================

-- Efficient top-N queries
SELECT 
    policy_id,
    policy_number,
    customer_id,
    coverage_amount,
    premium_amount
FROM policies
WHERE status = 'Active'
ORDER BY coverage_amount DESC
LIMIT 100;

-- Use LIMIT BY for getting top records per group
SELECT 
    policy_type,
    policy_id,
    policy_number,
    coverage_amount
FROM policies
WHERE status = 'Active'
ORDER BY policy_type, coverage_amount DESC
LIMIT 5 BY policy_type;

-- =============================================
-- 7. Date and Time Optimization
-- =============================================

-- Efficient date range queries
SELECT 
    toStartOfMonth(reported_date) as month,
    claim_type,
    count() as claim_count,
    sum(claim_amount) as total_amount
FROM claims
WHERE reported_date >= '2024-01-01 00:00:00'
  AND reported_date < '2024-07-01 00:00:00'
  AND _sign > 0
GROUP BY month, claim_type
ORDER BY month, claim_type;

-- Use proper date functions for time-based analysis
SELECT 
    toStartOfWeek(effective_date) as week,
    count() as policies_issued,
    sum(premium_amount) as weekly_premiums
FROM policies
WHERE effective_date >= today() - INTERVAL 12 WEEK
  AND status = 'Active'
GROUP BY week
ORDER BY week;

-- =============================================
-- 8. Memory Usage Optimization
-- =============================================

-- Use DISTINCT efficiently
SELECT DISTINCT
    policy_type,
    status
FROM policies
WHERE effective_date >= '2024-01-01';

-- Use uniq() instead of count(DISTINCT) for large datasets
SELECT 
    agent_id,
    uniq(customer_id) as unique_customers,
    count() as total_policies
FROM policies
WHERE status = 'Active'
GROUP BY agent_id
HAVING unique_customers > 10;

-- =============================================
-- 9. Query Performance Analysis
-- =============================================

-- Analyze query execution plan
EXPLAIN PLAN 
SELECT 
    c.customer_type,
    p.policy_type,
    count() as policy_count,
    avg(p.coverage_amount) as avg_coverage
FROM customers c
JOIN policies p ON c.customer_id = p.customer_id
WHERE c._sign > 0
  AND p.status = 'Active'
  AND p.effective_date >= '2024-01-01'
GROUP BY c.customer_type, p.policy_type;

-- Check query statistics
EXPLAIN SYNTAX
SELECT 
    policy_id,
    policy_number,
    coverage_amount
FROM policies
WHERE policy_number LIKE 'POL-2024%'
  AND coverage_amount > 500000;

-- =============================================
-- 10. Optimization Best Practices Examples
-- =============================================

-- Efficient customer policy summary
WITH customer_summary AS (
    SELECT 
        customer_id,
        count() as policy_count,
        sum(coverage_amount) as total_coverage,
        sum(premium_amount) as total_premiums
    FROM policies
    WHERE status = 'Active'
    GROUP BY customer_id
),
claim_summary AS (
    SELECT 
        p.customer_id,
        count(c.claim_id) as claim_count,
        sum(c.claim_amount) as total_claims
    FROM policies p
    LEFT JOIN claims c ON p.policy_id = c.policy_id AND c._sign > 0
    WHERE p.status = 'Active'
    GROUP BY p.customer_id
)
SELECT 
    cu.customer_id,
    cu.first_name,
    cu.last_name,
    cs.policy_count,
    cs.total_coverage,
    cs.total_premiums,
    COALESCE(cls.claim_count, 0) as claim_count,
    COALESCE(cls.total_claims, 0) as total_claims,
    CASE 
        WHEN cs.total_coverage > 0 
        THEN COALESCE(cls.total_claims, 0) / cs.total_coverage * 100
        ELSE 0 
    END as claim_ratio_percent
FROM customers cu
JOIN customer_summary cs ON cu.customer_id = cs.customer_id
LEFT JOIN claim_summary cls ON cu.customer_id = cls.customer_id
WHERE cu._sign > 0
ORDER BY cs.total_coverage DESC
LIMIT 100;

-- Efficient agent performance report
SELECT 
    a.agent_id,
    a.first_name,
    a.last_name,
    a.territory,
    count(p.policy_id) as policies_sold,
    sum(p.premium_amount) as total_premiums,
    avg(p.coverage_amount) as avg_coverage,
    uniq(p.customer_id) as unique_customers
FROM agents a
JOIN policies p ON a.agent_id = p.agent_id
WHERE a._sign > 0
  AND a.is_active = 1
  AND p.status = 'Active'
  AND p.effective_date >= '2024-01-01'
GROUP BY a.agent_id, a.first_name, a.last_name, a.territory
HAVING policies_sold > 0
ORDER BY total_premiums DESC;