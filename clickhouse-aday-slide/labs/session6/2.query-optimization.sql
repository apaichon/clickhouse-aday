-- =============================================
-- Query Execution Plan Analysis
-- =============================================
EXPLAIN
SELECT *
FROM life_insurance.claims
WHERE claim_status = 'Approved';

-- More detailed explain with settings
EXPLAIN pipeline
SELECT customer_id,
    count() AS policy_count,
    sum(if(policy_type = 'Term Life', 1, 0)) AS term_life_count
FROM life_insurance.policies
WHERE customer_id IN (1001, 1002, 1003)
GROUP BY customer_id;

-- =============================================
-- Query Tree Analysis
-- =============================================
EXPLAIN query tree
SELECT customer_id, 
    count() AS policy_count,
    sum(if(policy_type = 'Term Life', 1, 0)) AS term_life_count
FROM life_insurance.policies
WHERE customer_id IN (1001, 1002, 1003)
GROUP BY customer_id;       
-- =============================================
-- Optimizing WHERE Clauses
-- =============================================
-- Filter Optimization Principles
-- Bad: Non-indexed filter first
SELECT count(*)
FROM policies
WHERE policy_type = 'Term Life'
    AND customer_id = 1001
    AND effective_date >= '2025-01-01';
-- Good: Primary key columns first
SELECT count(*)
FROM policies
WHERE customer_id = 1001
    AND effective_date >= '2025-01-01'
    AND policy_type = 'Term Life';
-- Avoid transformations on indexed columns
-- Bad:
SELECT count(*)
FROM policies
WHERE toDate(effective_date) = '2025-01-01';
-- Good:
SELECT count(*)
FROM policies
WHERE effective_date >= '2025-01-01'
    AND effective_date < '2025-01-02';
-- Partition Pruning
SELECT count(*)
FROM policies
WHERE toYYYYMM(effective_date) = 202501
    AND customer_id = 1001;
SELECT count(*)
FROM claims
WHERE toYYYYMM(reported_date) = 202501 SETTINGS force_optimize_skip_unused_shards = 1;
-- IN Clause Optimization
-- Bad: Large inline list
SELECT count(*)
FROM policies
WHERE customer_id IN (
        1001,
        1002,
        1003,
        1004,
        1005,
        1006,
        1007,
        1008,
        1009,
        1010
        /* hundreds more values */
    );
-- Better: Use a temporary table
WITH [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010] as customer_ids
SELECT count(*)
FROM policies
WHERE customer_id IN customer_ids;
-- =============================================
-- JOIN Optimization
-- =============================================
-- Filter before joining
SELECT p.customer_id,
    c.claim_amount
FROM (
        SELECT *
        FROM policies
        WHERE customer_id = 1001
    ) AS p
    JOIN claims c ON p.policy_id = c.policy_id;
-- Use JOIN hints
SELECT p.customer_id,
    c.claim_amount
FROM policies p
    JOIN
    /* LOCAL */
    claims c ON p.policy_id = c.policy_id
WHERE p.customer_id = 1001;
-- JOIN for time-based matching
SELECT p.customer_id,
    p.effective_date,
    c.claim_amount
FROM policies p
    JOIN claims c USING (policy_id)
    JOIN customers cu ON p.customer_id = cu.customer_id
WHERE c.claim_type = 'Death';
SELECT *
FROM policies
LIMIT 10;
SELECT *
FROM customers
LIMIT 10;
SELECT *
FROM claims
LIMIT 10;
-- JOIN Algorithm Selection
-- Hash join (default, good for equality joins)
SELECT toDate(incident_date) AS incident_date,
    sum(claim_amount) AS total_amount,
    claim_type
FROM policies p
    JOIN claims c ON p.policy_id = c.policy_id
GROUP BY incident_date,
    claim_type SETTINGS join_algorithm = 'hash',
    use_query_cache = true,
    query_cache_min_query_duration = 5000;
-- Grace hash join (for large tables)
SELECT toDate(incident_date) AS incident_date,
    sum(claim_amount) AS total_amount,
    claim_type
FROM policies p
    JOIN claims c ON p.policy_id = c.policy_id
GROUP BY incident_date,
    claim_type SETTINGS join_algorithm = 'grace_hash';
-- Parallel hash join
SELECT toDate(incident_date) AS incident_date,
    sum(claim_amount) AS total_amount,
    claim_type
FROM policies p
    JOIN claims c ON p.policy_id = c.policy_id
GROUP BY incident_date,
    claim_type SETTINGS join_algorithm = 'parallel_hash';
