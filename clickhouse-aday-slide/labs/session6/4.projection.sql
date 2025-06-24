-- =============================================
-- ClickHouse Session 6: Performance Optimization - Projections
-- Life Insurance Management System
-- =============================================

USE life_insurance;

-- =============================================
-- 1. Basic Projections for Policies Table
-- =============================================

-- Create the policies table with projections defined in CREATE statement
CREATE TABLE policies_projection
(
    policy_id UUID,
    customer_id UInt64,
    agent_id UInt32,
    policy_type Enum8('Term Life' = 1, 'Whole Life' = 2, 'Universal Life' = 3, 'Variable Life' = 4, 'Endowment' = 5),
    policy_number String,
    coverage_amount Decimal64(2),
    premium_amount Decimal64(2),
    deductible_amount Decimal64(2),
    effective_date Date,
    end_date Date,
    status Enum8('Active' = 1, 'Lapsed' = 2, 'Terminated' = 3, 'Matured' = 4, 'Pending' = 5),
    created_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now(),
    version UInt32 DEFAULT 1,
    
    -- Projection 1: Policy Type Analysis
    PROJECTION policy_type_analysis (
        SELECT 
            policy_type,
            status,
            toStartOfMonth(effective_date) as month,
            count() as policy_count,
            sum(coverage_amount) as total_coverage,
            sum(premium_amount) as total_premiums,
            avg(coverage_amount) as avg_coverage
        GROUP BY policy_type, status, month
    ),
    
    -- Projection 2: Customer Portfolio
    PROJECTION customer_portfolio (
        SELECT 
            customer_id,
            agent_id,
            count() as policy_count,
            sum(coverage_amount) as total_coverage,
            sum(premium_amount) as total_premiums,
            groupUniqArray(policy_type) as policy_types,
            max(effective_date) as latest_policy_date
        GROUP BY customer_id, agent_id
    ),
    
    -- Projection 3: Agent Performance
    PROJECTION agent_performance (
        SELECT 
            agent_id,
            policy_type,
            toStartOfMonth(effective_date) as month,
            count() as policies_sold,
            sum(coverage_amount) as total_coverage,
            sum(premium_amount) as total_premiums,
            uniq(customer_id) as unique_customers
        GROUP BY agent_id, policy_type, month
    ),
    
    -- Projection 4: Time-based Analysis
    PROJECTION time_analysis (
        SELECT 
            toStartOfMonth(effective_date) as month,
            toStartOfWeek(effective_date) as week,
            policy_type,
            status,
            count() as policy_count,
            sum(coverage_amount) as total_coverage
        GROUP BY month, week, policy_type, status
    )
)
ENGINE = MergeTree()
PARTITION BY (toYYYYMM(effective_date), policy_type)
ORDER BY (effective_date, customer_id, policy_type, policy_id)
PRIMARY KEY (effective_date, customer_id)
SETTINGS index_granularity = 8192;


insert into policies_projection
select * from policies;

SELECT 
    database,
    table,
    name,
    type
FROM system.projections
WHERE database = 'life_insurance' 
  AND table = 'policies_projection'
ORDER BY name;

-- Projection 1: Policy Type Analysis
 SELECT 
            toStartOfMonth(effective_date) as month,
            toStartOfWeek(effective_date) as week,
            policy_type,
            status,
            count() as policy_count,
            sum(coverage_amount) as total_coverage
            from policies_projection
        GROUP BY month, week, policy_type, status

-- Without projection
 SELECT 
            toStartOfMonth(effective_date) as month,
            toStartOfWeek(effective_date) as week,
            policy_type,
            status,
            count() as policy_count,
            sum(coverage_amount) as total_coverage
            from policies
        GROUP BY month, week, policy_type, status


ALTER TABLE policies_projection 
    DROP PROJECTION policy_type_analysis,
    DROP PROJECTION customer_portfolio,
    DROP PROJECTION agent_performance,
    DROP PROJECTION time_analysis;

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
