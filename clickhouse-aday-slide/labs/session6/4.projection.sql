-- =============================================
-- ClickHouse Session 6: Performance Optimization - Projections
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Basic Projections for Policies Table
-- =============================================

-- Create projection for policy type analysis
ALTER TABLE policies ADD PROJECTION policy_type_projection (
    SELECT 
        policy_type,
        status,
        toStartOfMonth(effective_date) as month,
        count(),
        sum(coverage_amount),
        sum(premium_amount),
        avg(coverage_amount)
    GROUP BY policy_type, status, month
);

-- Create projection for customer analysis
ALTER TABLE policies ADD PROJECTION customer_projection (
    SELECT 
        customer_id,
        agent_id,
        count(),
        sum(coverage_amount),
        sum(premium_amount),
        max(effective_date)
    GROUP BY customer_id, agent_id
);

-- =============================================
-- 2. Claims Table Projections
-- =============================================

-- Create projection for claims analysis by type and status
ALTER TABLE claims ADD PROJECTION claims_analysis_projection (
    SELECT 
        claim_type,
        claim_status,
        toStartOfMonth(reported_date) as month,
        count(),
        sum(claim_amount),
        sum(approved_amount),
        avg(claim_amount)
    GROUP BY claim_type, claim_status, month
);

-- Create projection for policy-based claims analysis
ALTER TABLE claims ADD PROJECTION policy_claims_projection (
    SELECT 
        policy_id,
        customer_id,
        count(),
        sum(claim_amount),
        sum(approved_amount),
        max(reported_date)
    GROUP BY policy_id, customer_id
);

-- =============================================
-- 3. Materialized Projections
-- =============================================

-- Materialize the projections to improve query performance
ALTER TABLE policies MATERIALIZE PROJECTION policy_type_projection;
ALTER TABLE policies MATERIALIZE PROJECTION customer_projection;
ALTER TABLE claims MATERIALIZE PROJECTION claims_analysis_projection;
ALTER TABLE claims MATERIALIZE PROJECTION policy_claims_projection;

-- =============================================
-- 4. Querying with Projections
-- =============================================

-- Query that will use policy_type_projection
SELECT 
    policy_type,
    status,
    toStartOfMonth(effective_date) as month,
    count() as policy_count,
    sum(coverage_amount) as total_coverage,
    avg(coverage_amount) as avg_coverage
FROM policies
WHERE effective_date >= '2024-01-01'
GROUP BY policy_type, status, month
ORDER BY month DESC, policy_type;

-- Query that will use customer_projection
SELECT 
    customer_id,
    agent_id,
    count() as policy_count,
    sum(coverage_amount) as total_coverage,
    sum(premium_amount) as total_premiums
FROM policies
WHERE customer_id IN (1001, 1002, 1003)
GROUP BY customer_id, agent_id;

-- Query that will use claims_analysis_projection
SELECT 
    claim_type,
    claim_status,
    toStartOfMonth(reported_date) as month,
    count() as claim_count,
    sum(claim_amount) as total_claimed,
    sum(approved_amount) as total_approved
FROM claims
WHERE reported_date >= '2024-01-01'
  AND _sign > 0
GROUP BY claim_type, claim_status, month
ORDER BY month DESC, claim_type;

-- =============================================
-- 5. Projection Management
-- =============================================

-- Check projection status
SELECT 
    database,
    table,
    name,
    type,
    query
FROM system.projections
WHERE database = 'life_insurance'
ORDER BY table, name;

-- Monitor projection usage and performance
SELECT 
    table,
    name,
    sum(rows) as total_rows,
    sum(bytes_on_disk) as size_on_disk
FROM system.projection_parts
WHERE database = 'life_insurance'
  AND active = 1
GROUP BY table, name
ORDER BY table, name;

-- =============================================
-- 6. Cleanup (Optional)
-- =============================================

-- Drop projections if needed
-- ALTER TABLE policies DROP PROJECTION policy_type_projection;
-- ALTER TABLE policies DROP PROJECTION customer_projection;
-- ALTER TABLE claims DROP PROJECTION claims_analysis_projection;
-- ALTER TABLE claims DROP PROJECTION policy_claims_projection;