-- Memory Management for JOINs
SET max_bytes_in_join = 1000000000;
-- 1GB
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
SELECT uniq(customer_id)
FROM policies;
-- Instead of: SELECT count(DISTINCT customer_id) FROM policies;
-- For quantiles
SELECT quantileTDigest(0.95)(toFloat64(coverage_amount))
FROM policies;
-- Combine multiple aggregations
SELECT policy_type,
    count() AS count,
    sum(coverage_amount) AS total_coverage,
    round(avg(premium_amount), 2) AS average_premium
FROM policies
WHERE status = 'Active'
GROUP BY policy_type;
-- GROUP BY Optimization
SELECT customer_id,
    toDate(effective_date) AS date,
    count() AS policy_count
FROM policies
WHERE customer_id IN (1001, 1002, 1003)
GROUP BY customer_id,
    date
ORDER BY customer_id,
    date;
-- Use WITH TOTALS for summary rows
SELECT policy_type,
    claim_status,
    sum(claim_amount) AS total
FROM policies p
    JOIN claims c ON p.policy_id = c.policy_id
GROUP BY policy_type,
    claim_status WITH TOTALS
ORDER BY policy_type,
    claim_status;
-- Memory Settings for Aggregation
SET max_bytes_before_external_group_by = 2000000000;
SET group_by_overflow_mode = 'any';
-- =============================================
-- Other Query Optimization Techniques
-- =============================================
-- LIMIT Optimization
-- Use LIMIT with ORDER BY
SELECT *
FROM policies
WHERE customer_id = 1001
ORDER BY effective_date DESC
LIMIT 100;
-- Using LIMIT BY for top-N per group
SELECT customer_id,
    effective_date,
    policy_number
FROM policies
ORDER BY effective_date DESC
LIMIT 5 BY customer_id;
-- Optimizing String Operations
-- Bad
SELECT count(*)
FROM policy_documents
WHERE file_path LIKE '%application%';
-- Better - use a secondary index
ALTER TABLE policy_documents
ADD INDEX file_path_idx file_path TYPE tokenbf_v1(512, 3, 0) GRANULARITY 4;
DROP INDEX file_path_idx ON policy_documents;
-- =============================================
-- Query Cache
-- =============================================
-- Enable query cache (if supported in your version)
SELECT *
FROM policies
WHERE customer_id = 1001 SETTINGS use_query_cache = true,
    query_cache_min_query_duration = 50000;
ALTER TABLE policies
ADD INDEX idx_customer_id customer_id TYPE minmax GRANULARITY 1;
SELECT table,
    name as index_name,
    type,
    granularity
FROM system.data_skipping_indices
WHERE database = 'life_insurance'
ORDER BY table,
    name;
-- =============================================
-- Kill Long-Running Query Example
-- =============================================
SELECT query_id,
    user,
    elapsed,
    query
FROM system.processes
ORDER BY elapsed DESC;
KILL QUERY
WHERE query_id = '8bfe325d-617a-4f9f-ac94-c3f1e6a455ea' SYNC;
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
SELECT c.first_name,
    c.last_name,
    p.policy_number,
    p.coverage_amount,
    cl.claim_amount
FROM customers c
    JOIN policies p ON c.customer_id = p.customer_id
    LEFT JOIN claims cl ON p.policy_id = cl.policy_id
    AND cl._sign > 0
WHERE c.customer_id = 1001
    AND c._sign > 0
    AND p.status = 'Active';
-- =============================================
-- 2. WHERE Clause Optimization
-- =============================================
-- BAD: Function on indexed column
-- SELECT * FROM policies WHERE toYear(effective_date) = 2024;
-- GOOD: Range condition on indexed column
SELECT policy_id,
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
SELECT claim_id,
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
-- Bad
SELECT p.policy_type,
    count(p.policy_id) as policy_count,
    count(c.claim_id) as claim_count,
    avg(p.coverage_amount) as avg_coverage,
    sum(c.claim_amount) as total_claims
FROM (
        SELECT policy_id,
            policy_type,
            coverage_amount
        FROM policies
        WHERE status = 'Active'
            AND effective_date >= '2025-01-01'
    ) p
    LEFT JOIN (
        SELECT policy_id,
            claim_id,
            claim_amount
        FROM claims
        WHERE _sign > 0
            AND claim_status IN ('Approved', 'Paid')
    ) c ON p.policy_id = c.policy_id
GROUP BY p.policy_type 
-- =============================================
-- 4. JOIN Optimization
-- =============================================
-- Use GLOBAL JOIN for distributed queries
SELECT a.territory,
    count(p.policy_id) as policies_sold,
    sum(p.premium_amount) as total_premiums
