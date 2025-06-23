-- =============================================
-- ClickHouse Session 6: Performance Optimization - Indexes
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Primary Key Analysis
-- =============================================

-- Show current table structures and primary keys
SHOW CREATE TABLE customers;
SHOW CREATE TABLE policies;
SHOW CREATE TABLE claims;
SHOW CREATE TABLE agents;

-- Analyze primary key effectiveness for policies
SELECT 
    partition,
    name,
    rows,
    bytes_on_disk,
    primary_key_bytes_in_memory,
    marks_count
FROM system.parts
WHERE database = 'life_insurance' 
  AND table = 'policies'
  AND active = 1
ORDER BY partition;

-- =============================================
-- 2. Secondary Indexes
-- =============================================

-- Add secondary indexes for frequently queried columns

-- Customer email index for login/lookup queries
ALTER TABLE customers ADD INDEX idx_customer_email email TYPE bloom_filter() GRANULARITY 1;

-- Policy number index for policy lookup
ALTER TABLE policies ADD INDEX idx_policy_number policy_number TYPE bloom_filter() GRANULARITY 1;

-- Agent license number index
ALTER TABLE agents ADD INDEX idx_agent_license license_number TYPE bloom_filter() GRANULARITY 1;

-- Claim number index for claim tracking
ALTER TABLE claims ADD INDEX idx_claim_number claim_number TYPE bloom_filter() GRANULARITY 1;

-- Coverage amount range index for policies
ALTER TABLE policies ADD INDEX idx_coverage_amount coverage_amount TYPE minmax GRANULARITY 1;

-- Claim amount range index
ALTER TABLE claims ADD INDEX idx_claim_amount claim_amount TYPE minmax GRANULARITY 1;

-- Premium amount range index
ALTER TABLE policies ADD INDEX idx_premium_amount premium_amount TYPE minmax GRANULARITY 1;

-- Date range indexes
ALTER TABLE policies ADD INDEX idx_effective_date effective_date TYPE minmax GRANULARITY 1;
ALTER TABLE claims ADD INDEX idx_reported_date reported_date TYPE minmax GRANULARITY 1;
ALTER TABLE claims ADD INDEX idx_incident_date incident_date TYPE minmax GRANULARITY 1;

-- =============================================
-- 3. Index Usage Analysis
-- =============================================

-- Query to test policy number index
SELECT 
    policy_id,
    customer_id,
    policy_number,
    coverage_amount,
    status
FROM policies
WHERE policy_number = 'POL-2024-001';

-- Query to test customer email index
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    customer_type
FROM customers
WHERE email = 'john.smith@email.com'
  AND _sign > 0;

-- Query to test coverage amount range index
SELECT 
    policy_id,
    policy_number,
    customer_id,
    coverage_amount,
    policy_type
FROM policies
WHERE coverage_amount BETWEEN 500000 AND 1000000
  AND status = 'Active';

-- Query to test claim amount range with date filter
SELECT 
    claim_id,
    policy_id,
    claim_number,
    claim_amount,
    claim_status,
    reported_date
FROM claims
WHERE claim_amount > 100000
  AND reported_date >= '2024-01-01'
  AND _sign > 0;

-- =============================================
-- 4. Index Performance Comparison
-- =============================================

-- Query without using indexes (force full scan)
SELECT 
    count(*) as total_policies,
    avg(coverage_amount) as avg_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE policy_type = 'Term Life'
  AND status = 'Active';

-- Query using primary key efficiently
SELECT 
    p.policy_id,
    p.policy_number,
    p.coverage_amount,
    c.first_name,
    c.last_name
FROM policies p
JOIN customers c ON p.customer_id = c.customer_id
WHERE p.policy_id = '550e8400-e29b-41d4-a716-446655440000';

-- =============================================
-- 5. Composite Index Examples
-- =============================================

-- Add composite index for common query patterns
ALTER TABLE policies ADD INDEX idx_customer_status_type (customer_id, status, policy_type) TYPE bloom_filter() GRANULARITY 1;

-- Add composite index for claims analysis
ALTER TABLE claims ADD INDEX idx_policy_status_type (policy_id, claim_status, claim_type) TYPE bloom_filter() GRANULARITY 1;

-- Add composite index for agent performance queries
ALTER TABLE policies ADD INDEX idx_agent_effective_date (agent_id, effective_date) TYPE minmax GRANULARITY 1;

-- Test composite index usage
SELECT 
    policy_id,
    policy_number,
    coverage_amount,
    premium_amount
FROM policies
WHERE customer_id = 1001
  AND status = 'Active'
  AND policy_type = 'Term Life';

-- =============================================
-- 6. Index Maintenance and Monitoring
-- =============================================

-- Check index usage statistics
SELECT 
    database,
    table,
    name,
    type,
    granularity
FROM system.data_skipping_indices
WHERE database = 'life_insurance'
ORDER BY table, name;

-- Monitor index effectiveness
SELECT 
    table,
    name as index_name,
    type,
    granularity,
    marks_count
FROM system.parts
JOIN system.data_skipping_indices ON 
    system.parts.database = system.data_skipping_indices.database AND
    system.parts.table = system.data_skipping_indices.table
WHERE system.parts.database = 'life_insurance'
  AND system.parts.active = 1;

-- Analyze query performance with EXPLAIN
EXPLAIN SYNTAX 
SELECT 
    p.policy_number,
    p.coverage_amount,
    c.claim_amount,
    c.claim_status
FROM policies p
JOIN claims c ON p.policy_id = c.policy_id
WHERE p.policy_number LIKE 'POL-2024%'
  AND c.claim_amount > 50000;

-- =============================================
-- 7. Index Optimization Recommendations
-- =============================================

-- Find tables that might benefit from additional indexes
SELECT 
    table,
    count(*) as query_count,
    avg(read_rows) as avg_rows_read,
    avg(query_duration_ms) as avg_duration_ms
FROM system.query_log
WHERE database = 'life_insurance'
  AND type = 'QueryFinish'
  AND event_time > now() - INTERVAL 1 DAY
GROUP BY table
HAVING avg_rows_read > 1000
ORDER BY avg_duration_ms DESC;

-- Identify slow queries that might benefit from indexes
SELECT 
    query,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log
WHERE database = 'life_insurance'
  AND type = 'QueryFinish'
  AND query_duration_ms > 1000
  AND event_time > now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC
LIMIT 10;