FROM agents a GLOBAL
    JOIN policies p ON a.agent_id = p.agent_id
WHERE a.is_active = 1
    AND a._sign > 0
    AND p.status = 'Active'
GROUP BY a.territory;
-- =============================================
-- 5. Aggregation Optimization
-- =============================================
-- Use appropriate aggregation functions
SELECT policy_type,
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
SELECT toStartOfMonth(effective_date) as month,
    policy_type,
    agent_id,
    count() as policies_issued,
    sum(premium_amount) as monthly_premiums
FROM policies
WHERE effective_date >= '2024-01-01'
    AND status = 'Active'
GROUP BY month,
    policy_type,
    agent_id
ORDER BY month DESC,
    monthly_premiums DESC;
-- =============================================
-- 6. Subquery Optimization
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
    SELECT policy_type,
        avg(coverage_amount) as avg_coverage
    FROM policies
    WHERE status = 'Active'
    GROUP BY policy_type
)
SELECT p.policy_id,
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
-- 7. LIMIT and ORDER BY Optimization
-- =============================================
-- Efficient top-N queries
SELECT policy_id,
    policy_number,
    customer_id,
    coverage_amount,
    premium_amount
FROM policies
WHERE status = 'Active'
ORDER BY coverage_amount DESC
LIMIT 100;
-- Use LIMIT BY for getting top records per group
SELECT policy_type,
    policy_id,
    policy_number,
    coverage_amount
FROM policies
WHERE status = 'Active'
ORDER BY policy_type,
    coverage_amount DESC
LIMIT 5 BY policy_type;
-- =============================================
-- 8. Date and Time Optimization
-- =============================================
-- Efficient date range queries
SELECT toStartOfMonth(reported_date) as month,
    claim_type,
    count() as claim_count,
    sum(claim_amount) as total_amount
FROM claims
WHERE reported_date >= '2024-01-01 00:00:00'
    AND reported_date < '2024-07-01 00:00:00'
    AND _sign > 0
GROUP BY month,
    claim_type
ORDER BY month,
    claim_type;
-- =============================================
-- 9. Memory Usage Optimization
-- =============================================
-- Use proper date functions for time-based analysis
SELECT toStartOfWeek(effective_date) as week,
    count() as policies_issued,
    sum(premium_amount) as weekly_premiums
FROM policies
WHERE effective_date >= today() - INTERVAL 12 WEEK
    AND status = 'Active'
GROUP BY week
ORDER BY week;
-- =============================================
-- 10. Memory Usage Optimization
-- =============================================
-- Use DISTINCT efficiently
SELECT DISTINCT policy_type,
    status
FROM policies
WHERE effective_date >= '2024-01-01';

-- Use uniq() instead of count(DISTINCT) for large datasets
SELECT agent_id,
    uniq(customer_id) as unique_customers,
    count() as total_policies
FROM policies
WHERE status = 'Active'
GROUP BY agent_id
HAVING unique_customers > 10;
-- =============================================
-- 11. Query Performance Analysis
-- =============================================
-- Analyze table access patterns
SELECT arrayJoin(tables) as table_name,
    count(*) as query_count,
    avg(read_rows) as avg_rows_read,
    avg(query_duration_ms) as avg_duration_ms,
    avg(memory_usage) as avg_memory_usage
FROM system.query_log
WHERE current_database = 'life_insurance'
    AND type = 'QueryFinish'
    AND event_time > now() - INTERVAL 1 DAY
    AND length(tables) > 0
GROUP BY table_name
HAVING avg_rows_read > 1000
    AND table_name != ''
ORDER BY avg_duration_ms DESC;

-- Analyze query execution plan
EXPLAIN PLAN
SELECT c.customer_type,
    p.policy_type,
    count() as policy_count,
    avg(p.coverage_amount) as avg_coverage
FROM customers c
    JOIN policies p ON c.customer_id = p.customer_id
WHERE c._sign > 0
    AND p.status = 'Active'
    AND p.effective_date >= '2024-01-01'
GROUP BY c.customer_type,
    p.policy_type;
-- =============================================
-- Check query statistics for policy queries
EXPLAIN SYNTAX
SELECT policy_id,
    policy_number,
    coverage_amount
FROM policies
WHERE policy_number LIKE 'POL-2024%'
    AND coverage_amount > 500000;
-- =============================================
-- Insurance-Specific Query Optimizations
-- =============================================
-- Efficient agent performance analysis
SELECT a.agent_id,
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
GROUP BY a.agent_id,
    a.first_name,
    a.last_name,
    a.territory
HAVING policies_sold > 0
ORDER BY total_premiums DESC;

-- Claims analysis with proper optimization
SELECT c.claim_type,
    c.claim_status,
    count() as claim_count,
    sum(c.claim_amount) as total_claimed,
    sum(c.approved_amount) as total_approved,
    avg(c.claim_amount) as avg_claim_amount,
    avg(
        dateDiff('day', c.incident_date, c.reported_date)
    ) as avg_reporting_delay
FROM claims c
WHERE c._sign > 0
    AND c.reported_date >= '2024-01-01'
GROUP BY c.claim_type,
    c.claim_status
ORDER BY total_claimed DESC;

-- Customer policy portfolio analysis
WITH customer_summary AS (
    SELECT customer_id,
        count() as policy_count,
        sum(coverage_amount) as total_coverage,
        sum(premium_amount) as total_premiums,
        groupUniqArray(policy_type) as policy_types
    FROM policies
    WHERE status = 'Active'
    GROUP BY customer_id
),
claim_summary AS (
    SELECT p.customer_id,
        count(c.claim_id) as claim_count,
        sum(c.claim_amount) as total_claims,
        sum(c.approved_amount) as total_approved
    FROM policies p
        LEFT JOIN claims c ON p.policy_id = c.policy_id
        AND c._sign > 0
    WHERE p.status = 'Active'
    GROUP BY p.customer_id
)
SELECT cu.customer_id,
    cu.first_name,
    cu.last_name,
    cu.customer_type,
    cs.policy_count,
    cs.total_coverage,
    cs.total_premiums,
    cs.policy_types,
    COALESCE(cls.claim_count, 0) as claim_count,
    COALESCE(cls.total_claims, 0) as total_claims,
    COALESCE(cls.total_approved, 0) as total_approved,
    CASE
        WHEN cs.total_coverage > 0 THEN COALESCE(cls.total_claims, 0) / cs.total_coverage * 100
        ELSE 0
    END as claim_ratio_percent
FROM customers cu
    JOIN customer_summary cs ON cu.customer_id = cs.customer_id
    LEFT JOIN claim_summary cls ON cu.customer_id = cls.customer_id
WHERE cu._sign > 0
    AND cu.is_active = 1
ORDER BY cs.total_coverage DESC
LIMIT 100;
-- =============================================
-- 12. Document Processing Optimization
-- =============================================
-- Document processing optimization
SELECT d.document_type,
    count() as document_count,
    sum(d.file_size) as total_file_size,
    avg(d.file_size) as avg_file_size,
    uniq(d.policy_id) as unique_policies
FROM policy_documents d
WHERE d._sign > 0
    AND d.upload_date >= '2024-01-01'
GROUP BY d.document_type
ORDER BY document_count DESC;
-- =============================================
-- Customer Portfolio Analysis Query
-- =============================================
-- Step 1: Customer Policy Summary
WITH customer_summary AS (
    SELECT customer_id,
        count() as policy_count,
        sum(coverage_amount) as total_coverage,
        sum(premium_amount) as total_premiums,
        groupUniqArray(policy_type) as policy_types
    FROM policies
    WHERE status = 'Active'
    GROUP BY customer_id
),
-- Step 2: Customer Claims Summary
claim_summary AS (
    SELECT p.customer_id,
        count(c.claim_id) as claim_count,
        sum(c.claim_amount) as total_claims,
        sum(c.approved_amount) as total_approved
    FROM policies p
        LEFT JOIN claims c ON p.policy_id = c.policy_id
        AND c._sign > 0
    WHERE p.status = 'Active'
    GROUP BY p.customer_id
) 
-- Step 3: Final Result - Customer Portfolio with Claims Analysis
SELECT cu.customer_id,
    cu.first_name,
    cu.last_name,
    cu.customer_type,
    -- Policy Information
    cs.policy_count,
    cs.total_coverage,
    cs.total_premiums,
    cs.policy_types,
    -- Claims Information
    COALESCE(cls.claim_count, 0) as claim_count,
    COALESCE(cls.total_claims, 0) as total_claims,
    COALESCE(cls.total_approved, 0) as total_approved,
    -- Calculated Metrics
    CASE
        WHEN cs.total_coverage > 0 THEN COALESCE(cls.total_claims, 0) / cs.total_coverage * 100
        ELSE 0
    END as claim_ratio_percent
FROM customers cu
    JOIN customer_summary cs ON cu.customer_id = cs.customer_id
    LEFT JOIN claim_summary cls ON cu.customer_id = cls.customer_id
WHERE cu._sign > 0
    AND cu.is_active = 1
ORDER BY cs.total_coverage DESC
LIMIT 100;